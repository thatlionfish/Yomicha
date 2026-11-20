import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomicha/data/progress.dart';
import 'package:yomicha/data/schreib_plan.dart';
import 'package:yomicha/learn/schreiben.dart';

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
  test('Plan: N5 bis N2, mein Vorwissen, Wörter mit Okurigana', () {
    expect(plan.reihenfolge.length, greaterThan(950));
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

  test('Fertig mit allen Kanji', () {
    // 605 Kanji, 4 pro Tag ab Montag, 23.11.2026, sonntags frei.
    expect(fertigAm(605, 4, DateTime(2026, 11, 23)), DateTime(2027, 5, 18));
  });
}
