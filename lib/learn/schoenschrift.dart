import 'dart:math';
import 'dart:ui';

import 'strich_pruefung.dart';

/// Schönschreiben (Spezifikation 19): Pinselstrich und Vergleich mit der Vorlage.

/// Ein geschriebener Strich: Punkte im Feld 109 × 109 und die Breite des
/// Pinsels an jedem Punkt.
class Tinte {
  const Tinte(this.punkte, this.breiten);
  final List<Offset> punkte;
  final List<double> breiten;
}

/// Grundbreite des Strichs im Feld 109 × 109.
const grundBreite = 4.6;

/// Pinsel: Die Breite folgt dem Druck des Stifts (fester → breiter) und dem
/// Tempo (schnell → dünner, wie ein auslaufender Pinselstrich). Geglättet,
/// damit der Strich nicht flattert.
class Pinsel {
  Pinsel({this.an = true});
  final bool an;
  double _w = grundBreite;
  Offset? _p;
  Duration? _t;

  /// Breite am ersten Punkt eines Strichs.
  double start(Offset p, Duration t, {double? druck}) {
    _p = p;
    _t = t;
    _w = an ? (grundBreite * _druck(druck)).clamp(minBreite, maxBreite) : grundBreite;
    return _w;
  }

  /// Breite am nächsten Punkt.
  double weiter(Offset p, Duration t, {double? druck}) {
    if (!an) return grundBreite;
    final dist = _p == null ? 0.0 : (p - _p!).distance;
    final ms = _t == null ? 16.0 : max(1.0, (t - _t!).inMicroseconds / 1000);
    _p = p;
    _t = t;
    final tempo = dist / ms; // Feldeinheiten pro Millisekunde
    final faktorTempo = (1.3 - tempo * 1.8).clamp(0.4, 1.3);
    final ziel = grundBreite * _druck(druck) * faktorTempo;
    _w = (_w * 0.7 + ziel * 0.3).clamp(minBreite, maxBreite);
    return _w;
  }

  /// Nur beim Stift ist der Druck echt; Maus und Finger melden 0 oder 1.
  static double _druck(double? p) => p == null || p <= 0 ? 1.0 : 0.35 + 1.3 * p.clamp(0.0, 1.0);

  static const minBreite = 1.2;
  static const maxBreite = 10.0;
}

/// Note eines Strichs aus seinem mittleren Abstand zur Vorlage (Feld 109):
/// bis 1,5 Einheiten 100, je Einheit darüber 7 weniger (4 → 82, 8 → 54).
int strichNote(double abstand) => (100 - (abstand - 1.5) * 7).clamp(0, 100).round();

/// Ein fertig geschriebenes Zeichen im Vergleich mit der Vorlage.
class ZeichenNote {
  ZeichenNote({required this.zeichen, required this.paths, required this.tinte, required this.abstaende, required this.hinweise});

  final String zeichen;

  /// Die Striche der Vorlage (KanjiVG, SVG-Pfade).
  final List<String> paths;
  final List<Tinte> tinte;

  /// Mittlerer Abstand je Strich zur Vorlage.
  final List<double> abstaende;

  /// Was am Strich abweicht (z. B. „zu weit rechts“), je Strich.
  final List<String> hinweise;

  /// Schönschrift-Note des Zeichens, 0–100.
  int get note => abstaende.isEmpty ? 100 : (abstaende.map(strichNote).reduce((a, b) => a + b) / abstaende.length).round();

  /// Der Strich, der am meisten abweicht.
  int get schlechtester {
    var best = 0;
    for (var i = 1; i < abstaende.length; i++) {
      if (abstaende[i] > abstaende[best]) best = i;
    }
    return best;
  }

  /// Weicht überhaupt ein Strich sichtbar ab?
  bool get alleGut => abstaende.every((d) => strichNote(d) >= 85);

  String get urteil => switch (note) {
    >= 90 => 'Sehr schön',
    >= 75 => 'Schön',
    >= 55 => 'Gut lesbar',
    _ => 'Noch unruhig',
  };
}

/// Vergleicht die Striche eines Zeichens mit der Vorlage. [targets] sind die
/// mit [samplePath] abgetasteten Striche der Vorlage.
ZeichenNote bewerteZeichen(String zeichen, List<String> paths, List<List<Offset>> targets, List<Tinte> tinte) {
  final abstaende = <double>[];
  final hinweise = <String>[];
  for (var i = 0; i < tinte.length && i < targets.length; i++) {
    final u = resample(vereinfache(tinte[i].punkte));
    final t = targets[i];
    var s = 0.0;
    for (var k = 0; k < u.length; k++) {
      s += (u[k] - t[k]).distance;
    }
    abstaende.add(s / u.length);
    hinweise.add(_hinweis(u, t));
  }
  return ZeichenNote(zeichen: zeichen, paths: paths, tinte: tinte, abstaende: abstaende, hinweise: hinweise);
}

Offset _mitte(List<Offset> pts) {
  var x = 0.0, y = 0.0;
  for (final p in pts) {
    x += p.dx;
    y += p.dy;
  }
  return Offset(x / pts.length, y / pts.length);
}

/// Was an einem Strich abweicht: Lage, Länge oder Form.
String _hinweis(List<Offset> u, List<Offset> t) {
  final d = _mitte(u) - _mitte(t);
  if (d.distance > 4) {
    return d.dx.abs() >= d.dy.abs()
        ? (d.dx > 0 ? 'zu weit rechts' : 'zu weit links')
        : (d.dy > 0 ? 'zu tief' : 'zu hoch');
  }
  final tLen = strichLaenge(t);
  if (tLen > 8) {
    final ratio = strichLaenge(u) / tLen;
    if (ratio < 0.8) return 'zu kurz';
    if (ratio > 1.25) return 'zu lang';
  }
  return 'anders geschwungen';
}
