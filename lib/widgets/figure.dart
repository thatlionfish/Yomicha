import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Eine Pose einer Comic-Figur: Bilder, Dauer pro Bild, optional Blinzeln.
abstract interface class FigurePose {
  /// Dateinamen in `assets/<folder>/`.
  List<String> get frames;

  /// Anzeigedauer pro Bild in Millisekunden.
  List<int> get ms;

  /// Bild mit geschlossenen Augen, falls die Figur blinzeln kann.
  String? get blink;
  String get folder;

  /// Breite / Höhe.
  double get aspect;
}

/// Animierte Figur (Leoni, Kumachan).
///
/// Spielt die Bilder der Pose in einer Schleife ab, blinzelt ab und zu und
/// „atmet“ ganz leicht. Bei „Bewegung reduzieren“ steht die Figur still.
class AnimatedFigure extends StatefulWidget {
  const AnimatedFigure({super.key, required this.pose, this.height = 160});

  final FigurePose pose;
  final double height;

  /// In Widget-Tests ausschalten, damit pumpAndSettle zur Ruhe kommt.
  static bool animate = true;

  @override
  State<AnimatedFigure> createState() => _AnimatedFigureState();
}

class _AnimatedFigureState extends State<AnimatedFigure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  final Random _random = Random();
  Timer? _frameTimer;
  Timer? _blinkTimer;
  int _frame = 0;
  bool _blinking = false;
  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateRunning();
  }

  @override
  void didUpdateWidget(AnimatedFigure old) {
    super.didUpdateWidget(old);
    if (old.pose != widget.pose) {
      _stop();
      _frame = 0;
      _blinking = false;
      _updateRunning(force: true);
    }
  }

  void _updateRunning({bool force = false}) {
    final run =
        AnimatedFigure.animate && !MediaQuery.disableAnimationsOf(context);
    if (run == _running && !force) return;
    _running = run;
    if (run) {
      _breath.repeat(reverse: true);
      _scheduleFrame();
      _scheduleBlink();
    } else {
      _stop();
    }
  }

  void _stop() {
    _frameTimer?.cancel();
    _blinkTimer?.cancel();
    _breath.stop();
  }

  void _scheduleFrame() {
    final pose = widget.pose;
    if (pose.frames.length < 2) return;
    _frameTimer = Timer(Duration(milliseconds: pose.ms[_frame]), () {
      if (!mounted) return;
      setState(() => _frame = (_frame + 1) % pose.frames.length);
      _scheduleFrame();
    });
  }

  void _scheduleBlink() {
    if (widget.pose.blink == null) return;
    _blinkTimer = Timer(
      Duration(milliseconds: 2600 + _random.nextInt(2600)),
      () {
        if (!mounted) return;
        setState(() => _blinking = true);
        _blinkTimer = Timer(const Duration(milliseconds: 140), () {
          if (!mounted) return;
          setState(() => _blinking = false);
          _scheduleBlink();
        });
      },
    );
  }

  @override
  void dispose() {
    _stop();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pose = widget.pose;
    // Alle Bilder liegen bereit (IndexedStack), damit beim Wechsel nichts flackert.
    final files = [...pose.frames, ?pose.blink];
    // Blinzeln nur im Ruhebild, sonst würde die Bewegung „springen“.
    final index = _blinking && _frame == 0 && pose.blink != null
        ? files.length - 1
        : _frame;
    final figure = SizedBox(
      height: widget.height,
      width: widget.height * pose.aspect,
      child: IndexedStack(
        index: index,
        children: [
          for (final f in files)
            SvgPicture.asset(
              'assets/${pose.folder}/$f',
              height: widget.height,
              excludeFromSemantics: true,
            ),
        ],
      ),
    );
    if (!_running) return figure;
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_breath.value);
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(1, 1 + 0.012 * t, 1),
          child: child,
        );
      },
      child: figure,
    );
  }
}
