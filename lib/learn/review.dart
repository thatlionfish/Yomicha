import 'dart:math';

import 'package:fsrs/fsrs.dart' as fsrs;

import '../data/progress.dart';
import 'calendar.dart';

/// Wiederholung von „Meine Wörter“ mit FSRS (Spezifikation 12).
final scheduler = fsrs.Scheduler();

/// Höchstens so viele Wiederholungen und neue Wörter pro Tag.
const maxReviewsPerDay = 20;
const maxNewPerDay = 10;

class WordCard {
  const WordCard(this.word, this.card, {required this.isNew});
  final MyWord word;
  final fsrs.Card card;
  final bool isNew;
}

enum WordStatus {
  neu('neu'),
  lernen('im Lernen'),
  sicher('sicher');

  const WordStatus(this.label);
  final String label;
}

/// Neu, im Lernen oder sicher (Stabilität ab 21 Tagen).
WordStatus statusOf(Progress p, String key) {
  if (p.isNewCard(key)) return WordStatus.neu;
  final c = p.cardFor(key);
  return c.state == fsrs.State.review && (c.stability ?? 0) >= 21 ? WordStatus.sicher : WordStatus.lernen;
}

DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

/// Die Karten für heute. Sonntags ist nichts fällig; am Samstag kommen die
/// Karten von Sonntag schon dran (Spezifikation 12).
List<WordCard> dueToday(Progress p, DateTime now) {
  if (isRestDay(now)) return const [];
  var cutoff = _endOfDay(now);
  if (now.weekday == DateTime.saturday) cutoff = cutoff.add(const Duration(days: 1));
  final reviews = <WordCard>[];
  final fresh = <WordCard>[];
  for (final w in p.myWords.values) {
    final isNew = p.isNewCard(w.key);
    final card = p.cardFor(w.key);
    if (isNew) {
      fresh.add(WordCard(w, card, isNew: true));
    } else if (!card.due.toLocal().isAfter(cutoff)) {
      reviews.add(WordCard(w, card, isNew: false));
    }
  }
  reviews.sort((a, b) => a.card.due.compareTo(b.card.due));
  final newLeft = max(0, maxNewPerDay - p.newCardsOn(now));
  return [...reviews.take(maxReviewsPerDay), ...fresh.take(newLeft)];
}

/// Bewertet eine Karte und gibt die neue Karte zurück.
fsrs.Card review(fsrs.Card card, fsrs.Rating rating, DateTime now) =>
    scheduler.reviewCard(card, rating, reviewDateTime: now.toUtc()).card;

/// Wann die Karte bei dieser Bewertung wiederkommt, z. B. „10 Min“ oder „3 Tage“.
String intervalLabel(fsrs.Card card, fsrs.Rating rating, DateTime now) {
  final copy = fsrs.Card.fromMap(card.toMap());
  final next = review(copy, rating, now);
  final d = next.due.difference(now.toUtc());
  if (d.inMinutes < 60) return '${max(1, d.inMinutes)} Min';
  if (d.inHours < 24) return '${d.inHours} Std';
  if (d.inDays < 14) return d.inDays == 1 ? '1 Tag' : '${d.inDays} Tage';
  if (d.inDays < 60) return '${(d.inDays / 7).round()} Wo';
  return '${(d.inDays / 30).round()} Mon';
}
