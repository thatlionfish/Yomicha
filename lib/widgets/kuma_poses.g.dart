// GENERIERT von tool/gen_kuma.dart – nicht von Hand ändern.
import 'figure.dart';

/// Posen von Kumachan, der kleinen Teemeisterin.
enum KumaPose implements FigurePose {
  /// Tee anbieten
  tea(['tea_0.svg', 'tea_1.svg'], [900, 900]),
  /// Begrüßen mit Verbeugung
  bow(['bow_0.svg', 'bow_1.svg', 'bow_2.svg', 'bow_3.svg'], [900, 300, 900, 300]),
  /// Tee aufgießen
  whisk(['whisk_0.svg', 'whisk_1.svg', 'whisk_2.svg', 'whisk_3.svg'], [280, 280, 280, 280]),
  /// Daumen hoch
  thumbs(['thumbs_0.svg', 'thumbs_1.svg', 'thumbs_2.svg', 'thumbs_3.svg'], [700, 260, 260, 260]),
  /// Jubeln
  cheer(['cheer_0.svg', 'cheer_1.svg'], [260, 260]),
  /// Nachdenken
  think(['think_0.svg', 'think_1.svg', 'think_2.svg', 'think_3.svg'], [450, 450, 1000, 1000]),
  /// Teetrinken am Sonntag
  sip(['sip_0.svg', 'sip_1.svg'], [1300, 1300]),
  ;

  const KumaPose(this.frames, this.ms);

  @override
  final List<String> frames;

  @override
  final List<int> ms;

  /// Knopfaugen blinzeln nicht.
  @override
  String? get blink => null;

  @override
  String get folder => 'kuma';

  /// Seitenverhältnis Breite/Höhe der Bilder.
  @override
  double get aspect => 200 / 300;
}
