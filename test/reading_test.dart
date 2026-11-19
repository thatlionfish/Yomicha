import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomicha/data/models.dart';
import 'package:yomicha/data/progress.dart';
import 'package:yomicha/data/repository.dart';
import 'package:yomicha/main.dart';
import 'package:yomicha/screens/reading_screen.dart';
import 'package:yomicha/widgets/figure.dart';
import 'package:yomicha/widgets/furigana.dart';

/// Liefert den Beispieltext ohne Netz.
class _Repo extends Repository {
  _Repo(this.doc);
  final TextDoc doc;
  @override
  Future<TextDoc> text(String folder) async => doc;
  @override
  Future<Map<String, KanjiInfo>> kanjiFor(Iterable<String> chars) async => {};
}

Future<void> _tapIn(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first, warnIfMissed: false);
  await tester.pump();
}

void main() {
  final file = File('web/data/texte/2026/11/2026-11-12-hojicha-2/text.json');
  final doc = TextDoc.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>, folder: 'texte/2026/11/2026-11-12-hojicha-2');

  testWidgets('Prüfungsdurchgang, Auswertung, Lernrunde', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = Progress();
    await p.load();
    p.setKuma(KumaMode.aus);
    AnimatedFigure.animate = false;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(YomichaApp(repo: _Repo(doc), progress: p, home: ReadingScreen(folder: doc.folder)));
    await tester.pump();

    // Prüfungsstil: keine Übersetzung, keine Grammatik-Hilfe, keine Vorlese-Leiste.
    expect(find.text('Prüfungsdurchgang'), findsOneWidget);
    expect(find.text(doc.titleDe), findsNothing);
    expect(find.text('Grammatik in diesem Text'), findsNothing);
    expect(find.byTooltip('Vorlesen'), findsNothing);
    expect(find.byTooltip('Furigana'), findsNothing);

    final qs = doc.questions;
    expect(qs, hasLength(4));
    // Frage 2 absichtlich falsch, die anderen richtig.
    for (final (i, q) in qs.indexed) {
      final pick = i == 1 ? (q.answer + 1) % q.options.length : q.answer;
      await _tapIn(tester, find.byWidgetPredicate((w) => w is RubyText && w.markup == q.options[pick]));
    }
    await _tapIn(tester, find.text('Abgeben'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passt'));
    await tester.pumpAndSettle();

    expect(find.text('Auswertung'), findsOneWidget);
    expect(find.text('3 von 4 richtig'), findsOneWidget);
    final r = p.reads.single;
    expect((r.correct, r.total, r.lookups, r.rating), (3, 4, 0, 0));
    expect(r.wrong, [1]);

    await _tapIn(tester, find.text('Text jetzt lernen'));
    expect(find.text('Lernrunde'), findsOneWidget);
    expect(find.textContaining('Markiert sind die Stellen'), findsOneWidget);
    expect(find.text(doc.titleDe), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Später noch einmal geöffnet: gleich die Lernrunde, kein zweiter Prüfungsdurchgang.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(YomichaApp(repo: _Repo(doc), progress: p, home: ReadingScreen(folder: doc.folder)));
    await tester.pump();
    expect(find.text('Lernrunde'), findsOneWidget);
    expect(p.reads, hasLength(1));
  });
}
