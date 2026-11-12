import '../data/models.dart';

/// Texte, die heute schon sichtbar sind. Texte mit späterem Datum
/// (Ferienpaket) erscheinen erst an ihrem Tag.
List<TextEntry> visibleTexts(List<TextEntry> all, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  return all.where((e) => !e.date.isAfter(day)).toList();
}

/// Jeder Inhalt steht in mehreren Stufen; gezeigt wird meine Stufe, sonst
/// pro Inhalt die nächstliegende (die anderen erreicht man über „leichter / schwerer“).
List<TextEntry> textsForStufe(List<TextEntry> all, int stufe) {
  final best = <String, TextEntry>{};
  for (final e in all) {
    final content = e.id.replaceFirst(RegExp(r'-\d$'), '');
    final old = best[content];
    if (old == null || (e.stufe - stufe).abs() < (old.stufe - stufe).abs()) best[content] = e;
  }
  return best.values.toList()..sort((a, b) => b.date.compareTo(a.date));
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
