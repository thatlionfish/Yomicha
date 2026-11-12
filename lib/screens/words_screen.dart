import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../audio/player.dart';
import '../data/audio_key.dart';
import '../data/models.dart';
import '../data/progress.dart';
import '../learn/calendar.dart';
import '../learn/review.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import 'review_screen.dart';

/// Satz mit hervorgehobenem Wort.
InlineSpan highlighted(String sentence, String word, {double size = 19}) {
  final base = jp(size);
  if (word.isEmpty || !sentence.contains(word)) return TextSpan(text: sentence, style: base);
  final parts = sentence.split(word);
  return TextSpan(children: [
    for (var i = 0; i < parts.length; i++) ...[
      TextSpan(text: parts[i], style: base),
      if (i < parts.length - 1)
        TextSpan(
          text: word,
          style: base.copyWith(
            backgroundColor: YoColors.sand,
            decoration: TextDecoration.underline,
            decorationColor: YoColors.chocolate,
          ),
        ),
    ],
  ]);
}

/// Aussprache eines gespeicherten Wortes (dieselbe Datei wie in der Wortleiste).
String wordAudioUrl(BuildContext context, MyWord w) =>
    AppScope.of(context).repo.audioUrl(wordAudioPath(Token(t: w.t, r: w.reading)));

/// „Meine Wörter“ (Spezifikation 12): alle gespeicherten Wörter mit Stand,
/// dazu die Wiederholung für heute. Die Wörter bleiben, auch wenn die Texte
/// gelöscht werden – Satz, Lesung und Bedeutung speichert die App selbst.
class WordsScreen extends StatelessWidget {
  const WordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    return Scaffold(
      appBar: AppBar(title: const Text('Meine Wörter')),
      body: ListenableBuilder(
        listenable: progress,
        builder: (context, _) {
          final now = DateTime.now();
          final due = dueToday(progress, now);
          final words = progress.myWords.values.toList().reversed.toList();
          final counts = {for (final s in WordStatus.values) s: 0};
          for (final w in words) {
            counts[statusOf(progress, w.key)] = counts[statusOf(progress, w.key)]! + 1;
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(color: YoColors.brightWhite, borderRadius: organicRadius),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRestDay(now)
                              ? 'Sonntag – heute ist nichts fällig.'
                              : due.isEmpty
                              ? 'Heute ist nichts mehr fällig.'
                              : 'Heute zu wiederholen: ${due.length} ${due.length == 1 ? 'Wort' : 'Wörter'}',
                          style: sans(17, weight: 650),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${counts[WordStatus.neu]} neu · ${counts[WordStatus.lernen]} im Lernen · ${counts[WordStatus.sicher]} sicher',
                          style: sans(14, color: YoColors.inkSoft),
                        ),
                        if (due.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => ReviewScreen(cards: due)),
                            ),
                            child: const Text('Wiederholen'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (words.isEmpty)
                    Text(
                      'Noch keine Wörter. Tippe beim Lesen auf ein Wort und dann auf „＋ Meine Wörter“.',
                      style: sans(15.5, height: 1.5),
                    ),
                  for (final w in words)
                    _WordRow(word: w, status: statusOf(progress, w.key), onTap: () => _details(context, w)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _details(BuildContext context, MyWord w) {
    final progress = AppScope.of(context).progress;
    final card = progress.cardFor(w.key);
    final status = statusOf(progress, w.key);
    showModalBottomSheet<void>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(w.t, style: jp(34)),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    tooltip: 'Aussprache',
                    onPressed: () => playClip(wordAudioUrl(context, w)),
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
                ],
              ),
              Text(w.reading, style: jp(18, color: YoColors.inkSoft)),
              const SizedBox(height: 8),
              Text(w.gloss, style: sans(18, weight: 560)),
              if (w.sentence != null) ...[
                const SizedBox(height: 14),
                Text.rich(highlighted(w.sentence!, w.t, size: 18)),
              ],
              const SizedBox(height: 14),
              Text(
                status == WordStatus.neu
                    ? 'Noch nicht wiederholt.'
                    : '${status.label} · nächste Wiederholung: ${_date(card.due.toLocal())}',
                style: sans(14, color: YoColors.inkSoft),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  progress.removeWord(w.key);
                  Navigator.pop(sheet);
                },
                icon: const Icon(Icons.remove_circle_outline_rounded),
                label: const Text('Aus „Meine Wörter“ entfernen'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _date(DateTime d) => '${d.day}.${d.month}.${d.year}';
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.word, required this.status, required this.onTap});
  final MyWord word;
  final WordStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: word.t, style: jp(21)),
                  TextSpan(text: '  ${word.reading}', style: jp(14, color: YoColors.inkSoft)),
                ])),
                Text(word.gloss, style: sans(14.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: status == WordStatus.sicher ? YoColors.brightWhite : YoColors.vanillaIce,
              borderRadius: organicRadius,
              border: status == WordStatus.sicher ? Border.all(color: YoColors.lemonGrass, width: 2) : null,
            ),
            child: Text(status.label, style: sans(12.5, weight: 600)),
          ),
        ],
      ),
    ),
  );
}
