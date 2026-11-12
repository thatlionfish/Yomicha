import 'package:flutter/material.dart';

import 'colors.dart';

/// Überschriften: Fraunces (variable, weich gestellt).
TextStyle serif(double size, {double weight = 420, double height = 1.2}) =>
    TextStyle(
      fontFamily: 'Fraunces',
      fontSize: size,
      height: height,
      color: YoColors.chocolate,
      fontWeight: _weight(weight),
      fontVariations: [
        FontVariation('wght', weight),
        const FontVariation('SOFT', 100),
        FontVariation('opsz', size.clamp(9, 144).toDouble()),
      ],
    );

/// Fließtext der Oberfläche: Nunito (variable).
TextStyle sans(
  double size, {
  double weight = 420,
  Color? color,
  double height = 1.45,
}) => TextStyle(
  fontFamily: 'Nunito',
  fontSize: size,
  height: height,
  color: color ?? YoColors.chocolate,
  fontWeight: _weight(weight),
  fontVariations: [FontVariation('wght', weight)],
);

/// Japanischer Text: Zen Old Mincho (verkleinert auf Jōyō-Kanji und Kana).
/// Seltene Zeichen lädt der Browser als Ersatzschrift nach.
TextStyle jp(double size, {Color? color, double height = 1.25, FontWeight? weight}) =>
    TextStyle(
      fontFamily: 'ZenOldMincho',
      fontSize: size,
      height: height,
      color: color ?? YoColors.chocolate,
      fontWeight: weight ?? FontWeight.w400,
      letterSpacing: 0.4,
    );

FontWeight _weight(double w) =>
    FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];

/// Weiche, leicht ungleichmäßige Rundung wie bei LearnwithLeoni.
/// Für Eingabefelder: Flutter erlaubt dort nur runde (nicht elliptische) Ecken.
const fieldRadius = BorderRadius.all(Radius.circular(24));

const organicRadius = BorderRadius.only(
  topLeft: Radius.elliptical(26, 22),
  topRight: Radius.elliptical(22, 26),
  bottomLeft: Radius.elliptical(24, 28),
  bottomRight: Radius.elliptical(28, 22),
);

ThemeData buildYoTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: YoColors.chocolate,
    onPrimary: YoColors.brightWhite,
    secondary: YoColors.woodAsh,
    onSecondary: YoColors.chocolate,
    tertiary: YoColors.lemonGrass,
    onTertiary: YoColors.chocolate,
    error: YoColors.chocolate,
    onError: YoColors.brightWhite,
    surface: YoColors.coconutMilk,
    onSurface: YoColors.chocolate,
    onSurfaceVariant: YoColors.inkSoft,
    surfaceContainerLowest: YoColors.brightWhite,
    surfaceContainerLow: YoColors.brightWhite,
    surfaceContainer: YoColors.vanillaIce,
    surfaceContainerHigh: YoColors.vanillaIce,
    surfaceContainerHighest: YoColors.sand,
    outline: YoColors.woodAsh,
    outlineVariant: YoColors.sand,
  );

  final text = TextTheme(
    displaySmall: serif(34, weight: 380),
    headlineMedium: serif(28, weight: 400),
    headlineSmall: serif(24, weight: 420),
    titleLarge: serif(21, weight: 460),
    titleMedium: sans(16.5, weight: 650),
    titleSmall: sans(14.5, weight: 650),
    bodyLarge: sans(16.5),
    bodyMedium: sans(15),
    bodySmall: sans(13.5, color: YoColors.inkSoft),
    labelLarge: sans(15.5, weight: 650),
    labelMedium: sans(13.5, weight: 600, color: YoColors.inkSoft),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: YoColors.coconutMilk,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: YoColors.chocolate,
      titleTextStyle: serif(22, weight: 440),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: YoColors.chocolate,
        foregroundColor: YoColors.brightWhite,
        disabledBackgroundColor: YoColors.sand,
        disabledForegroundColor: YoColors.inkSoft,
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        textStyle: sans(16, weight: 650),
        shape: const RoundedRectangleBorder(borderRadius: organicRadius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: YoColors.chocolate,
        side: const BorderSide(color: YoColors.woodAsh, width: 1.4),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: sans(15.5, weight: 600),
        shape: const RoundedRectangleBorder(borderRadius: organicRadius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: YoColors.chocolate,
        minimumSize: const Size(48, 48),
        textStyle: sans(15, weight: 600),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: YoColors.brightWhite,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: YoColors.woodAsh,
    ),
    dividerTheme: const DividerThemeData(color: YoColors.sand, thickness: 1),
  );
}
