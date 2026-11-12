import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomicha/data/models.dart';
import 'package:yomicha/data/progress.dart';
import 'package:yomicha/data/repository.dart';
import 'package:yomicha/learn/weekly.dart';
import 'package:yomicha/main.dart';
import 'package:yomicha/screens/weekly_screen.dart';
import 'package:yomicha/widgets/figure.dart';

List<TextDoc> _docs() => [
  for (final f in Directory('web/data/texte').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('text.json')))
    TextDoc.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>, folder: f.parent.path),
].where((d) => d.stufe == 2).toList();

Future<Progress> _progress() async {
  SharedPreferences.setMockInitialValues({});
  final p = Progress();
  await p.load();
  p.setKuma(KumaMode.aus);
  return p;
}

void main() {
  test('Welche Woche dran ist', () {
    final sat = DateTime(2026, 11, 14);
    expect(testWeek(sat), DateTime(2026, 11, 9)); // samstags: diese Woche
    expect(testWeek(DateTime(2026, 11, 17)), DateTime(2026, 11, 9)); // Dienstag: letzte Woche nachholen
    expect(testWeek(DateTime(2026, 11, 15)), isNull); // Sonntag: Ruhetag
    expect(isoWeek(DateTime(2026, 11, 12)), 46);
    expect(inWeek(DateTime(2026, 11, 12), DateTime(2026, 11, 9)), isTrue);
    expect(inWeek(DateTime(2026, 11, 16), DateTime(2026, 11, 9)), isFalse);
  });

  test('Wochentest aus den Texten: alle Bereiche, gültige Antworten, gleich bei gleicher Woche', () async {
    final p = await _progress();
    final week = DateTime(2026, 11, 9);
    final qs = buildWeeklyTest(docs: _docs(), progress: p, weekStart: week);
    expect(qs.length, greaterThanOrEqualTo(10));
    expect(qs.map((q) => q.section).toSet(), WeeklySection.values.toSet());
    for (final q in qs) {
      expect(q.options.length, greaterThanOrEqualTo(3), reason: q.prompt);
      expect(q.options.toSet().length, q.options.length, reason: 'doppelte Antwort: ${q.prompt}');
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
    }
    final again = buildWeeklyTest(docs: _docs(), progress: p, weekStart: week);
    expect(again.map((q) => q.prompt), qs.map((q) => q.prompt));
  });

  test('Falsch beantwortete Lesefragen kommen zuerst', () async {
    final p = await _progress();
    final doc = _docs().firstWhere((d) => d.id == '2026-11-12-hojicha-2');
    p.addRead(ReadRecord(
      id: doc.id, day: DateTime(2026, 11, 12), seconds: 120, chars: 190,
      correct: 3, total: 4, lookups: 0, rating: 0, usedAudio: false, wrong: const [2],
    ));
    final qs = buildWeeklyTest(docs: _docs(), progress: p, weekStart: DateTime(2026, 11, 9));
    final firstReading = qs.firstWhere((q) => q.section == WeeklySection.lesen);
    expect(firstReading.explain, startsWith('Diese Frage hattest du beim Lesen falsch.'));
  });

  testWidgets('Wochentest durchspielen und speichern', (tester) async {
    final p = await _progress();
    AnimatedFigure.animate = false;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final week = DateTime(2026, 11, 9);
    await tester.pumpWidget(YomichaApp(repo: Repository(), progress: p, home: WeeklyScreen(weekStart: week, docs: _docs())));
    await tester.pumpAndSettle();
    for (var i = 0; i < 20; i++) {
      if (find.text('Zur Startseite').evaluate().isNotEmpty) break;
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      final next = find.textContaining(RegExp('Nächste Frage|Auswertung'));
      await tester.scrollUntilVisible(next, 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(next);
      await tester.pump();
    }
    expect(find.text('Zur Startseite'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d+ von \d+ richtig')), findsOneWidget);
    expect(p.weeklyFor(week), isNotNull);
    expect(tester.takeException(), isNull);
  });
}
