import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yomicha/data/audio_key.dart';
import 'package:yomicha/data/models.dart';
import 'package:yomicha/data/stufen.dart';

/// Prüft alle veröffentlichten Texte – so fallen Fehler der Teeküche auf,
/// bevor sie online gehen.
void main() {
  final files = Directory('web/data/texte')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('text.json'))
      .toList();

  test('Es gibt Texte', () => expect(files, isNotEmpty));

  final index = jsonDecode(File('web/data/texte/index.json').readAsStringSync()) as Map<String, dynamic>;
  final entries = [for (final e in index['texts'] as List) TextEntry.fromJson(e as Map<String, dynamic>)];

  test('Jeder Eintrag im Verzeichnis hat einen Text', () {
    for (final e in entries) {
      expect(File('web/data/${e.folder}/text.json').existsSync(), isTrue, reason: e.folder);
    }
  });

  for (final f in files) {
    final doc = TextDoc.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>, folder: f.parent.path);

    group(doc.id, () {
      test('Lesungen: Hiragana, und die Teile ergeben das Wort', () {
        final hira = RegExp(r'^[ぁ-ゟー]+$');
        for (final t in [...doc.title, for (final s in doc.sentences) ...s.tokens]) {
          if (t.r != null) expect(hira.hasMatch(t.r!), isTrue, reason: '${t.t}: ${t.r}');
          if (t.ruby != null) {
            expect(t.ruby!.map((s) => s.base).join(), t.t, reason: t.t);
            expect(t.ruby!.map((s) => s.hasRuby ? s.reading : s.base).join(), t.r, reason: t.t);
          }
          if (t.hasKanji) expect(t.r, isNotNull, reason: 'Lesung fehlt: ${t.t}');
        }
      });

      test('Fragen: 4 Antworten, Lösung und Textstellen gültig', () {
        for (final q in doc.questions) {
          expect(q.options, hasLength(4), reason: q.q);
          expect(q.answer, inInclusiveRange(0, 3), reason: q.q);
          for (final e in q.evidence) {
            expect(e, inInclusiveRange(0, doc.sentences.length - 1), reason: q.q);
          }
        }
      });

      test('Grammatik-Verweise gibt es', () {
        for (final s in doc.sentences) {
          for (final t in s.tokens) {
            if (t.grammar != null) expect(doc.grammar.containsKey(t.grammar), isTrue, reason: t.t);
          }
        }
      });

      test('Länge passt zur Stufe (Spezifikation 9.1)', () {
        const ranges = {1: (120, 200), 2: (150, 250), 3: (200, 300), 4: (250, 400), 5: (300, 450), 6: (350, 550), 7: (400, 700)};
        final (min, max) = ranges[doc.stufe]!;
        expect(doc.chars, inInclusiveRange(min, max), reason: '${Stufe.of(doc.stufe).name}: ${doc.chars} Zeichen');
      });

      test('Aufnahmen sind vorhanden', () {
        for (final s in doc.sentences) {
          if (s.audio != null) expect(File('${doc.folder}/${s.audio}').existsSync(), isTrue, reason: s.audio);
        }
        for (final t in [for (final s in doc.sentences) ...s.tokens]) {
          if (wantsWordAudio(t)) {
            expect(File('web/data/${wordAudioPath(t)}').existsSync(), isTrue, reason: t.t);
          }
        }
      });
    });
  }
}
