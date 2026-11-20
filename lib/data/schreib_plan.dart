import 'models.dart';

/// Ein Wort zum Schreiben – aus der JLPT-Liste oder aus „Meine Wörter“.
class SchreibWort {
  const SchreibWort({
    required this.t,
    required this.r,
    required this.n,
    required this.en,
    this.de,
    this.satz,
    this.textId,
  });

  /// Schreibung, so wie sie im Text steht (Kanji mit Okurigana).
  final String t;
  final String r;

  /// JLPT-Stufe (5 = N5 … 2 = N2); 0 = nicht aus der JLPT-Liste.
  final int n;
  final String en;
  final String? de;

  /// Beispielsatz (aus meinem Text oder später aus der Teeküche).
  final String? satz;

  /// Der Text, aus dem ich das Wort gespeichert habe („Meine Wörter“).
  final String? textId;

  /// Kommt aus einem meiner Texte.
  bool get ausText => textId != null;

  String get key => '$t|$r';
  String get bedeutung => de ?? en;

  /// Die Kanji, die man für das Wort können muss (ohne 々).
  List<String> get kanji => [for (final k in kanjiOf(t)) if (k != '々') k];
}

/// Beispielsatz zu einem Wort (Spezifikation 19, Stufe 2): Ruby-Schreibweise
/// ({漢字|かんじ}) mit dem Wort in [ ], dazu die deutsche Übersetzung und – wo
/// der Plan nur Englisch hat – die deutsche Bedeutung des Wortes.
class Beispiel {
  const Beispiel({required this.ruby, required this.de, this.bedeutung});
  final String ruby;
  final String de;
  final String? bedeutung;

  /// Der Satz ohne Lesungen und Markierung.
  String get text => ruby
      .replaceAllMapped(RegExp(r'\{([^|{}]+)\|[^{}]+\}'), (m) => m.group(1)!)
      .replaceAll('[', '')
      .replaceAll(']', '');

  factory Beispiel.fromJson(Map<String, dynamic> j) =>
      Beispiel(ruby: j['r'] as String, de: j['de'] as String, bedeutung: j['bedeutung'] as String?);
}

/// Lernplan für „Kanji schreiben“ (Spezifikation 19), aus
/// `tool/teekueche/schreiben_daten.py`.
class SchreibPlan {
  SchreibPlan({
    required this.reihenfolge,
    required this.stufe,
    required this.vorwissen,
    required this.teile,
    required this.woerter,
  }) : index = {for (var i = 0; i < reihenfolge.length; i++) reihenfolge[i]: i},
       allein = {
         for (final w in woerter)
           if (w.t.length == 1 && isKanji(w.t)) w.t,
       };

  /// Alle Kanji von N5 bis N1 in Lernreihenfolge (N1 nach der N2).
  final List<String> reihenfolge;
  final Map<String, int> stufe;

  /// Kanji, die ich schon vor Yomicha schreiben konnte.
  final Set<String> vorwissen;

  /// Bestandteile, die selbst Lern-Kanji sind.
  final Map<String, List<String>> teile;

  /// Alle JLPT-Wörter N5–N1, nach der Reihenfolge ihrer Kanji.
  final List<SchreibWort> woerter;

  final Map<String, int> index;

  /// Kanji, die es auch allein als Wort gibt (z. B. 首 くび).
  final Set<String> allein;

  bool lernKanji(String k) => index.containsKey(k);

  /// Alles bis zum letzten Kanji der N2 – auch N1-Bestandteile, die davor
  /// gelernt werden (z. B. 又 vor 支). Der Rest ist die N1.
  late final List<String> bisN2 = reihenfolge.sublist(
    0,
    reihenfolge.lastIndexWhere((k) => (stufe[k] ?? 1) >= 2) + 1,
  );
  late final List<String> nachN2 = reihenfolge.sublist(bisN2.length);

  factory SchreibPlan.fromJson(Map<String, dynamic> j) {
    final order = (j['reihenfolge'] as String).split('');
    final stufen = (j['stufen'] as String).split('');
    return SchreibPlan(
      reihenfolge: order,
      stufe: {for (var i = 0; i < order.length; i++) order[i]: int.parse(stufen[i])},
      vorwissen: (j['vorwissen'] as String? ?? '').split('').toSet(),
      teile: {
        for (final e in (j['teile'] as Map<String, dynamic>? ?? const {}).entries)
          e.key: (e.value as String).split(''),
      },
      woerter: [
        for (final w in (j['woerter'] as List).cast<List<dynamic>>())
          SchreibWort(
            t: w[0] as String,
            r: w[1] as String,
            n: w[2] as int,
            en: w[3] as String,
            de: w.length > 4 ? w[4] as String? : null,
            satz: w.length > 5 ? w[5] as String? : null,
          ),
      ],
    );
  }
}
