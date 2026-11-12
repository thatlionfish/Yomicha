import 'calendar.dart';

/// Zielkurve bis zur N2 (Spezifikation 9.4): von der Startstufe bis Stufe 6
/// (Gyokuro, N2) Ende August 2027, danach Prüfungstraining bis Stufe 7 (Matcha).
final gyokuroBy = DateTime(2027, 8, 31);
final matchaBy = DateTime(2027, 11, 30);

/// Ziel-Stufe an einem Tag (Kommazahl, z. B. 3,4).
double targetStufe(DateTime start, int startStufe, DateTime day) {
  double lerp(DateTime a, double va, DateTime b, double vb) {
    final t = day.difference(a).inHours / b.difference(a).inHours;
    return va + (vb - va) * t.clamp(0, 1);
  }

  if (!day.isAfter(start)) return startStufe.toDouble();
  if (!day.isAfter(gyokuroBy)) return lerp(start, startStufe.toDouble(), gyokuroBy, 6);
  if (!day.isAfter(matchaBy)) return lerp(gyokuroBy, 6, matchaBy, 7);
  return 7;
}

/// Wie weit ich vor oder hinter dem Plan liege, in Wochen
/// (positiv = voraus, negativ = hinterher).
int weeksAhead(DateTime start, int startStufe, DateTime today, int stufe) {
  // Der Tag, an dem das Ziel meine Stufe erreicht.
  var lo = start, hi = examDate;
  if (targetStufe(start, startStufe, hi) < stufe) return (hi.difference(today).inDays / 7).round();
  for (var i = 0; i < 40; i++) {
    final mid = lo.add(Duration(hours: hi.difference(lo).inHours ~/ 2));
    if (targetStufe(start, startStufe, mid) < stufe) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (hi.difference(today).inDays / 7).round();
}

/// Kurzer Satz zum Stand: „im Plan“, „2 Wochen voraus“, „3 Wochen hinterher“.
String planStatus(int weeks) {
  if (weeks.abs() <= 1) return 'Im Plan';
  final w = weeks.abs();
  return weeks > 0 ? '$w Wochen voraus' : '$w Wochen hinterher';
}
