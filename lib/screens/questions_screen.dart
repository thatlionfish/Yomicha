import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../data/progress.dart';
import '../learn/calendar.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import '../widgets/furigana.dart';
import '../widgets/kumachan.dart';

/// Fragen zum Text im Stil der JLPT (Spezifikation 8).
class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({
    super.key,
    required this.doc,
    required this.seconds,
    required this.lookups,
    required this.rating,
    required this.usedAudio,
  });

  final TextDoc doc;
  final int seconds;
  final List<Token> lookups;
  final int rating;
  final bool usedAudio;

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  var _index = 0;
  int? _chosen;
  var _correct = 0;
  var _showDe = false;
  var _saved = false;
  final _wrong = <int>[];

  List<Question> get _qs => widget.doc.questions;
  bool get _done => _index >= _qs.length;

  void _choose(int i) {
    if (_chosen != null) return;
    setState(() {
      _chosen = i;
      if (i == _qs[_index].answer) {
        _correct++;
      } else {
        _wrong.add(_index);
      }
    });
  }

  void _next() => setState(() {
    _index++;
    _chosen = null;
    _showDe = false;
    if (_done) _save();
  });

  void _save() {
    if (_saved) return;
    _saved = true;
    final now = DateTime.now();
    AppScope.of(context).progress.addRead(
      ReadRecord(
        id: widget.doc.id,
        day: DateTime(now.year, now.month, now.day),
        seconds: widget.seconds,
        chars: widget.doc.chars,
        correct: _correct,
        total: _qs.length,
        lookups: widget.lookups.length,
        rating: widget.rating,
        usedAudio: widget.usedAudio,
        wrong: List.of(_wrong),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_done ? 'Geschafft' : 'Fragen zum Text')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _done ? _summary(context) : _question(context, _qs[_index]),
        ),
      ),
    );
  }

  Widget _question(BuildContext context, Question q) {
    final answered = _chosen != null;
    final right = _chosen == q.answer;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Text(
          'Frage ${_index + 1} von ${_qs.length} · ${q.kind == 'sprache' ? 'Sprache' : 'Inhalt'}',
          style: sans(13.5, color: YoColors.inkSoft),
        ),
        const SizedBox(height: 12),
        RubyText(q.q, fontSize: 21),
        if (q.qDe != null && widget.doc.stufe <= 3)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showDe = !_showDe),
              child: Text(_showDe ? q.qDe! : 'Auf Deutsch'),
            ),
          ),
        const SizedBox(height: 12),
        for (var i = 0; i < q.options.length; i++) ...[
          _Option(
            number: i + 1,
            markup: q.options[i],
            state: !answered
                ? _OptionState.open
                : i == q.answer
                ? _OptionState.right
                : i == _chosen
                ? _OptionState.wrong
                : _OptionState.other,
            onTap: () => _choose(i),
          ),
          const SizedBox(height: 10),
        ],
        if (answered) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                right ? Icons.check_circle_rounded : Icons.lightbulb_outline_rounded,
                color: right ? YoColors.lemonGrass : YoColors.chocolate,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(right ? 'Richtig!' : 'Fast – richtig ist Antwort ${q.answer + 1}.', style: sans(17, weight: 650)),
            ],
          ),
          const SizedBox(height: 8),
          Text(q.explain, style: sans(15.5, height: 1.55)),
          if (!right && AppScope.of(context).progress.kuma == KumaMode.oft) ...[
            const SizedBox(height: 10),
            KumaMoment(key: ValueKey('hinweis-$_index'), mood: 'hinweis', height: 96),
          ],
          if (q.evidence.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Hier steht es im Text', style: sans(13.5, weight: 650, color: YoColors.inkSoft)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(color: YoColors.brightWhite, borderRadius: organicRadius),
              child: FuriganaFlow(
                sentences: [
                  for (final i in [...q.evidence]..sort()) (i, widget.doc.sentences[i].tokens),
                ],
                fontSize: 19,
                rules: const FuriganaRules(mode: FuriganaMode.alle, userJlpt: 5),
                markedSentences: {q.evidence.first},
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _next,
            child: Text(_index + 1 < _qs.length ? 'Nächste Frage' : 'Auswertung'),
          ),
        ],
      ],
    );
  }

  Widget _summary(BuildContext context) {
    final progress = AppScope.of(context).progress;
    final minutes = widget.seconds / 60;
    final speed = minutes > 0 ? (widget.doc.chars / minutes).round() : 0;
    final words = [
      for (final t in widget.lookups)
        if (t.gloss != null) MyWord(t: t.t, reading: t.reading, gloss: t.gloss!, textId: widget.doc.id),
    ];
    final ratio = _qs.isEmpty ? 1.0 : _correct / _qs.length;
    final serie = streak(progress.readDays, DateTime.now());
    final mood = ratio == 1
        ? 'perfekt'
        : ratio < 0.5
        ? 'rueckschlag'
        : serie >= 3
        ? 'serie'
        : 'fertig';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        if (progress.kuma != KumaMode.aus) ...[
          KumaMoment(mood: mood, height: 130),
          const SizedBox(height: 12),
        ],
        Text('$_correct von ${_qs.length} richtig', style: serif(30, weight: 420)),
        if (serie >= 2) Text('Lernserie: $serie Tage', style: sans(15, color: YoColors.inkSoft)),
        const SizedBox(height: 8),
        Text(
          'Lesezeit ${widget.seconds ~/ 60}:${(widget.seconds % 60).toString().padLeft(2, '0')} Min'
          // Unter 20 Sekunden wurde nicht wirklich gelesen – kein Tempo.
          '${widget.usedAudio ? ' (mit Vorlesen)' : widget.seconds < 20 ? '' : ' · $speed Zeichen pro Minute'}',
          style: sans(15.5, color: YoColors.inkSoft),
        ),
        const SizedBox(height: 22),
        Text(
          words.isEmpty ? 'Kein Wort nachgeschlagen.' : 'Nachgeschlagen: ${words.length} Wörter',
          style: sans(16, weight: 650),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final w in words)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(color: YoColors.brightWhite, borderRadius: organicRadius),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: w.t, style: jp(18)),
                  TextSpan(text: '  ${w.reading}  ', style: jp(13.5, color: YoColors.inkSoft)),
                  TextSpan(text: w.gloss, style: sans(13.5)),
                ])),
              ),
          ],
        ),
        if (words.isNotEmpty) ...[
          const SizedBox(height: 14),
          ListenableBuilder(
            listenable: progress,
            builder: (context, _) {
              final all = words.every((w) => progress.hasWord(w.key));
              return OutlinedButton.icon(
                onPressed: all ? null : () => progress.addWords(words),
                icon: Icon(all ? Icons.check_rounded : Icons.add_rounded),
                label: Text(all ? 'Alle in „Meine Wörter“' : 'Alle zu „Meine Wörtern“'),
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

enum _OptionState { open, right, wrong, other }

class _Option extends StatelessWidget {
  const _Option({required this.number, required this.markup, required this.state, required this.onTap});
  final int number;
  final String markup;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = switch (state) {
      _OptionState.right => YoColors.brightWhite,
      _OptionState.wrong => YoColors.woodAsh,
      _ => YoColors.brightWhite,
    };
    final border = switch (state) {
      _OptionState.right => const BorderSide(color: YoColors.lemonGrass, width: 3),
      _ => const BorderSide(color: YoColors.sand, width: 1.4),
    };
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: organicRadius, side: border),
      child: InkWell(
        customBorder: const RoundedRectangleBorder(borderRadius: organicRadius),
        onTap: state == _OptionState.open ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(width: 28, child: Text('$number', style: sans(16, weight: 650, color: YoColors.inkSoft))),
              Expanded(child: RubyText(markup, fontSize: 19)),
              if (state == _OptionState.right) const Icon(Icons.check_rounded, color: YoColors.chocolate),
            ],
          ),
        ),
      ),
    );
  }
}
