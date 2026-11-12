import '../data/progress.dart';

// --- Laufende Einschätzung (Spezifikation 9.3) ------------------------------
// Startwerte – nach ein paar Wochen fein abstimmen.

/// Aufstieg: in den letzten 5 Texten der Stufe mindestens 80 % richtig und
/// höchstens 5 % der Wörter nachgeschlagen.
const aufstiegTexte = 5;
const aufstiegRichtig = 0.8;
const aufstiegNachgeschlagen = 0.05;

/// Zurück: 3 Texte nacheinander unter 50 % richtig (oder dreimal „zu schwer“).
const zurueckTexte = 3;
const zurueckRichtig = 0.5;

/// Nach „Noch nicht“ fragt die App erst nach so vielen weiteren Texten wieder.
const vorschlagPauseTexte = 3;

enum Richtung { hoch, zurueck }

class StufenVorschlag {
  const StufenVorschlag(this.richtung, this.von, this.nach, this.grund);
  final Richtung richtung;
  final int von;
  final int nach;

  /// Begründung, z. B. „In deinen letzten 5 Texten waren 85 % richtig …“.
  final String grund;
}

String _pct(double x) => '${(100 * x).round()} %';

/// Texte meiner jetzigen Stufe, seit ich auf ihr bin (älteste zuerst).
List<ReadRecord> textsOnStufe(Progress p) {
  final since = p.stufeSince;
  return [
    for (final r in p.reads)
      if (r.stufe == p.stufe && !r.day.isBefore(since)) r,
  ];
}

/// Schlägt einen Stufenwechsel vor – ich bestätige ihn selbst.
StufenVorschlag? stufenVorschlag(Progress p) {
  final s = p.stufe;
  final texts = textsOnStufe(p);
  final pause = p.vorschlagPause;
  if (pause != null && pause.$1 == s && texts.length < pause.$2 + vorschlagPauseTexte) return null;
  final answered = [for (final r in texts) if (r.total > 0) r];

  if (s > 1 && texts.length >= zurueckTexte) {
    final last = answered.length >= zurueckTexte ? answered.sublist(answered.length - zurueckTexte) : const <ReadRecord>[];
    if (last.isNotEmpty && last.every((r) => r.correct / r.total < zurueckRichtig)) {
      return StufenVorschlag(Richtung.zurueck, s, s - 1,
          'In deinen letzten $zurueckTexte Texten war jeweils weniger als die Hälfte der Antworten richtig.');
    }
    if (texts.sublist(texts.length - zurueckTexte).every((r) => r.rating > 0)) {
      return StufenVorschlag(Richtung.zurueck, s, s - 1, 'Die letzten $zurueckTexte Texte waren dir zu schwer.');
    }
  }

  if (s < 7 && answered.length >= aufstiegTexte) {
    final last = answered.sublist(answered.length - aufstiegTexte);
    final right = last.fold(0, (n, r) => n + r.correct) / last.fold(0, (n, r) => n + r.total);
    final looked = last.fold(0.0, (n, r) => n + r.lookupShare) / last.length;
    final tooHard = last.where((r) => r.rating > 0).length;
    if (right >= aufstiegRichtig && looked <= aufstiegNachgeschlagen && tooHard < 2) {
      return StufenVorschlag(Richtung.hoch, s, s + 1,
          'In deinen letzten $aufstiegTexte Texten waren ${_pct(right)} der Antworten richtig, '
          'und du hast nur ${_pct(looked)} der Wörter nachgeschlagen.');
    }
  }
  return null;
}

// --- Einstufung zu Beginn (Spezifikation 9.2) -------------------------------

/// Antwort im Wortschatz-Check.
class WortAntwort {
  const WortAntwort({required this.jlpt, required this.kenne, this.geprueft});
  final int jlpt;
  final bool kenne;

  /// Bei jedem vierten Wort: Bedeutung richtig gewählt? null = nicht geprüft.
  final bool? geprueft;
}

/// Ab diesem Anteil (bereinigt) gilt eine JLPT-Stufe im Wortschatz als erreicht.
const wortschatzSchwelle = 0.7;

/// Anteil bekannter Wörter einer JLPT-Stufe. Falsch beantwortete Prüfwörter
/// zählen als unbekannt, und die übrigen „kenne ich“ werden mit dem Anteil
/// richtig geprüfter gewichtet – so überschätze ich mich nicht.
double knownShare(List<WortAntwort> answers, int jlpt) {
  final a = [for (final x in answers) if (x.jlpt == jlpt) x];
  if (a.isEmpty) return 0;
  final checked = [for (final x in a) if (x.geprueft != null) x];
  final trust = checked.isEmpty ? 1.0 : checked.where((x) => x.geprueft!).length / checked.length;
  var known = 0.0;
  for (final x in a) {
    if (!x.kenne) continue;
    if (x.geprueft != null) {
      known += x.geprueft! ? 1 : 0;
    } else {
      known += trust;
    }
  }
  return known / a.length;
}

/// Höchste JLPT-Stufe (5 … 2), die ich im Wortschatz sicher habe – alle
/// leichteren auch. null = nicht einmal N5.
int? wortschatzStufe(List<WortAntwort> answers) {
  int? best;
  for (final j in [5, 4, 3, 2]) {
    if (knownShare(answers, j) < wortschatzSchwelle) break;
    best = j;
  }
  return best;
}

/// Wortschatz → Stufe: N5 → 1, N4 → 2, N3 → 4, N2 → 6.
int stufeAusWortschatz(int? jlpt) => switch (jlpt) {
  null || 5 => 1,
  4 => 2,
  3 => 4,
  _ => 6,
};

/// Ergebnis eines Mini-Textes.
class TextAntwort {
  const TextAntwort({required this.jlpt, required this.richtig, required this.fragen, required this.zeichenProMinute});
  final int jlpt;
  final int richtig;
  final int fragen;
  final double zeichenProMinute;

  bool get verstanden => richtig == fragen;
}

/// Mindesttempo (Zeichen pro Minute) für „flüssig gelesen“ – Startwerte.
const lesetempo = {4: 100.0, 3: 130.0, 2: 160.0};

/// Lesen → Stufe. Gezählt wird von unten, bis ein Text nicht verstanden ist:
/// N4 nicht verstanden → 1; N4 → 2; N3 langsam → 3, flüssig → 4;
/// N2 langsam → 5, flüssig → 6.
int leseStufe(List<TextAntwort> texts) {
  var stufe = 1;
  for (final t in [...texts]..sort((a, b) => b.jlpt.compareTo(a.jlpt))) {
    if (!t.verstanden) break;
    final fluent = t.zeichenProMinute >= (lesetempo[t.jlpt] ?? 0);
    stufe = switch (t.jlpt) {
      4 => 2,
      3 => fluent ? 4 : 3,
      _ => fluent ? 6 : 5,
    };
  }
  return stufe;
}

/// Startstufe: Mittel aus Wortschatz und Lesen, aufgerundet
/// (Wortschatz N3 = 4, Lesen N4 = 2 → Stufe 3).
int startStufe(int? wortschatz, int lesen) => ((stufeAusWortschatz(wortschatz) + lesen) / 2).ceil().clamp(1, 7);

/// Deutsche Bezeichnung einer JLPT-Zahl.
String jlptName(int? j) => j == null ? 'unter N5' : 'N$j';
