import 'dart:math';

import 'package:flutter/material.dart';

import '../ui/app_icon.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';

/// Größe des Logos beim Start – dieselbe Formel wie `#splash img` in
/// `web/index.html` (min(260px, 60vmin)), damit der Übergang vom
/// HTML-Startbild zu Flutter nicht springt.
double splashLogoSize(Size screen) => min(260, 0.6 * screen.shortestSide);

/// Beim Öffnen der App einmal groß das Logo, dann 読み茶 · Yomicha, dann
/// blendet die Startseite ein. Die Startseite baut sich darunter schon auf
/// und lädt ihre Texte.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});
  final Widget child;

  static const hold = Duration(milliseconds: 1500);
  static const fade = Duration(milliseconds: 500);

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with TickerProviderStateMixin {
  late final _name = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  late final _out = AnimationController(vsync: this, duration: SplashGate.fade);
  var _gone = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(SplashGate.hold, () async {
      if (!mounted) return;
      await _out.forward();
      if (mounted) setState(() => _gone = true);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (!_gone)
        Positioned.fill(
          child: IgnorePointer(
            ignoring: _out.isAnimating,
            child: FadeTransition(
              opacity: ReverseAnimation(_out),
              child: _Splash(name: CurvedAnimation(parent: _name, curve: Curves.easeOut)),
            ),
          ),
        ),
    ],
  );
}

class _Splash extends StatelessWidget {
  const _Splash({required this.name});
  final Animation<double> name;

  @override
  Widget build(BuildContext context) {
    final size = splashLogoSize(MediaQuery.sizeOf(context));
    return Material(
      color: YoColors.coconutMilk,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AppIcon(size: size, zoom: 1.15),
          // Der Name unter dem Logo, ohne das Logo aus der Mitte zu schieben.
          Transform.translate(
            offset: Offset(0, size / 2 + 44),
            child: FadeTransition(
              opacity: name,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('読み茶', style: jp(34, weight: FontWeight.w500)),
                  Text('Yomicha', style: serif(20).copyWith(color: YoColors.inkSoft)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
