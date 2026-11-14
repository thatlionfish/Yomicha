import 'dart:math';

import 'package:flutter/material.dart';

import '../ui/colors.dart';

/// Kleine Feier: ein paar Teeblätter fallen einmal sanft herab (ca. 3 s).
/// Wer in den Systemeinstellungen „Bewegung reduzieren“ gewählt hat, sieht nichts.
class Teeblaetter extends StatefulWidget {
  const Teeblaetter({super.key, this.count = 22});
  final int count;

  @override
  State<Teeblaetter> createState() => _TeeblaetterState();
}

class _TeeblaetterState extends State<Teeblaetter> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));
  late final _leaves = List.generate(widget.count, (i) => _Leaf(Random(i * 7 + 3)));
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _anim.forward();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) => _anim.isCompleted
            ? const SizedBox.shrink()
            : CustomPaint(painter: _LeavesPainter(_leaves, _anim.value), size: Size.infinite),
      ),
    );
  }
}

class _Leaf {
  _Leaf(Random r)
    : x = r.nextDouble(),
      delay = r.nextDouble() * 0.35,
      size = 7 + r.nextDouble() * 7,
      spin = (r.nextDouble() - 0.5) * 5,
      phase = r.nextDouble() * 2 * pi,
      color = const [Color(0xFFB9BF6E), YoColors.lemonGrass, Color(0xFF8E9A5B), YoColors.woodAsh][r.nextInt(4)];
  final double x, delay, size, spin, phase;
  final Color color;
}

class _LeavesPainter extends CustomPainter {
  _LeavesPainter(this.leaves, this.t);
  final List<_Leaf> leaves;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in leaves) {
      final p = ((t - l.delay) / (1 - l.delay)).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final y = -20 + p * (size.height + 40);
      final x = l.x * size.width + sin(p * 2 * pi + l.phase) * 14;
      final fade = 1 - pow(p, 3).toDouble();
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(l.phase + p * l.spin);
      final s = l.size;
      final leaf = Path()
        ..moveTo(-s, 0)
        ..quadraticBezierTo(0, -s * 0.55, s, 0)
        ..quadraticBezierTo(0, s * 0.55, -s, 0)
        ..close();
      canvas.drawPath(leaf, Paint()..color = l.color.withValues(alpha: 0.85 * fade));
      canvas.drawLine(Offset(-s * 0.8, 0), Offset(s * 0.8, 0), Paint()
        ..color = YoColors.chocolate.withValues(alpha: 0.25 * fade)
        ..strokeWidth = 0.8);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LeavesPainter old) => old.t != t;
}
