import 'dart:async';

import 'package:flutter/foundation.dart';

import 'player_stub.dart' if (dart.library.js_interop) 'player_web.dart' as impl;

/// Spielt eine einzelne Aufnahme, z. B. ein Wort. Fehlt die Aufnahme, liest
/// die Sprachausgabe des Geräts [sprich] vor (wenn angegeben).
Future<void> playClip(String url, {void Function()? onEnded, String? sprich}) =>
    impl.play(url, rate: 1, onEnded: onEnded, sprich: sprich);

void stopAudio() => impl.stop();

/// Ein Stück zum Vorlesen: die Aufnahme und – falls sie fehlt – der Text für
/// die Sprachausgabe des Geräts.
typedef Vortrag = ({String url, String text});

/// Liest Stücke nacheinander vor, mit einer Pause dazwischen; [endlos] immer
/// wieder von vorn, bis [stop] (Spezifikation 19: Schreiben mit Ton).
class Schleife {
  Schleife(this.stuecke, {this.endlos = true, this.pause = const Duration(milliseconds: 1800)});
  final List<Vortrag> stuecke;
  final bool endlos;
  final Duration pause;

  Timer? _timer;
  var _laeuft = false;
  var _lauf = 0;
  var _i = 0;

  bool get laeuft => _laeuft;

  void start() {
    if (stuecke.isEmpty) return;
    _laeuft = true;
    _spiele();
  }

  void _spiele() {
    final lauf = ++_lauf;
    final s = stuecke[_i % stuecke.length];
    playClip(
      s.url,
      sprich: s.text,
      onEnded: () {
        if (!_laeuft || lauf != _lauf) return;
        _i++;
        if (!endlos && _i >= stuecke.length) {
          _laeuft = false;
          return;
        }
        _timer = Timer(_i % stuecke.length == 0 ? pause : pause ~/ 2, () {
          if (_laeuft && lauf == _lauf) _spiele();
        });
      },
    );
  }

  void stop() {
    if (!_laeuft && _timer == null) return;
    _laeuft = false;
    _lauf++;
    _timer?.cancel();
    _timer = null;
    impl.stop();
  }
}

/// Liest einen Text Satz für Satz vor und meldet, welcher Satz gerade läuft
/// (Spezifikation 6). Pause und Weiter beginnen den Satz von vorn.
class SentencePlayer extends ChangeNotifier {
  SentencePlayer(this.urls, {this.rate = 1});

  /// Eine Aufnahme pro Satz; null = keine Aufnahme.
  final List<String?> urls;
  double rate;
  int? current;
  bool playing = false;

  /// Wurde überhaupt vorgelesen? (Dann zählt das Lesetempo nicht.)
  bool used = false;

  bool get available => urls.any((u) => u != null);

  void playFrom(int i) {
    while (i < urls.length && urls[i] == null) {
      i++;
    }
    if (i < 0 || i >= urls.length) {
      playing = false;
      notifyListeners();
      return;
    }
    current = i;
    playing = true;
    used = true;
    notifyListeners();
    impl.play(urls[i]!, rate: rate, onEnded: () {
      if (!playing || current != i) return;
      if (i + 1 < urls.length) {
        playFrom(i + 1);
      } else {
        playing = false;
        notifyListeners();
      }
    });
  }

  void toggle() => playing ? pause() : playFrom(current ?? 0);

  void pause() {
    impl.stop();
    playing = false;
    notifyListeners();
  }

  void next() => playFrom((current ?? -1) + 1);

  void previous() => playFrom(((current ?? 1) - 1).clamp(0, urls.length - 1));

  void setRate(double r) {
    rate = r;
    impl.setRate(r);
    notifyListeners();
  }

  @override
  void dispose() {
    impl.stop();
    super.dispose();
  }
}
