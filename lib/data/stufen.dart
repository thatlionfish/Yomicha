/// Die 7 Stufen von Yomicha, benannt nach Teesorten (Spezifikation 9.1).
class Stufe {
  const Stufe(this.nr, this.name, this.kanji, this.jlpt, this.label);

  /// 1 (Bancha) bis 7 (Matcha).
  final int nr;
  final String name;
  final String kanji;

  /// JLPT-Zahl: 5 = N5 (leicht) … 2 = N2.
  final int jlpt;

  /// Anzeige der JLPT-Stufe, z. B. „N3 leicht“.
  final String label;

  static const all = [
    Stufe(1, 'Bancha', '番茶', 5, 'N5'),
    Stufe(2, 'Hōjicha', 'ほうじ茶', 4, 'N4'),
    Stufe(3, 'Genmaicha', '玄米茶', 3, 'N3 leicht'),
    Stufe(4, 'Sencha', '煎茶', 3, 'N3'),
    Stufe(5, 'Kabusecha', 'かぶせ茶', 2, 'N2 leicht'),
    Stufe(6, 'Gyokuro', '玉露', 2, 'N2'),
    Stufe(7, 'Matcha', '抹茶', 2, 'N2+'),
  ];

  static Stufe of(int nr) => all[(nr.clamp(1, 7)) - 1];
}
