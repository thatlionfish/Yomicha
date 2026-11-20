import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Ein einziges Audio-Element für alle Aufnahmen: iPhone und iPad erlauben
/// das Abspielen ohne Antippen nur einem Element, das schon einmal gespielt hat.
web.HTMLAudioElement? _el;
var _generation = 0;

/// Aufnahmen, die sich nicht laden ließen – dann gleich die Sprachausgabe.
final _fehlt = <String>{};

Future<void> play(String url, {required double rate, void Function()? onEnded, String? sprich}) async {
  stop();
  final gen = _generation;
  if (url.isEmpty || _fehlt.contains(url)) {
    if (sprich != null) _speak(sprich, gen, onEnded);
    return;
  }
  final a = _el ??= web.HTMLAudioElement()..preload = 'auto';
  a.onended = ((web.Event _) {
    if (gen == _generation) onEnded?.call();
  }).toJS;
  a.onerror = ((web.Event _) {
    if (gen != _generation) return;
    _fehlt.add(url);
    if (sprich != null) _speak(sprich, gen, onEnded);
  }).toJS;
  a.src = url;
  // Beim Laden einer neuen Quelle setzt der Browser das Tempo zurück.
  a.defaultPlaybackRate = rate;
  a.playbackRate = rate;
  try {
    await a.play().toDart;
  } catch (_) {
    // z. B. wenn der Browser ohne Antippen nicht abspielen darf.
  }
}

/// Sprachausgabe des Geräts (Japanisch), wenn es keine Aufnahme gibt.
void speak(String text, {void Function()? onEnded}) {
  stop();
  _speak(text, _generation, onEnded);
}

void _speak(String text, int gen, void Function()? onEnded) {
  try {
    final u = web.SpeechSynthesisUtterance(text)
      ..lang = 'ja-JP'
      ..rate = 0.9;
    u.onend = ((web.Event _) {
      if (gen == _generation) onEnded?.call();
    }).toJS;
    web.window.speechSynthesis.speak(u);
  } catch (_) {
    // Ohne Sprachausgabe bleibt es still.
  }
}

void setRate(double rate) {
  _el?.defaultPlaybackRate = rate;
  _el?.playbackRate = rate;
}

void stop() {
  _generation++;
  _el?.pause();
  try {
    web.window.speechSynthesis.cancel();
  } catch (_) {}
}
