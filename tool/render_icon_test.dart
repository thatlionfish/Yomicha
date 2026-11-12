// Rendert das App-Icon (lib/ui/app_icon.dart) in alle Größen für web/.
//
//   flutter test tool/render_icon_test.dart
//
// Läuft als Test, weil Flutter dort ohne Fenster echte Bilder zeichnen kann.
// Liegt unter tool/, damit `flutter test` (test/) es nicht jedes Mal ausführt.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yomicha/ui/app_icon.dart';

/// Eckig zugeschnittene Icons dürfen Kumachan größer zeigen; „maskable“
/// (Android schneidet einen Kreis aus) bleibt bei 1.
const _gross = 1.15;

Future<void> _render(String path, int size, {double zoom = _gross}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  AppIconPainter(zoom: zoom).paint(canvas, Size.square(size.toDouble()));
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
  stdout.writeln('$path ($size × $size)');
}

void main() {
  testWidgets('App-Icon rendern', (tester) async {
    await tester.runAsync(() async {
      // Im Test gibt es keine App-Schriften; 読み茶 braucht Zen Old Mincho.
      final font = File('assets/fonts/ZenOldMincho-Yomicha.ttf').readAsBytesSync();
      await (FontLoader('ZenOldMincho')..addFont(Future.value(ByteData.sublistView(font)))).load();
      await _render('web/icons/Icon-512.png', 512);
      await _render('web/icons/Icon-192.png', 192);
      await _render('web/icons/Icon-maskable-512.png', 512, zoom: 1);
      await _render('web/icons/Icon-maskable-192.png', 192, zoom: 1);
      await _render('web/icons/apple-touch-icon.png', 180);
      await _render('web/favicon.png', 64);
      await _render('assets/logo/icon-1024.png', 1024);
    });
  });
}
