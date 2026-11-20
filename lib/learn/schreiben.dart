import 'dart:math';

import 'package:fsrs/fsrs.dart' as fsrs;

import '../data/models.dart';
import '../data/progress.dart';
import '../data/schreib_plan.dart';
import '../data/schreib_stand.dart';
import 'calendar.dart';

/// „Kanji schreiben“ (Spezifikation 19): Tagesplan, neue Kanji und Wörter,
/// fällige Karten, Bewertung und die Auswahl der Lesungen.

/// Höchstens so viele Wiederholungen pro Tag.
const maxSchreibWiederholungen = 100;

/// Eine Karte der Schreibübung: ein Kanji (wenn es nicht allein als Wort
/// vorkommt) oder ein Wort.
class SchreibKarte {
  const SchreibKarte.kanji(String this.kanji) : wort = null;
  const SchreibKarte.wort(SchreibWort this.wort) : kanji = null;
  final String? kanji;
  final SchreibWort? wort;

  String get key => kanji != null ? 'k:$kanji' : 'w:${wort!.key}';
  String get text => kanji ?? wort!.t;
}

/// Alle Wörter zum Schreiben: die JLPT-Liste und meine Wörter aus den Texten.
/// Steht ein Wort in beiden, gilt meine Fassung mit dem Satz aus dem Text.
List<SchreibWort> alleWoerter(SchreibPlan plan, Iterable<MyWord> myWords, Set<String> kana) {
  final mine = <String, SchreibWort>{};
  final sorted = myWords.toList()..sort((a, b) => (a.added ?? DateTime(2000)).compareTo(b.added ?? DateTime(2000)));
  for (final w in sorted) {
    final sw = SchreibWort(t: w.t, r: w.reading, n: 0, en: w.gloss, de: w.gloss, satz: w.sentence, textId: w.textId);
    if (sw.kanji.isEmpty) continue;
    final ok = w.t.split('').every((c) => plan.lernKanji(c) || kana.contains(c));
    if (ok) mine[sw.key] = sw;
  }
  return [
    for (final w in plan.woerter)
      if (mine.remove(w.key) case final m?)
        SchreibWort(t: w.t, r: w.r, n: w.n, en: w.en, de: m.de ?? w.de, satz: m.satz ?? w.satz, textId: m.textId)
      else
        w,
    ...mine.values,
  ];
}

/// Die nächsten [n] neuen Kanji: zuerst Kanji aus Wörtern meiner Texte (mit
/// ihren Bestandteilen davor), dann die Reihenfolge des Plans.
List<String> naechsteKanji(SchreibPlan plan, SchreibStand st, Iterable<MyWord> myWords, int n) {
  final out = <String>[];
  void add(String k, [Set<String> seen = const {}]) {
    if (out.length >= n || st.kann(k) || out.contains(k) || !plan.lernKanji(k) || seen.contains(k)) return;
    for (final p in plan.teile[k] ?? const <String>[]) {
      add(p, {...seen, k});
    }
    if (out.length < n) out.add(k);
  }

  final fromTexts = myWords.where((w) => w.textId != null).toList()
    ..sort((a, b) => (a.added ?? DateTime(2000)).compareTo(b.added ?? DateTime(2000)));
  for (final w in fromTexts) {
    for (final k in kanjiOfWord(w.t)) {
      add(k);
    }
  }
  for (final k in plan.reihenfolge) {
    if (out.length >= n) break;
    add(k);
  }
  return out;
}

/// Verdeckt die Kanji von [wort] in einem Hinweistext (Bedeutung, Satz,
/// Geschichte), damit ich sie beim Schreiben aus dem Kopf nicht abschreibe.
String verdecke(String text, String wort) {
  final ks = {for (final k in kanjiOf(wort)) if (k != '々') k};
  if (ks.isEmpty) return text;
  return text.split('').map((c) => ks.contains(c) ? '〇' : c).join();
}

/// Kanji eines Wortes ohne 々.
List<String> kanjiOfWord(String t) => SchreibWort(t: t, r: '', n: 0, en: '').kanji;

/// Wie viele neue Kanji heute noch dran sind (sonntags keine).
int neueKanjiHeute(SchreibStand st, DateTime now) =>
    isRestDay(now) ? 0 : max(0, st.zielAm(now) - st.kanjiAm(now));

/// Neue Wörter für heute: zuerst die Wörter der zuletzt gelernten Kanji
/// (ältere Lektionen zuerst), dann meine Wörter aus den Texten, dann Wörter
/// aus Kanji, die ich schon vorher konnte. [auch] sind Kanji, die gerade in
/// der Lektion gelernt werden.
List<SchreibWort> neueWoerter(
  SchreibStand st,
  List<SchreibWort> alle,
  DateTime now, {
  Set<String> auch = const {},
  int? limit,
}) {
  if (isRestDay(now)) return const [];
  final left = limit ?? max(0, st.woerterProTag - st.neueWoerterAm(now));
  if (left == 0) return const [];
  final today = SchreibStand.tagKey(now);
  String? lektion(SchreibWort w) {
    String? newest;
    for (final k in w.kanji) {
      final d = auch.contains(k) ? today : st.gelernt[k];
      if (d == null) return 'x';
      if (d != 'v' && (newest == null || d.compareTo(newest) > 0)) newest = d;
    }
    return newest;
  }

  final lesson = <(String, int, SchreibWort)>[];
  final own = <SchreibWort>[];
  final old = <SchreibWort>[];
  for (var i = 0; i < alle.length; i++) {
    final w = alle[i];
    if (st.hatKarte('w:${w.key}')) continue;
    final d = lektion(w);
    if (d == 'x') continue;
    if (d != null) {
      lesson.add((d, i, w));
    } else if (w.ausText) {
      own.add(w);
    } else {
      old.add(w);
    }
  }
  lesson.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  return [for (final (_, _, w) in lesson) w, ...own, ...old].take(left).toList();
}

DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

/// Fällige Karten (sonntags keine; samstags schon die von Sonntag).
List<SchreibKarte> faelligeKarten(SchreibStand st, Map<String, SchreibWort> woerter, DateTime now) {
  if (isRestDay(now)) return const [];
  var cutoff = _endOfDay(now);
  if (now.weekday == DateTime.saturday) cutoff = cutoff.add(const Duration(days: 1));
  final due = <(DateTime, SchreibKarte)>[];
  for (final key in st.kartenKeys) {
    final c = st.karte(key);
    if (c.due.toLocal().isAfter(cutoff)) continue;
    if (key.startsWith('k:')) {
      due.add((c.due, SchreibKarte.kanji(key.substring(2))));
    } else if (woerter[key.substring(2)] case final w?) {
      due.add((c.due, SchreibKarte.wort(w)));
    }
  }
  due.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, k) in due.take(maxSchreibWiederholungen)) k];
}

/// Wie viele Karten heute fällig sind (für die Startseite, ohne Wortliste).
int faelligAnzahl(SchreibStand st, DateTime now) {
  if (isRestDay(now)) return 0;
  var cutoff = _endOfDay(now);
  if (now.weekday == DateTime.saturday) cutoff = cutoff.add(const Duration(days: 1));
  final n = st.kartenKeys.where((k) => !st.karte(k).due.toLocal().isAfter(cutoff)).length;
  return min(n, maxSchreibWiederholungen);
}

/// Bewertung aus dem Schreiben: Fehler sind falsche Striche, [hinweis] die
/// höchste Hinweisstufe (1 Bausteine und Geschichte, 2 nächster Strich,
/// 3 ganzes Zeichen).
fsrs.Rating schreibBewertung({required int fehler, required int hinweis, bool lesungFalsch = false}) {
  if (lesungFalsch || hinweis >= 3 || fehler >= 4) return fsrs.Rating.again;
  if (hinweis >= 1 || fehler >= 2) return fsrs.Rating.hard;
  return fsrs.Rating.good;
}

/// Fertig mit allen offenen Kanji – bei [proTag] neuen Kanji von Montag bis Samstag.
DateTime fertigAm(int offen, int proTag, DateTime from) {
  var d = DateTime(from.year, from.month, from.day);
  var left = offen;
  while (left > 0) {
    if (d.weekday != DateTime.sunday) left -= proTag;
    if (left > 0) d = d.add(const Duration(days: 1));
  }
  return d;
}

// --- Lesung wählen (wie 漢字読み in der N2) ---------------------------------

const _dakuten = {
  'か': 'が', 'き': 'ぎ', 'く': 'ぐ', 'け': 'げ', 'こ': 'ご', 'さ': 'ざ', 'し': 'じ', 'す': 'ず', 'せ': 'ぜ', 'そ': 'ぞ', //
  'た': 'だ', 'ち': 'ぢ', 'つ': 'づ', 'て': 'で', 'と': 'ど', 'は': 'ば', 'ひ': 'び', 'ふ': 'ぶ', 'へ': 'べ', 'ほ': 'ぼ',
};
const _oLaut = 'こごそぞとどのほぼぽもよょろお';
const _uLaut = 'くぐすずつづぬふぶぷむゆゅるう';
const _vorTsu = 'かきくけこさしすせそたちつてとぱぴぷぺぽ';

/// Falsche Lesungen, wie sie in der Prüfung als Falle stehen: stimmhaft oder
/// nicht, langer oder kurzer Vokal, mit oder ohne っ.
Set<String> lesungsFallen(String r) {
  final out = <String>{};
  final c = r.split('');
  final back = {for (final e in _dakuten.entries) e.value: e.key};
  for (var i = 0; i < c.length; i++) {
    final ch = c[i];
    String? swap = _dakuten[ch] ?? back[ch];
    if (ch == 'ぢ' || ch == 'づ') swap = null;
    if (swap != null) out.add([...c.sublist(0, i), swap, ...c.sublist(i + 1)].join());
    final next = i + 1 < c.length ? c[i + 1] : '';
    if ((_oLaut.contains(ch) || _uLaut.contains(ch)) && next != 'う' && next != 'ー' && !'ゃゅょ'.contains(next)) {
      out.add([...c.sublist(0, i + 1), 'う', ...c.sublist(i + 1)].join());
    }
    if (next == 'う' && (_oLaut.contains(ch) || _uLaut.contains(ch))) {
      out.add([...c.sublist(0, i + 1), ...c.sublist(i + 2)].join());
    }
    if (ch == 'っ') {
      out.add([...c.sublist(0, i), ...c.sublist(i + 1)].join());
      out.add([...c.sublist(0, i), 'つ', ...c.sublist(i + 1)].join());
    } else if (i > 0 && _vorTsu.contains(next) && c[i] != 'ん' && c[i] != 'っ' && i + 1 < c.length - 0) {
      out.add([...c.sublist(0, i + 1), 'っ', ...c.sublist(i + 1)].join());
    }
  }
  out.remove(r);
  out.removeWhere((s) => s.isEmpty || s.startsWith('っ') || s.contains('っっ'));
  return out;
}

/// Vier Lesungen zur Auswahl (die richtige dabei), gemischt mit [seed].
/// Zwei Fallen aus der richtigen Lesung, eine echte Lesung eines anderen Wortes.
List<String> lesungsAuswahl(String richtig, Iterable<String> andere, int seed) {
  final rnd = Random(seed);
  final fallen = lesungsFallen(richtig).toList()..shuffle(rnd);
  final others = [
    for (final o in andere)
      if (o != richtig && (o.length - richtig.length).abs() <= 1) o,
  ]..shuffle(rnd);
  final pick = <String>{richtig};
  for (final f in fallen.take(2)) {
    pick.add(f);
  }
  for (final o in [...others, ...fallen.skip(2)]) {
    if (pick.length >= 4) break;
    pick.add(o);
  }
  final list = pick.toList()..shuffle(rnd);
  return list;
}
