import '../data/progress.dart';
import 'einstufung.dart';
import 'weekly.dart';

/// Wochenbilanz: dieselben Kennzahlen für jede Woche (Montag bis Samstag),
/// damit ich schon von Woche zu Woche sehe, wie ich besser werde – nicht erst
/// an der großen Stufen-Kurve.
class WeekStats {
  const WeekStats({
    required this.weekStart,
    required this.texts,
    required this.correct,
    required this.speed,
    required this.looked,
    required this.newWords,
    required this.test,
    required this.testSections,
  });

  /// Montag der Woche.
  final DateTime weekStart;

  /// Gelesene Texte (jeder Text einmal).
  final int texts;

  /// Anteil richtiger Antworten bei den Fragen zu den Texten; null = keine Fragen.
  final double? correct;

  /// Lesetempo in Zeichen pro Minute, ohne Vorlesen; null = nicht gemessen.
  final double? speed;

  /// Anteil nachgeschlagener Wörter; null = nichts gelesen.
  final double? looked;

  /// Neu in „Meine Wörter“.
  final int newWords;

  /// Wochentest: Anteil richtig; null = nicht gemacht.
  final double? test;

  /// Wochentest je Bereich (Bezeichnung → Anteil richtig).
  final Map<String, double> testSections;

  bool get isEmpty => texts == 0 && test == null && newWords == 0;
}

WeekStats weekStats(Progress p, DateTime monday) {
  final reads = [for (final r in p.reads) if (inWeek(r.day, monday)) r];
  final answered = [for (final r in reads) if (r.total > 0) r];
  final timed = [for (final r in reads) if (!r.usedAudio && r.seconds >= 20) r];
  final secs = timed.fold(0, (n, r) => n + r.seconds);
  final test = p.weeklyFor(monday);
  return WeekStats(
    weekStart: monday,
    texts: {for (final r in reads) r.id}.length,
    correct: answered.isEmpty
        ? null
        : answered.fold(0, (n, r) => n + r.correct) / answered.fold(0, (n, r) => n + r.total),
    speed: secs == 0 ? null : timed.fold(0, (n, r) => n + r.chars) * 60 / secs,
    looked: reads.isEmpty ? null : reads.fold(0.0, (n, r) => n + r.lookupShare) / reads.length,
    newWords: p.myWords.values.where((w) => w.added != null && inWeek(w.added!, monday)).length,
    test: test == null || test.total == 0 ? null : test.correct / test.total,
    testSections: {
      if (test != null)
        for (final MapEntry(:key, :value) in test.sections.entries)
          if (value.$2 > 0) key: value.$1 / value.$2,
    },
  );
}

/// Die letzten [n] Wochen bis einschließlich der Woche von [today], älteste zuerst.
List<WeekStats> lastWeeks(Progress p, DateTime today, {int n = 8}) {
  final monday = mondayOf(today);
  return [
    for (var i = n - 1; i >= 0; i--) weekStats(p, DateTime(monday.year, monday.month, monday.day - 7 * i)),
  ];
}

/// Eine Kennzahl der Wochenbilanz.
enum Kennzahl {
  correct('Fragen richtig', higherIsBetter: true),
  speed('Lesetempo', higherIsBetter: true),
  looked('Nachgeschlagen', higherIsBetter: false),
  texts('Gelesene Texte', higherIsBetter: true),
  newWords('Neue Wörter', higherIsBetter: true),
  test('Wochentest', higherIsBetter: true);

  const Kennzahl(this.label, {required this.higherIsBetter});
  final String label;
  final bool higherIsBetter;

  double? of(WeekStats w) => switch (this) {
    correct => w.correct,
    speed => w.speed,
    looked => w.looked,
    texts => w.texts == 0 ? null : w.texts.toDouble(),
    newWords => w.newWords == 0 ? null : w.newWords.toDouble(),
    test => w.test,
  };

  bool get isShare => this == correct || this == looked || this == test;

  /// Wert lesbar: „82 %“, „140 Zeichen/Min“, „3“.
  String format(double? v) {
    if (v == null) return '–';
    if (isShare) return '${(100 * v).round()} %';
    if (this == speed) return '${v.round()} Zeichen/Min';
    return '${v.round()}';
  }

  /// Zahl ohne Einheit für die Kachel („125“), dazu [unit] klein daneben.
  String formatNumber(double? v) => v == null || this != speed ? format(v) : '${v.round()}';

  /// Einheit, die die Kachel klein neben die Zahl setzt.
  String get unit => this == speed ? 'Zeichen/Min' : '';

  /// Unterschied lesbar: „+6 Prozentpunkte“, „+12 Zeichen/Min“, „+2“;
  /// kurz für die Kachel: „+6 Punkte“, „+12 pro Min“.
  String formatDelta(double d, {bool short = false}) {
    final sign = d > 0 ? '+' : d < 0 ? '−' : '±';
    final a = d.abs();
    if (isShare) return '$sign${(100 * a).round()} ${short ? 'Punkte' : 'Prozentpunkte'}';
    if (this == speed) return '$sign${a.round()} ${short ? 'pro Min' : 'Zeichen/Min'}';
    return '$sign${a.round()}';
  }

  /// Ab welchem Unterschied es zählt (kleinere Schwankungen sind Zufall).
  double get threshold => switch (this) {
    correct || test => 0.03,
    looked => 0.01,
    speed => 5,
    texts || newWords => 1,
  };
}

/// Veränderung einer Kennzahl gegenüber der Vorwoche.
class Veraenderung {
  const Veraenderung(this.kennzahl, this.vorher, this.jetzt);
  final Kennzahl kennzahl;
  final double vorher;
  final double jetzt;

  double get delta => jetzt - vorher;
  bool get spuerbar => delta.abs() >= kennzahl.threshold;
  bool get besser => spuerbar && (kennzahl.higherIsBetter ? delta > 0 : delta < 0);
  bool get schlechter => spuerbar && !besser;
}

List<Veraenderung> veraenderungen(WeekStats vorher, WeekStats jetzt) => [
  for (final k in Kennzahl.values)
    if (k.of(vorher) case final a?)
      if (k.of(jetzt) case final b?) Veraenderung(k, a, b),
];

/// Übungstipp für einen Bereich des Wochentests.
String tippFuer(String bereich) => switch (bereich) {
  'Wortschatz' => 'Wiederhole jeden Tag „Meine Wörter“ – fünf Minuten reichen.',
  'Kanji-Lesung' => 'Lies Wörter mit Kanji laut mit und tippe sie an, wenn du die Lesung nicht sicher weißt.',
  'Grammatik' => 'Tippe unter dem Text die Grammatik-Muster an und lies die Beispielsätze.',
  'Lesen' => 'Lies zuerst die Frage, dann such im Text die passende Stelle – oft steht die Antwort nach しかし oder am Satzende.',
  _ => 'Lies jeden Tag deinen Text bis zu den Fragen.',
};

/// Wie weit es noch bis zum Vorschlag für die nächste Stufe ist (Spezifikation 9.3).
String aufstiegStand(Progress p) {
  if (p.stufe >= 7) return 'Du bist auf der höchsten Stufe – jetzt geht es um das Prüfungstraining.';
  final answered = [for (final r in textsOnStufe(p)) if (r.total > 0) r];
  if (answered.length < aufstiegTexte) {
    final fehlen = aufstiegTexte - answered.length;
    return 'Noch $fehlen ${fehlen == 1 ? 'Text' : 'Texte'} mit Fragen auf Stufe ${p.stufe}, '
        'dann prüft die App, ob du aufsteigen kannst.';
  }
  final last = answered.sublist(answered.length - aufstiegTexte);
  final right = last.fold(0, (n, r) => n + r.correct) / last.fold(0, (n, r) => n + r.total);
  final looked = last.fold(0.0, (n, r) => n + r.lookupShare) / last.length;
  if (right < aufstiegRichtig) {
    return 'Für den Aufstieg: in den letzten $aufstiegTexte Texten ${(100 * right).round()} % richtig – '
        'Ziel sind ${(100 * aufstiegRichtig).round()} %.';
  }
  if (looked > aufstiegNachgeschlagen) {
    return 'Für den Aufstieg: ${(100 * looked).round()} % der Wörter nachgeschlagen – '
        'Ziel sind höchstens ${(100 * aufstiegNachgeschlagen).round()} %.';
  }
  return 'Du erfüllst die Bedingungen für die nächste Stufe – die App schlägt sie dir vor.';
}
