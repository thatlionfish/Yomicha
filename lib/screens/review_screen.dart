import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

import '../app_scope.dart';
import '../audio/player.dart';
import '../data/progress.dart';
import '../learn/review.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import '../widgets/kumachan.dart';
import 'words_screen.dart';

/// Wiederholung im Zusammenhang (Spezifikation 12): Ich sehe den Satz, in dem
/// ich das Wort gelesen habe, erinnere mich an Lesung und Bedeutung, decke auf
/// und bewerte mich.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.cards});
  final List<WordCard> cards;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final List<WordCard> _queue = [...widget.cards];
  var _shown = false;
  var _done = 0;

  static const _ratings = [
    (fsrs.Rating.again, 'Nochmal'),
    (fsrs.Rating.hard, 'Schwer'),
    (fsrs.Rating.good, 'Gut'),
    (fsrs.Rating.easy, 'Leicht'),
  ];

  void _rate(fsrs.Rating rating) {
    final progress = AppScope.of(context).progress;
    final now = DateTime.now();
    final current = _queue.removeAt(0);
    final next = review(current.card, rating, now);
    progress.saveCard(current.word.key, next, now);
    // Kommt die Karte in den nächsten 15 Minuten wieder, noch in dieser Runde zeigen.
    if (next.due.difference(now.toUtc()).inMinutes < 15) {
      _queue.add(WordCard(current.word, next, isNew: false));
    } else {
      _done++;
    }
    setState(() => _shown = false);
  }

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    final finished = _queue.isEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(finished ? 'Geschafft' : 'Wiederholen')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: finished ? _summary(progress) : _card(context, _queue.first),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, WordCard c) {
    final w = c.word;
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Text(
          '${widget.cards.length - _queue.length + 1 > widget.cards.length ? widget.cards.length : widget.cards.length - _queue.length + 1} von ${widget.cards.length}'
          '${c.isNew ? ' · neues Wort' : ''}',
          style: sans(13.5, color: YoColors.inkSoft),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(color: YoColors.brightWhite, borderRadius: organicRadius),
          child: Column(
            children: [
              Text(w.t, style: jp(44)),
              if (_shown) ...[
                const SizedBox(height: 4),
                Text(w.reading, style: jp(22, color: YoColors.inkSoft)),
                const SizedBox(height: 8),
                Text(w.gloss, style: sans(19, weight: 560), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                IconButton.filledTonal(
                  tooltip: 'Aussprache',
                  onPressed: () => playClip(wordAudioUrl(context, w)),
                  icon: const Icon(Icons.volume_up_rounded),
                ),
              ],
              if (w.sentence != null) ...[
                const SizedBox(height: 18),
                Text.rich(highlighted(w.sentence!, w.t, size: 18), textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (!_shown)
          FilledButton(
            onPressed: () {
              setState(() => _shown = true);
              playClip(wordAudioUrl(context, w));
            },
            child: const Text('Aufdecken'),
          )
        else ...[
          Text('Wie gut wusstest du es?', style: sans(14, color: YoColors.inkSoft), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (rating, label) in _ratings) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10)),
                    onPressed: () => _rate(rating),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: sans(14.5, weight: 650)),
                        Text(intervalLabel(c.card, rating, now), style: sans(12, color: YoColors.inkSoft)),
                      ],
                    ),
                  ),
                ),
                if (rating != fsrs.Rating.easy) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _summary(Progress progress) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
    children: [
      if (progress.kuma != KumaMode.aus) ...[
        const KumaMoment(mood: 'fertig', height: 130),
        const SizedBox(height: 12),
      ],
      Text('$_done ${_done == 1 ? 'Wort' : 'Wörter'} wiederholt', style: serif(28, weight: 420)),
      const SizedBox(height: 20),
      FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Zurück zu Meinen Wörtern')),
    ],
  );
}
