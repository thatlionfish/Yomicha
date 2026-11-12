import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Aussprache-Bewertung mit Azure Speech „Pronunciation Assessment“
/// (Spezifikation 7). Japanisch (ja-JP) wird unterstützt; die Satzmelodie
/// (Prosodie) bewertet Azure für Japanisch nicht.
class WordScore {
  const WordScore(this.word, this.accuracy, this.error);
  final String word;
  final double accuracy;

  /// None, Mispronunciation, Omission, Insertion.
  final String error;

  WordGrade get grade {
    if (error == 'Omission') return WordGrade.ausgelassen;
    if (error == 'Mispronunciation' || accuracy < 60) return WordGrade.falsch;
    if (accuracy < 80) return WordGrade.unsicher;
    return WordGrade.gut;
  }
}

enum WordGrade {
  gut('gut'),
  unsicher('unsicher'),
  falsch('falsch ausgesprochen'),
  ausgelassen('ausgelassen');

  const WordGrade(this.label);
  final String label;
}

class PronunciationResult {
  const PronunciationResult({
    required this.recognized,
    required this.accuracy,
    required this.fluency,
    required this.completeness,
    required this.overall,
    required this.words,
  });
  final String recognized;
  final double accuracy;
  final double fluency;
  final double completeness;
  final double overall;
  final List<WordScore> words;

  /// Liest die Antwort von Azure (beide Formen: Werte direkt im NBest-Eintrag
  /// oder unter „PronunciationAssessment“).
  factory PronunciationResult.fromJson(Map<String, dynamic> j) {
    if (j['RecognitionStatus'] != 'Success') {
      throw PronunciationError(
        j['RecognitionStatus'] == 'NoMatch' || j['RecognitionStatus'] == 'InitialSilenceTimeout'
            ? 'Ich habe nichts verstanden. Sprich bitte etwas lauter und näher am Mikrofon.'
            : 'Azure meldet: ${j['RecognitionStatus']}',
      );
    }
    final best = ((j['NBest'] as List?) ?? const []).cast<Map<String, dynamic>>();
    if (best.isEmpty) throw const PronunciationError('Azure hat kein Ergebnis geliefert.');
    final b = best.first;
    final pa = (b['PronunciationAssessment'] as Map<String, dynamic>?) ?? b;
    double n(Map<String, dynamic> m, String k) => (m[k] as num?)?.toDouble() ?? 0;
    return PronunciationResult(
      recognized: (b['Display'] as String?) ?? (j['DisplayText'] as String?) ?? '',
      accuracy: n(pa, 'AccuracyScore'),
      fluency: n(pa, 'FluencyScore'),
      completeness: n(pa, 'CompletenessScore'),
      overall: n(pa, 'PronScore'),
      words: [
        for (final w in ((b['Words'] as List?) ?? const []).cast<Map<String, dynamic>>())
          () {
            final wa = (w['PronunciationAssessment'] as Map<String, dynamic>?) ?? w;
            return WordScore(
              w['Word'] as String? ?? '',
              n(wa, 'AccuracyScore'),
              (wa['ErrorType'] as String?) ?? 'None',
            );
          }(),
      ],
    );
  }
}

class PronunciationError implements Exception {
  const PronunciationError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Kopfzeile „Pronunciation-Assessment“: JSON, Base64-kodiert.
String assessmentHeader(String referenceText) => base64.encode(utf8.encode(jsonEncode({
  'ReferenceText': referenceText,
  'GradingSystem': 'HundredMark',
  'Granularity': 'Word',
  'Dimension': 'Comprehensive',
  'EnableMiscue': true,
})));

/// Schickt eine WAV-Aufnahme (16 kHz, mono) an Azure und bewertet sie.
Future<PronunciationResult> assess({
  required String key,
  required String region,
  required Uint8List wav,
  required String referenceText,
  http.Client? client,
}) async {
  final url = Uri.parse(
    'https://$region.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1'
    '?language=ja-JP&format=detailed',
  );
  final c = client ?? http.Client();
  try {
    final res = await c.post(
      url,
      headers: {
        'Ocp-Apim-Subscription-Key': key,
        'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
        'Accept': 'application/json',
        'Pronunciation-Assessment': assessmentHeader(referenceText),
      },
      body: wav,
    );
    if (res.statusCode == 401) {
      throw const PronunciationError('Der Azure-Schlüssel stimmt nicht. Bitte in den Einstellungen prüfen.');
    }
    if (res.statusCode == 429) {
      throw const PronunciationError('Azure bremst gerade (Gratis-Stufe). Bitte in einer Minute noch einmal.');
    }
    if (res.statusCode != 200) {
      throw PronunciationError('Azure antwortet mit Fehler ${res.statusCode}.');
    }
    return PronunciationResult.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  } finally {
    if (client == null) c.close();
  }
}

/// Kurze Tipps auf Deutsch zu typischen Schwierigkeiten (Spezifikation 7),
/// abhängig von der Lesung der Wörter, die nicht gut klangen.
List<String> pronunciationTips(String readings, {required double fluency}) {
  final tips = <String>[];
  // Lange Vokale: o-Silbe + う (こう, ほう), e-Silbe + い (せい), doppelte Vokale, ー.
  if (RegExp(r'ー|[おこごそぞとどのほぼぽもよょろ]う|[えけげせぜてでねへべぺめれ]い|ゅう|うう|いい|ああ|ええ|おお').hasMatch(readings)) {
    tips.add('Lange Vokale doppelt so lang halten: おう klingt wie „oo“, ええ wie „ee“.');
  }
  if (readings.contains('っ')) {
    tips.add('Kleines っ: vor dem nächsten Konsonanten eine kurze Pause machen (きって = kit-te).');
  }
  if (readings.contains('ん')) {
    tips.add('ん ist eine eigene Silbe und bekommt einen ganzen Takt.');
  }
  if (fluency < 60) {
    tips.add('Gleichmäßiger Takt: Im Japanischen ist jede Silbe (Mora) etwa gleich lang.');
  }
  return tips;
}
