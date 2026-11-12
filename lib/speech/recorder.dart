import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:record/record.dart';

/// Aufnahme fürs Nachsprechen: WAV, 16 kHz, mono – das Format, das Azure erwartet.
class Recorder {
  final _rec = AudioRecorder();
  DateTime? _started;

  Future<bool> start() async {
    if (!await _rec.hasPermission()) return false;
    await _rec.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: '',
    );
    _started = DateTime.now();
    return true;
  }

  /// Beendet die Aufnahme: Datei-Adresse (zum Anhören), Bytes und Länge in Sekunden.
  Future<(String, Uint8List, int)?> stop() async {
    final url = await _rec.stop();
    final started = _started;
    _started = null;
    if (url == null || started == null) return null;
    final res = await http.get(Uri.parse(url));
    final seconds = DateTime.now().difference(started).inMilliseconds / 1000;
    return (url, res.bodyBytes, seconds.ceil());
  }

  Future<void> dispose() => _rec.dispose();
}
