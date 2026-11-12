import 'package:flutter/material.dart';

import 'colors.dart';

/// App-Icon von Yomicha: Kumachan, die kleine Teemeisterin, hält eine
/// Teeschale mit Matcha, auf der 読み茶 steht. Formen und Farben wie in
/// `tool/gen_kuma.dart` (Knopfaugen, rosa Kragen, rosa Pfoten).
///
/// Gezeichnet im Feld 1024 × 1024; alles Wichtige liegt im sicheren Kreis
/// (80 %), damit es auch als „maskable“ Icon nichts abschneidet.
class AppIconPainter extends CustomPainter {
  const AppIconPainter({this.background = true, this.zoom = 1});

  /// Ohne Hintergrund z. B. für das Logo in der App.
  final bool background;

  /// Vergrößert Kumachan um die Mitte. 1 = sicher für „maskable“ (Kreis),
  /// bis etwa 1,25 für Icons mit eckigem Zuschnitt und ohne Hintergrund.
  final double zoom;

  // Kumachans Farben (wie in tool/gen_kuma.dart).
  static const _ink = Color(0xFF685A4E);
  static const _mauve = Color(0xFF8E7486);
  static const _mauveDark = Color(0xFF6F5869);
  static const _mauveLight = Color(0xFFA38D9C);
  static const _paw = Color(0xFFF1DCD6);
  static const _collar = Color(0xFFEFD6E2);
  static const _pink = Color(0xFFE7A9B9);
  static const _nose = Color(0xFF5B4A3E);
  static const _button = Color(0xFFFBF8F1);
  static const _mouth = Color(0xFFC97F6E);
  // Teeschale.
  static const _matcha = Color(0xFFB9BF6E);
  static const _clay = YoColors.woodAsh;
  static const _glaze = Color(0xFF9C8A78);
  static const _foot = Color(0xFFB3A288);

  /// Kumachan ist im Feld 200 × 300 entworfen; hier 5,2-fach vergrößert.
  static const _s = 5.2;
  static const _tx = 512 - 100 * _s;
  static const _ty = -40.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1024, size.height / 1024);
    if (background) {
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1024, 1024), Paint()..color = YoColors.coconutMilk);
    }
    canvas.translate(512, 512);
    canvas.scale(zoom);
    canvas.translate(-512, -512);
    if (background) {
      // Weicher Schatten unter der Schale.
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(512, 874), width: 380, height: 34),
        Paint()..color = YoColors.woodAsh.withValues(alpha: 0.55),
      );
    }

    // Kumachan (Oberkörper, Arme, Kopf) im Entwurfsfeld.
    _inDesign(canvas, _bear);
    // Die Schale vor dem Körper, die Pfoten halten sie seitlich.
    _cup(canvas);
    _inDesign(canvas, (c) {
      for (final x in [70.0, 130.0]) {
        _shape(c, Path()..addOval(Rect.fromCircle(center: Offset(x, 140), radius: 7.5)), _paw);
      }
    });
    canvas.restore();
  }

  void _inDesign(Canvas canvas, void Function(Canvas) draw) {
    canvas.save();
    canvas.translate(_tx, _ty);
    canvas.scale(_s);
    draw(canvas);
    canvas.restore();
  }

  /// Fläche mit dunklem Umriss, wie in den SVG-Posen.
  void _shape(Canvas canvas, Path p, Color fill, {double stroke = 2}) {
    canvas.drawPath(p, Paint()..color = fill);
    canvas.drawPath(
      p,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _bear(Canvas canvas) {
    // Oberkörper (unten von der Schale verdeckt) und Hals.
    _shape(
      canvas,
      Path()
        ..moveTo(74, 118)
        ..cubicTo(68, 132, 68, 146, 72, 156)
        ..cubicTo(76, 166, 124, 166, 128, 156)
        ..cubicTo(132, 146, 132, 132, 126, 118)
        ..cubicTo(116, 108, 84, 108, 74, 118)
        ..close(),
      _mauve,
    );
    _shape(
      canvas,
      Path()
        ..moveTo(88, 98)
        ..cubicTo(87, 106, 87, 114, 86, 121)
        ..cubicTo(94, 125, 106, 125, 114, 121)
        ..cubicTo(113, 114, 113, 106, 112, 98)
        ..close(),
      _mauve,
    );
    _shape(
      canvas,
      Path()
        ..moveTo(82, 111)
        ..cubicTo(94, 119, 106, 119, 118, 111)
        ..cubicTo(119, 117, 112, 123, 100, 123)
        ..cubicTo(88, 123, 81, 117, 82, 111)
        ..close(),
      _collar,
    );

    // Arme zur Schale.
    for (final arm in [
      Path()
        ..moveTo(80, 126)
        ..cubicTo(70, 128, 66, 133, 70, 140),
      Path()
        ..moveTo(120, 126)
        ..cubicTo(130, 128, 134, 133, 130, 140),
    ]) {
      canvas.drawPath(arm, Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 19
        ..strokeCap = StrokeCap.round);
      canvas.drawPath(arm, Paint()
        ..color = _mauve
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round);
    }

    // Ohren.
    for (final x in [68.0, 132.0]) {
      _shape(canvas, Path()..addOval(Rect.fromCircle(center: Offset(x, 52), radius: 13)), _mauve);
      canvas.drawCircle(Offset(x + (x < 100 ? 1 : -1), 53), 6.5, Paint()..color = _mauveDark.withValues(alpha: 0.55));
    }

    // Kopf.
    _shape(canvas, Path()..addOval(Rect.fromCircle(center: const Offset(100, 78), radius: 34)), _mauve);

    // Wangen.
    for (final x in [74.0, 126.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 86), width: 11, height: 6.5),
        Paint()..color = _pink.withValues(alpha: 0.6),
      );
    }

    // Schnauze, Nase, Mund.
    _shape(canvas, Path()..addOval(Rect.fromCenter(center: const Offset(100, 91), width: 31, height: 25)), _mauveLight);
    _shape(
      canvas,
      Path()..addOval(Rect.fromCenter(center: const Offset(100, 86.5), width: 14.4, height: 11.2)),
      _nose,
      stroke: 1,
    );
    canvas.drawLine(const Offset(100, 92), const Offset(100, 95.5), Paint()
      ..color = _ink
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round);
    _shape(
      canvas,
      Path()
        ..moveTo(93.5, 95)
        ..cubicTo(97, 101, 103, 101, 106.5, 95)
        ..close(),
      _mouth,
      stroke: 1.4,
    );

    // Knopfaugen.
    for (final x in [84.0, 116.0]) {
      const y = 71.0;
      _shape(canvas, Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: 7.2)), _button, stroke: 1.6);
      final hole = Paint()..color = _ink;
      for (final (dx, dy) in const [(-2.0, -2.0), (2.0, -2.0), (-2.0, 2.0), (2.0, 2.0)]) {
        canvas.drawCircle(Offset(x + dx, y + dy), 1, hole);
      }
      final thread = Paint()
        ..color = _ink.withValues(alpha: 0.7)
        ..strokeWidth = 0.7
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x - 2, y - 2), Offset(x + 2, y + 2), thread);
      canvas.drawLine(Offset(x + 2, y - 2), Offset(x - 2, y + 2), thread);
    }
  }

  /// Teeschale (茶碗) mit Matcha: heller Ton, Glasur läuft vom Rand herab.
  void _cup(Canvas canvas) {
    const top = 660.0;
    final ink = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeJoin = StrokeJoin.round;

    final foot = RRect.fromRectAndRadius(const Rect.fromLTWH(436, 836, 152, 30), const Radius.circular(10));
    canvas.drawRRect(foot, Paint()..color = _foot);
    canvas.drawRRect(foot, ink);

    final body = Path()
      ..moveTo(350, top)
      ..cubicTo(348, 748, 372, 808, 420, 836)
      ..cubicTo(452, 854, 572, 854, 604, 836)
      ..cubicTo(652, 808, 676, 748, 674, top)
      ..close();
    canvas.drawPath(body, Paint()..color = _clay);

    final glaze = Path()
      ..moveTo(350, top)
      ..lineTo(674, top)
      ..cubicTo(675, 692, 660, 704, 642, 699)
      ..cubicTo(622, 694, 616, 724, 594, 720)
      ..cubicTo(570, 716, 566, 696, 542, 700)
      ..cubicTo(516, 705, 508, 734, 482, 730)
      ..cubicTo(456, 726, 452, 700, 428, 702)
      ..cubicTo(404, 704, 396, 720, 374, 714)
      ..cubicTo(356, 709, 351, 692, 350, top)
      ..close();
    canvas.drawPath(glaze, Paint()..color = _glaze);
    canvas.drawPath(body, ink);

    final rim = Rect.fromCenter(center: const Offset(512, top), width: 324, height: 64);
    canvas.drawOval(rim, Paint()..color = _glaze);
    canvas.drawOval(rim, ink);
    canvas.drawOval(Rect.fromCenter(center: const Offset(512, top + 2), width: 284, height: 44), Paint()..color = _matcha);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(494, top - 2), width: 140, height: 14),
      Paint()..color = YoColors.lemonGrass.withValues(alpha: 0.9),
    );

    // Der Name auf der Schale, wie aufgemalt. Zen Old Mincho ist sehr fein;
    // ein zarter Umriss macht die Striche auch im kleinen Icon sichtbar.
    for (final stroke in [true, false]) {
      final name = TextPainter(
        text: TextSpan(
          text: '読み茶',
          style: TextStyle(
            fontFamily: 'ZenOldMincho',
            fontSize: 68,
            height: 1,
            letterSpacing: 4,
            foreground: Paint()
              ..color = _ink
              ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
              ..strokeWidth = 2.6
              ..strokeJoin = StrokeJoin.round,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      name.paint(canvas, Offset(512 - (name.width - 4) / 2 - 2, 784 - name.height / 2));
      name.dispose();
    }
  }

  @override
  bool shouldRepaint(AppIconPainter oldDelegate) =>
      oldDelegate.background != background || oldDelegate.zoom != zoom;
}

/// Das Icon als Widget (z. B. klein in der App).
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, this.size = 48, this.background = true, this.zoom = 1});
  final double size;
  final bool background;
  final double zoom;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: AppIconPainter(background: background, zoom: zoom),
      );
}
