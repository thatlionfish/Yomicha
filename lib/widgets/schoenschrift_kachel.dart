import 'package:flutter/material.dart';

import '../learn/schoenschrift.dart';
import '../learn/strich_pruefung.dart' show feld;
import '../ui/colors.dart';
import '../ui/theme.dart';
import 'schreibfeld.dart' show zeichneTinte;
import 'stroke_order.dart';

/// Mein Zeichen über der Vorlage (Spezifikation 19, Schönschreiben): Vorlage
/// blass, meine Striche darüber; der Strich, der am meisten abweicht, ist in
/// der Vorlage dunkler und hat einen Punkt am Anfang. Darunter die Note.
class SchoenschriftKachel extends StatelessWidget {
  const SchoenschriftKachel({super.key, required this.note, this.size = 120, this.mitText = true});
  final ZeichenNote note;
  final double size;
  final bool mitText;

  @override
  Widget build(BuildContext context) {
    final schlecht = note.alleGut ? null : note.schlechtester;
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(color: YoColors.brightWhite, borderRadius: BorderRadius.all(Radius.circular(14))),
            child: CustomPaint(painter: _KachelPainter(note: note, schlecht: schlecht)),
          ),
          if (mitText) ...[
            const SizedBox(height: 6),
            Text('${note.urteil} · ${note.note}', style: sans(14, weight: 650), textAlign: TextAlign.center),
            Text(
              schlecht == null ? 'Alle Striche nah an der Vorlage' : 'Strich ${schlecht + 1}: ${note.hinweise[schlecht]}',
              style: sans(13, color: YoColors.inkSoft),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _KachelPainter extends CustomPainter {
  _KachelPainter({required this.note, required this.schlecht});
  final ZeichenNote note;
  final int? schlecht;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / feld);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Hilfslinien wie im Schreibheft.
    line
      ..color = YoColors.sand
      ..strokeWidth = 0.5;
    for (var y = 4.0; y < 105; y += 4) {
      canvas.drawLine(Offset(54.5, y), Offset(54.5, y + 2), line);
      canvas.drawLine(Offset(y, 54.5), Offset(y + 2, 54.5), line);
    }
    final paths = [for (final d in note.paths) parseSvgPath(d)];
    for (var i = 0; i < paths.length; i++) {
      line
        ..color = i == schlecht ? YoColors.woodAsh : YoColors.sand
        ..strokeWidth = i == schlecht ? 6.5 : 5.5;
      canvas.drawPath(paths[i], line);
    }
    for (final t in note.tinte) {
      zeichneTinte(canvas, t, YoColors.chocolate);
    }
    if (schlecht case final s? when s < paths.length) {
      // Anfang des Strichs, der am meisten abweicht: Punkt in Lemon Grass.
      final m = paths[s].computeMetrics().firstOrNull;
      final a = m?.getTangentForOffset(0)?.position;
      if (a != null) {
        canvas.drawCircle(a, 2.6, Paint()..color = YoColors.lemonGrass);
        canvas.drawCircle(
          a,
          2.6,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7
            ..color = YoColors.chocolate,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KachelPainter old) => old.note != note || old.schlecht != schlecht;
}

/// Die Kacheln aller geschriebenen Zeichen eines Wortes, darüber die Note.
class SchoenschriftReihe extends StatelessWidget {
  const SchoenschriftReihe({super.key, required this.noten});
  final List<ZeichenNote> noten;

  @override
  Widget build(BuildContext context) {
    if (noten.isEmpty) return const SizedBox.shrink();
    final gesamt = (noten.map((n) => n.note).reduce((a, b) => a + b) / noten.length).round();
    return Column(
      children: [
        Text('Schönschrift $gesamt', style: sans(13.5, weight: 650, color: YoColors.inkSoft)),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [for (final n in noten) SchoenschriftKachel(note: n, size: noten.length > 3 ? 96 : 120)],
        ),
      ],
    );
  }
}
