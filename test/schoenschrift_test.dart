import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomicha/data/models.dart';
import 'package:yomicha/data/progress.dart';
import 'package:yomicha/data/repository.dart';
import 'package:yomicha/learn/schoenschrift.dart';
import 'package:yomicha/learn/strich_pruefung.dart';
import 'package:yomicha/main.dart';
import 'package:yomicha/screens/schoenschreib_screen.dart';
import 'package:yomicha/widgets/figure.dart';
import 'package:yomicha/widgets/schreibfeld.dart';
import 'package:yomicha/widgets/stroke_order.dart';

List<String> pathsOf(String kanji) {
  final f = File('web/data/kanji/${kanjiBucket(kanji)}.json');
  final j = (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)[kanji] as Map<String, dynamic>;
  return (j['paths'] as List).cast<String>();
}

List<List<Offset>> targetsOf(List<String> paths) => [for (final d in paths) samplePath(parseSvgPath(d))];

Tinte tinte(List<Offset> pts) => Tinte(pts, List.filled(pts.length, grundBreite));

void main() {
  test('Pinsel: fester Druck breiter, schnell dünner, ohne Pinsel gleichmäßig', () {
    const t0 = Duration.zero;
    final leicht = Pinsel()..start(Offset.zero, t0, druck: 0.2);
    final fest = Pinsel()..start(Offset.zero, t0, druck: 0.9);
    var wl = 0.0, wf = 0.0;
    for (var i = 1; i <= 10; i++) {
      wl = leicht.weiter(Offset(i * 1.0, 0), Duration(milliseconds: i * 16), druck: 0.2);
      wf = fest.weiter(Offset(i * 1.0, 0), Duration(milliseconds: i * 16), druck: 0.9);
    }
    expect(wf, greaterThan(wl));

    final langsam = Pinsel()..start(Offset.zero, t0);
    final schnell = Pinsel()..start(Offset.zero, t0);
    var ws = 0.0, wq = 0.0;
    for (var i = 1; i <= 10; i++) {
      ws = langsam.weiter(Offset(i * 0.5, 0), Duration(milliseconds: i * 16));
      wq = schnell.weiter(Offset(i * 12.0, 0), Duration(milliseconds: i * 16));
    }
    expect(wq, lessThan(ws));

    final aus = Pinsel(an: false);
    expect(aus.start(Offset.zero, t0, druck: 1), grundBreite);
    expect(aus.weiter(const Offset(30, 0), const Duration(milliseconds: 1), druck: 1), grundBreite);
  });

  test('Pinsel: schnell beendet spitz (はらい), langsam beendet rund (とめ)', () {
    List<double> ziehe(double schritt) {
      final pinsel = Pinsel();
      final pts = <Offset>[Offset.zero];
      final ws = <double>[pinsel.start(Offset.zero, Duration.zero, druck: 0.5)];
      for (var i = 1; i <= 20; i++) {
        final q = Offset(i * schritt, 0);
        pts.add(q);
        ws.add(pinsel.weiter(q, Duration(milliseconds: i * 16), druck: 0.5));
      }
      return pinsel.ende(pts, ws);
    }

    final schnell = ziehe(6); // 6 Einheiten in 16 ms
    final langsam = ziehe(1);
    expect(schnell.last, lessThan(schnell[10] * 0.3));
    expect(langsam.last, greaterThan(langsam[10] * 0.8));
  });

  test('Pinselform: geschlossene, gefüllte Kontur um den Strich', () {
    final pts = [for (var i = 0; i <= 20; i++) Offset(10.0 + i * 4, 50)];
    final t = Tinte(pts, List.filled(pts.length, 6.0));
    final path = pinselPfad(t);
    final r = path.getBounds();
    // So breit wie der Strich, oben und unten je die halbe Breite.
    expect(r.top, closeTo(47, 0.6));
    expect(r.bottom, closeTo(53, 0.6));
    expect(r.left, closeTo(7, 0.6));
    expect(r.right, closeTo(93, 0.6));
    expect(path.contains(const Offset(50, 50)), isTrue);
    expect(path.contains(const Offset(50, 56)), isFalse);
    // Einzelner Punkt: ein Kreis.
    expect(pinselPfad(Tinte(const [Offset(5, 5)], const [4])).getBounds().width, closeTo(4, 0.01));
    // Derselbe Strich wird nur einmal berechnet.
    expect(identical(pinselPfad(t), path), isTrue);
  });

  test('Schönschrift: genau wie die Vorlage 100, verschoben weniger mit Hinweis', () {
    final paths = pathsOf('十');
    final targets = targetsOf(paths);
    final genau = bewerteZeichen('十', paths, targets, [for (final t in targets) tinte(t)]);
    expect(genau.note, 100);
    expect(genau.alleGut, isTrue);

    // Der senkrechte Strich 8 Einheiten zu weit rechts.
    final schief = bewerteZeichen('十', paths, targets, [
      tinte(targets[0]),
      tinte([for (final p in targets[1]) p + const Offset(8, 0)]),
    ]);
    expect(schief.note, lessThan(genau.note));
    expect(schief.schlechtester, 1);
    expect(schief.hinweise[1], 'zu weit rechts');
    expect(schief.alleGut, isFalse);

    // Der waagerechte Strich nur halb so lang.
    final kurz = bewerteZeichen('十', paths, targets, [
      tinte(targets[0].sublist(6, 18)),
      tinte(targets[1]),
    ]);
    expect(kurz.schlechtester, 0);
    expect(kurz.hinweise[0], 'zu kurz');
    expect(strichNote(1.5), 100);
    expect(strichNote(4), 83);
    expect(strichNote(20), 0);
  });

  testWidgets('Schönschreiben: schreiben, Vergleich mit Note, nochmal', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = Progress();
    await p.load();
    p.setKuma(KumaMode.aus);
    AnimatedFigure.animate = false;
    tester.view.physicalSize = const Size(820 * 2, 1180 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final paths = pathsOf('十');

    await tester.pumpWidget(
      YomichaApp(repo: Repository(), progress: p, home: SchoenschreibScreen(zeichen: '十', paths: paths, bedeutung: 'zehn')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Schönschreiben · 十'), findsOneWidget);

    Future<void> schreibe() async {
      final box = find.byType(Schreibfeld);
      final topLeft = tester.getTopLeft(box);
      final size = tester.getSize(box).shortestSide;
      for (final d in paths) {
        final pts = resample(samplePath(parseSvgPath(d)), 12);
        final g = await tester.startGesture(topLeft + pts.first * (size / feld), kind: PointerDeviceKind.stylus);
        for (final q in pts.skip(1)) {
          await g.moveTo(topLeft + q * (size / feld));
        }
        await g.up();
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));
    }

    await schreibe();
    expect(find.textContaining('Schönschrift'), findsOneWidget);
    expect(find.text('Beste Note: 100 · 1 Versuch'), findsOneWidget);
    await tester.tap(find.text('Nochmal'));
    await tester.pumpAndSettle();
    expect(find.byType(Schreibfeld), findsOneWidget);
    await schreibe();
    expect(find.text('Beste Note: 100 · 2 Versuche'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
