import 'dart:js_interop';

import 'package:web/web.dart' as web;

web.HTMLAudioElement? _el;
var _generation = 0;

Future<void> play(String url, {required double rate, void Function()? onEnded}) async {
  stop();
  final gen = _generation;
  final a = web.HTMLAudioElement()
    ..src = url
    ..preload = 'auto';
  a.playbackRate = rate;
  a.onended = ((web.Event _) {
    if (gen == _generation) onEnded?.call();
  }).toJS;
  _el = a;
  try {
    await a.play().toDart;
  } catch (_) {
    // z. B. wenn der Browser ohne Antippen nicht abspielen darf.
  }
}

void setRate(double rate) => _el?.playbackRate = rate;

void stop() {
  _generation++;
  _el?.pause();
  _el = null;
}
