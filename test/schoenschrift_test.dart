import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
    bool ziehe(double schritt) {
      final pinsel = Pinsel()..start(Offset.zero, Duration.zero, druck: 0.5);
      for (var i = 1; i <= 20; i++) {
        pinsel.weiter(Offset(i * schritt, 0), Duration(milliseconds: i * 16), druck: 0.5);
      }
      return pinsel.spitzesEnde;
    }

    expect(ziehe(6), isTrue); // 6 Einheiten in 16 ms
    expect(ziehe(1), isFalse);
    expect(Pinsel(an: false).spitzesEnde, isFalse);

    // In der Form: spitz läuft das Ende schmal aus, rund bleibt es breit.
    final pts = [for (var i = 0; i <= 20; i++) Offset(10.0 + i * 4, 50)];
    final ws = List.filled(pts.length, 6.0);
    final spitz = pinselPfad(Tinte(pts, ws, spitz: true));
    final rund = pinselPfad(Tinte(pts, ws));
    expect(spitz.contains(const Offset(87, 52)), isFalse);
    expect(rund.contains(const Offset(87, 52)), isTrue);
    expect(spitz.contains(const Offset(40, 52)), isTrue);
    expect(spitz.getBounds().right, lessThan(90.5));
  });

  test('Spitz auslaufen nur bei はらい und はね, nicht bei waagerecht oder senkrecht', () {
    List<Offset> linie(Offset a, Offset b) => [for (var i = 0; i <= 10; i++) a + (b - a) * (i / 10)];
    expect(darfAuslaufen(linie(const Offset(20, 50), const Offset(80, 50))), isFalse); // ㇐
    expect(darfAuslaufen(linie(const Offset(50, 20), const Offset(50, 80))), isFalse); // ㇑
    expect(darfAuslaufen(linie(const Offset(60, 20), const Offset(20, 80))), isTrue); // ㇒
    expect(darfAuslaufen(linie(const Offset(40, 40), const Offset(80, 80))), isTrue); // ㇏
    expect(darfAuslaufen([...linie(const Offset(50, 20), const Offset(50, 80)), const Offset(46, 76), const Offset(42, 72)]), isTrue); // 亅
    // Echte Vorlagen: 木 – waagerecht und senkrecht rund, die beiden Schrägen spitz.
    final mu = targetsOf(pathsOf('木'));
    expect([for (final t in mu) darfAuslaufen(t)], [false, false, true, true]);
    // 小: der Haken (亅) läuft aus.
    expect(darfAuslaufen(targetsOf(pathsOf('小')).first), isTrue);
  });

  test('Pinselform: keine weißen Lücken an scharfen Ecken (z. B. ㇕)', () {
    // Waagerecht nach rechts, dann scharf nach unten – breiter Pinsel.
    final pts = <Offset>[
      for (var x = 10.0; x <= 50; x += 2) Offset(x, 30),
      for (var y = 32.0; y <= 80; y += 2) Offset(50, y),
    ];
    final path = pinselPfad(Tinte(pts, List.filled(pts.length, 9.0)));
    // Alles im Umkreis von 3 Einheiten um die Mittellinie ist gefüllt,
    // auch innen an der Ecke, wo sich der Rand überschlägt.
    for (var x = 12.0; x <= 50; x += 1) {
      for (final dy in [-3.0, 0.0, 3.0]) {
        expect(path.contains(Offset(x, 30 + dy)), isTrue, reason: 'waagerecht bei ($x, ${30 + dy})');
      }
    }
    for (var y = 30.0; y <= 78; y += 1) {
      for (final dx in [-3.0, 0.0, 3.0]) {
        expect(path.contains(Offset(50 + dx, y)), isTrue, reason: 'senkrecht bei (${50 + dx}, $y)');
      }
    }
    // Außerhalb bleibt frei.
    expect(path.contains(const Offset(30, 40)), isFalse);
    expect(path.contains(const Offset(60, 60)), isFalse);
  });

  test('Pinselform: glatt auch bei wenigen, groben Stiftpunkten', () {
    // Ein Bogen aus nur fünf Punkten (schnell gezogen): Die Kontur folgt einer
    // Kurve durch die Punkte, ohne Knick und ohne Lücke.
    final pts = [for (var i = 0; i <= 4; i++) Offset(20.0 + i * 15, 60 - 20 * sin(i * pi / 4))];
    final path = pinselPfad(Tinte(pts, List.filled(pts.length, 6.0)));
    for (var i = 0; i < 4; i++) {
      final mitte = (pts[i] + pts[i + 1]) / 2;
      expect(path.contains(mitte), isTrue, reason: 'zwischen Punkt $i und ${i + 1}');
    }
    for (final q in pts) {
      expect(path.contains(q), isTrue);
    }
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
