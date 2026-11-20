import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../audio/player.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import 'figure.dart';
import 'kuma_poses.g.dart';

/// Hüllt eine Lernansicht ein (Spezifikation 20): zählt die Lernzeit und
/// zeigt nach 20 Minuten fünf Minuten Pause. Die Ansicht darunter bleibt, wie
/// sie ist – nach der Pause geht es genau dort weiter.
///
/// [sofort]: Die Pause beginnt beim nächsten Antippen, sobald die Zeit um ist
/// (Lesen, Wochentest). Sonst ruft die Ansicht selbst zwischen zwei Karten
/// `lernUhr.pruefe` auf (Schreiben, Wiederholen).
class LernPause extends StatefulWidget {
  const LernPause({super.key, required this.child, this.sofort = false, this.onEnde});
  final Widget child;
  final bool sofort;

  /// Die Pause ist vorbei (z. B. um das Vorlesen wieder zu starten).
  final VoidCallback? onEnde;

  @override
  State<LernPause> createState() => _LernPauseState();
}

class _LernPauseState extends State<LernPause> {
  Timer? _tick;
  bool _warPause = false;

  @override
  void initState() {
    super.initState();
    // Öffne ich eine Lernansicht und die 20 Minuten sind um, kommt erst die Pause.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).progress.lernUhr.pruefe(DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _down(PointerDownEvent _) {
    final uhr = AppScope.of(context).progress.lernUhr;
    final now = DateTime.now();
    if (widget.sofort) {
      uhr.pruefe(now);
    } else {
      uhr.aktiv(now);
    }
  }

  void _laufen(bool pause) {
    if (pause && _tick == null) {
      stopAudio();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final uhr = AppScope.of(context).progress.lernUhr;
        final now = DateTime.now();
        if (uhr.pausiert(now)) {
          setState(() {});
        } else {
          uhr.weiter(now);
        }
      });
    } else if (!pause && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
    if (_warPause && !pause) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onEnde?.call());
    }
    _warPause = pause;
  }

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final now = DateTime.now();
        final pause = progress.lernUhr.pausiert(now);
        _laufen(pause);
        return Stack(
          children: [
            Listener(onPointerDown: _down, behavior: HitTestBehavior.translucent, child: widget.child),
            if (pause) Positioned.fill(child: _PauseView(rest: progress.lernUhr.rest(now))),
          ],
        );
      },
    );
  }
}

class _PauseView extends StatelessWidget {
  const _PauseView({required this.rest});
  final Duration rest;

  @override
  Widget build(BuildContext context) {
    final s = rest.inSeconds;
    final mm = (s ~/ 60).toString();
    final ss = (s % 60).toString().padLeft(2, '0');
    return Material(
      color: YoColors.coconutMilk,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const AnimatedFigure(pose: KumaPose.tea, height: 150),
                  const SizedBox(height: 12),
                  Text('Pause', style: serif(30, weight: 460)),
                  const SizedBox(height: 6),
                  Text('$mm:$ss', style: serif(54, weight: 400)),
                  const SizedBox(height: 10),
                  Text(
                    'Du hast 20 Minuten gelernt. Jetzt fünf Minuten Pause: aufstehen, in die Ferne schauen, '
                    'einen Schluck Tee trinken. Danach geht es genau hier weiter.',
                    style: sans(16, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  TextButton(
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    child: const Text('Zur Startseite'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
