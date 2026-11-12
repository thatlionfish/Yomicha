import 'package:flutter/foundation.dart';

import 'player_stub.dart' if (dart.library.js_interop) 'player_web.dart' as impl;

/// Spielt eine einzelne Aufnahme, z. B. ein Wort.
Future<void> playClip(String url) => impl.play(url, rate: 1);

void stopAudio() => impl.stop();

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
