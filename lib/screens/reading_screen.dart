import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../audio/player.dart';
import '../data/models.dart';
import '../data/progress.dart';
import '../data/stufen.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import '../widgets/furigana.dart';
import '../widgets/speak_sheet.dart';
import '../widgets/word_sheet.dart';
import 'questions_screen.dart';

/// Lesen (Spezifikation 4) mit Vorlesen (6).
class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key, required this.folder});
  final String folder;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

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

  Future<void> _finish() async {
    _watch.stop();
    _player?.pause();
    final rating = await showModalBottomSheet<int>(
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
    if (rating == null || !mounted) {
      _watch.start();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuestionsScreen(
          doc: _doc!,
          seconds: _watch.elapsed.inSeconds,
          lookups: _lookups.values.toList(),
          rating: rating,
          usedAudio: _player?.used ?? false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final doc = _doc;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesen'),
        actions: [
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
          : _body(context, doc),
      bottomNavigationBar: doc == null || !(_player?.available ?? false) ? null : _audioBar(),
    );
  }

  Widget _body(BuildContext context, TextDoc doc) {
    final scope = AppScope.of(context);
    final stufe = Stufe.of(doc.stufe);
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
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                Text(
                  '${topicLabels[doc.topic] ?? doc.topic} · Stufe ${stufe.nr} ${stufe.name} (${stufe.label}) · '
                  '≈ ${(doc.chars / 80).ceil()} Min',
                  style: sans(13.5, color: YoColors.inkSoft),
                ),
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
                  Text('Quellen: ${doc.sources.map((s) => s.name).join(', ')}',
                      style: sans(13, color: YoColors.inkSoft)),
                ],
                const SizedBox(height: 20),
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
                FilledButton(onPressed: _finish, child: const Text('Fertig gelesen')),
              ],
            ),
          ),
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
