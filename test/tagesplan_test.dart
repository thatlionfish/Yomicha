import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomicha/data/models.dart';
import 'package:yomicha/data/progress.dart';
import 'package:yomicha/data/repository.dart';
import 'package:yomicha/data/schreib_plan.dart';
import 'package:yomicha/main.dart';
import 'package:yomicha/screens/tagesplan_screen.dart';
import 'package:yomicha/widgets/figure.dart';

dynamic _file(String path) => jsonDecode(File('web/data/$path').readAsStringSync());

/// Keine Texte, Lernplan aus web/data.
class _Repo extends Repository {
  @override
  Future<List<TextEntry>> index() async => const [];
  @override
  Future<SchreibPlan> schreibPlan() async => SchreibPlan.fromJson(_file('schreiben/plan.json') as Map<String, dynamic>);
  @override
  Future<Map<String, List<String>>> kana() async => {
    for (final e in (_file('schreiben/kana.json') as Map<String, dynamic>).entries) e.key: (e.value as List).cast<String>(),
  };
  @override
  Future<Map<String, KanjiInfo>> kanjiFor(Iterable<String> chars) async => const {};
  @override
  Future<Map<String, String>> partNames() async => const {};
}

void main() {
  testWidgets('Heute lernen: Aufgaben des Tages, eine nach der anderen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = Progress();
    await p.load();
    p.setKuma(KumaMode.aus);
    AnimatedFigure.animate = false;
    tester.view.physicalSize = const Size(820 * 2, 1180 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // Ein Freitag: Der Wochentest der Vorwoche ist zum Nachholen dran.
    final friday = DateTime(2026, 11, 20, 9);

    await tester.pumpWidget(YomichaApp(repo: _Repo(), progress: p, home: TagesplanScreen(today: friday)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Noch 2 Aufgaben'), findsOneWidget);
    expect(find.text('Kanji schreiben'), findsOneWidget);
    expect(find.textContaining('Einmal einrichten'), findsOneWidget);
    expect(find.text('Wochentest · KW 46'), findsOneWidget);
    // Ohne gespeicherte Wörter gibt es nichts zu wiederholen.
    expect(find.text('Meine Wörter wiederholen'), findsNothing);

    // „Los geht’s“ öffnet die erste offene Aufgabe.
    await tester.tap(find.text('Los geht’s'));
    await tester.pumpAndSettle();
    expect(find.text('Dein bisheriger Stand'), findsOneWidget);
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Noch nicht fertig geschrieben: zurück auf der Liste, mit dem, was heute dran ist.
    expect(find.textContaining('4 neue Kanji'), findsOneWidget);
    expect(find.textContaining('Weiter mit „Kanji schreiben“'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sonntag: nichts dran', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = Progress();
    await p.load();
    await tester.pumpWidget(
      YomichaApp(repo: _Repo(), progress: p, home: TagesplanScreen(today: DateTime(2026, 11, 22, 9))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sonntag ist Ruhetag'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}
