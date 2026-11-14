import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomicha/data/progress.dart';
import 'package:yomicha/learn/wochenbilanz.dart';

Future<Progress> _fresh() async {
  SharedPreferences.setMockInitialValues({});
  final p = Progress();
  await p.load();
  return p;
}

var _n = 0;
ReadRecord _read(DateTime day, {int correct = 3, int total = 4, int lookups = 2, int seconds = 120, bool audio = false}) =>
    ReadRecord(
      id: 'text-${_n++}-2',
      day: day,
      seconds: seconds,
      chars: 240,
      correct: correct,
      total: total,
      lookups: lookups,
      rating: 0,
      usedAudio: audio,
      textStufe: 2,
      words: 40,
    );

void main() {
  final lastMonday = DateTime(2026, 11, 9);
  final thisMonday = DateTime(2026, 11, 16);

  test('Kennzahlen einer Woche', () async {
    final p = await _fresh();
    p.addRead(_read(DateTime(2026, 11, 16), correct: 3, total: 4, lookups: 4));
    p.addRead(_read(DateTime(2026, 11, 18), correct: 4, total: 4, lookups: 0, seconds: 60));
    p.addRead(_read(DateTime(2026, 11, 19), audio: true, seconds: 300)); // mit Vorlesen: zählt nicht fürs Tempo
    p.addRead(_read(DateTime(2026, 11, 12))); // Vorwoche
    p.addWords(const [MyWord(t: '香り', reading: 'かおり', gloss: 'Duft')]);
    p.addWeekly(WeeklyResult(weekStart: thisMonday, sections: const {'Wortschatz': (4, 5), 'Lesen': (2, 4)}));

    final w = weekStats(p, thisMonday);
    expect(w.texts, 3);
    expect(w.correct, closeTo(10 / 12, 1e-9));
    expect(w.speed, closeTo(480 * 60 / 180, 1e-9)); // 2 Texte à 240 Zeichen in 180 s
    expect(w.test, closeTo(6 / 9, 1e-9));
    expect(w.testSections['Lesen'], 0.5);
    expect(weekStats(p, lastMonday).texts, 1);
  });

  test('Besser und schlechter – weniger nachschlagen ist besser', () {
    WeekStats w(DateTime m, {double? correct, double? looked, double? speed}) => WeekStats(
      weekStart: m, texts: 3, correct: correct, speed: speed, looked: looked, newWords: 0, test: null, testSections: const {});
    final changes = veraenderungen(
      w(lastMonday, correct: 0.70, looked: 0.10, speed: 140),
      w(thisMonday, correct: 0.85, looked: 0.06, speed: 142),
    );
    final by = {for (final c in changes) c.kennzahl: c};
    expect(by[Kennzahl.correct]!.besser, isTrue);
    expect(by[Kennzahl.correct]!.kennzahl.formatDelta(by[Kennzahl.correct]!.delta), '+15 Prozentpunkte');
    expect(by[Kennzahl.looked]!.besser, isTrue);
    expect(by[Kennzahl.speed]!.spuerbar, isFalse); // 2 Zeichen/Min sind Zufall
    expect(by.containsKey(Kennzahl.test), isFalse); // kein Test in beiden Wochen
  });

  test('Die letzten 8 Wochen enden mit der laufenden', () async {
    final p = await _fresh();
    final weeks = lastWeeks(p, DateTime(2026, 11, 19));
    expect(weeks, hasLength(8));
    expect(weeks.last.weekStart, thisMonday);
    expect(weeks.first.weekStart, DateTime(2026, 9, 28));
    expect(weeks.every((w) => w.isEmpty), isTrue);
  });

  test('Stand bis zum Aufstieg', () async {
    final p = await _fresh();
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    expect(aufstiegStand(p), contains('Noch 5 Texte'));
    for (var i = 0; i < 5; i++) {
      p.addRead(_read(today, correct: 2, total: 4, lookups: 1));
    }
    expect(aufstiegStand(p), contains('50 % richtig'));
  });
}
