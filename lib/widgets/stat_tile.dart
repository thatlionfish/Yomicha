import 'package:flutter/material.dart';

import '../learn/weekly.dart';
import '../learn/wochenbilanz.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';

/// Farben der Wochenbalken – geprüft mit dem Palette-Validator (Stufen eines
/// Farbtons, helles Ende 2,03:1 gegen den Kartengrund #F4F9FF).
const wocheAktuell = Color(0xFF2A5F9E);
const wocheFrueher = Color(0xFF9FB2D3);

/// Kennzahl einer Woche als Kachel (Spezifikation 13): Wert, Veränderung zur
/// Vorwoche und die letzten Wochen als kleine Balken. Antippen eines Balkens
/// zeigt seinen Wert.
class StatTile extends StatefulWidget {
  const StatTile({super.key, required this.kennzahl, required this.weeks});
  final Kennzahl kennzahl;

  /// Älteste zuerst, die letzte ist die laufende Woche.
  final List<WeekStats> weeks;

  @override
  State<StatTile> createState() => _StatTileState();
}

class _StatTileState extends State<StatTile> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final k = widget.kennzahl;
    final weeks = widget.weeks;
    final values = [for (final w in weeks) k.of(w)];
    // Gezeigt wird die laufende Woche; hat sie noch nichts, die letzte mit Werten.
    var shown = values.length - 1;
    while (shown > 0 && values[shown] == null) {
      shown--;
    }
    if (values.isNotEmpty && values[shown] == null) shown = values.length - 1;
    final value = values.isEmpty ? null : values[shown];
    final before = shown > 0 ? values[shown - 1] : null;
    final change = value != null && before != null ? Veraenderung(k, before, value) : null;
    final which = shown == values.length - 1 ? 'diese Woche' : 'letzte Woche';
    final sel = _selected;
    return Semantics(
      label: '${k.label}: ${k.format(value)} $which. '
          '${[for (final (i, w) in weeks.indexed) 'KW ${isoWeek(w.weekStart)} ${k.format(values[i])}'].join(', ')}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: const BoxDecoration(color: YoColors.brightWhite, borderRadius: organicRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k.label, style: sans(13.5, weight: 650, color: YoColors.inkSoft)),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: k.formatNumber(value), style: sans(22, weight: 650)),
                if (value != null && k.unit.isNotEmpty)
                  TextSpan(text: ' ${k.unit}', style: sans(13, color: YoColors.inkSoft)),
              ]),
            ),
            Text(which, style: sans(12, color: YoColors.inkSoft)),
            const SizedBox(height: 6),
            if (change != null && change.spuerbar)
              _DeltaChip(change: change)
            else
              Text(
                change == null ? 'Vergleich ab der zweiten Woche' : 'wie in der Vorwoche',
                style: sans(12.5, color: YoColors.inkSoft),
              ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, box) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => setState(() {
                  final i = (d.localPosition.dx / box.maxWidth * values.length).floor().clamp(0, values.length - 1);
                  _selected = _selected == i ? null : i;
                }),
                child: CustomPaint(
                  size: Size(box.maxWidth, 40),
                  painter: _Bars(values: values, current: values.length - 1, selected: sel),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sel == null
                  ? 'letzte ${values.length} Wochen'
                  : 'KW ${isoWeek(weeks[sel].weekStart)}: ${values[sel] == null ? 'keine Werte' : k.format(values[sel])}',
              style: sans(12, color: YoColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.change});
  final Veraenderung change;

  @override
  Widget build(BuildContext context) {
    final up = change.delta > 0;
    final good = change.besser;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // Die Farbe unterstützt nur; Pfeil und Wort sagen dasselbe.
        color: good ? YoColors.lemonGrass.withValues(alpha: 0.45) : YoColors.sand,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 15, color: YoColors.chocolate),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '${change.kennzahl.formatDelta(change.delta, short: true)} · ${good ? 'besser' : 'weniger gut'}',
              style: sans(12.5, weight: 600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dünne Balken, am Grund verankert, oben 4 px gerundet, 2 px Abstand.
/// Wochen ohne Wert zeigen nur einen kurzen Strich auf der Grundlinie.
class _Bars extends CustomPainter {
  _Bars({required this.values, required this.current, required this.selected});
  final List<double?> values;
  final int current;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    final max = values.whereType<double>().fold(0.0, (a, b) => b > a ? b : a);
    final slot = size.width / n;
    final w = (slot - 4).clamp(4.0, 24.0);
    final base = size.height - 1;
    canvas.drawLine(Offset(0, base + 0.5), Offset(size.width, base + 0.5), Paint()
      ..color = YoColors.woodAsh
      ..strokeWidth = 1);
    for (var i = 0; i < n; i++) {
      final x = slot * i + (slot - w) / 2;
      final v = values[i];
      if (v == null || max <= 0) {
        canvas.drawRect(Rect.fromLTWH(x + w / 2 - 3, base - 2, 6, 2), Paint()..color = YoColors.woodAsh);
        continue;
      }
      final h = (v / max * (size.height - 4)).clamp(3.0, size.height - 2);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, base - h, w, h),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(rect, Paint()..color = i == current ? wocheAktuell : wocheFrueher);
      if (i == selected) {
        canvas.drawRRect(rect.inflate(1.5), Paint()
          ..color = YoColors.chocolate
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      }
    }
  }

  @override
  bool shouldRepaint(_Bars old) => old.values != values || old.selected != selected;
}

/// Kacheln nebeneinander, zwei pro Zeile (ab 560 px drei).
class StatTileGrid extends StatelessWidget {
  const StatTileGrid({super.key, required this.weeks, required this.kennzahlen});
  final List<WeekStats> weeks;
  final List<Kennzahl> kennzahlen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final perRow = box.maxWidth >= 560 ? 3 : 2;
      final w = (box.maxWidth - 10 * (perRow - 1)) / perRow;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final k in kennzahlen) SizedBox(width: w, child: StatTile(kennzahl: k, weeks: weeks)),
        ],
      );
    },
  );
}
