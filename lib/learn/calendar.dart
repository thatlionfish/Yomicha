/// Lerntage und Ruhetag (Spezifikation 1, 9.4).
///
/// Sonntag ist Leonis Ruhetag: keine neuen Texte, nichts fällig, und die
/// Lernserie läuft trotzdem weiter.
library;

/// Prüfungstermin der JLPT N2 (Spezifikation 9.4).
final examDate = DateTime(2027, 12, 5);

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

bool isRestDay(DateTime d) => d.weekday == DateTime.sunday;

/// Lerntage (Montag bis Samstag) von [from] einschließlich bis zum Tag vor
/// [until]. Der Prüfungstag selbst zählt nicht.
int learningDaysBetween(DateTime from, DateTime until) {
  var d = _day(from);
  final end = _day(until);
  var n = 0;
  while (d.isBefore(end)) {
    if (!isRestDay(d)) n++;
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return n;
}

/// Lernserie: Lerntage in Folge mit gelesenem Text, rückwärts ab [today].
/// Sonntage werden übersprungen und unterbrechen die Serie nie. Ist heute
/// noch nichts gelesen, zählt die Serie bis gestern.
int streak(Set<DateTime> readDays, DateTime today) {
  final days = {for (final d in readDays) _day(d)};
  var d = _day(today);
  if (!days.contains(d)) d = DateTime(d.year, d.month, d.day - 1);
  var n = 0;
  while (true) {
    if (isRestDay(d)) {
      d = DateTime(d.year, d.month, d.day - 1);
      continue;
    }
    if (!days.contains(d)) break;
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}
