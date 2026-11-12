import 'package:flutter_test/flutter_test.dart';
import 'package:yomicha/learn/calendar.dart';

void main() {
  test('Sonntag ist Ruhetag', () {
    expect(isRestDay(DateTime(2026, 11, 15)), isTrue); // Sonntag
    expect(isRestDay(DateTime(2026, 11, 14)), isFalse); // Samstag
    expect(isRestDay(DateTime(2027, 12, 5)), isTrue); // Prüfungstag
  });

  test('Lerntage bis zur Prüfung zählen keine Sonntage', () {
    // Do, 12.11.2026 bis Sa, 4.12.2027: 388 Tage, davon 55 Sonntage.
    expect(learningDaysBetween(DateTime(2026, 11, 12), examDate), 333);
    // Eine Woche ab Montag: 6 Lerntage.
    expect(learningDaysBetween(DateTime(2026, 11, 16), DateTime(2026, 11, 23)), 6);
  });

  test('Der Sonntag unterbricht die Lernserie nicht', () {
    final read = {
      DateTime(2026, 11, 13), // Fr
      DateTime(2026, 11, 14), // Sa
      DateTime(2026, 11, 16), // Mo
    };
    expect(streak(read, DateTime(2026, 11, 16)), 3);
    // Am Dienstag vor dem Lesen zählt die Serie bis Montag.
    expect(streak(read, DateTime(2026, 11, 17)), 3);
    // Am Sonntag selbst bleibt die Serie stehen.
    expect(streak(read, DateTime(2026, 11, 15)), 2);
    // Ein ausgelassener Lerntag beendet sie.
    expect(streak(read, DateTime(2026, 11, 18)), 0);
  });
}
