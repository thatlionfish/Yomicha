import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yomicha/speech/assessment.dart';

void main() {
  test('Antwort von Azure lesen (Werte direkt im NBest-Eintrag)', () {
    final r = PronunciationResult.fromJson({
      'RecognitionStatus': 'Success',
      'DisplayText': '冬になると。',
      'NBest': [
        {
          'Display': '冬になると。',
          'AccuracyScore': 86.0,
          'FluencyScore': 72,
          'CompletenessScore': 100.0,
          'PronScore': 82.5,
          'Words': [
            {'Word': '冬', 'AccuracyScore': 95.0, 'ErrorType': 'None'},
            {'Word': 'に', 'AccuracyScore': 70.0, 'ErrorType': 'None'},
            {'Word': 'なる', 'AccuracyScore': 40.0, 'ErrorType': 'Mispronunciation'},
            {'Word': 'と', 'AccuracyScore': 0, 'ErrorType': 'Omission'},
          ],
        },
      ],
    });
    expect(r.accuracy, 86);
    expect(r.fluency, 72);
    expect(r.words.map((w) => w.grade), [WordGrade.gut, WordGrade.unsicher, WordGrade.falsch, WordGrade.ausgelassen]);
  });

  test('Antwort von Azure lesen (unter PronunciationAssessment)', () {
    final r = PronunciationResult.fromJson({
      'RecognitionStatus': 'Success',
      'NBest': [
        {
          'Display': 'お茶',
          'PronunciationAssessment': {'AccuracyScore': 90, 'FluencyScore': 80, 'CompletenessScore': 100, 'PronScore': 88},
          'Words': [
            {'Word': 'お茶', 'PronunciationAssessment': {'AccuracyScore': 90, 'ErrorType': 'None'}},
          ],
        },
      ],
    });
    expect(r.overall, 88);
    expect(r.words.single.grade, WordGrade.gut);
  });

  test('Nichts verstanden → verständliche Meldung', () {
    expect(
      () => PronunciationResult.fromJson({'RecognitionStatus': 'NoMatch'}),
      throwsA(isA<PronunciationError>().having((e) => e.message, 'message', contains('nichts verstanden'))),
    );
  });

  test('Kopfzeile enthält den Referenztext', () {
    final j = jsonDecode(utf8.decode(base64.decode(assessmentHeader('寒くなってきましたね。')))) as Map;
    expect(j['ReferenceText'], '寒くなってきましたね。');
    expect(j['Granularity'], 'Word');
  });

  test('Tipps zu langen Vokalen, っ und ん', () {
    final tips = pronunciationTips('きって さいきん ほうじちゃ がっこう', fluency: 50);
    expect(tips.join(' '), allOf(contains('Lange Vokale'), contains('っ'), contains('ん'), contains('Takt')));
    expect(pronunciationTips('さむい', fluency: 90), isEmpty);
  });
}
