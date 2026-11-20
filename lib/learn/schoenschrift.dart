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

/// Breite der gleichmäßigen Linie (ohne Pinsel) im Feld 109 × 109.
const grundBreite = 4.6;

/// Mittlere Breite des Pinselstrichs – kräftiger als die Linie, wie ein Pinsel.
const pinselBreite = 6.4;

/// Pinsel: Die Breite folgt dem Druck des Stifts (fester → breiter) und dem
/// Tempo (schnell → dünner). Stark geglättet, damit der Strich ruhig fließt,
/// auch wenn der Druck des Pencil schwankt. Am Ende läuft ein schnell
/// gezogener Strich spitz aus (はらい), ein langsamer bleibt rund (とめ).
class Pinsel {
  Pinsel({this.an = true});
  final bool an;
  double _w = pinselBreite;
  double _tempo = 0;
  Offset? _p;
  Duration? _t;

  static const minBreite = 1.2;
  static const maxBreite = 11.0;

  /// Breite am ersten Punkt eines Strichs (Ansatz, 起筆: etwas kräftiger).
  double start(Offset p, Duration t, {double? druck}) {
    _p = p;
    _t = t;
    _tempo = 0;
    _w = an ? (pinselBreite * 1.08 * _druck(druck)).clamp(minBreite, maxBreite) : grundBreite;
    return _w;
  }

  /// Breite am nächsten Punkt.
  double weiter(Offset p, Duration t, {double? druck}) {
    if (!an) return grundBreite;
    final dist = _p == null ? 0.0 : (p - _p!).distance;
    final ms = _t == null ? 16.0 : max(1.0, (t - _t!).inMicroseconds / 1000);
    _p = p;
    _t = t;
    // Tempo in Feldeinheiten pro Millisekunde, geglättet.
    _tempo = _tempo * 0.6 + (dist / ms) * 0.4;
    final faktorTempo = (1.2 - _tempo * 1.4).clamp(0.5, 1.2);
    final ziel = pinselBreite * _druck(druck) * faktorTempo;
    _w = (_w * 0.85 + ziel * 0.15).clamp(minBreite, maxBreite);
    return _w;
  }

  /// Strich fertig: Wurde er schnell beendet, läuft er über das letzte Stück
  /// spitz aus (はらい); langsam beendet bleibt das Ende rund (とめ).
  List<double> ende(List<Offset> punkte, List<double> breiten) {
    if (!an || punkte.length < 3 || _tempo < 0.18) return breiten;
    final out = List.of(breiten);
    final lang = max(6.0, strichLaenge(punkte) * 0.3);
    var rest = 0.0;
    for (var i = punkte.length - 1; i >= 0 && rest < lang; i--) {
      out[i] *= 0.1 + 0.9 * pow(rest / lang, 0.75);
      if (i > 0) rest += (punkte[i] - punkte[i - 1]).distance;
    }
    return out;
  }

  /// Druckkurve: Der Pencil meldet 0–1 und schwankt; die Wurzel-artige Kurve
  /// (Gamma 0,6) hebt leichten Druck an, damit der Strich nicht abreißt.
  /// Maus und Finger melden keinen echten Druck (0 oder 1).
  static double _druck(double? p) => p == null || p <= 0 ? 1.0 : 0.55 + 0.85 * pow(p.clamp(0.0, 1.0), 0.6);
}

final _pfade = Expando<Path>('pinselPfad');

/// Der Umriss eines Strichs als gefüllte Form: Punkte ausdünnen, Mittellinie
/// und Breiten glätten (Chaikin), links und rechts um die halbe Breite
/// versetzen, Anfang und Ende rund – ein spitz auslaufendes Ende ist einfach
/// sehr schmal. So fließt der Strich wie mit dem Pinsel statt perlig.
Path pinselPfad(Tinte t) => _pfade[t] ??= _baueUmriss(t.punkte, t.breiten);

Path _baueUmriss(List<Offset> punkte, List<double> breiten) {
  double b(int i) => i < breiten.length ? breiten[i] : grundBreite;
  // 1. Ausdünnen: Punkte näher als 0,8 Einheiten zusammenfassen.
  final pts = <Offset>[];
  final ws = <double>[];
  for (var i = 0; i < punkte.length; i++) {
    if (pts.isEmpty || (punkte[i] - pts.last).distance >= 0.8 || i == punkte.length - 1) {
      if (pts.length > 1 && i == punkte.length - 1 && (punkte[i] - pts.last).distance < 0.8) {
        pts.removeLast();
        ws.removeLast();
      }
      pts.add(punkte[i]);
      ws.add(b(i));
    }
  }
  if (pts.isEmpty) return Path();
  if (pts.length == 1) return Path()..addOval(Rect.fromCircle(center: pts.first, radius: ws.first / 2));

  // 2. Glätten: zweimal Chaikin (Ecken abschneiden), Enden bleiben.
  var cp = pts;
  var cw = ws;
  for (var r = 0; r < 2; r++) {
    final np = <Offset>[cp.first];
    final nw = <double>[cw.first];
    for (var i = 0; i < cp.length - 1; i++) {
      np
        ..add(cp[i] * 0.75 + cp[i + 1] * 0.25)
        ..add(cp[i] * 0.25 + cp[i + 1] * 0.75);
      nw
        ..add(cw[i] * 0.75 + cw[i + 1] * 0.25)
        ..add(cw[i] * 0.25 + cw[i + 1] * 0.75);
    }
    np.add(cp.last);
    nw.add(cw.last);
    cp = np;
    cw = nw;
  }
  // Breiten zusätzlich gleitend mitteln, damit die Kontur nicht wellig wird.
  final glatt = [
    for (var i = 0; i < cw.length; i++)
      (cw[max(0, i - 2)] + cw[max(0, i - 1)] + cw[i] + cw[min(cw.length - 1, i + 1)] + cw[min(cw.length - 1, i + 2)]) / 5,
  ];
  // Die Enden behalten ihre eigene Breite (spitz oder rund).
  glatt[0] = cw.first;
  glatt[glatt.length - 1] = cw.last;

  // 3. Normalen und Ränder.
  final n = cp.length;
  final links = <Offset>[];
  final rechts = <Offset>[];
  final dirs = <Offset>[];
  for (var i = 0; i < n; i++) {
    var d = cp[min(n - 1, i + 1)] - cp[max(0, i - 1)];
    if (d.distance < 1e-6) d = dirs.isEmpty ? const Offset(1, 0) : dirs.last;
    d = d / d.distance;
    dirs.add(d);
    final norm = Offset(-d.dy, d.dx) * (glatt[i] / 2);
    links.add(cp[i] + norm);
    rechts.add(cp[i] - norm);
  }

  // 4. Umriss: linker Rand, rundes Ende, rechter Rand zurück, runder Anfang.
  final path = Path()..moveTo(links.first.dx, links.first.dy);
  for (final q in links.skip(1)) {
    path.lineTo(q.dx, q.dy);
  }
  void kappe(Offset c, Offset d, double r, {required bool vorn}) {
    // Halbkreis um c: vorn von links über die Spitze nach rechts, hinten umgekehrt.
    final nrm = Offset(-d.dy, d.dx);
    for (var k = 1; k < 8; k++) {
      final a = pi * k / 8;
      final q = vorn ? c + (nrm * cos(a) + d * sin(a)) * r : c + (-nrm * cos(a) - d * sin(a)) * r;
      path.lineTo(q.dx, q.dy);
    }
  }

  kappe(cp.last, dirs.last, glatt.last / 2, vorn: true);
  for (final q in rechts.reversed) {
    path.lineTo(q.dx, q.dy);
  }
  kappe(cp.first, dirs.first, glatt.first / 2, vorn: false);
  return path..close();
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
