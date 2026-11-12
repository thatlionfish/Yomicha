import 'package:flutter/material.dart';

import '../ui/colors.dart';
import '../ui/theme.dart';

/// Liest die SVG-Pfade von KanjiVG (Befehle M, L, H, V, C, S, Z; groß und klein).
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'[MmLlHhVvCcSsZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  var i = 0;
  var cmd = 'M';
  var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;
  double? lastC2x, lastC2y;
  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double n() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
    switch (cmd.toUpperCase()) {
      case 'M':
        x = ox + n();
        y = oy + n();
        path.moveTo(x, y);
        startX = x;
        startY = y;
        cmd = rel ? 'l' : 'L'; // weitere Zahlenpaare sind Linien
        lastC2x = null;
      case 'L':
        x = ox + n();
        y = oy + n();
        path.lineTo(x, y);
        lastC2x = null;
      case 'H':
        x = ox + n();
        path.lineTo(x, y);
        lastC2x = null;
      case 'V':
        y = oy + n();
        path.lineTo(x, y);
        lastC2x = null;
      case 'C':
        final x1 = ox + n(), y1 = oy + n(), x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
        lastC2x = x2;
        lastC2y = y2;
      case 'S':
        final x1 = lastC2x == null ? x : 2 * x - lastC2x;
        final y1 = lastC2y == null || lastC2x == null ? y : 2 * y - lastC2y;
        final x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
        lastC2x = x2;
        lastC2y = y2;
      case 'Z':
        path.close();
        x = startX;
        y = startY;
        lastC2x = null;
      default:
        i++; // unbekannt: überspringen
    }
  }
  return path;
}

/// Anfangspunkt eines Strichs (für die Nummer).
Offset strokeStart(String d) {
  final m = RegExp(r'[Mm]\s*(-?[\d.]+)[,\s]*(-?[\d.]+)').firstMatch(d);
  return m == null ? Offset.zero : Offset(double.parse(m.group(1)!), double.parse(m.group(2)!));
}

/// Strichfolge: nummerierte Striche, Strich für Strich weiterschaltbar
/// (Spezifikation 5; die Animation folgt in Stufe 2).
class StrokeOrder extends StatefulWidget {
  const StrokeOrder({super.key, required this.paths, this.size = 150});
  final List<String> paths;
  final double size;

  @override
  State<StrokeOrder> createState() => _StrokeOrderState();
}

class _StrokeOrderState extends State<StrokeOrder> {
  late final _paths = [for (final d in widget.paths) parseSvgPath(d)];
  late final _starts = [for (final d in widget.paths) strokeStart(d)];

  /// Anzahl gezeigter Striche; alle = fertiges Kanji mit Nummern.
  late int _shown = widget.paths.length;

  void _step(int delta) => setState(() {
    final n = widget.paths.length;
    if (n == 0) return;
    _shown = ((_shown - 1 + delta) % n + n) % n + 1;
  });

  @override
  Widget build(BuildContext context) {
    final n = widget.paths.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _step(1),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: const BoxDecoration(color: YoColors.brightWhite, borderRadius: organicRadius),
            child: CustomPaint(painter: _StrokePainter(_paths, _starts, _shown)),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Strich $_shown von $n', style: sans(14.5, weight: 600)),
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  tooltip: 'Strich zurück',
                  onPressed: () => _step(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  tooltip: 'Nächster Strich',
                  onPressed: () => _step(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Text('Tippen: nächster Strich', style: sans(12.5, color: YoColors.inkSoft)),
          ],
        ),
      ],
    );
  }
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.paths, this.starts, this.shown);
  final List<Path> paths;
  final List<Offset> starts;
  final int shown;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 109;
    canvas.save();
    canvas.scale(scale);
    final grid = Paint()
      ..color = YoColors.sand
      ..strokeWidth = 0.6;
    canvas.drawLine(const Offset(54.5, 4), const Offset(54.5, 105), grid);
    canvas.drawLine(const Offset(4, 54.5), const Offset(105, 54.5), grid);
    for (var i = 0; i < paths.length; i++) {
      final done = i < shown;
      final current = i == shown - 1 && shown < paths.length;
      canvas.drawPath(
        paths[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 3.4
          ..color = !done
              ? YoColors.sand
              : current || shown == paths.length
              ? YoColors.chocolate
              : YoColors.woodAsh,
      );
    }
    for (var i = 0; i < shown && i < starts.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: '${i + 1}', style: sans(7, weight: 700, color: YoColors.chocolate, height: 1)),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = starts[i] - const Offset(5.5, 5.5);
      tp.paint(canvas, Offset(p.dx.clamp(0, 102), p.dy.clamp(0, 102)));
      tp.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StrokePainter old) => old.shown != shown || old.paths != paths;
}
