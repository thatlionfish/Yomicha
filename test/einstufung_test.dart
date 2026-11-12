import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomicha/data/progress.dart';
import 'package:yomicha/data/repository.dart';
import 'package:yomicha/learn/einstufung.dart';
import 'package:yomicha/learn/einstufung_daten.dart';
import 'package:yomicha/main.dart';
import 'package:yomicha/screens/einstufung_screen.dart';
import 'package:yomicha/widgets/figure.dart';
import 'package:yomicha/widgets/furigana.dart';

Future<Progress> _fresh() async {
  SharedPreferences.setMockInitialValues({});
  final p = Progress();
  await p.load();
  return p;
}

final _today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
var _n = 0;

ReadRecord _read({int stufe = 2, int correct = 4, int total = 4, int lookups = 1, int rating = 0, DateTime? day}) =>
    ReadRecord(
      id: 'text-${_n++}-$stufe',
      day: day ?? _today,
      seconds: 180,
      chars: 200,
      correct: correct,
      total: total,
      lookups: lookups,
      rating: rating,
      usedAudio: false,
      textStufe: stufe,
      words: 40,
    );

/// Im Scrollbereich hinscrollen, ganz sichtbar machen, antippen.
Future<void> _tapIn(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

void main() {
  group('Laufende Einschätzung', () {
    test('Aufstieg nach 5 guten Texten, nicht vorher', () async {
      final p = await _fresh();
      for (var i = 0; i < 4; i++) {
        p.addRead(_read());
      }
      expect(stufenVorschlag(p), isNull);
      p.addRead(_read(correct: 3));
      final v = stufenVorschlag(p)!;
      expect(v.richtung, Richtung.hoch);
      expect((v.von, v.nach), (2, 3));
      expect(v.grund, contains('95 %'));
    });

    test('Kein Aufstieg bei vielen nachgeschlagenen Wörtern oder „zu schwer“', () async {
      final p = await _fresh();
      for (var i = 0; i < 5; i++) {
        p.addRead(_read(lookups: 4)); // 10 %
      }
      expect(stufenVorschlag(p), isNull);
      final q = await _fresh();
      for (var i = 0; i < 5; i++) {
        q.addRead(_read(rating: i < 2 ? 1 : 0));
      }
      expect(stufenVorschlag(q), isNull);
    });

    test('Zurück nach 3 Texten unter 50 % oder dreimal „zu schwer“', () async {
      final p = await _fresh();
      p.setStufe(3);
      for (var i = 0; i < 3; i++) {
        p.addRead(_read(stufe: 3, correct: 1));
      }
      expect(stufenVorschlag(p)!.richtung, Richtung.zurueck);
      expect(stufenVorschlag(p)!.nach, 2);

      final q = await _fresh();
      q.setStufe(3);
      for (var i = 0; i < 3; i++) {
        q.addRead(_read(stufe: 3, total: 0, correct: 0, rating: 1));
      }
      expect(stufenVorschlag(q)!.grund, contains('zu schwer'));
    });

    test('„Noch nicht“ pausiert für 3 Texte', () async {
      final p = await _fresh();
      for (var i = 0; i < 5; i++) {
        p.addRead(_read());
      }
      p.pauseVorschlag(2, textsOnStufe(p).length);
      for (var i = 0; i < 2; i++) {
        p.addRead(_read());
        expect(stufenVorschlag(p), isNull);
      }
      p.addRead(_read());
      expect(stufenVorschlag(p), isNotNull);
    });

    test('Texte von vor dem letzten Stufenwechsel zählen nicht', () async {
      final p = await _fresh();
      for (var i = 0; i < 5; i++) {
        p.addRead(_read(day: DateTime(2026, 11, 1)));
      }
      p.setStufe(3);
      p.setStufe(2);
      expect(stufenVorschlag(p), isNull);
    });

    test('Ältere Einträge: Stufe aus der Kennung, Wortzahl geschätzt', () {
      final r = ReadRecord.fromJson({
        'id': '2026-11-12-hojicha-2', 'day': '2026-11-12', 'seconds': 100, 'chars': 210,
        'correct': 3, 'total': 4, 'lookups': 7, 'rating': 0,
      });
      expect(r.stufe, 2);
      expect(r.lookupShare, closeTo(0.1, 0.001));
    });
  });

  group('Einstufung zu Beginn', () {
    test('Falsch geprüfte Wörter senken den Anteil', () {
      final a = [
        for (var i = 0; i < 6; i++) const WortAntwort(jlpt: 4, kenne: true),
        const WortAntwort(jlpt: 4, kenne: true, geprueft: true),
        const WortAntwort(jlpt: 4, kenne: true, geprueft: false),
        const WortAntwort(jlpt: 4, kenne: false),
        const WortAntwort(jlpt: 4, kenne: false),
      ];
      // 6 × 0,5 (Vertrauen) + 1 richtig geprüft = 4 von 10.
      expect(knownShare(a, 4), closeTo(0.4, 0.001));
    });

    test('Wortschatz, Lesen und Startstufe wie im Beispiel der Spezifikation', () {
      final words = [
        for (final j in [5, 4, 3]) for (var i = 0; i < 10; i++) WortAntwort(jlpt: j, kenne: i < 8),
        for (var i = 0; i < 10; i++) WortAntwort(jlpt: 2, kenne: i < 3),
      ];
      expect(wortschatzStufe(words), 3);
      final texts = [
        const TextAntwort(jlpt: 4, richtig: 2, fragen: 2, zeichenProMinute: 140),
        const TextAntwort(jlpt: 3, richtig: 1, fragen: 2, zeichenProMinute: 120),
      ];
      expect(leseStufe(texts), 2);
      expect(startStufe(3, 2), 3); // Wortschatz N3, Lesen N4 → Genmaicha
      expect(leseStufe(const [TextAntwort(jlpt: 4, richtig: 1, fragen: 2, zeichenProMinute: 200)]), 1);
      expect(leseStufe(const [
        TextAntwort(jlpt: 4, richtig: 2, fragen: 2, zeichenProMinute: 200),
        TextAntwort(jlpt: 3, richtig: 2, fragen: 2, zeichenProMinute: 100),
      ]), 3);
    });

    test('Die Inhalte: 10 Wörter je Stufe, eindeutige Bedeutungen, 2 Fragen je Text', () {
      for (final j in [5, 4, 3, 2]) {
        final w = einstufungWoerter.where((x) => x.jlpt == j).toList();
        expect(w, hasLength(10), reason: 'N$j');
        expect(w.map((x) => x.de).toSet(), hasLength(10), reason: 'N$j');
      }
      expect(einstufungTexte.map((t) => t.jlpt), [4, 3, 2]);
      for (final t in einstufungTexte) {
        expect(t.fragen, hasLength(2));
        for (final f in t.fragen) {
          expect(f.antworten.toSet(), hasLength(4));
        }
        expect(t.chars, greaterThan(140));
      }
      expect(const MiniText(jlpt: 4, text: '{漢字|かんじ}です', fragen: []).chars, 4);
    });

    testWidgets('Einmal durch: alles gewusst → Vorschlag, Stufe übernommen', (tester) async {
      final p = await _fresh();
      p.setKuma(KumaMode.aus);
      AnimatedFigure.animate = false;
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      const words = [
        PruefWort('天気', 'てんき', 'Wetter', 5),
        PruefWort('駅', 'えき', 'Bahnhof', 5),
        PruefWort('飲む', 'のむ', 'trinken', 5),
        PruefWort('近い', 'ちかい', 'nah', 5),
        PruefWort('準備', 'じゅんび', 'Vorbereitung', 4),
        PruefWort('経験', 'けいけん', 'Erfahrung', 4),
        PruefWort('説明', 'せつめい', 'Erklärung', 4),
        PruefWort('安心', 'あんしん', 'beruhigt sein', 4),
      ];
      await tester.pumpWidget(YomichaApp(
        repo: Repository(),
        progress: p,
        home: EinstufungScreen(woerter: words, texte: einstufungTexte.take(2).toList()),
      ));
      await tester.tap(find.text('Los geht’s'));
      await tester.pump();

      for (var i = 0; i < words.length; i++) {
        await tester.tap(find.text('Kenne ich'));
        await tester.pump();
        if (find.text('Was bedeutet es?').evaluate().isNotEmpty) {
          final shown = (find.byType(Text).evaluate().map((e) => (e.widget as Text).data)).whereType<String>();
          final word = words.firstWhere((w) => shown.contains(w.t));
          await tester.tap(find.text(word.de));
          await tester.pump();
          await _tapIn(tester, find.text('Weiter'));
        }
      }

      for (final text in einstufungTexte.take(2)) {
        expect(find.textContaining('· N${text.jlpt}'), findsOneWidget);
        await _tapIn(tester, find.text('Fertig gelesen'));
        for (final f in text.fragen) {
          final right = find.byWidgetPredicate((w) => w is RubyText && w.markup == f.antworten.first);
          await _tapIn(tester, right);
        }
        await _tapIn(tester, find.text('Weiter'));
      }

      // Wortschatz N4 (= 2) und Lesen N3 flüssig (= 4) → Stufe 3.
      expect(find.text('Dein Ergebnis'), findsOneWidget);
      expect(find.textContaining('Vorschlag: Stufe 3'), findsOneWidget);
      await _tapIn(tester, find.text('Mit Stufe 3 starten'));
      expect(p.stufe, 3);
      expect(p.einstufung!.wortschatz, 4);
      expect(p.einstufung!.lesen, 4);
      expect(tester.takeException(), isNull);
    });
  });
}
