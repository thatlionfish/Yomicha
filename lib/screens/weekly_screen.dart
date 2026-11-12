import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../data/progress.dart';
import '../learn/library.dart';
import '../learn/weekly.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import '../widgets/furigana.dart';
import '../widgets/kumachan.dart';

/// Wochentest: Fragen zu den Texten der Woche, mit Auswertung pro Bereich.
class WeeklyScreen extends StatefulWidget {
  const WeeklyScreen({super.key, required this.weekStart, this.docs});
  final DateTime weekStart;

  /// Nur für Tests: Texte direkt übergeben.
  final List<TextDoc>? docs;

  @override
  State<WeeklyScreen> createState() => _WeeklyScreenState();
}

class _WeeklyScreenState extends State<WeeklyScreen> {
  List<WeeklyQuestion>? _qs;
  Object? _error;
  var _index = 0;
  int? _chosen;
  final _right = <WeeklySection, int>{};
  final _total = <WeeklySection, int>{};
  final _wrongWords = <MyWord>[];
  var _saved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_qs == null && _error == null) _load();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    try {
      var docs = widget.docs;
      if (docs == null) {
        final all = await scope.repo.index();
        final week = textsForStufe(
          visibleTexts(all, DateTime.now()).where((e) => inWeek(e.date, widget.weekStart)).toList(),
          scope.progress.stufe,
        );
        docs = [for (final e in week) await scope.repo.text(e.folder)];
      }
      final qs = buildWeeklyTest(docs: docs, progress: scope.progress, weekStart: widget.weekStart);
      if (mounted) setState(() => _qs = qs);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _choose(int i) {
    if (_chosen != null) return;
    final q = _qs![_index];
    setState(() {
      _chosen = i;
      _total[q.section] = (_total[q.section] ?? 0) + 1;
      if (i == q.answer) {
        _right[q.section] = (_right[q.section] ?? 0) + 1;
      } else if (q.word != null) {
        _wrongWords.add(q.word!);
      }
    });
  }

  void _next() => setState(() {
    _index++;
    _chosen = null;
    if (_index >= _qs!.length) _save();
  });

  void _save() {
    if (_saved) return;
    _saved = true;
    AppScope.of(context).progress.addWeekly(WeeklyResult(
      weekStart: widget.weekStart,
      sections: {for (final s in _total.keys) s.label: (_right[s] ?? 0, _total[s]!)},
    ));
  }

  @override
  Widget build(BuildContext context) {
    final qs = _qs;
    final done = qs != null && _index >= qs.length;
    return Scaffold(
      appBar: AppBar(title: Text(done ? 'Wochentest geschafft' : 'Wochentest · KW ${isoWeek(widget.weekStart)}')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _error != null
              ? Padding(padding: const EdgeInsets.all(24), child: Text('$_error'))
              : qs == null
              ? const Center(child: CircularProgressIndicator())
              : qs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('In dieser Woche gab es noch keine Texte für einen Test.', style: sans(16)),
                )
              : done
              ? _summary(context)
              : _question(qs[_index], qs.length),
        ),
      ),
    );
  }

  Widget _question(WeeklyQuestion q, int n) {
    final answered = _chosen != null;
    final right = _chosen == q.answer;
    final single = q.section == WeeklySection.wortschatz || q.section == WeeklySection.lesung || q.section == WeeklySection.grammatik;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Text('Frage ${_index + 1} von $n · ${q.section.label}', style: sans(13.5, color: YoColors.inkSoft)),
        const SizedBox(height: 14),
        if (q.excerpt != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(color: YoColors.brightWhite, borderRadius: organicRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (q.excerptTitle != null)
                  Text('Aus „${q.excerptTitle}“', style: sans(12.5, color: YoColors.inkSoft)),
                const SizedBox(height: 6),
                FuriganaFlow(
                  sentences: [(0, q.excerpt!)],
                  fontSize: 18,
                  rules: const FuriganaRules(mode: FuriganaMode.alle, userJlpt: 5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (single)
          Center(child: Text(q.prompt, style: jp(40)))
        else
          RubyText(q.prompt, fontSize: 20),
        const SizedBox(height: 6),
        if (q.promptDe.isNotEmpty)
          Text(q.promptDe, style: sans(15, color: YoColors.inkSoft), textAlign: single ? TextAlign.center : TextAlign.start),
        const SizedBox(height: 16),
        for (var i = 0; i < q.options.length; i++) ...[
          _Option(
            text: q.options[i],
            japanese: q.japaneseOptions,
            state: !answered
                ? 0
                : i == q.answer
                ? 1
                : i == _chosen
                ? 2
                : 3,
            onTap: () => _choose(i),
          ),
          const SizedBox(height: 10),
        ],
        if (answered) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                right ? Icons.check_circle_rounded : Icons.lightbulb_outline_rounded,
                color: right ? YoColors.lemonGrass : YoColors.chocolate,
                size: 26,
              ),
              const SizedBox(width: 8),
              Text(right ? 'Richtig!' : 'Fast.', style: sans(17, weight: 650)),
            ],
          ),
          const SizedBox(height: 6),
          Text(q.explain, style: sans(15.5, height: 1.5)),
          const SizedBox(height: 18),
          FilledButton(onPressed: _next, child: Text(_index + 1 < _qs!.length ? 'Nächste Frage' : 'Auswertung')),
        ],
      ],
    );
  }

  Widget _summary(BuildContext context) {
    final progress = AppScope.of(context).progress;
    final correct = _right.values.fold(0, (a, b) => a + b);
    final total = _total.values.fold(0, (a, b) => a + b);
    final ratio = total == 0 ? 1.0 : correct / total;
    final previous = progress.weeklyResults.where((r) => r.weekStart.isBefore(widget.weekStart)).toList();
    final last = previous.isEmpty ? null : previous.last;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        if (progress.kuma != KumaMode.aus) ...[
          KumaMoment(mood: ratio == 1 ? 'perfekt' : ratio < 0.5 ? 'rueckschlag' : 'fertig', height: 130),
          const SizedBox(height: 12),
        ],
        Text('$correct von $total richtig', style: serif(30, weight: 420)),
        if (last != null)
          Text(
            'Letzte Woche: ${last.correct} von ${last.total} (${(100 * last.correct / last.total).round()} %)',
            style: sans(15, color: YoColors.inkSoft),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(color: YoColors.vanillaIce, borderRadius: organicRadius),
          child: Column(
            children: [
              for (final s in WeeklySection.values)
                if (_total[s] != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(s.label, style: sans(15, weight: 600))),
                        Text('${_right[s] ?? 0} von ${_total[s]}', style: sans(15)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        if (_wrongWords.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Zum Üben: ${_wrongWords.length} ${_wrongWords.length == 1 ? 'Wort' : 'Wörter'}', style: sans(16, weight: 650)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final w in _wrongWords)
                Text.rich(TextSpan(children: [
                  TextSpan(text: w.t, style: jp(18)),
                  TextSpan(text: '  ${w.reading}', style: jp(13.5, color: YoColors.inkSoft)),
                ])),
            ],
          ),
          const SizedBox(height: 10),
          ListenableBuilder(
            listenable: progress,
            builder: (context, _) {
              final all = _wrongWords.every((w) => progress.hasWord(w.key));
              return OutlinedButton.icon(
                onPressed: all ? null : () => progress.addWords(_wrongWords),
                icon: Icon(all ? Icons.check_rounded : Icons.add_rounded),
                label: Text(all ? 'In „Meine Wörter“' : 'Zu „Meinen Wörtern“'),
              );
            },
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const Text('Zur Startseite'),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.text, required this.japanese, required this.state, required this.onTap});
  final String text;
  final bool japanese;

  /// 0 offen, 1 richtig, 2 falsch gewählt, 3 andere.
  final int state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: state == 2 ? YoColors.woodAsh : YoColors.brightWhite,
    shape: RoundedRectangleBorder(
      borderRadius: organicRadius,
      side: state == 1
          ? const BorderSide(color: YoColors.lemonGrass, width: 3)
          : const BorderSide(color: YoColors.sand, width: 1.4),
    ),
    child: InkWell(
      customBorder: const RoundedRectangleBorder(borderRadius: organicRadius),
      onTap: state == 0 ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(child: japanese ? RubyText(text, fontSize: 19) : Text(text, style: sans(16))),
            if (state == 1) const Icon(Icons.check_rounded, color: YoColors.chocolate),
          ],
        ),
      ),
    ),
  );
}
