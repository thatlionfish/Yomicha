import 'package:flutter/material.dart';

import '../data/stufen.dart';
import '../learn/calendar.dart';
import '../learn/goal.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';

/// Farben der beiden Linien – geprüft mit dem Palette-Validator (Kontrast,
/// Farbsehschwäche, Unterscheidbarkeit) auf Bright White.
const indigo = Color(0xFF2A5F9E); // meine Stufe (藍色)
const hojicha = Color(0xFFB5673A); // Ziel (ほうじ茶)

const _monthsShort = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];

String fmtStufe(double s) => s.toStringAsFixed(1).replaceAll('.', ',');
String fmtDate(DateTime d) => '${d.day}.${d.month}.${d.year}';

/// Zielkurve (gestrichelt) und meine Stufe (durchgezogen) bis zur Prüfung.
class GoalChart extends StatefulWidget {
  const GoalChart({super.key, required this.history, required this.today, this.height = 250});

  /// Stufenverlauf, erster Eintrag = Start.
  final List<(DateTime, int)> history;
  final DateTime today;
  final double height;

  @override
  State<GoalChart> createState() => _GoalChartState();
}

class _GoalChartState extends State<GoalChart> {
  DateTime? _hover;

  @override
  Widget build(BuildContext context) {
    final (start, startStufe) = widget.history.first;
    final now = widget.today;
    final current = widget.history.last.$2;
    return Semantics(
      label: 'Zielkurve: Start ${fmtDate(start)} auf Stufe $startStufe, Ziel Stufe 6 bis 31.8.2027 und Stufe 7 bis 30.11.2027. '
          'Heute Ziel Stufe ${fmtStufe(targetStufe(start, startStufe, now))}, meine Stufe $current.',
      child: LayoutBuilder(
        builder: (context, box) {
          final geo = _Geometry(Size(box.maxWidth, widget.height), start, examDate);
          void hover(Offset p) => setState(() => _hover = geo.dateAt(p.dx));
          return GestureDetector(
            onTapDown: (d) => hover(d.localPosition),
            onHorizontalDragUpdate: (d) => hover(d.localPosition),
            child: MouseRegion(
              onHover: (e) => hover(e.localPosition),
              onExit: (_) => setState(() => _hover = null),
              child: CustomPaint(
                size: Size(box.maxWidth, widget.height),
                painter: _GoalPainter(geo, widget.history, now, _hover),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Geometry {
  _Geometry(this.size, this.start, this.end);
  final Size size;
  final DateTime start;
  final DateTime end;

  static const left = 84.0, right = 14.0, top = 14.0, bottom = 30.0;
  double get w => size.width - left - right;
  double get h => size.height - top - bottom;

  double x(DateTime d) => left + w * (d.difference(start).inHours / end.difference(start).inHours).clamp(0, 1);
  double y(double stufe) => top + h * (7 - stufe) / 6;
  DateTime dateAt(double px) {
    final t = ((px - left) / w).clamp(0.0, 1.0);
    return start.add(Duration(hours: (end.difference(start).inHours * t).round()));
  }
}

class _GoalPainter extends CustomPainter {
  _GoalPainter(this.g, this.history, this.today, this.hover);
  final _Geometry g;
  final List<(DateTime, int)> history;
  final DateTime today;
  final DateTime? hover;

  void _text(Canvas c, String s, Offset at, {double size = 11, Color color = YoColors.inkSoft, TextAlign align = TextAlign.left, FontWeight? weight}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: sans(size, color: color, height: 1.1, weight: weight == FontWeight.w600 ? 600 : 420)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => at.dx - tp.width,
      TextAlign.center => at.dx - tp.width / 2,
      _ => at.dx,
    };
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
    tp.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final (start, startStufe) = history.first;
    final grid = Paint()
      ..color = YoColors.sand
      ..strokeWidth = 1;

    // Gitter und Stufen (zurückhaltend).
    for (var s = 1; s <= 7; s++) {
      final y = g.y(s.toDouble());
      canvas.drawLine(Offset(_Geometry.left, y), Offset(size.width - _Geometry.right, y), grid);
      _text(canvas, '$s ${Stufe.of(s).name}', Offset(_Geometry.left - 8, y), align: TextAlign.right);
    }

    // Monate an der Zeitachse, jeder zweite beschriftet.
    var m = DateTime(start.year, start.month + 1);
    var i = 0;
    while (m.isBefore(g.end)) {
      final x = g.x(m);
      canvas.drawLine(Offset(x, g.size.height - _Geometry.bottom), Offset(x, g.size.height - _Geometry.bottom + 4), grid);
      // Nicht mit „Prüfung“ am rechten Rand zusammenstoßen.
      if (i.isEven && x < size.width - _Geometry.right - 56) {
        _text(canvas, m.month == 1 ? '${_monthsShort[0]} ${m.year % 100}' : _monthsShort[m.month - 1],
            Offset(x, g.size.height - _Geometry.bottom + 14), align: TextAlign.center);
      }
      m = DateTime(m.year, m.month + 1);
      i++;
    }

    // Heute: feine senkrechte Linie.
    final xt = g.x(today);
    canvas.drawLine(Offset(xt, _Geometry.top), Offset(xt, g.size.height - _Geometry.bottom), grid..strokeWidth = 1.2);

    // Ziel: gestrichelt (zweites Merkmal neben der Farbe).
    final target = Path()..moveTo(g.x(start), g.y(startStufe.toDouble()));
    for (final (d, s) in [(gyokuroBy, 6.0), (matchaBy, 7.0), (g.end, 7.0)]) {
      target.lineTo(g.x(d), g.y(s));
    }
    _dashed(canvas, target, Paint()
      ..color = hojicha
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);

    // Meine Stufe: Stufenlinie bis heute.
    final actual = Path()..moveTo(g.x(start), g.y(startStufe.toDouble()));
    var last = startStufe;
    for (final (d, s) in history.skip(1)) {
      actual
        ..lineTo(g.x(d), g.y(last.toDouble()))
        ..lineTo(g.x(d), g.y(s.toDouble()));
      last = s;
    }
    actual.lineTo(xt, g.y(last.toDouble()));
    canvas.drawPath(actual, Paint()
      ..color = indigo
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round);

    // Punkt „heute“ mit hellem Ring.
    final dot = Offset(xt, g.y(last.toDouble()));
    canvas.drawCircle(dot, 6, Paint()..color = YoColors.brightWhite);
    canvas.drawCircle(dot, 4, Paint()..color = indigo);

    // Direkte Beschriftung (Textfarbe, nicht Serienfarbe).
    // Unter dem Punkt – die Ziellinie steigt nach rechts oben.
    _text(canvas, 'Meine Stufe', dot + const Offset(10, 13), weight: FontWeight.w600, color: YoColors.chocolate);
    _text(canvas, 'Ziel', Offset(g.x(matchaBy) - 4, g.y(7) + 12), align: TextAlign.right, weight: FontWeight.w600, color: YoColors.chocolate);
    _text(canvas, 'Prüfung', Offset(size.width - _Geometry.right, g.size.height - _Geometry.bottom + 14), align: TextAlign.right);

    // Fadenkreuz und Hinweis beim Antippen.
    final h = hover;
    if (h != null) {
      final x = g.x(h);
      canvas.drawLine(Offset(x, _Geometry.top), Offset(x, g.size.height - _Geometry.bottom),
          Paint()..color = YoColors.inkSoft..strokeWidth = 1);
      final t = targetStufe(start, startStufe, h);
      canvas.drawCircle(Offset(x, g.y(t)), 4, Paint()..color = hojicha);
      final lines = ['${h.day}.${h.month}.${h.year}', 'Ziel: Stufe ${fmtStufe(t)} (${Stufe.of(t.floor()).name})'];
      if (!h.isAfter(today)) {
        var s = startStufe;
        for (final (d, v) in history) {
          if (!d.isAfter(h)) s = v;
        }
        lines.add('Meine Stufe: $s (${Stufe.of(s).name})');
      }
      final tp = TextPainter(
        text: TextSpan(text: lines.join('\n'), style: sans(12, color: YoColors.chocolate, height: 1.35)),
        textDirection: TextDirection.ltr,
      )..layout();
      var bx = x + 10;
      if (bx + tp.width + 16 > size.width) bx = x - tp.width - 26;
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(bx, _Geometry.top, tp.width + 16, tp.height + 12), const Radius.circular(10));
      canvas.drawRRect(rect, Paint()..color = YoColors.brightWhite);
      canvas.drawRRect(rect, Paint()
        ..color = YoColors.woodAsh
        ..style = PaintingStyle.stroke);
      tp.paint(canvas, Offset(bx + 8, _Geometry.top + 6));
      tp.dispose();
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_GoalPainter old) => old.hover != hover || old.history != history || old.today != today;
}

/// Legende über dem Diagramm.
class GoalLegend extends StatelessWidget {
  const GoalLegend({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 18,
    children: [
      _item(dashed: false, color: indigo, label: 'Meine Stufe'),
      _item(dashed: true, color: hojicha, label: 'Ziel'),
    ],
  );

  Widget _item({required bool dashed, required Color color, required String label}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CustomPaint(size: const Size(26, 10), painter: _LegendLine(color, dashed)),
      const SizedBox(width: 6),
      Text(label, style: sans(13.5)),
    ],
  );
}

class _LegendLine extends CustomPainter {
  _LegendLine(this.color, this.dashed);
  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (dashed) {
      canvas.drawLine(Offset(0, y), Offset(9, y), p);
      canvas.drawLine(Offset(15, y), Offset(size.width, y), p);
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_LegendLine old) => false;
}
