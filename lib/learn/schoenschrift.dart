import 'dart:math';
import 'dart:ui';

import 'strich_pruefung.dart';

/// Schönschreiben (Spezifikation 19): Pinselstrich und Vergleich mit der Vorlage.

/// Ein geschriebener Strich: Punkte im Feld 109 × 109 und die Breite des
/// Pinsels an jedem Punkt. [spitz]: Der Strich wurde schnell beendet und
/// läuft spitz aus (はらい); sonst ist das Ende rund (とめ).
class Tinte {
  const Tinte(this.punkte, this.breiten, {this.spitz = false});
  final List<Offset> punkte;
  final List<double> breiten;
  final bool spitz;
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

  /// Strich fertig: Wurde er schnell beendet, läuft er spitz aus (はらい);
  /// langsam beendet bleibt das Ende rund (とめ).
  bool get spitzesEnde => an && _tempo >= 0.18;

  /// Druckkurve: Der Pencil meldet 0–1 und schwankt; die Wurzel-artige Kurve
  /// (Gamma 0,6) hebt leichten Druck an, damit der Strich nicht abreißt.
  /// Maus und Finger melden keinen echten Druck (0 oder 1).
  static double _druck(double? p) => p == null || p <= 0 ? 1.0 : 0.55 + 0.85 * pow(p.clamp(0.0, 1.0), 0.6);
}

final _pfade = Expando<Path>('pinselPfad');

/// Der Umriss eines Strichs als gefüllte, glatte Form (wie mit dem Pinsel):
/// 1. Mittellinie als Kurve durch die Stiftpunkte (Catmull-Rom), dicht und
///    gleichmäßig neu abgetastet – auch wenn der Stift nur wenige Punkte meldet;
/// 2. Linie und Breite sanft geglättet (gaußsch), damit nichts zittert;
/// 3. beim spitzen Ende (はらい) läuft die Breite über das letzte Drittel aus;
/// 4. Ränder als Kurven, Anfang und Ende exakte Halbkreise.
Path pinselPfad(Tinte t) => _pfade[t] ??= _baueUmriss(t.punkte, t.breiten, t.spitz);

/// Abstand der neu abgetasteten Punkte (Feldeinheiten).
const _schritt = 0.5;

Path _baueUmriss(List<Offset> punkte, List<double> breiten, bool spitz) {
  double b(int i) => i < breiten.length ? breiten[i] : grundBreite;
  // Ausdünnen: Punkte näher als einen halben Schritt zusammenfassen.
  final pts = <Offset>[];
  final ws = <double>[];
  for (var i = 0; i < punkte.length; i++) {
    if (pts.isNotEmpty && (punkte[i] - pts.last).distance < _schritt) {
      if (i == punkte.length - 1 && pts.length > 1) {
        pts[pts.length - 1] = punkte[i];
        ws[ws.length - 1] = b(i);
      }
      continue;
    }
    pts.add(punkte[i]);
    ws.add(b(i));
  }
  if (pts.isEmpty) return Path();
  if (pts.length == 1) return Path()..addOval(Rect.fromCircle(center: pts.first, radius: ws.first / 2));

  // 1. Kurve durch die Punkte (zentripetales Catmull-Rom), fein unterteilt.
  final dicht = <Offset>[pts.first];
  final dichtW = <double>[ws.first];
  for (var i = 0; i < pts.length - 1; i++) {
    final p1 = pts[i], p2 = pts[i + 1];
    final p0 = i > 0 ? pts[i - 1] : p1 * 2 - p2;
    final p3 = i + 2 < pts.length ? pts[i + 2] : p2 * 2 - p1;
    final schritte = max(2, ((p2 - p1).distance / (_schritt / 2)).ceil());
    for (var k = 1; k <= schritte; k++) {
      final u = k / schritte;
      dicht.add(_catmullRom(p0, p1, p2, p3, u));
      dichtW.add(ws[i] + (ws[i + 1] - ws[i]) * u);
    }
  }

  // Gleichmäßig nach Weglänge neu abtasten.
  final c = <Offset>[dicht.first];
  final w = <double>[dichtW.first];
  var rest = _schritt;
  for (var i = 1; i < dicht.length; i++) {
    var a = dicht[i - 1];
    var aw = dichtW[i - 1];
    final z = dicht[i];
    final zw = dichtW[i];
    var seg = (z - a).distance;
    while (seg >= rest) {
      final f = rest / seg;
      a = a + (z - a) * f;
      aw = aw + (zw - aw) * f;
      c.add(a);
      w.add(aw);
      seg = (z - a).distance;
      rest = _schritt;
    }
    rest -= seg;
  }
  if ((c.last - dicht.last).distance > 1e-3) {
    c.add(dicht.last);
    w.add(dichtW.last);
  }
  final n = c.length;
  if (n < 2) return Path()..addOval(Rect.fromCircle(center: c.first, radius: w.first / 2));

  // 2. Glätten: Linie leicht (σ ≈ 0,8 Einheiten), Breite kräftig (σ ≈ 3 Einheiten).
  final xs = _gauss([for (final q in c) q.dx], 0.8 / _schritt);
  final ys = _gauss([for (final q in c) q.dy], 0.8 / _schritt);
  final mitte = [for (var i = 0; i < n; i++) Offset(xs[i], ys[i])];
  mitte[0] = c.first;
  mitte[n - 1] = c.last;
  final breite = _gauss(w, 3 / _schritt);

  // 3. Spitzes Ende (はらい): über das letzte Drittel (6–22 Einheiten) auslaufen.
  if (spitz) {
    final lang = ((n - 1) * _schritt * 0.33).clamp(6.0, 22.0);
    for (var i = n - 1; i >= 0; i--) {
      final d = (n - 1 - i) * _schritt;
      if (d >= lang) break;
      breite[i] *= 0.06 + 0.94 * pow(d / lang, 0.8);
    }
  }

  // Richtung und Ränder.
  final dirs = <Offset>[];
  final links = <Offset>[];
  final rechts = <Offset>[];
  for (var i = 0; i < n; i++) {
    var d = mitte[min(n - 1, i + 2)] - mitte[max(0, i - 2)];
    if (d.distance < 1e-6) d = dirs.isEmpty ? const Offset(1, 0) : dirs.last;
    d = d / d.distance;
    dirs.add(d);
    final nrm = Offset(-d.dy, d.dx) * (breite[i] / 2);
    links.add(mitte[i] + nrm);
    rechts.add(mitte[i] - nrm);
  }

  // 4. Umriss mit Kurven: linker Rand, Halbkreis vorn, rechter Rand zurück, Halbkreis hinten.
  final path = Path()..moveTo(links.first.dx, links.first.dy);
  void rand(List<Offset> r) {
    for (var i = 1; i < r.length - 1; i++) {
      final m = (r[i] + r[i + 1]) / 2;
      path.quadraticBezierTo(r[i].dx, r[i].dy, m.dx, m.dy);
    }
    path.lineTo(r.last.dx, r.last.dy);
  }

  void halbkreis(Offset mp, Offset d, double r, {required bool vorn}) {
    // Zwei Viertelkreise als exakte Kegelschnitte (Gewicht √½).
    final nrm = Offset(-d.dy, d.dx) * r;
    final dir = d * r;
    const g = 0.7071067811865476;
    if (vorn) {
      final spitze = mp + dir;
      final e1 = mp + nrm + dir, e2 = mp + dir - nrm, ziel = mp - nrm;
      path
        ..conicTo(e1.dx, e1.dy, spitze.dx, spitze.dy, g)
        ..conicTo(e2.dx, e2.dy, ziel.dx, ziel.dy, g);
    } else {
      final hinten = mp - dir;
      final e1 = mp - nrm - dir, e2 = mp - dir + nrm, ziel = mp + nrm;
      path
        ..conicTo(e1.dx, e1.dy, hinten.dx, hinten.dy, g)
        ..conicTo(e2.dx, e2.dy, ziel.dx, ziel.dy, g);
    }
  }

  rand(links);
  halbkreis(mitte.last, dirs.last, breite.last / 2, vorn: true);
  rand(rechts.reversed.toList());
  halbkreis(mitte.first, dirs.first, breite.first / 2, vorn: false);
  return path..close();
}

Offset _catmullRom(Offset p0, Offset p1, Offset p2, Offset p3, double u) {
  double knoten(Offset a, Offset b) => max(1e-4, sqrt((b - a).distance));
  const t0 = 0.0;
  final t1 = t0 + knoten(p0, p1);
  final t2 = t1 + knoten(p1, p2);
  final t3 = t2 + knoten(p2, p3);
  final t = t1 + (t2 - t1) * u;
  final a1 = p0 * ((t1 - t) / (t1 - t0)) + p1 * ((t - t0) / (t1 - t0));
  final a2 = p1 * ((t2 - t) / (t2 - t1)) + p2 * ((t - t1) / (t2 - t1));
  final a3 = p2 * ((t3 - t) / (t3 - t2)) + p3 * ((t - t2) / (t3 - t2));
  final b1 = a1 * ((t2 - t) / (t2 - t0)) + a2 * ((t - t0) / (t2 - t0));
  final b2 = a2 * ((t3 - t) / (t3 - t1)) + a3 * ((t - t1) / (t3 - t1));
  return b1 * ((t2 - t) / (t2 - t1)) + b2 * ((t - t1) / (t2 - t1));
}

/// Gaußsche Glättung mit σ in Punkten; an den Rändern wird der Randwert fortgesetzt.
List<double> _gauss(List<double> v, double sigma) {
  if (v.length < 3 || sigma <= 0) return List.of(v);
  final r = (sigma * 3).ceil();
  final gewicht = [for (var k = -r; k <= r; k++) exp(-(k * k) / (2 * sigma * sigma))];
  return [
    for (var i = 0; i < v.length; i++)
      () {
        var s = 0.0, g = 0.0;
        for (var k = -r; k <= r; k++) {
          final j = (i + k).clamp(0, v.length - 1);
          s += v[j] * gewicht[k + r];
          g += gewicht[k + r];
        }
        return s / g;
      }(),
  ];
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
