import 'dart:math';
import 'dart:ui';

/// Strichprüfung für „Kanji schreiben“ (Spezifikation 19): Jeder Strich wird
/// mit dem nächsten Strich aus KanjiVG verglichen – Lage, Form, Richtung und
/// Reihenfolge. Alles im Feld 109 × 109 von KanjiVG.

/// So viele Punkte vergleicht die Prüfung pro Strich.
const strichPunkte = 24;

/// Größe des KanjiVG-Felds.
const feld = 109.0;

double strichLaenge(List<Offset> pts) {
  var s = 0.0;
  for (var i = 1; i < pts.length; i++) {
    s += (pts[i] - pts[i - 1]).distance;
  }
  return s;
}

/// Entfernt Punkte, die näher als [minAbstand] am vorigen liegen – so zählt
/// das Zittern der Hand nicht zur Länge des Strichs.
List<Offset> vereinfache(List<Offset> pts, [double minAbstand = 2.0]) {
  if (pts.length < 3) return pts;
  final out = <Offset>[pts.first];
  for (final p in pts.skip(1)) {
    if ((p - out.last).distance >= minAbstand) out.add(p);
  }
  if (out.last != pts.last) {
    if (out.length > 1 && (pts.last - out.last).distance < minAbstand) out.removeLast();
    out.add(pts.last);
  }
  return out;
}

/// Verteilt [n] Punkte gleichmäßig entlang eines Linienzugs.
List<Offset> resample(List<Offset> pts, [int n = strichPunkte]) {
  if (pts.isEmpty) return const [];
  final total = strichLaenge(pts);
  if (total == 0 || pts.length == 1) return List.filled(n, pts.first);
  final step = total / (n - 1);
  final out = <Offset>[pts.first];
  var carry = 0.0;
  for (var i = 1; i < pts.length && out.length < n; i++) {
    var a = pts[i - 1];
    final b = pts[i];
    var seg = (b - a).distance;
    while (carry + seg >= step && out.length < n) {
      final t = (step - carry) / seg;
      a = Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
      out.add(a);
      seg = (b - a).distance;
      carry = 0;
    }
    carry += seg;
  }
  while (out.length < n) {
    out.add(pts.last);
  }
  return out;
}

/// Punkte entlang eines Pfads (z. B. eines Strichs aus KanjiVG).
List<Offset> samplePath(Path path, [int n = strichPunkte]) {
  final metrics = path.computeMetrics().toList();
  final total = metrics.fold(0.0, (a, m) => a + m.length);
  if (metrics.isEmpty) return const [];
  if (total == 0) return List.filled(n, metrics.first.getTangentForOffset(0)?.position ?? Offset.zero);
  final out = <Offset>[];
  for (var i = 0; i < n; i++) {
    var d = total * i / (n - 1);
    for (final m in metrics) {
      if (d <= m.length || identical(m, metrics.last)) {
        out.add(m.getTangentForOffset(min(d, m.length))!.position);
        break;
      }
      d -= m.length;
    }
  }
  return out;
}

double _mittlererAbstand(List<Offset> a, List<Offset> b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    s += (a[i] - b[i]).distance;
  }
  return s / a.length;
}

enum StrichUrteil {
  /// Der erwartete Strich.
  richtig,

  /// Richtiger Strich, aber verkehrt herum gezogen.
  richtung,

  /// Ein späterer Strich – die Reihenfolge stimmt nicht.
  reihenfolge,

  /// Passt zu keinem Strich.
  falsch,
}

class StrichErgebnis {
  const StrichErgebnis(this.urteil, [this.strich]);
  final StrichUrteil urteil;

  /// Bei [StrichUrteil.reihenfolge]: welcher Strich es eigentlich war.
  final int? strich;

  @override
  String toString() => 'StrichErgebnis($urteil, $strich)';
}

/// Wie streng die Prüfung ist: 1 = normal, größer = lockerer.
class StrichToleranz {
  const StrichToleranz([this.faktor = 1.0]);
  final double faktor;

  /// Mittlerer Abstand der Punkte (Form und Lage).
  double get form => 15 * faktor;

  /// Abstand von Anfang und Ende.
  double get enden => 24 * faktor;
}

bool _passt(List<Offset> u, List<Offset> t, double uLen, StrichToleranz tol) {
  final tLen = strichLaenge(t);
  final kurz = tLen < 14;
  final form = kurz ? tol.form + 4 : tol.form;
  if (_mittlererAbstand(u, t) > form) return false;
  if ((u.first - t.first).distance > tol.enden || (u.last - t.last).distance > tol.enden) return false;
  if (!kurz) {
    final ratio = uLen / tLen;
    if (ratio < 0.35 || ratio > 2.6) return false;
  }
  return true;
}

/// Prüft einen gezeichneten Strich [drawn] (Feldkoordinaten) gegen die
/// Striche [targets] (schon mit [samplePath] abgetastet); [next] ist der
/// Strich, der jetzt dran ist.
StrichErgebnis pruefeStrich(
  List<Offset> drawn,
  List<List<Offset>> targets,
  int next, {
  StrichToleranz toleranz = const StrichToleranz(),
}) {
  if (next >= targets.length || drawn.isEmpty) return const StrichErgebnis(StrichUrteil.falsch);
  final glatt = vereinfache(drawn);
  final uLen = strichLaenge(glatt);
  final u = resample(glatt);
  final t = targets[next];
  if (_passt(u, t, uLen, toleranz)) return const StrichErgebnis(StrichUrteil.richtig);
  if (strichLaenge(t) >= 14 && _passt(u.reversed.toList(), t, uLen, toleranz)) {
    return const StrichErgebnis(StrichUrteil.richtung);
  }
  for (var j = next + 1; j < targets.length; j++) {
    if (_passt(u, targets[j], uLen, toleranz)) return StrichErgebnis(StrichUrteil.reihenfolge, j);
  }
  return const StrichErgebnis(StrichUrteil.falsch);
}
