import 'package:flutter/material.dart';

/// Farbpalette von Yomicha – dieselbe wie bei LearnwithLeoni
/// (Pantone TCX, Hex als Bildschirm-Annäherung).
///
/// Grün (Lemon Grass) nur als Detail: Punkt, Linie, Häkchen.
/// Nie als Textfarbe auf hellem Grund, nie flächig. Kein Rot für „falsch“.
abstract final class YoColors {
  /// 11-0608 TCX Coconut Milk – Seitenhintergrund.
  static const Color coconutMilk = Color(0xFFF1EEE6);

  /// 11-0601 TCX Bright White – Kartenflächen.
  static const Color brightWhite = Color(0xFFF4F9FF);

  /// 11-0104 TCX Vanilla Ice – sekundäre Flächen.
  static const Color vanillaIce = Color(0xFFF0EADA);

  /// 14-1108 TCX Wood Ash – Linien, organische Formen, inaktiv.
  static const Color woodAsh = Color(0xFFD7CAB0);

  /// Frei gewählter Zwischenton – Fortschritt, Markierung des gelesenen Satzes.
  static const Color sand = Color(0xFFE3D8C2);

  /// 19-0809 TCX Chocolate Chip – Text, Symbole, Hauptknöpfe.
  static const Color chocolate = Color(0xFF685A4E);

  /// Dezenter Text; Kontrast ≥ 4,5:1 auf allen hellen Flächen.
  static const Color inkSoft = Color(0xFF73655A);

  /// 12-0626 TCX Lemon Grass – das Sencha-Grün, nur als Detail.
  static const Color lemonGrass = Color(0xFFDCD494);
}
