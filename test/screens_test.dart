import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomicha/data/models.dart';
import 'package:yomicha/data/progress.dart';
import 'package:yomicha/data/repository.dart';
import 'package:yomicha/main.dart';
import 'package:yomicha/screens/archive_screen.dart';
import 'package:yomicha/screens/progress_screen.dart';
import 'package:yomicha/screens/words_screen.dart';
import 'package:yomicha/widgets/splash.dart';
import 'package:yomicha/widgets/word_sheet.dart';
import 'package:yomicha/widgets/figure.dart';
import 'package:yomicha/widgets/speak_sheet.dart';

Future<Progress> _progress() async {
  SharedPreferences.setMockInitialValues({});
  final p = Progress();
  await p.load();
  p.setKuma(KumaMode.aus);
  p.addWords(const [
    MyWord(t: '香り', reading: 'かおり', gloss: 'Duft', sentence: '香ばしい香りがします。'),
    MyWord(t: '眠れます', reading: 'ねむれます', gloss: 'schlafen können', sentence: 'よく眠れます。'),
  ]);
  return p;
}

Future<void> _pump(WidgetTester tester, Progress p, Widget home) async {
  AnimatedFigure.animate = false;
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(YomichaApp(repo: Repository(), progress: p, home: home));
  await tester.pump();
}

void main() {
  testWidgets('Meine Wörter → Wiederholen bis zum Ende', (tester) async {
    final p = await _progress();
    // Ein fester Lerntag (kein Sonntag): Freitag.
    await _pump(tester, p, const WordsScreen());
    if (DateTime.now().weekday == DateTime.sunday) {
      expect(find.textContaining('Sonntag'), findsOneWidget);
      return;
    }
    expect(find.text('Heute zu wiederholen: 2 Wörter'), findsOneWidget);
    expect(find.textContaining('香り', findRichText: true), findsWidgets);

    await tester.tap(find.text('Wiederholen'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 10 && find.text('Aufdecken').evaluate().isNotEmpty; i++) {
      await tester.tap(find.text('Aufdecken'));
      await tester.pump();
      expect(find.text('Gut'), findsOneWidget);
      await tester.tap(find.text('Gut'));
      await tester.pump();
    }
    expect(find.textContaining('wiederholt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fortschritt mit Zielkurve', (tester) async {
    final p = await _progress();
    await _pump(tester, p, const ProgressScreen());
    expect(find.text('Im Plan'), findsOneWidget);
    expect(find.text('31.8.2027'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Lernstatistik'), 300);
    expect(find.text('Lernstatistik'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nachsprechen ohne Schlüssel erklärt, was fehlt', (tester) async {
    final p = await _progress();
    final doc = TextDoc(
      id: 't-2',
      folder: 'texte/t-2',
      date: DateTime(2026, 11, 12),
      topic: 'tee',
      type: 'essay',
      stufe: 2,
      title: const [Token(t: 'お茶', r: 'おちゃ')],
      titleDe: 'Tee',
      sentences: const [
        Sentence(tokens: [Token(t: '冬', r: 'ふゆ', gloss: 'Winter'), Token(t: 'です'), Token(t: '。')], audio: 's01.mp3'),
      ],
      grammar: const {},
      questions: const [],
    );
    await _pump(
      tester,
      p,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(onPressed: () => showSpeakSheet(context, doc: doc), child: const Text('los')),
        ),
      ),
    );
    await tester.tap(find.text('los'));
    await tester.pumpAndSettle();
    expect(find.text('Nachsprechen'), findsOneWidget);
    expect(find.textContaining('Azure-Schlüssel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Archiv mit Filter', (tester) async {
    final p = await _progress();
    final texts = [
      TextEntry(id: 'a-2', folder: 'texte/a-2', date: DateTime(2026, 11, 12), topic: 'tee', stufe: 2,
          title: 'ほうじ茶の季節', titleDe: 'Die Zeit für Hōjicha', minutes: 2),
      TextEntry(id: 'b-2', folder: 'texte/b-2', date: DateTime(2026, 10, 30), topic: 'mode', stufe: 2,
          title: '古着が好きな若者', titleDe: 'Secondhand', minutes: 2),
    ];
    await _pump(tester, p, ArchiveScreen(texts: texts));
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('Oktober 2026'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Mode'));
    await tester.pump();
    expect(find.text('ほうじ茶の季節'), findsNothing);
    expect(find.text('古着が好きな若者'), findsOneWidget);
  });

  testWidgets('Angetippte Wörter kommen von selbst in „Meine Wörter“', (tester) async {
    final p = await _progress();
    final f = File('web/data/texte/2026/11/2026-11-12-hojicha-2/text.json');
    final doc = TextDoc.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>, folder: f.parent.path);
    final sentence = doc.sentences.firstWhere((s) => s.tokens.any((t) => t.hasKanji && t.gloss != null));
    final token = sentence.tokens.firstWhere((t) => t.hasKanji && t.gloss != null);
    final key = myWordOf(token, sentence, doc).key;
    expect(p.hasWord(key), isFalse);

    await _pump(tester, p, Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showWordSheet(context, token: token, sentence: sentence, doc: doc, repo: Repository(), progress: p),
          child: const Text('Wort'),
        ),
      ),
    ));
    await tester.tap(find.text('Wort'));
    await tester.pumpAndSettle();
    expect(p.hasWord(key), isTrue);
    expect(p.myWords[key]!.sentence, sentence.plain);
    expect(find.text('Gespeichert in „Meine Wörter“'), findsOneWidget);

    // Wieder entfernen geht in der Wortleiste.
    await tester.tap(find.text('Entfernen'));
    await tester.pump();
    expect(p.hasWord(key), isFalse);
    expect(find.text('Meine Wörter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Beim Öffnen erst groß das Logo, dann die Startseite', (tester) async {
    final p = await _progress();
    AnimatedFigure.animate = false;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(YomichaApp(repo: Repository(), progress: p));
    await tester.pump(const Duration(milliseconds: 700));
    // Startbild und Titelleiste zeigen beide 読み茶.
    expect(find.text('読み茶'), findsNWidgets(2));
    expect(find.text('Yomicha'), findsNWidgets(2));

    await tester.pump(SplashGate.hold);
    await tester.pump(); // Ausblenden beginnt
    await tester.pump(SplashGate.fade);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // Startbild entfernt
    expect(find.text('読み茶'), findsOneWidget);
    expect(find.textContaining('レオニ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
