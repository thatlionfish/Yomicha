import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../audio/player.dart';
import '../data/models.dart';
import '../data/progress.dart';
import '../data/stufen.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import '../widgets/exam.dart';
import '../widgets/furigana.dart';
import '../widgets/speak_sheet.dart';
import '../widgets/word_sheet.dart';

/// Ein Text in zwei Durchgängen (Spezifikation 4 und 8, Wunsch vom 19.11.2026):
/// 1. **Prüfungsdurchgang** wie in der JLPT – Text und Fragen auf einer Seite,
///    ohne Nachschlagen, Vorlesen oder Übersetzung. Nur dieses Ergebnis zählt
///    für die Einstufung.
/// 2. **Lernrunde** – derselbe Text mit allem: Wörter antippen (kommen in
///    „Meine Wörter“), Grammatik, Vorlesen, Nachsprechen; die Stellen zu den
///    falschen Antworten sind markiert.
class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key, required this.folder});
  final String folder;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

enum _Phase { exam, result, study }

class _ReadingScreenState extends State<ReadingScreen> {
  TextDoc? _doc;
  Object? _error;
  Map<String, int?> _kanjiLevels = const {};
  SentencePlayer? _player;
  final _revealed = <WordRef>{};
  final _lookups = <String, Token>{};
  WordRef? _selected;
  final _watch = Stopwatch();
  double _fontSize = 24;

  var _phase = _Phase.exam;
  final _chosen = <int, int>{};

  /// Lesezeit: vom Öffnen bis zur ersten Antwort (danach wird geantwortet).
  int? _readSeconds;

  /// Sätze zu den falsch beantworteten Fragen (in der Lernrunde markiert).
  Set<int> _marked = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_doc == null && _error == null) _load();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    try {
      final doc = await scope.repo.text(widget.folder);
      final kanji = await scope.repo.kanjiFor([
        for (final t in [...doc.title, for (final s in doc.sentences) ...s.tokens]) ...t.kanji,
      ]);
      if (!mounted) return;
      // Schon im Prüfungsdurchgang gelesen (z. B. aus dem Archiv): gleich die Lernrunde.
      final done = scope.progress.reads.where((r) => r.id == doc.id && r.total > 0).toList();
      setState(() {
        _doc = doc;
        _kanjiLevels = {for (final e in kanji.entries) e.key: e.value.jlpt};
        _player = SentencePlayer(
          [
            for (final s in doc.sentences)
              s.audio == null ? null : scope.repo.audioUrl('${doc.folder}/${s.audio}'),
          ],
          rate: scope.progress.rate,
        )..addListener(() => setState(() {}));
        if (done.isNotEmpty) {
          _phase = _Phase.study;
          _marked = wrongEvidence(doc, done.last.wrong);
        }
      });
      _watch.start();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  // --- Prüfungsdurchgang ----------------------------------------------------

  void _choose(int q, int o) => setState(() {
    _readSeconds ??= _watch.elapsed.inSeconds;
    _chosen[q] = o;
  });

  Future<int?> _askRating() => showModalBottomSheet<int>(
    context: context,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Wie war der Text?', style: serif(22)),
            const SizedBox(height: 16),
            for (final (value, label) in [(-1, 'Zu leicht'), (0, 'Passt'), (1, 'Zu schwer')]) ...[
              OutlinedButton(onPressed: () => Navigator.pop(context, value), child: Text(label)),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    final doc = _doc!;
    final seconds = _readSeconds ?? _watch.elapsed.inSeconds;
    final rating = await _askRating();
    if (rating == null || !mounted) return;
    _watch.stop();
    final qs = doc.questions;
    final wrong = [for (final (i, q) in qs.indexed) if (_chosen[i] != q.answer) i];
    final now = DateTime.now();
    AppScope.of(context).progress.addRead(
      ReadRecord(
        id: doc.id,
        day: DateTime(now.year, now.month, now.day),
        seconds: seconds,
        chars: doc.chars,
        correct: qs.length - wrong.length,
        total: qs.length,
        lookups: 0,
        rating: rating,
        usedAudio: false,
        textStufe: doc.stufe,
        words: doc.contentWords,
        wrong: wrong,
      ),
    );
    setState(() {
      _readSeconds = seconds;
      _marked = wrongEvidence(doc, wrong);
      _phase = qs.isEmpty ? _Phase.study : _Phase.result;
    });
  }

  // --- Lernrunde ------------------------------------------------------------

  void _tap(WordRef ref, Token t) {
    final scope = AppScope.of(context);
    final doc = _doc!;
    setState(() {
      _revealed.add(ref);
      _selected = ref;
    });
    _lookups['${t.t}|${t.reading}'] = t;
    showWordSheet(
      context,
      token: t,
      sentence: ref.sentence < 0 ? Sentence(tokens: doc.title) : doc.sentences[ref.sentence],
      doc: doc,
      repo: scope.repo,
      progress: scope.progress,
    ).then((_) {
      if (mounted) setState(() => _selected = null);
    });
  }

  void _finishStudy() {
    _player?.pause();
    final progress = AppScope.of(context).progress;
    // Nachgeschlagene Wörter vermerken – sie zählen nicht für die Einstufung.
    final last = progress.reads.where((r) => r.id == _doc!.id).lastOrNull;
    if (last != null && _lookups.isNotEmpty) {
      progress.addRead(
        ReadRecord(
          id: last.id,
          day: last.day,
          seconds: last.seconds,
          chars: last.chars,
          correct: last.correct,
          total: last.total,
          lookups: _lookups.length,
          rating: last.rating,
          usedAudio: _player?.used ?? false,
          textStufe: last.textStufe,
          words: last.words,
          wrong: last.wrong,
        ),
      );
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final doc = _doc;
    final study = _phase == _Phase.study;
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_phase) {
          _Phase.exam => 'Prüfungsdurchgang',
          _Phase.result => 'Auswertung',
          _Phase.study => 'Lernrunde',
        }),
        actions: [
          if (_phase != _Phase.result) ...[
            IconButton(
              tooltip: 'Schrift kleiner',
              onPressed: () => setState(() => _fontSize = (_fontSize - 2).clamp(18, 36)),
              icon: const Icon(Icons.text_decrease_rounded),
            ),
            IconButton(
              tooltip: 'Schrift größer',
              onPressed: () => setState(() => _fontSize = (_fontSize + 2).clamp(18, 36)),
              icon: const Icon(Icons.text_increase_rounded),
            ),
          ],
          if (study)
            ListenableBuilder(
              listenable: scope.progress,
              builder: (context, _) => PopupMenuButton<FuriganaMode>(
                tooltip: 'Furigana',
                icon: const Icon(Icons.translate_rounded),
                initialValue: scope.progress.furigana,
                onSelected: scope.progress.setFurigana,
                itemBuilder: (_) => [
                  for (final m in FuriganaMode.values)
                    CheckedPopupMenuItem(
                      value: m,
                      checked: m == scope.progress.furigana,
                      child: Text('Furigana: ${m.label}'),
                    ),
                ],
              ),
            ),
        ],
      ),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$_error')))
          : doc == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: switch (_phase) {
                  _Phase.exam => _examBody(doc),
                  _Phase.result => ExamResult(
                    doc: doc,
                    chosen: _chosen,
                    seconds: _readSeconds ?? 0,
                    progress: scope.progress,
                    onStudy: () => setState(() => _phase = _Phase.study),
                  ),
                  _Phase.study => _studyBody(doc),
                },
              ),
            ),
      bottomNavigationBar: doc == null || !study || !(_player?.available ?? false) ? null : _audioBar(),
    );
  }

  Widget _meta(TextDoc doc) {
    final stufe = Stufe.of(doc.stufe);
    return Text(
      '${topicLabels[doc.topic] ?? doc.topic} · Stufe ${stufe.nr} ${stufe.name} (${stufe.label}) · '
      '≈ ${(doc.chars / 80).ceil()} Min',
      style: sans(13.5, color: YoColors.inkSoft),
    );
  }

  Widget _banner(String text) => Container(
    padding: const EdgeInsets.all(14),
    decoration: const BoxDecoration(
      color: YoColors.vanillaIce,
      borderRadius: organicRadius,
      border: Border(left: BorderSide(color: YoColors.woodAsh, width: 4)),
    ),
    child: Text(text, style: sans(14, height: 1.4)),
  );

  Widget _examBody(TextDoc doc) {
    final scope = AppScope.of(context);
    // Wie in der Prüfung: Furigana nur für Kanji oberhalb meiner Stufe, sonst keine Hilfe.
    final rules = FuriganaRules(
      mode: FuriganaMode.aus,
      userJlpt: Stufe.of(scope.progress.stufe).jlpt,
      kanjiLevels: _kanjiLevels,
    );
    final qs = doc.questions;
    final all = _chosen.length == qs.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        _banner(
          'Wie in der Prüfung: ohne Nachschlagen, ohne Vorlesen, ohne Übersetzung. '
          'Lies den Text und beantworte die Fragen darunter. Danach lernst du den Text mit allen Hilfen.',
        ),
        const SizedBox(height: 14),
        _meta(doc),
        const SizedBox(height: 10),
        FuriganaFlow(sentences: [(-1, doc.title)], fontSize: _fontSize + 6, rules: rules),
        const SizedBox(height: 18),
        for (final para in doc.paragraphs) ...[
          FuriganaFlow(
            sentences: [for (final i in para) (i, doc.sentences[i].tokens)],
            fontSize: _fontSize,
            rules: rules,
          ),
          SizedBox(height: _fontSize * 0.9),
        ],
        if (qs.isNotEmpty) ...[
          const Divider(color: YoColors.sand, height: 24),
          Text('問題', style: jp(22, weight: FontWeight.w600)),
          Text('次の文章を読んで、質問に答えなさい。答えは1・2・3・4から一つ選びなさい。', style: jp(15, color: YoColors.inkSoft)),
          ExamQuestions(questions: qs, chosen: _chosen, onChoose: _choose),
        ],
        const SizedBox(height: 22),
        if (_chosen.isEmpty)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: doc.versions[doc.stufe - 1] == null ? null : () => _switch(doc.versions[doc.stufe - 1]!),
                  child: const Text('Leichter'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: doc.versions[doc.stufe + 1] == null ? null : () => _switch(doc.versions[doc.stufe + 1]!),
                  child: const Text('Schwerer'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: qs.isEmpty || all ? _submit : null,
          child: Text(qs.isEmpty ? 'Fertig gelesen' : all ? 'Abgeben' : 'Noch ${qs.length - _chosen.length} offen'),
        ),
      ],
    );
  }

  Widget _studyBody(TextDoc doc) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.progress,
      builder: (context, _) {
        final rules = FuriganaRules(
          mode: scope.progress.furigana,
          userJlpt: Stufe.of(scope.progress.stufe).jlpt,
          kanjiLevels: _kanjiLevels,
        );
        final usedGrammar = <String>{
          for (final s in doc.sentences)
            for (final t in s.tokens)
              if (t.grammar != null) t.grammar!,
        };
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            _banner(
              'Lernrunde: Tippe Wörter und Kanji an, die du nicht kennst – sie kommen in „Meine Wörter“.'
              '${_marked.isEmpty ? '' : ' Markiert sind die Stellen zu deinen falschen Antworten.'}',
            ),
            const SizedBox(height: 14),
            _meta(doc),
            const SizedBox(height: 10),
            FuriganaFlow(
              sentences: [(-1, doc.title)],
              fontSize: _fontSize + 6,
              rules: rules,
              revealed: _revealed,
              selected: _selected,
              onTap: _tap,
            ),
            Text(doc.titleDe, style: sans(14.5, color: YoColors.inkSoft)),
            const SizedBox(height: 18),
            for (final para in doc.paragraphs) ...[
              FuriganaFlow(
                sentences: [for (final i in para) (i, doc.sentences[i].tokens)],
                fontSize: _fontSize,
                rules: rules,
                revealed: _revealed,
                currentSentence: _player?.playing == true ? _player?.current : null,
                markedSentences: _marked,
                selected: _selected,
                onTap: _tap,
              ),
              SizedBox(height: _fontSize * 0.9),
            ],
            if (usedGrammar.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Grammatik in diesem Text', style: sans(13.5, weight: 650, color: YoColors.inkSoft)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in usedGrammar)
                    if (doc.grammar[id] case final g?)
                      ActionChip(
                        label: Text(g.pattern, style: jp(16)),
                        backgroundColor: YoColors.vanillaIce,
                        side: BorderSide.none,
                        shape: const RoundedRectangleBorder(borderRadius: organicRadius),
                        onPressed: () => showGrammarSheet(context, g),
                      ),
                ],
              ),
            ],
            if (doc.sources.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Quellen: ${doc.sources.map((s) => s.name).join(', ')}', style: sans(13, color: YoColors.inkSoft)),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _finishStudy, child: const Text('Fertig')),
          ],
        );
      },
    );
  }

  void _switch(String folder) => Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => ReadingScreen(folder: folder)),
  );

  Widget _audioBar() {
    final p = _player!;
    final scope = AppScope.of(context);
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: YoColors.brightWhite,
          border: Border(top: BorderSide(color: YoColors.sand)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Satz zurück',
                  onPressed: p.previous,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                IconButton.filled(
                  tooltip: p.playing ? 'Pause' : 'Vorlesen',
                  onPressed: p.toggle,
                  iconSize: 30,
                  icon: Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
                IconButton(
                  tooltip: 'Satz vor',
                  onPressed: p.next,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.current == null ? 'Vorlesen' : 'Satz ${p.current! + 1} von ${p.urls.length}',
                    style: sans(14, color: YoColors.inkSoft),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final r = p.rate == 1.0 ? 0.75 : 1.0;
                    p.setRate(r);
                    scope.progress.setRate(r);
                  },
                  child: Text(p.rate == 1.0 ? '1×' : '0,75×'),
                ),
                IconButton(
                  tooltip: 'Nachsprechen',
                  onPressed: () {
                    p.pause();
                    showSpeakSheet(context, doc: _doc!, start: p.current ?? 0);
                  },
                  icon: const Icon(Icons.mic_none_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
