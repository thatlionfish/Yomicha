import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../learn/schoenschrift.dart';
import '../learn/strich_pruefung.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import 'stroke_order.dart';

/// Schreibfeld für ein Zeichen (Spezifikation 19). Jeder Strich wird sofort
/// geprüft: Ein richtiger Strich bleibt stehen, ein falscher verblasst wieder.
///
/// Mit dem Apple Pencil: Sobald auf dem Gerät einmal ein Stift geschrieben
/// hat ([nurStift]), zählen Finger und Handballen im Feld nicht mehr.
/// [pinsel]: Die Strichbreite folgt Druck und Tempo des Stifts.
class Schreibfeld extends StatefulWidget {
  const Schreibfeld({
    super.key,
    required this.paths,
    required this.onStrich,
    required this.onFertig,
    this.vorlage = false,
    this.hinweis = 0,
    this.nurStift = false,
    this.onStift,
    this.toleranz = const StrichToleranz(),
    this.anfang = const [],
    this.pinsel = false,
  });

  /// Die Striche des Zeichens in der richtigen Reihenfolge (KanjiVG).
  final List<String> paths;

  /// Nachfahren: das ganze Zeichen blass, dazu der Anfang des nächsten Strichs.
  final bool vorlage;

  /// 2: nächster Strich blass mit Anfangspunkt, 3: ganzes Zeichen blass.
  final int hinweis;

  final bool nurStift;
  final VoidCallback? onStift;
  final StrichToleranz toleranz;

  /// Schon geschriebene Striche (nach „Rückgängig“ aus dem nächsten Zeichen).
  final List<Tinte> anfang;

  final bool pinsel;

  /// Nach jedem Strich: wie er bewertet wurde.
  final void Function(StrichErgebnis ergebnis) onStrich;

  /// Alle Striche geschrieben; [fehler] = falsche Striche.
  final void Function(int fehler) onFertig;

  @override
  State<Schreibfeld> createState() => SchreibfeldState();
}

class SchreibfeldState extends State<Schreibfeld> {
  late List<Path> _paths;
  late List<List<Offset>> _targets;
  final List<Tinte> _ink = [];
  List<Offset>? _current;
  List<double> _currentW = [];
  late Pinsel _pinsel = Pinsel(an: widget.pinsel);
  int? _pointer;
  Tinte? _wrong;
  Timer? _wrongTimer;
  int _next = 0;
  int _fehler = 0;

  /// Falsche Versuche am aktuellen Strich – ab zwei zeigt das Feld ihn blass.
  int _miss = 0;

  int get fehler => _fehler;
  int get naechsterStrich => _next;
  bool get fertig => _next >= _paths.length;

  /// Die richtigen Striche, so wie ich sie geschrieben habe.
  List<Tinte> get tinte => List.of(_ink);

  /// Vergleich mit der Vorlage (Schönschrift), sobald das Zeichen fertig ist.
  ZeichenNote bewerte(String zeichen) => bewerteZeichen(zeichen, widget.paths, _targets, _ink);

  @override
  void initState() {
    super.initState();
    _prepare();
    _ink.addAll(widget.anfang.take(_paths.length));
    _next = _ink.length;
  }

  /// Nimmt den letzten richtigen Strich zurück; false, wenn es keinen gibt.
  bool rueckgaengig() {
    if (_ink.isEmpty) return false;
    setState(() {
      _ink.removeLast();
      _next = _ink.length;
      _current = null;
      _pointer = null;
      _wrong = null;
      _miss = 0;
    });
    return true;
  }

  void _prepare() {
    _paths = [for (final d in widget.paths) parseSvgPath(d)];
    _targets = [for (final p in _paths) samplePath(p)];
  }

  @override
  void didUpdateWidget(Schreibfeld oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paths != widget.paths) {
      _prepare();
      neu();
    }
    if (oldWidget.pinsel != widget.pinsel) _pinsel = Pinsel(an: widget.pinsel);
  }

  @override
  void dispose() {
    _wrongTimer?.cancel();
    super.dispose();
  }

  /// Alles löschen und von vorn schreiben (die Fehler bleiben gezählt).
  void neu() {
    setState(() {
      _ink.clear();
      _current = null;
      _pointer = null;
      _wrong = null;
      _next = 0;
      _miss = 0;
    });
  }

  static bool _stift(PointerEvent e) => e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.invertedStylus;

  bool _accept(PointerEvent e) {
    if (_stift(e)) {
      widget.onStift?.call();
      return true;
    }
    return !(widget.nurStift && e.kind == PointerDeviceKind.touch);
  }

  Offset _toField(Offset p, double size) => p * (feld / size);

  void _down(PointerDownEvent e, double size) {
    if (fertig || _pointer != null || !_accept(e)) return;
    final p = _toField(e.localPosition, size);
    setState(() {
      _pointer = e.pointer;
      _current = [p];
      _currentW = [_pinsel.start(p, e.timeStamp, druck: _stift(e) ? e.pressure : null)];
    });
  }

  void _move(PointerMoveEvent e, double size) {
    if (e.pointer != _pointer) return;
    final p = _toField(e.localPosition, size);
    setState(() {
      _current!.add(p);
      _currentW.add(_pinsel.weiter(p, e.timeStamp, druck: _stift(e) ? e.pressure : null));
    });
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    final drawn = _current ?? const [];
    final breiten = _currentW;
    _pointer = null;
    _current = null;
    _currentW = [];
    if (e is PointerCancelEvent || drawn.isEmpty) {
      setState(() {});
      return;
    }
    final r = pruefeStrich(drawn, _targets, _next, toleranz: widget.toleranz);
    setState(() {
      if (r.urteil == StrichUrteil.richtig) {
        _ink.add(Tinte(drawn, breiten));
        _next++;
        _miss = 0;
      } else {
        _fehler++;
        _miss++;
        _wrong = Tinte(drawn, breiten);
        _wrongTimer?.cancel();
        _wrongTimer = Timer(const Duration(milliseconds: 650), () {
          if (mounted) setState(() => _wrong = null);
        });
      }
    });
    widget.onStrich(r);
    if (fertig) widget.onFertig(_fehler);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final size = c.biggest.shortestSide;
      return SizedBox.square(
        dimension: size,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _down(e, size),
          onPointerMove: (e) => _move(e, size),
          onPointerUp: _up,
          onPointerCancel: _up,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: YoColors.brightWhite, borderRadius: organicRadius),
            child: CustomPaint(
              size: Size.square(size),
              painter: _FeldPainter(
                paths: _paths,
                targets: _targets,
                ink: _ink,
                current: _current == null ? null : Tinte(_current!, _currentW),
                wrong: _wrong,
                next: _next,
                vorlage: widget.vorlage || widget.hinweis >= 3,
                naechsterBlass: widget.vorlage || widget.hinweis >= 2 || _miss >= 2,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _FeldPainter extends CustomPainter {
  _FeldPainter({
    required this.paths,
    required this.targets,
    required this.ink,
    required this.current,
    required this.wrong,
    required this.next,
    required this.vorlage,
    required this.naechsterBlass,
  });

  final List<Path> paths;
  final List<List<Offset>> targets;
  final List<Tinte> ink;
  final Tinte? current;
  final Tinte? wrong;
  final int next;
  final bool vorlage;
  final bool naechsterBlass;

  Paint _stroke(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = w
    ..color = c;


  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / feld);

    // Hilfslinien wie im Schreibheft.
    final grid = _stroke(YoColors.sand, 0.5);
    for (var y = 4.0; y < 105; y += 4) {
      canvas.drawLine(Offset(54.5, y), Offset(54.5, y + 2), grid);
      canvas.drawLine(Offset(y, 54.5), Offset(y + 2, 54.5), grid);
    }

    final done = next >= paths.length;
    if (vorlage || done) {
      for (var i = 0; i < paths.length; i++) {
        if (i >= ink.length || done) canvas.drawPath(paths[i], _stroke(YoColors.sand, done ? 3.2 : 4.2));
      }
    }
    if (!done && naechsterBlass) {
      canvas.drawPath(paths[next], _stroke(YoColors.woodAsh, 4.2));
    }
    if (!done && (vorlage || naechsterBlass) && targets[next].isNotEmpty) {
      // Anfang des nächsten Strichs: Punkt in Lemon Grass, dunkel umrandet.
      final a = targets[next].first;
      canvas.drawCircle(a, 2.6, Paint()..color = YoColors.lemonGrass);
      canvas.drawCircle(a, 2.6, _stroke(YoColors.chocolate, 0.7));
    }
    for (final s in ink) {
      zeichneTinte(canvas, s, YoColors.chocolate);
    }
    if (wrong case final w?) zeichneTinte(canvas, w, YoColors.woodAsh);
    if (current case final c?) zeichneTinte(canvas, c, YoColors.chocolate);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FeldPainter old) => true;
}

/// Zeichnet einen Strich mit wechselnder Breite (Pinsel): Stück für Stück mit
/// runden Enden, jedes Stück so breit wie das Mittel seiner beiden Punkte.
void zeichneTinte(Canvas canvas, Tinte t, Color farbe) {
  final pts = t.punkte;
  if (pts.isEmpty) return;
  final w = t.breiten;
  double breite(int i) => i < w.length ? w[i] : grundBreite;
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = farbe;
  if (pts.length == 1) {
    canvas.drawCircle(pts.first, breite(0) / 2, Paint()..color = farbe);
    return;
  }
  for (var i = 1; i < pts.length; i++) {
    paint.strokeWidth = (breite(i - 1) + breite(i)) / 2;
    canvas.drawLine(pts[i - 1], pts[i], paint);
  }
}
