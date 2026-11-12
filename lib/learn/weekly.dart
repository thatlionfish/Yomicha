import 'dart:math';

import '../data/models.dart';
import '../data/progress.dart';
import '../data/stufen.dart';
import 'calendar.dart';

/// Wochentest: ca. 15 Fragen zu den Texten einer Woche (Montag bis Samstag).
/// Die App stellt ihn selbst zusammen – die Teeküche braucht dafür nichts.

DateTime mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Die Woche, deren Test heute dran ist: samstags die laufende Woche,
/// Montag bis Freitag die vergangene (zum Nachholen), sonntags keine.
DateTime? testWeek(DateTime today) {
  if (isRestDay(today)) return null;
  final monday = mondayOf(today);
  return today.weekday == DateTime.saturday ? monday : DateTime(monday.year, monday.month, monday.day - 7);
}

bool inWeek(DateTime d, DateTime monday) {
  final day = DateTime(d.year, d.month, d.day);
  return !day.isBefore(monday) && day.isBefore(DateTime(monday.year, monday.month, monday.day + 7));
}

/// Kalenderwoche nach ISO 8601.
int isoWeek(DateTime d) {
  final thursday = DateTime(d.year, d.month, d.day - (d.weekday - 1) + 3);
  final firstThursday = DateTime(thursday.year, 1, 4);
  final week1Monday = DateTime(firstThursday.year, 1, 4 - (firstThursday.weekday - 1));
  return 1 + thursday.difference(week1Monday).inDays ~/ 7;
}

enum WeeklySection {
  wortschatz('Wortschatz'),
  lesung('Kanji-Lesung'),
  grammatik('Grammatik'),
  lesen('Lesen');

  const WeeklySection(this.label);
  final String label;
}

class WeeklyQuestion {
  const WeeklyQuestion({
    required this.section,
    required this.prompt,
    required this.promptDe,
    required this.options,
    required this.answer,
    required this.explain,
    this.japaneseOptions = true,
    this.excerpt,
    this.excerptTitle,
    this.word,
  });

  final WeeklySection section;

  /// Japanisch in Ruby-Schreibweise.
  final String prompt;
  final String promptDe;
  final List<String> options;
  final bool japaneseOptions;
  final int answer;
  final String explain;

  /// Textstelle für Lesefragen.
  final List<Token>? excerpt;
  final String? excerptTitle;

  /// Das Wort, um das es geht (für „zu Meinen Wörtern“).
  final MyWord? word;
}

const sizes = {
  WeeklySection.wortschatz: 5,
  WeeklySection.lesung: 4,
  WeeklySection.grammatik: 3,
  WeeklySection.lesen: 3,
};

String _title(TextDoc d) => d.title.map((t) => t.t).join();

/// Stellt den Wochentest zusammen. Gleiche Woche → gleiche Fragen.
List<WeeklyQuestion> buildWeeklyTest({
  required List<TextDoc> docs,
  required Progress progress,
  required DateTime weekStart,
}) {
  final rnd = Random(weekStart.difference(DateTime(2026)).inDays);
  final userJlpt = Stufe.of(progress.stufe).jlpt;

  // Wörter der Woche (ohne Grammatik- und kurze Kana-Wörter).
  final words = <String, (Token, TextDoc, Sentence)>{};
  for (final d in docs) {
    for (final s in d.sentences) {
      for (final t in s.tokens) {
        if (t.gloss == null || t.grammar != null || t.isPunct) continue;
        if (!t.hasKanji && t.t.length < 3) continue;
        words.putIfAbsent('${t.t}|${t.reading}', () => (t, d, s));
      }
    }
  }
  // Zuerst gespeicherte Wörter, dann schwerere (über oder auf meiner Stufe), dann der Rest.
  int rank((Token, TextDoc, Sentence) w) {
    final (t, _, _) = w;
    if (progress.hasWord('${t.t}|${t.reading}')) return 0;
    if (t.jlpt == null || t.jlpt! <= userJlpt) return 1;
    return 2;
  }

  final pool = words.values.toList()..shuffle(rnd);
  pool.sort((a, b) => rank(a).compareTo(rank(b)));

  final out = <WeeklyQuestion>[];
  final used = <String>{};

  (List<String>, int) withDistractors(String correct, Iterable<String> candidates) {
    final others = candidates.where((c) => c != correct).toSet().toList()..shuffle(rnd);
    if (others.length < 2) return (const [], -1);
    final opts = [...others.take(3), correct]..shuffle(rnd);
    return (opts, opts.indexOf(correct));
  }

  MyWord myWord(Token t, TextDoc d, Sentence s) =>
      MyWord(t: t.t, reading: t.reading, gloss: t.gloss!, sentence: s.plain, textId: d.id);

  // Wortschatz: Was bedeutet das Wort?
  for (final (t, d, s) in pool) {
    if (out.where((q) => q.section == WeeklySection.wortschatz).length >= sizes[WeeklySection.wortschatz]!) break;
    final (opts, answer) = withDistractors(t.gloss!, [for (final (o, _, _) in pool) o.gloss!]);
    if (answer < 0) continue;
    used.add(t.t);
    out.add(WeeklyQuestion(
      section: WeeklySection.wortschatz,
      prompt: t.t,
      promptDe: 'Was bedeutet das Wort?',
      options: opts,
      japaneseOptions: false,
      answer: answer,
      explain: '${t.t} (${t.reading}) heißt: ${t.gloss}. Aus „${_title(d)}“.',
      word: myWord(t, d, s),
    ));
  }

  // Kanji-Lesung: Wie liest man das? (andere Wörter als oben)
  final kanjiPool = [for (final w in pool) if (w.$1.hasKanji && w.$1.r != null) w];
  for (final (t, d, s) in kanjiPool) {
    if (out.where((q) => q.section == WeeklySection.lesung).length >= sizes[WeeklySection.lesung]!) break;
    if (used.contains(t.t)) continue;
    final (opts, answer) = withDistractors(t.reading, [for (final (o, _, _) in kanjiPool) o.reading]);
    if (answer < 0) continue;
    used.add(t.t);
    out.add(WeeklyQuestion(
      section: WeeklySection.lesung,
      prompt: t.t,
      promptDe: 'Wie liest man das?',
      options: opts,
      answer: answer,
      explain: '${t.t} liest man ${t.reading} – ${t.gloss}.',
      word: myWord(t, d, s),
    ));
  }

  // Grammatik: Was bedeutet das Muster?
  final grammar = <String, GrammarPoint>{};
  for (final d in docs) {
    for (final g in d.grammar.values) {
      grammar.putIfAbsent(g.pattern, () => g);
    }
  }
  final gList = grammar.values.toList()..shuffle(rnd);
  for (final g in gList.take(sizes[WeeklySection.grammatik]!)) {
    final (opts, answer) = withDistractors(g.de, [for (final o in gList) o.de]);
    if (answer < 0) continue;
    out.add(WeeklyQuestion(
      section: WeeklySection.grammatik,
      prompt: g.pattern,
      promptDe: 'Was bedeutet dieses Muster?',
      options: opts,
      japaneseOptions: false,
      answer: answer,
      explain: '${g.pattern}: ${g.de}${g.exampleDe == null ? '' : ' Beispiel: ${g.exampleDe}'}',
    ));
  }

  // Lesen: Fragen aus den Texten – zuerst die, die ich falsch hatte.
  final wrong = <String, Set<int>>{};
  for (final r in progress.reads) {
    if (r.wrong.isNotEmpty) wrong.putIfAbsent(r.id, () => {}).addAll(r.wrong);
  }
  final reading = <(TextDoc, int, bool)>[
    for (final d in docs)
      for (var i = 0; i < d.questions.length; i++)
        if (d.questions[i].kind == 'inhalt') (d, i, wrong[d.id]?.contains(i) ?? false),
  ]..shuffle(rnd);
  reading.sort((a, b) => (b.$3 ? 1 : 0).compareTo(a.$3 ? 1 : 0));
  for (final (d, i, wasWrong) in reading.take(sizes[WeeklySection.lesen]!)) {
    final q = d.questions[i];
    final evidence = q.evidence.isEmpty ? [0] : ([...q.evidence]..sort());
    out.add(WeeklyQuestion(
      section: WeeklySection.lesen,
      prompt: q.q,
      promptDe: q.qDe ?? '',
      options: q.options,
      answer: q.answer,
      explain: '${wasWrong ? 'Diese Frage hattest du beim Lesen falsch. ' : ''}${q.explain}',
      excerpt: [for (final e in evidence) ...d.sentences[e].tokens],
      excerptTitle: _title(d),
    ));
  }

  return out;
}
