import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomicha/data/models.dart';
import 'package:yomicha/data/progress.dart';
import 'package:yomicha/data/repository.dart';
import 'package:yomicha/data/schreib_plan.dart';
import 'package:yomicha/learn/schreiben.dart';
import 'package:yomicha/learn/strich_pruefung.dart';
import 'package:yomicha/main.dart';
import 'package:yomicha/screens/schreiben_screen.dart';
import 'package:yomicha/widgets/figure.dart';
import 'package:yomicha/widgets/schreibfeld.dart';
import 'package:yomicha/widgets/stroke_order.dart';

dynamic _file(String path) => jsonDecode(File('web/data/$path').readAsStringSync());

/// Liest alles aus web/data statt aus dem Netz.
class _FileRepo extends Repository {
  @override
  Future<SchreibPlan> schreibPlan() async => SchreibPlan.fromJson(_file('schreiben/plan.json') as Map<String, dynamic>);
  @override
  Future<Map<String, List<String>>> kana() async => {
    for (final e in (_file('schreiben/kana.json') as Map<String, dynamic>).entries) e.key: (e.value as List).cast<String>(),
  };
  @override
  Future<KanjiInfo?> kanjiInfo(String kanji) async {
    final f = File('web/data/kanji/${kanjiBucket(kanji)}.json');
    if (!f.existsSync()) return null;
    final j = (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)[kanji];
    return j == null ? null : KanjiInfo.fromJson(kanji, j as Map<String, dynamic>);
  }

  @override
  Future<Map<String, KanjiInfo>> kanjiFor(Iterable<String> chars) async {
    final out = <String, KanjiInfo>{};
    for (final c in chars.toSet()) {
      final k = await kanjiInfo(c);
      if (k != null) out[c] = k;
    }
    return out;
  }
  @override
  Future<Map<String, String>> partNames() async => {};
}

/// Schreibt das Zeichen im Schreibfeld mit dem Stift, Strich für Strich richtig.
Future<void> _write(WidgetTester tester, List<String> paths) async {
  final box = find.byType(Schreibfeld);
  final topLeft = tester.getTopLeft(box);
  final size = tester.getSize(box).shortestSide;
  for (final d in paths) {
    final pts = resample(samplePath(parseSvgPath(d)), 12);
    final g = await tester.startGesture(topLeft + pts.first * (size / feld), kind: PointerDeviceKind.stylus);
    for (final p in pts.skip(1)) {
      await g.moveTo(topLeft + p * (size / feld));
    }
    await g.up();
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
}

Future<(Progress, _FileRepo, SchreibPlan)> _setup(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final p = Progress();
  await p.load();
  p.setKuma(KumaMode.aus);
  AnimatedFigure.animate = false;
  tester.view.physicalSize = const Size(820 * 2, 1180 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final repo = _FileRepo();
  return (p, repo, await repo.schreibPlan());
}

void main() {
  testWidgets('Wiederholung: Lesung wählen, dann das Wort mit Okurigana schreiben', (tester) async {
    if (DateTime.now().weekday == DateTime.sunday) return; // Ruhetag
    final (p, repo, plan) = await _setup(tester);
    final st = p.schreiben..uebernimm(plan.vorwissen);
    st.setTagesziel(1);
    st.mehrKanji(DateTime.now(), -1); // heute keine neuen Kanji
    st.setWoerterProTag(5);
    final word = plan.woerter.firstWhere((w) => w.key == '大きい|おおきい');
    final now = DateTime.now();
    st.speichere('w:${word.key}', fsrs.Card(cardId: 7, due: now.subtract(const Duration(hours: 1)).toUtc(), state: fsrs.State.review, stability: 3, difficulty: 5, lastReview: now.subtract(const Duration(days: 3)).toUtc()), now);
    // Alle anderen neuen Wörter sind für heute schon dran gewesen.
    for (var i = 0; i < 5; i++) {
      st.speichere('w:x$i', fsrs.Card(cardId: 100 + i, due: now.add(const Duration(days: 9)).toUtc()), now);
    }

    await tester.pumpWidget(YomichaApp(repo: repo, progress: p, home: const SchreibenScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Wiederholen: 1'), findsOneWidget);
    await tester.tap(find.text('Los geht’s'));
    await tester.pumpAndSettle();
    expect(find.text('Wie liest man das Wort?'), findsOneWidget);
    expect(find.text(word.bedeutung), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'おおきい'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(4));
    await tester.tap(find.widgetWithText(OutlinedButton, 'おおきい'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Schreibe das Wort'), findsOneWidget);
    final striche = await repo.striche(word.t.split(''));
    for (final c in word.t.split('')) {
      await _write(tester, striche[c]!);
    }
    await tester.pumpAndSettle();
    expect(find.text('Gut geschrieben'), findsOneWidget);
    expect(st.karte('w:${word.key}').due.isAfter(now.add(const Duration(days: 1)).toUtc()), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Neues Kanji: vorstellen, nachfahren, aus dem Kopf – mit dem Stift', (tester) async {
    if (DateTime.now().weekday == DateTime.sunday) return; // Ruhetag
    SharedPreferences.setMockInitialValues({});
    final p = Progress();
    await p.load();
    p.setKuma(KumaMode.aus);
    AnimatedFigure.animate = false;
    tester.view.physicalSize = const Size(820 * 2, 1180 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final repo = _FileRepo();
    final plan = await repo.schreibPlan();

    await tester.pumpWidget(YomichaApp(repo: repo, progress: p, home: const SchreibenScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Dein bisheriger Stand'), findsOneWidget);
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();
    expect(p.schreiben.kann('配'), isTrue);
    expect(find.text('Neue Kanji: noch 4 von 4'), findsOneWidget);
    // Bis N2 zählen auch die N1-Bestandteile, die davor drankommen (又 vor 支).
    final bisN2 = plan.bisN2.where((k) => !plan.vorwissen.contains(k)).length;
    expect(bisN2, greaterThan(605));
    expect(find.textContaining('Noch $bisN2 Kanji bis N2'), findsOneWidget);
    expect(find.textContaining('Danach N1:'), findsOneWidget);

    // 又 (ein N1-Bestandteil von 支) hat kein eigenes Wort: als schon gelernt
    // annehmen, damit nach dem ersten Kanji gleich seine Wörter kommen.
    expect(plan.reihenfolge.firstWhere((k) => !plan.vorwissen.contains(k)), '又');
    p.schreiben.lerne('又', DateTime(2026, 1, 5));
    await tester.tap(find.text('Schreiben'));
    await tester.pumpAndSettle();
    final first = plan.reihenfolge.firstWhere((k) => !p.schreiben.kann(k));
    expect(find.text('Neues Kanji · 1'), findsOneWidget);
    await tester.tap(find.text('Nachfahren'));
    await tester.pumpAndSettle();
    final paths = (await repo.kanjiInfo(first))!.paths;
    final zaehler = find.textContaining(RegExp(r'^1 von \d+$'));
    expect(zaehler, findsOneWidget);
    final gesamt = tester.widget<Text>(zaehler).data;

    // Rückgängig: Der erste Strich steht, dann ist er wieder weg.
    await _write(tester, paths.take(1).toList());
    final feld = tester.state<SchreibfeldState>(find.byType(Schreibfeld));
    expect(feld.naechsterStrich, 1);
    await tester.tap(find.text('Rückgängig'));
    await tester.pump();
    expect(feld.naechsterStrich, 0);

    // Nachfahren mit Vorlage, dann aus dem Kopf.
    await _write(tester, paths);
    expect(find.text('Neues Kanji · Jetzt aus dem Kopf'), findsOneWidget);
    await _write(tester, paths);
    await tester.pumpAndSettle();
    expect(find.text('Gut geschrieben'), findsOneWidget);
    expect(p.schreiben.kann(first), isTrue);
    expect(p.schreiben.kanjiAm(DateTime.now()), 1);

    // Ein Finger zählt jetzt nicht mehr: Der Stift war da.
    expect(p.schreiben.stiftGesehen, isTrue);
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();

    // Danach die Wörter mit dem neuen Kanji – ganz, mit Kana.
    final kana = await repo.kana();
    final alle = alleWoerter(plan, const [], kana.keys.toSet());
    final word = neueWoerter(p.schreiben, alle, DateTime.now()).firstWhere((w) => w.kanji.contains(first));
    expect(find.text('Neues Wort'), findsOneWidget);
    expect(find.text(word.t), findsWidgets);
    await tester.tap(find.text('Nachschreiben'));
    await tester.pumpAndSettle();
    final striche = await repo.striche(word.t.split(''));
    for (final c in word.t.split('')) {
      await _write(tester, striche[c]!);
    }
    await tester.pumpAndSettle();
    expect(p.schreiben.hatKarte('w:${word.key}'), isTrue);
    expect(p.schreiben.neueWoerterAm(DateTime.now()), 1);
    // Fertig geschrieben: Wort (und Satz) einmal, dann weiter.
    expect(find.text('Neues Wort geschrieben'), findsOneWidget);
    // Die Gesamtzahl wächst nicht, auch wenn Karten nochmal drankommen.
    expect(find.textContaining(RegExp(r'von \d+$')).evaluate().map((e) => (e.widget as Text).data!.split(' ').last),
        everyElement(gesamt!.split(' ').last));

    // Nach 20 Minuten Lernen kommt zwischen zwei Karten die Pause.
    p.lernUhr.aktiv(DateTime.now());
    p.lernUhr.gelernt = const Duration(minutes: 21);
    await tester.tap(find.text('Weiter'));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);
    expect(p.lernUhr.pausiert(DateTime.now()), isTrue);
    expect(tester.takeException(), isNull);
  });
}
