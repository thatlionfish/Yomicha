import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomicha/data/progress.dart';
import 'package:yomicha/data/schreib_plan.dart';
import 'package:yomicha/learn/schreiben.dart';
import 'package:yomicha/screens/schreiben_screen.dart' show KanjiStand, kanjiStaende;

final plan = SchreibPlan.fromJson(
  jsonDecode(File('web/data/schreiben/plan.json').readAsStringSync()) as Map<String, dynamic>,
);
final kana = (jsonDecode(File('web/data/schreiben/kana.json').readAsStringSync()) as Map<String, dynamic>).keys.toSet();

Future<Progress> _progress() async {
  SharedPreferences.setMockInitialValues({});
  final p = Progress();
  await p.load();
  return p;
}

// Ein Freitag und der Sonntag danach.
final friday = DateTime(2026, 11, 20, 9);
final sunday = DateTime(2026, 11, 22, 9);

void main() {
  test('Plan: N5 bis N1, mein Vorwissen, Wörter mit Okurigana', () {
    // Alle 2136 Jōyō-Kanji.
    expect(plan.reihenfolge.length, 2136);
    // Erst alles bis N2 (mit N1-Bestandteilen wie 又 vor 支), dann die N1.
    expect(plan.bisN2.where((k) => (plan.stufe[k] ?? 1) >= 2).length, greaterThan(1020));
    // Die neue JLPT-Liste führt 結, 保, 基 unter N1 – die alte zählt sie zur N2.
    for (final k in ['結', '保', '基', '第', '暖']) {
      expect(plan.stufe[k], 2, reason: k);
      expect(plan.bisN2, contains(k));
    }
    // Jōyō-Kanji ohne JLPT-Stufe (z. B. seit 2010) kommen in die N1.
    expect(plan.stufe['誰'], 1);
    expect(plan.stufe['頃'], 1);
    expect({for (final w in plan.woerter) w.t}, containsAll(['結婚', '保険']));
    expect(plan.bisN2.indexOf('又'), lessThan(plan.bisN2.indexOf('支')));
    expect(plan.nachN2.every((k) => plan.stufe[k] == 1), isTrue);
    expect(plan.stufe['舌'], 5, reason: 'Vorwissen bleibt in der Stufe meiner bisherigen App');
    expect(plan.vorwissen.length, 380);
    expect(plan.vorwissen, containsAll(['配', '交', '首', '一']));
    expect(plan.vorwissen.contains('若'), isFalse);
    expect(plan.stufe['若'], 3);
    // Bestandteile kommen vor dem Kanji, in dem sie stecken.
    for (final e in plan.teile.entries) {
      for (final t in e.value) {
        if (!plan.vorwissen.contains(e.key)) {
          expect(plan.index[t]!, lessThan(plan.index[e.key]!), reason: '${e.key} braucht $t');
        }
      }
    }
    final keys = {for (final w in plan.woerter) w.key};
    expect(keys, containsAll(['確かめる|たしかめる', '若い|わかい', '落とす|おとす']));
    expect(keys.contains('落す|おとす'), isFalse);
    // Jedes Zeichen lässt sich schreiben.
    for (final w in plan.woerter) {
      for (final c in w.t.split('')) {
        expect(plan.lernKanji(c) || kana.contains(c), isTrue, reason: '${w.t}: $c');
      }
    }
  });

  test('Vorwissen übernehmen; danach kommt 若 nicht vor seinen Bestandteilen', () async {
    final p = await _progress();
    final st = p.schreiben;
    st.uebernimm(plan.vorwissen);
    expect(st.kann('配'), isTrue);
    expect(st.kanjiAm(friday), 0);
    final next = naechsteKanji(plan, st, const [], 4);
    expect(next.length, 4);
    expect(next.every((k) => !plan.vorwissen.contains(k)), isTrue);
    expect(next.first, plan.reihenfolge.firstWhere((k) => !plan.vorwissen.contains(k)));
  });

  test('Kanji aus meinen Texten werden vorgezogen, mit ihren Bestandteilen', () async {
    final p = await _progress();
    final st = p.schreiben..uebernimm(plan.vorwissen);
    final late = plan.reihenfolge.lastWhere((k) => (plan.teile[k] ?? const []).any((t) => !st.kann(t)));
    final word = MyWord(t: late, reading: 'x', gloss: 'Test', textId: 'text-1', added: DateTime(2026, 11, 20));
    final next = naechsteKanji(plan, st, [word], 4);
    expect(next, contains(late));
    for (final t in plan.teile[late]!.where((t) => !st.kann(t))) {
      expect(next.indexOf(t), lessThan(next.indexOf(late)));
    }
  });

  test('Tagesziel, Sonntag und neue Wörter in Lektionsreihenfolge', () async {
    final p = await _progress();
    final st = p.schreiben..uebernimm(plan.vorwissen);
    expect(neueKanjiHeute(st, friday), 4);
    expect(neueKanjiHeute(st, sunday), 0);
    final alle = alleWoerter(plan, const [], kana);
    final next = naechsteKanji(plan, st, const [], 2);
    for (final k in next) {
      st.lerne(k, friday);
    }
    expect(neueKanjiHeute(st, friday), 2);
    st.mehrKanji(friday, 4);
    expect(neueKanjiHeute(st, friday), 6);
    final words = neueWoerter(st, alle, friday);
    expect(words.length, st.woerterProTag);
    // Zuerst die Wörter der neuen Kanji, dann alte.
    expect(words.first.kanji.any(next.contains), isTrue);
    expect(words.every((w) => w.kanji.every(st.kann)), isTrue);
    expect(neueWoerter(st, alle, sunday), isEmpty);
  });

  test('Meine Wörter aus Texten werden zu Schreibwörtern', () {
    final mine = [
      const MyWord(t: '若い', reading: 'わかい', gloss: 'jung', sentence: '若い人が多い。', textId: 't1'),
      const MyWord(t: '下北沢', reading: 'しもきたざわ', gloss: 'Shimokitazawa', textId: 't1'),
    ];
    final alle = alleWoerter(plan, mine, kana);
    final waka = alle.firstWhere((w) => w.key == '若い|わかい');
    expect(waka.satz, '若い人が多い。');
    expect(waka.bedeutung, 'jung');
    expect(waka.n, greaterThan(0));
  });

  test('Fällige Karten und Bewertung', () async {
    final p = await _progress();
    final st = p.schreiben;
    final w = plan.woerter.first;
    st.speichere('w:${w.key}', fsrs.Card(cardId: 1, due: friday.toUtc()), friday);
    st.speichere('k:若', fsrs.Card(cardId: 2, due: friday.add(const Duration(days: 30)).toUtc()), friday);
    final due = faelligeKarten(st, {w.key: w}, friday);
    expect(due.map((k) => k.key), ['w:${w.key}']);
    expect(faelligeKarten(st, {w.key: w}, sunday), isEmpty);
    expect(st.neueWoerterAm(friday), 1);

    expect(schreibBewertung(fehler: 0, hinweis: 0), fsrs.Rating.good);
    expect(schreibBewertung(fehler: 2, hinweis: 0), fsrs.Rating.hard);
    expect(schreibBewertung(fehler: 0, hinweis: 1), fsrs.Rating.hard);
    expect(schreibBewertung(fehler: 0, hinweis: 3), fsrs.Rating.again);
    expect(schreibBewertung(fehler: 0, hinweis: 0, lesungFalsch: true), fsrs.Rating.again);
  });

  test('Lesungen zur Auswahl mit Prüfungsfallen', () {
    final f = lesungsFallen('しょうせつ');
    expect(f, contains('しょせつ'));
    expect(f, isNot(contains('しょうせつ')));
    expect(lesungsFallen('がっこう'), containsAll(['がこう', 'かっこう']));
    final a = lesungsAuswahl('きゅうけい', ['しょうせつ', 'きゅうか', 'せつめい'], 3);
    expect(a.length, 4);
    expect(a, contains('きゅうけい'));
    expect(a.toSet().length, 4);
    expect(lesungsAuswahl('きゅうけい', const [], 3), a.isEmpty ? isEmpty : isNotEmpty);
  });

  test('Hinweistexte verraten das Kanji nicht', () {
    expect(verdecke('viel, ziemlich (wie 大分 (だいぶん))', '大分'), 'viel, ziemlich (wie 〇〇 (だいぶん))');
    expect(verdecke('erledigt (z. B. 支払い済み)', '済み'), 'erledigt (z. B. 支払い〇み)');
    expect(verdecke('人々が来た', '人々'), '〇々が来た');
  });

  test('Stand je Kanji für die Farben der Übersicht', () async {
    final p = await _progress();
    final st = p.schreiben..uebernimm(['一']);
    st.lerne('支', friday);
    st.gelesenAusTexten({'text-1': ['共', '一']});
    final stand = kanjiStaende(plan, p);
    expect(stand['一'], KanjiStand.gelernt);
    expect(stand['支'], KanjiStand.amLernen);
    expect(stand['共'], KanjiStand.gelesen);
    expect(stand['済'], KanjiStand.offen);
    // Sicher geschrieben (Stabilität ab 21 Tagen): gelernt.
    final w = plan.woerter.firstWhere((w) => w.t == '支店');
    st.speichere('w:${w.key}', fsrs.Card(cardId: 3, state: fsrs.State.review, stability: 30, difficulty: 5), friday);
    expect(kanjiStaende(plan, p)['支'], KanjiStand.gelernt);
    expect(st.gelesenAus, contains('text-1'));
  });

  test('Fertig mit allen Kanji', () {
    // 605 Kanji, 4 pro Tag ab Montag, 23.11.2026, sonntags frei.
    expect(fertigAm(605, 4, DateTime(2026, 11, 23)), DateTime(2027, 5, 18));
  });
}
