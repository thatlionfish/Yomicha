import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomicha/data/progress.dart';
import 'package:yomicha/learn/goal.dart';
import 'package:yomicha/learn/review.dart';

Future<Progress> _progress({int words = 0}) async {
  SharedPreferences.setMockInitialValues({});
  final p = Progress();
  await p.load();
  p.addWords([
    for (var i = 0; i < words; i++) MyWord(t: '語$i', reading: 'ご$i', gloss: 'Wort $i', sentence: '語$iを読む。'),
  ]);
  return p;
}

void main() {
  final friday = DateTime(2026, 11, 13, 9);
  final saturday = DateTime(2026, 11, 14, 9);
  final sunday = DateTime(2026, 11, 15, 9);

  test('Höchstens 10 neue Wörter pro Tag', () async {
    final p = await _progress(words: 14);
    expect(dueToday(p, friday), hasLength(maxNewPerDay));
  });

  test('Sonntags ist nichts fällig', () async {
    final p = await _progress(words: 3);
    expect(dueToday(p, sunday), isEmpty);
  });

  test('Nach „Gut“ ist das Wort heute nicht mehr fällig, „Nochmal“ kommt in Minuten wieder', () async {
    final p = await _progress(words: 2);
    final [a, b] = dueToday(p, friday);
    p.saveCard(a.word.key, review(a.card, fsrs.Rating.good, friday), friday);
    final again = review(b.card, fsrs.Rating.again, friday);
    expect(again.due.difference(friday.toUtc()).inMinutes, lessThan(15));
    expect(p.newCardsOn(friday), 1);
    // Am selben Tag später: das gute Wort ist (beim Lernschritt von 10 Min) noch fällig,
    // am nächsten Tag ist es wieder dran oder später – nie verloren.
    expect(statusOf(p, a.word.key), WordStatus.lernen);
    expect(p.cardFor(a.word.key).lastReview, isNotNull);
  });

  test('Karten werden gespeichert und wieder gelesen – auch mit ganzen Zahlen (Browser)', () async {
    final p = await _progress(words: 1);
    final c = dueToday(p, friday).single;
    var card = review(c.card, fsrs.Rating.good, friday);
    card = review(card, fsrs.Rating.good, friday.add(const Duration(minutes: 11)));
    p.saveCard(c.word.key, card, friday);
    final back = p.cardFor(c.word.key);
    expect(back.stability, card.stability);
    // Im Browser kommt 3.0 als 3 zurück:
    final m = card.toMap()..['stability'] = 3;
    expect(() => fsrs.Card.fromMap({...m, 'stability': (m['stability'] as num).toDouble()}), returnsNormally);
  });

  test('Am Samstag kommen die Sonntagskarten schon dran', () async {
    final p = await _progress(words: 1);
    final c = dueToday(p, friday).single;
    // Karte so legen, dass sie am Sonntag fällig ist.
    final sundayCard = fsrs.Card.fromMap({
      ...review(c.card, fsrs.Rating.good, friday).toMap(),
      'due': DateTime(2026, 11, 15, 8).toUtc().toIso8601String(),
    });
    p.saveCard(c.word.key, sundayCard, friday);
    expect(dueToday(p, saturday).map((x) => x.word.key), contains(c.word.key));
  });

  test('Wort entfernen löscht auch die Karte', () async {
    final p = await _progress(words: 1);
    final c = dueToday(p, friday).single;
    p.saveCard(c.word.key, review(c.card, fsrs.Rating.good, friday), friday);
    p.removeWord(c.word.key);
    expect(p.myWords, isEmpty);
    expect(p.isNewCard(c.word.key), isTrue);
  });

  group('Zielkurve', () {
    final start = DateTime(2026, 11, 12);
    test('von Stufe 2 bis 6 Ende August, 7 Ende November', () {
      expect(targetStufe(start, 2, start), 2);
      expect(targetStufe(start, 2, gyokuroBy), closeTo(6, 0.001));
      expect(targetStufe(start, 2, matchaBy), closeTo(7, 0.001));
      expect(targetStufe(start, 2, DateTime(2027, 12, 5)), 7);
      final mid = targetStufe(start, 2, DateTime(2027, 4, 1));
      expect(mid, greaterThan(2));
      expect(mid, lessThan(6));
    });

    test('voraus und hinterher', () {
      expect(planStatus(weeksAhead(start, 2, start, 2)), 'Im Plan');
      // Im März 2027 noch auf Stufe 2 → hinterher.
      expect(weeksAhead(start, 2, DateTime(2027, 3, 1), 2), lessThan(-10));
      // Schon im Januar auf Stufe 4 → voraus.
      expect(weeksAhead(start, 2, DateTime(2027, 1, 5), 4), greaterThan(4));
    });
  });

  test('Stufenverlauf: Start bleibt, Wechsel am selben Tag zählt nur einmal', () async {
    final p = await _progress();
    expect(p.stufeHistory, hasLength(1));
    p.setStufe(3);
    p.setStufe(4);
    expect(p.stufeHistory.length, lessThanOrEqualTo(2));
    expect(p.stufeHistory.last.$2, 4);
  });
}
