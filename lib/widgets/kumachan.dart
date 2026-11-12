import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../audio/player.dart';
import '../data/audio_key.dart';
import '../data/models.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import 'figure.dart';
import 'furigana.dart';
import 'kuma_poses.g.dart';

/// Kumachan, die kleine Teemeisterin, in einer Stimmung (Spezifikation 13):
/// begruessung, fertig, perfekt, rueckschlag, hinweis, serie, ruhetag, aufstieg.
///
/// Sie wählt einen Spruch und eine passende Pose. Antippen der Sprechblase
/// spielt ihre Stimme ab; „auf Deutsch“ steht klein darunter.
class KumaMoment extends StatefulWidget {
  const KumaMoment({super.key, required this.mood, this.height = 140});

  final String mood;
  final double height;

  @override
  State<KumaMoment> createState() => _KumaMomentState();
}

class _KumaMomentState extends State<KumaMoment> {
  final _random = Random();
  (KumaPose, KumaLine)? _choice;
  var _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_choice == null && !_loading) _pick();
  }

  @override
  void didUpdateWidget(KumaMoment old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) _pick();
  }

  Future<void> _pick() async {
    _loading = true;
    final moods = await AppScope.of(context).repo.kumaMoods();
    _loading = false;
    final mood = moods[widget.mood];
    if (!mounted || mood == null || mood.lines.isEmpty) return;
    final poses = [for (final p in mood.poses) ?KumaPose.values.asNameMap()[p]];
    setState(() {
      _choice = (
        poses.isEmpty ? KumaPose.tea : poses[_random.nextInt(poses.length)],
        mood.lines[_random.nextInt(mood.lines.length)],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final choice = _choice;
    if (choice == null) return SizedBox(height: widget.height);
    final (pose, line) = choice;
    final repo = AppScope.of(context).repo;
    return Kumachan(
      pose: pose,
      say: line.ja,
      de: line.de,
      height: widget.height,
      onTap: () => playClip(repo.audioUrl(kumaAudioPath(line.ja))),
    );
  }
}

/// Kumachan mit Sprechblase.
class Kumachan extends StatelessWidget {
  const Kumachan({
    super.key,
    required this.say,
    required this.de,
    this.pose = KumaPose.tea,
    this.height = 140,
    this.onTap,
  });

  /// Spruch in Ruby-Schreibweise, z. B. „お{茶|ちゃ}をどうぞ。“
  final String say;
  final String de;
  final KumaPose pose;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      AnimatedFigure(pose: pose, height: height),
      const SizedBox(width: 6),
      Flexible(
        child: Padding(
          padding: EdgeInsets.only(bottom: height * 0.45),
          child: MouseRegion(
            cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: CustomPaint(
                painter: _BubblePainter(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(child: RubyText(say, fontSize: height < 110 ? 16 : 19)),
                          if (onTap != null) ...[
                            const SizedBox(width: 6),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 3),
                              child: Icon(Icons.volume_up_rounded, size: 16, color: YoColors.inkSoft),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(de, style: sans(13.5, color: YoColors.inkSoft)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// Sprechblase mit weichen Rundungen und kleiner Spitze nach links.
class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tip = 10.0;
    final r = RRect.fromRectAndCorners(
      Rect.fromLTWH(tip, 0, size.width - tip, size.height),
      topLeft: const Radius.elliptical(22, 18),
      topRight: const Radius.elliptical(18, 22),
      bottomLeft: const Radius.elliptical(20, 24),
      bottomRight: const Radius.elliptical(24, 18),
    );
    final path = Path()
      ..addRRect(r)
      ..moveTo(tip + 2, size.height - 22)
      ..lineTo(0, size.height - 10)
      ..lineTo(tip + 8, size.height - 12)
      ..close();
    canvas.drawPath(path, Paint()..color = YoColors.brightWhite);
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => false;
}
