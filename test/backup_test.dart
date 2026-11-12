import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomicha/data/progress.dart';

Future<Progress> _fresh() async {
  SharedPreferences.setMockInitialValues({});
  final p = Progress();
  await p.load();
  return p;
}

ReadRecord _read({int correct = 0, int total = 0}) => ReadRecord(
  id: 'tee-2',
  day: DateTime(2026, 11, 12),
  seconds: 180,
  chars: 300,
  correct: correct,
  total: total,
  lookups: 2,
  rating: 0,
  usedAudio: false,
);

void main() {
  test('Ein Text zählt schon nach „Fertig“, die Fragen ersetzen den Eintrag', () async {
    final p = await _fresh();
    p.addRead(_read());
    expect(p.readDays, {DateTime(2026, 11, 12)});
    expect(p.reads.single.total, 0);

    p.addRead(_read(correct: 3, total: 4));
    expect(p.reads, hasLength(1));
    expect(p.reads.single.correct, 3);

    // Nochmal gelesen ohne Fragen: Die Antworten bleiben.
    p.addRead(_read());
    expect(p.reads.single.total, 4);
  });

  test('Sicherung: alles zurück auf einem anderen Gerät, ohne Azure-Schlüssel', () async {
    final a = await _fresh();
    a.addWords(const [MyWord(t: '香り', reading: 'かおり', gloss: 'Duft', sentence: '香りがします。')]);
    a.addRead(_read(correct: 2, total: 3));
    a.setStufe(3);
    a.setRate(0.75);
    a.setStory('茶', 'Meine Geschichte');
    a.setAzure('geheim', 'switzerlandnorth');
    final json = a.backupJson(DateTime(2026, 11, 12, 20));
    expect(json, isNot(contains('geheim')));
    expect(Progress.previewBackup(json), (saved: DateTime(2026, 11, 12, 20), words: 1, reads: 1));

    // Anderes Gerät mit eigenem Schlüssel und eigenem (älterem) Stand.
    final b = await _fresh();
    b.setAzure('anderer', 'westeurope');
    b.addWords(const [MyWord(t: '古着', reading: 'ふるぎ', gloss: 'Secondhand')]);
    await b.restoreBackup(json);
    expect(b.myWords.keys, ['香り|かおり']);
    expect(b.myWords.values.single.sentence, '香りがします。');
    expect(b.reads.single.correct, 2);
    expect(b.stufe, 3);
    expect(b.rate, 0.75);
    expect(b.stories['茶'], 'Meine Geschichte');
    expect(b.azureKey, 'anderer');
    expect(b.azureRegion, 'westeurope');

    // Nach einem Neustart steht dasselbe da.
    final again = Progress();
    await again.load();
    expect(again.myWords.keys, ['香り|かおり']);
    expect(again.stufe, 3);
  });

  test('Fremde Dateien werden abgelehnt', () async {
    expect(() => Progress.previewBackup('kein json'), throwsA(isA<BackupError>()));
    expect(() => Progress.previewBackup(jsonEncode({'app': 'anders', 'data': {}})), throwsA(isA<BackupError>()));
    final p = await _fresh();
    p.addWords(const [MyWord(t: '香り', reading: 'かおり', gloss: 'Duft')]);
    await expectLater(p.restoreBackup('{}'), throwsA(isA<BackupError>()));
    expect(p.myWords, hasLength(1));
  });

  test('Merkt sich die letzte Sicherung', () async {
    final p = await _fresh();
    expect(p.lastBackup, isNull);
    p.markBackedUp(DateTime(2026, 11, 12));
    final again = Progress();
    await again.load();
    expect(again.lastBackup, DateTime(2026, 11, 12));
  });
}
