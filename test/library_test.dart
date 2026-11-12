import 'package:flutter_test/flutter_test.dart';
import 'package:yomicha/data/models.dart';
import 'package:yomicha/learn/library.dart';

TextEntry _e(String id, DateTime date, {bool vorrat = false, int stufe = 2}) => TextEntry(
  id: '$id-$stufe',
  folder: 'texte/$id-$stufe',
  date: date,
  topic: 'tee',
  stufe: stufe,
  title: id,
  titleDe: id,
  minutes: 2,
  vorrat: vorrat,
);

void main() {
  final today = DateTime(2026, 11, 20); // Freitag
  final regular = [_e('neu', today), _e('gestern', DateTime(2026, 11, 19)), _e('alt', DateTime(2026, 11, 10))];
  final stock = [_e('vorrat-a', DateTime(2026, 11, 13), vorrat: true), _e('vorrat-b', DateTime(2026, 11, 14), vorrat: true)];

  test('Heute: die neuen Texte', () {
    final r = textsForToday(regular: regular, stock: stock, read: {}, today: today, rest: false);
    expect(r.label, 'Deine Texte für heute');
    expect(r.texts.map((e) => e.title), ['neu']);
  });

  test('Teeküche ausgefallen: erst die letzten Tage, dann der Vorrat, dann Älteres', () {
    final noToday = regular.skip(1).toList();
    var r = textsForToday(regular: noToday, stock: stock, read: {}, today: today, rest: false);
    expect(r.label, 'Noch nicht gelesen');
    expect(r.texts.map((e) => e.title).toList(), ['gestern']);

    r = textsForToday(regular: noToday, stock: stock, read: {'gestern-2'}, today: today, rest: false);
    expect(r.label, 'Aus dem Vorrat');
    expect(r.texts.map((e) => e.title).toList(), ['vorrat-a', 'vorrat-b']);

    r = textsForToday(regular: noToday, stock: stock, read: {'gestern-2', 'vorrat-a-2', 'vorrat-b-2'}, today: today, rest: false);
    expect(r.label, 'Noch nicht gelesen');
    expect(r.texts.map((e) => e.title).toList(), ['alt']);
  });

  test('Sonntag: nichts', () {
    final r = textsForToday(regular: regular, stock: stock, read: {}, today: DateTime(2026, 11, 22), rest: true);
    expect(r.texts, isEmpty);
  });

  test('Vorrat im Verzeichnis', () {
    final e = TextEntry.fromJson({
      'id': 'a-2', 'folder': 'texte/a-2', 'date': '2026-11-13', 'topic': 'tee', 'stufe': 2,
      'title': 'a', 'titleDe': 'a', 'minutes': 2, 'vorrat': true,
    });
    expect(e.vorrat, isTrue);
    expect(TextEntry.fromJson({
      'id': 'b-2', 'folder': 'texte/b-2', 'date': '2026-11-13', 'topic': 'tee', 'stufe': 2,
      'title': 'b', 'titleDe': 'b', 'minutes': 2,
    }).vorrat, isFalse);
  });
}
