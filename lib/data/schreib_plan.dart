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
    this.ausText = false,
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

  /// Kommt aus einem meiner Texte („Meine Wörter“).
  final bool ausText;

  String get key => '$t|$r';
  String get bedeutung => de ?? en;

  /// Die Kanji, die man für das Wort können muss (ohne 々).
  List<String> get kanji => [for (final k in kanjiOf(t)) if (k != '々') k];
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

  /// Alle Kanji von N5 bis N2 in Lernreihenfolge.
  final List<String> reihenfolge;
  final Map<String, int> stufe;

  /// Kanji, die ich schon vor Yomicha schreiben konnte.
  final Set<String> vorwissen;

  /// Bestandteile, die selbst Lern-Kanji sind.
  final Map<String, List<String>> teile;

  /// Alle JLPT-Wörter, nach der Reihenfolge ihrer Kanji.
  final List<SchreibWort> woerter;

  final Map<String, int> index;

  /// Kanji, die es auch allein als Wort gibt (z. B. 首 くび).
  final Set<String> allein;

  bool lernKanji(String k) => index.containsKey(k);

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
