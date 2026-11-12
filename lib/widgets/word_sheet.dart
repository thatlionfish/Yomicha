import 'package:flutter/material.dart';

import '../audio/player.dart';
import '../data/audio_key.dart';
import '../data/models.dart';
import '../data/progress.dart';
import '../data/repository.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import 'furigana.dart';
import 'kanji_card.dart';

String jlptLabel(int? j) => j == null ? 'nicht in den JLPT-Listen' : 'N$j';

/// Das angetippte Wort als Eintrag für „Meine Wörter“.
MyWord myWordOf(Token t, Sentence sentence, TextDoc doc) => MyWord(
  t: t.t,
  reading: t.reading,
  gloss: t.gloss ?? '',
  sentence: sentence.plain,
  textId: doc.id,
);

/// Wortleiste (Spezifikation 4.2): Lesung, Bedeutung, Grundform, Stufe,
/// Kanji und „Meine Wörter“. Wer ein Wort antippt, will es lernen: Es kommt
/// gleich in „Meine Wörter“ (Wörter ohne Bedeutung nicht) und lässt sich in
/// der Leiste wieder entfernen.
Future<void> showWordSheet(
  BuildContext context, {
  required Token token,
  required Sentence sentence,
  required TextDoc doc,
  required Repository repo,
  required Progress progress,
}) {
  final word = myWordOf(token, sentence, doc);
  if (word.gloss.isNotEmpty && !progress.hasWord(word.key)) progress.addWords([word]);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _WordSheet(
      token: token,
      sentence: sentence,
      doc: doc,
      repo: repo,
      progress: progress,
    ),
  );
}

class _WordSheet extends StatelessWidget {
  const _WordSheet({
    required this.token,
    required this.sentence,
    required this.doc,
    required this.repo,
    required this.progress,
  });

  final Token token;
  final Sentence sentence;
  final TextDoc doc;
  final Repository repo;
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final t = token;
    final grammar = t.grammar == null ? null : doc.grammar[t.grammar];
    final word = myWordOf(t, sentence, doc);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: FuriganaFlow(
                    sentences: [(0, [t])],
                    fontSize: 34,
                    rules: const FuriganaRules(mode: FuriganaMode.alle, userJlpt: 5),
                  ),
                ),
                const SizedBox(width: 12),
                if (wantsWordAudio(t))
                  IconButton.filledTonal(
                    tooltip: 'Aussprache',
                    onPressed: () => playClip(repo.audioUrl(wordAudioPath(t))),
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (t.hasKanji) Text(t.reading, style: jp(20, color: YoColors.inkSoft)),
            const SizedBox(height: 12),
            if (t.gloss != null) Text(t.gloss!, style: sans(19, weight: 560)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(jlptLabel(t.jlpt)),
                if (t.base != null && t.base != t.t) _chip('Grundform: ${t.base}'),
              ],
            ),
            if (grammar != null) ...[
              const SizedBox(height: 18),
              _GrammarBox(grammar: grammar),
            ],
            if (t.kanji.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Kanji', style: sans(13.5, weight: 650, color: YoColors.inkSoft)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final k in t.kanji)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(64, 64),
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () => showKanjiCard(
                        context,
                        kanji: k,
                        repo: repo,
                        progress: progress,
                        doc: doc,
                      ),
                      child: Text(k, style: kanjiStyle(32)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            ListenableBuilder(
              listenable: progress,
              builder: (context, _) {
                final has = progress.hasWord(word.key);
                return has
                    ? Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: YoColors.chocolate, size: 22),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Gespeichert in „Meine Wörter“', style: sans(15, weight: 600))),
                          TextButton(
                            onPressed: () => progress.removeWord(word.key),
                            child: const Text('Entfernen'),
                          ),
                        ],
                      )
                    : FilledButton.icon(
                        onPressed: () => progress.toggleWord(word),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Meine Wörter'),
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: const BoxDecoration(color: YoColors.vanillaIce, borderRadius: organicRadius),
    child: Text(label, style: sans(13.5, weight: 600)),
  );
}

class _GrammarBox extends StatelessWidget {
  const _GrammarBox({required this.grammar});
  final GrammarPoint grammar;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: YoColors.vanillaIce,
      borderRadius: organicRadius,
      border: const Border(left: BorderSide(color: YoColors.lemonGrass, width: 4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(grammar.pattern, style: jp(20, weight: FontWeight.w600)),
            const SizedBox(width: 10),
            Text('Grammatik · N${grammar.jlpt}', style: sans(13, color: YoColors.inkSoft)),
          ],
        ),
        const SizedBox(height: 6),
        Text(grammar.de, style: sans(15.5)),
        if (grammar.example != null) ...[
          const SizedBox(height: 10),
          RubyText(grammar.example!, fontSize: 17),
          if (grammar.exampleDe != null)
            Text(grammar.exampleDe!, style: sans(14, color: YoColors.inkSoft)),
        ],
      ],
    ),
  );
}

/// Grammatik-Erklärung als eigene Leiste (Liste unter dem Text).
Future<void> showGrammarSheet(BuildContext context, GrammarPoint g) => showModalBottomSheet(
  context: context,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (_) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: _GrammarBox(grammar: g),
    ),
  ),
);
