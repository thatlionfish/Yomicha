import 'package:flutter_test/flutter_test.dart';
import 'package:yomicha/data/models.dart';
import 'package:yomicha/data/progress.dart';
import 'package:yomicha/widgets/furigana.dart';

void main() {
  const nomu = Token(
    t: '飲みます',
    r: 'のみます',
    ruby: [RubySeg('飲', 'の'), RubySeg('みます', '')],
    jlpt: 5,
    gloss: 'trinken',
  );
  const ryokucha = Token(t: '緑茶', r: 'りょくちゃ', jlpt: 3, gloss: 'Grüntee');
  const kana = Token(t: 'よく', jlpt: 5, gloss: 'oft');

  const levels = {'飲': 5, '緑': 3, '茶': 4};

  test('Furigana nur über den Kanji', () {
    expect(nomu.segments.map((s) => s.reading), ['の', '']);
    expect(ryokucha.segments.single.reading, 'りょくちゃ');
    expect(kana.segments.single.hasRuby, isFalse);
  });

  test('„Nur auf Antippen“: Kanji oberhalb der Stufe trotzdem mit Furigana', () {
    const rules = FuriganaRules(mode: FuriganaMode.aus, userJlpt: 4, kanjiLevels: levels);
    expect(rules.show(nomu), isFalse); // 飲 ist N5
    expect(rules.show(ryokucha), isTrue); // 緑 ist N3
    expect(rules.show(nomu, revealed: true), isTrue);
    expect(rules.show(kana), isFalse);
  });

  test('Unbekannte Kanji bekommen immer Furigana', () {
    const rules = FuriganaRules(mode: FuriganaMode.aus, userJlpt: 4);
    expect(rules.show(nomu), isTrue);
  });

  test('„Über meiner Stufe“ richtet sich nach der Stufe des Wortes', () {
    const word = Token(t: '飲料', r: 'いんりょう', jlpt: 2, gloss: 'Getränk');
    const rules = FuriganaRules(mode: FuriganaMode.ueberStufe, userJlpt: 4, kanjiLevels: {'飲': 5, '料': 4});
    expect(rules.show(word), isTrue);
    expect(const FuriganaRules(mode: FuriganaMode.aus, userJlpt: 4, kanjiLevels: {'飲': 5, '料': 4}).show(word), isFalse);
  });

  test('Satzzeichen hängen am Wort davor, Klammern am Wort danach', () {
    final tokens = [
      const Token(t: '「'),
      const Token(t: '香り', r: 'かおり'),
      const Token(t: '」'),
      const Token(t: 'が'),
      const Token(t: '。'),
    ];
    expect(groupUnits(tokens), [
      [0, 1, 2],
      [3, 4],
    ]);
  });

  test('Ruby-Schreibweise', () {
    final t = parseRuby('{静岡|しずおか}は{有名|ゆうめい}です。');
    expect(t.first.t, '静岡');
    expect(t.first.r, 'しずおか');
    expect(t[1].t, 'は');
    expect(t.map((x) => x.t).join(), '静岡は有名です。');
  });
}
