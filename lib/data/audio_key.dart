import 'models.dart';

/// Dateiname der Wortaufnahme. Jede Aufnahme gibt es nur einmal für alle
/// Texte (Spezifikation 11, Speicherplatz). Die App und `tool/tts.dart`
/// rechnen denselben Namen aus.
///
/// Zwei kleine Polynom-Hashes statt eines 32-Bit-Hashs, damit die Rechnung
/// im Browser (JavaScript-Zahlen) und in der Dart-VM gleich ausfällt.
String wordAudioKey(Token t) => audioKey('${t.t}|${t.reading}');

/// Kurzer, stabiler Schlüssel für einen Text (z. B. Kumachans Spruch).
String audioKey(String s) {
  var a = 7, b = 11;
  for (final c in s.codeUnits) {
    a = (a * 131 + c) % 1000003;
    b = (b * 137 + c) % 999983;
  }
  return a.toRadixString(36).padLeft(4, '0') + b.toRadixString(36).padLeft(4, '0');
}

/// Pfad unter data/.
String wordAudioPath(Token t) => 'woerter/${wordAudioKey(t)}.mp3';

/// Pfad der Aufnahme eines Spruchs von Kumachan unter data/.
String kumaAudioPath(String markup) => 'kuma/${audioKey(markup)}.mp3';

/// Bekommt das Wort eine eigene Aufnahme?
bool wantsWordAudio(Token t) => t.isWord && !t.isPunct && t.gloss != null;
