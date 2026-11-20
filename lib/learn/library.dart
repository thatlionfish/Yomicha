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

/// Texte für die Startseite: die von heute. Fehlen sie (Teeküche ausgefallen),
/// erst ungelesene der letzten 3 Tage, dann ungelesene aus dem Vorrat, dann
/// ältere ungelesene (Spezifikation 3 und 10). Sonntags keine.
({List<TextEntry> texts, String label}) textsForToday({
  required List<TextEntry> regular,
  required List<TextEntry> stock,
  required Set<String> read,
  required DateTime today,
  required bool rest,
}) {
  if (rest) return (texts: const [], label: '');
  final fresh = regular.where((e) => sameDay(e.date, today)).take(2).toList();
  if (fresh.isNotEmpty) {
    return (texts: fresh, label: fresh.length == 1 ? 'Dein Text für heute' : 'Deine Texte für heute');
  }
  bool unread(TextEntry e) => !read.contains(e.id);
  final lately = regular.where((e) => unread(e) && today.difference(e.date).inDays <= 3).take(2).toList();
  if (lately.isNotEmpty) return (texts: lately, label: 'Noch nicht gelesen');
  final fromStock = stock.where(unread).take(2).toList();
  if (fromStock.isNotEmpty) return (texts: fromStock, label: 'Aus dem Vorrat');
  return (texts: regular.where(unread).take(2).toList(), label: 'Noch nicht gelesen');
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Die Texte von heute für meine Stufe – dieselbe Auswahl wie auf der Startseite.
List<TextEntry> heutigeTexte(
  List<TextEntry> index, {
  required int stufe,
  required Set<String> read,
  required DateTime today,
}) {
  final visible = visibleTexts(index, today);
  final regular = textsForStufe([
    for (final e in visible)
      if (!e.vorrat) e,
  ], stufe);
  final stock = textsForStufe([
    for (final e in visible)
      if (e.vorrat) e,
  ], stufe);
  return textsForToday(
    regular: regular,
    stock: stock,
    read: read,
    today: today,
    rest: today.weekday == DateTime.sunday,
  ).texts;
}
