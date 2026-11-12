// Teeküche, Schritt 9: Aufnahmen mit Azure (Stimme ja-JP-NanamiNeural).
//
//   - jeder Satz eines Textes      → <textordner>/<satz.audio>, z. B. s01.mp3
//   - jedes Wort mit Bedeutung     → web/data/woerter/<schlüssel>.mp3 (einmal für alle Texte)
//
// Aufruf:
//   dart run tool/tts.dart                       # erzeugt, was fehlt
//   dart run tool/tts.dart --dry                 # zeigt nur, was erzeugt würde
//   dart run tool/tts.dart --force               # alles neu erzeugen
//   dart run tool/tts.dart --key=werkstatt/azure-speech.env   # anderer Zugang
//   dart run tool/tts.dart --jlpt                # dazu der JLPT-Wortschatz N5–N2 (Aufbaupaket)
//   dart run tool/tts.dart --hoerkontrolle       # Satzaufnahmen abhören (neue Texte; --alle: alle)
//
// Standard ist der Aufbau-Zugang werkstatt/azure-aufbau.env (S0, Startguthaben).
// Ab dem 6.12.2026 nur noch den Gratis-Zugang F0 verwenden.
// Den Schlüssel nie ausgeben, nie committen.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:yomicha/data/audio_key.dart';
import 'package:yomicha/data/models.dart';
import 'package:yomicha/speech/assessment.dart';

const voice = 'ja-JP-NanamiNeural';

/// Kumachan: hell und etwas höher als Nanami.
const kumaVoice = 'ja-JP-AoiNeural';
const kumaPitch = '+12%';
const format = 'audio-16khz-32kbitrate-mono-mp3';

/// Etwas langsamer in den unteren Stufen (Spezifikation 6).
const rateByStufe = {1: '-20%', 2: '-15%', 3: '-10%', 4: '-8%', 5: '-5%', 6: '0%', 7: '0%'};

late final String key;
late final String region;

/// F0 (gratis) oder S0 (bezahlt, nur für den Aufbau) – aus AZURE_SPEECH_TIER.
var tier = 'F0';
var billed = 0;
var made = 0;
var skipped = 0;

Future<void> main(List<String> args) async {
  final dry = args.contains('--dry');
  final force = args.contains('--force');
  final keyFile = args
      .firstWhere((a) => a.startsWith('--key='), orElse: () => '--key=werkstatt/azure-aufbau.env')
      .substring(6);

  if (!dry) {
    final cfg = _readEnv(keyFile);
    key = cfg['AZURE_SPEECH_KEY'] ?? '';
    region = cfg['AZURE_SPEECH_REGION'] ?? '';
    tier = cfg['AZURE_SPEECH_TIER'] ?? 'F0';
    if (key.isEmpty || region.isEmpty) {
      stderr.writeln('Schlüssel fehlt in $keyFile');
      exit(1);
    }
  }

  if (args.contains('--hoerkontrolle')) {
    await _hoerkontrolle(
      all: args.contains('--alle'),
      paths: [for (final a in args) if (!a.startsWith('--')) a],
    );
    if (billed > 0) _count();
    return;
  }

  final texts = Directory('web/data/texte')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('text.json'));
  final words = <String, Token>{};

  for (final file in texts) {
    final folder = file.parent.path;
    final doc = TextDoc.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      folder: folder,
    );
    final rate = rateByStufe[doc.stufe] ?? '0%';
    for (var i = 0; i < doc.sentences.length; i++) {
      final s = doc.sentences[i];
      final name = s.audio ?? 's${(i + 1).toString().padLeft(2, '0')}.mp3';
      final out = File('$folder/$name');
      final ssml = _ssml(_sentenceText(s), rate);
      await _make(out, ssml, _billable(s.plain), dry: dry, force: force);
    }
    for (final t in [...doc.title, for (final s in doc.sentences) ...s.tokens]) {
      if (wantsWordAudio(t)) words[wordAudioKey(t)] = t;
    }
  }

  // Aufbaupaket: Aufnahmen für den ganzen JLPT-Wortschatz N5–N2 (Spezifikation 16),
  // mit demselben Schlüssel wie im Text (Schreibung|Lesung).
  if (args.contains('--jlpt')) {
    final before = words.length;
    for (final t in _jlptWords()) {
      words.putIfAbsent(wordAudioKey(t), () => t);
    }
    stdout.writeln('JLPT-Wortschatz: ${words.length - before} Wörter dazu');
  }

  for (final t in words.values) {
    final out = File('web/data/${wordAudioPath(t)}');
    // Wörter allein: mit fester Lesung, damit z. B. 葉 nicht als よう gelesen wird.
    final text = t.hasKanji ? '<sub alias="${_esc(t.reading)}">${_esc(t.t)}</sub>' : _esc(t.t);
    await _make(out, _ssml(text, '-10%'), _billable(t.reading), dry: dry, force: force);
  }

  // Kumachans Sprüche: helle Stimme, etwas höher (Spezifikation 13).
  final kuma = File('web/data/kuma/sprueche.json');
  if (kuma.existsSync()) {
    final moods = jsonDecode(await kuma.readAsString()) as Map<String, dynamic>;
    for (final mood in moods.values.whereType<Map<String, dynamic>>()) {
      for (final line in (mood['sprueche'] as List).cast<Map<String, dynamic>>()) {
        final markup = line['ja'] as String;
        final out = File('web/data/${kumaAudioPath(markup)}');
        final ssml =
            "<speak version='1.0' xml:lang='ja-JP' xmlns='http://www.w3.org/2001/10/synthesis'>"
            "<voice name='$kumaVoice'><prosody rate='-5%' pitch='$kumaPitch'>${_rubyToSsml(markup)}</prosody></voice></speak>";
        await _make(out, ssml, _billable(markup), dry: dry, force: force);
      }
    }
  }

  stdout.writeln(
    '${dry ? 'Würde erzeugen' : 'Erzeugt'}: $made · übersprungen: $skipped · '
    'ca. $billed abgerechnete Zeichen ($tier)',
  );
  if (!dry && billed > 0) _count();
}

/// Verbrauch pro Monat in einer gemeinsamen lokalen Datei (auch für
/// LearnwithLeoni gedacht). Beim Gratis-Zugang F0 gibt es ab dem
/// eingestellten Anteil eine Meldung auf der Startseite (Spezifikation 16).
void _count() {
  final cfg = jsonDecode(File('tool/teekueche/config.json').readAsStringSync()) as Map<String, dynamic>;
  final file = File(cfg['verbrauch_datei'] as String);
  final data = file.existsSync() ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic> : <String, dynamic>{};
  final month = DateTime.now().toIso8601String().substring(0, 7);
  final m = (data[month] as Map<String, dynamic>?) ?? <String, dynamic>{};
  m[tier] = ((m[tier] as int?) ?? 0) + billed;
  m['yomicha_$tier'] = ((m['yomicha_$tier'] as int?) ?? 0) + billed;
  data[month] = m;
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));

  final limit = cfg['azure_gratis_zeichen_pro_monat'] as int;
  final share = ((m['F0'] as int?) ?? 0) / limit;
  stdout.writeln('Azure-Verbrauch $month: F0 ${m['F0'] ?? 0} von $limit (${(share * 100).round()} %), S0 ${m['S0'] ?? 0}');
  if (share >= (cfg['warnen_ab_anteil'] as num)) {
    final status = File('web/data/status.json');
    final s = jsonDecode(status.readAsStringSync()) as Map<String, dynamic>;
    final list = (s['meldungen'] as List).cast<Map<String, dynamic>>();
    final text = 'Das Azure-Gratiskontingent ist diesen Monat zu ${(share * 100).round()} % verbraucht.';
    if (!list.any((x) => (x['text'] as String).startsWith('Das Azure-Gratiskontingent') && (x['datum'] as String).startsWith(month))) {
      list.insert(0, {'datum': DateTime.now().toIso8601String().substring(0, 10), 'text': text});
      s['meldungen'] = list;
      status.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(s)}\n');
      stdout.writeln('MELDUNG: $text');
    }
  }
}

Future<void> _make(File out, String ssml, int chars, {required bool dry, required bool force}) async {
  if (out.existsSync() && !force) {
    skipped++;
    return;
  }
  made++;
  billed += chars;
  if (dry) {
    stdout.writeln('  ${out.path}');
    return;
  }
  final bytes = await _synth(ssml, format, label: out.path);
  if (bytes == null) {
    billed -= chars;
    return;
  }
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(bytes);
  stdout.writeln('  ✓ ${out.path}');
}

/// Eine Aufnahme bei Azure holen; bei 429 (Gratis-Zugang F0) warten und erneut versuchen.
Future<List<int>?> _synth(String ssml, String outputFormat, {required String label}) async {
  final client = HttpClient();
  try {
    for (var attempt = 1; ; attempt++) {
      final req = await client.postUrl(
        Uri.parse('https://$region.tts.speech.microsoft.com/cognitiveservices/v1'),
      );
      req.headers
        ..set('Ocp-Apim-Subscription-Key', key)
        ..set('X-Microsoft-OutputFormat', outputFormat)
        ..set('User-Agent', 'yomicha-teekueche')
        ..contentType = ContentType('application', 'ssml+xml', charset: 'utf-8');
      req.add(utf8.encode(ssml));
      final res = await req.close();
      if (res.statusCode == 429 && attempt < 8) {
        await res.drain<void>();
        final wait = int.tryParse(res.headers.value('retry-after') ?? '') ?? 10 * attempt;
        stdout.writeln('  … Azure bremst, warte $wait s');
        await Future<void>.delayed(Duration(seconds: wait));
        continue;
      }
      if (res.statusCode != 200) {
        final body = await res.transform(utf8.decoder).join();
        stderr.writeln('FEHLER ${res.statusCode} bei $label: $body');
        exitCode = 1;
        return null;
      }
      final out = BytesBuilder(copy: false);
      await res.forEach(out.add);
      return out.takeBytes();
    }
  } finally {
    client.close();
  }
}

/// Hörkontrolle (Spezifikation 16): Für jeden Satz holt Azure dieselbe Aufnahme
/// als WAV, und die Aussprache-Bewertung vergleicht sie mit der **Lesung des
/// Textes in Kana**. Liest die Stimme ein Kanji anders (今日 als こんにち statt
/// きょう), fällt das Wort durch. Abhilfe: im Satz eine feste Lesung (`say`)
/// eintragen und die Aufnahme mit --force neu erzeugen.
Future<void> _hoerkontrolle({required bool all, required List<String> paths}) async {
  final files = paths.isNotEmpty
      ? [for (final p in paths) File(p)]
      : (Directory('web/data/texte')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('text.json'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path)));
  var checked = 0, flagged = 0, ms = 0;
  for (final file in files) {
    final folder = file.parent.path;
    final report = File('$folder/hoerkontrolle.json');
    if (!all && paths.isEmpty && report.existsSync()) continue;
    final doc = TextDoc.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>, folder: folder);
    final rate = rateByStufe[doc.stufe] ?? '0%';
    stdout.writeln('\n== ${doc.id} (Stufe ${doc.stufe}) ==');
    final result = <String, Object>{};
    for (var i = 0; i < doc.sentences.length; i++) {
      final s = doc.sentences[i];
      final name = s.audio ?? 's${(i + 1).toString().padLeft(2, '0')}.mp3';
      if (!File('$folder/$name').existsSync()) continue;
      final wav = await _synth(_ssml(_sentenceText(s), rate), 'riff-16khz-16bit-mono-pcm', label: '$folder/$name');
      if (wav == null) continue;
      billed += _billable(s.plain);
      final PronunciationResult pa;
      try {
        pa = await assess(key: key, region: region, wav: Uint8List.fromList(wav), referenceText: _spokenReading(s));
      } on PronunciationError catch (e) {
        stderr.writeln('  FEHLER Satz ${i + 1}: $e');
        exitCode = 1;
        continue;
      }
      checked++;
      ms += ((wav.length - 44) / 32).round(); // 16 kHz · 16 bit = 32 Byte pro ms
      // „Insertion“ meldet die Erkennung oft bei reinem Kana-Bezug, ohne dass die
      // Stimme etwas falsch macht – zählt nicht. Verdächtig sind ausgelassene und
      // deutlich anders gesprochene Wörter.
      final bad = [
        for (final w in pa.words)
          if (w.error == 'Omission' || (w.error == 'Mispronunciation' && w.accuracy < 60)) w,
      ];
      if (bad.isEmpty) {
        stdout.writeln('  OK          Satz ${i + 1} (${pa.accuracy.round()})');
        result[name] = 'ok';
      } else {
        flagged++;
        stdout.writeln('  ABWEICHUNG  Satz ${i + 1}: '
            '${bad.map((w) => '${w.word} (${w.error}, ${w.accuracy.round()})').join(', ')} · gehört: ${pa.recognized}');
        result[name] = {'status': 'abweichung', 'woerter': [for (final w in bad) w.word], 'gehoert': pa.recognized};
      }
    }
    report.writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(result)}\n');
  }
  stdout.writeln('\nHörkontrolle: $checked Sätze, ${(ms / 1000).round()} s Audio · Abweichungen: $flagged');
  if (flagged > 0) exitCode = 1;
}

/// So soll der Satz klingen: feste Lesung, sonst die Lesung des Textes, Kana wie geschrieben.
String _spokenReading(Sentence s) =>
    s.tokens.map((t) => t.say ?? (t.hasKanji ? t.reading : t.t)).join();

/// Satztext für die Stimme; Wörter mit fester Lesung ([Token.say]) als <sub>.
String _sentenceText(Sentence s) => s.tokens
    .map((t) => t.say != null ? '<sub alias="${_esc(t.say!)}">${_esc(t.t)}</sub>' : _esc(t.t))
    .join();

String _ssml(String inner, String rate) =>
    "<speak version='1.0' xml:lang='ja-JP' xmlns='http://www.w3.org/2001/10/synthesis'>"
    "<voice name='$voice'><prosody rate='$rate'>$inner</prosody></voice></speak>";

/// Ruby-Schreibweise {漢字|かな} → <sub alias="かな">漢字</sub>, damit die
/// Stimme die Lesung sicher richtig spricht.
String _rubyToSsml(String markup) {
  final re = RegExp(r'\{([^|{}]+)\|([^{}]+)\}');
  final out = StringBuffer();
  var last = 0;
  for (final m in re.allMatches(markup)) {
    out
      ..write(_esc(markup.substring(last, m.start)))
      ..write('<sub alias="${_esc(m.group(2)!)}">${_esc(m.group(1)!)}</sub>');
    last = m.end;
  }
  out.write(_esc(markup.substring(last)));
  return out.toString();
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Japanische Zeichen zählen bei Azure teilweise doppelt – vorsichtig schätzen.
/// Wörter N5–N2 aus `tool/teekueche/daten/jlpt_woerter.json` als Token wie im Text:
/// Kana-Wörter ohne Lesung (Schlüssel „たくさん|たくさん“), Kanji-Wörter mit Lesung in Hiragana.
List<Token> _jlptWords() {
  final list = jsonDecode(File('tool/teekueche/daten/jlpt_woerter.json').readAsStringSync()) as Map<String, dynamic>;
  final kana = RegExp(r'^[ぁ-ゖァ-ヺー]+$');
  final hira = RegExp(r'^[ぁ-ゖー]+$');
  final japanese = RegExp(r'^[ぁ-ゖァ-ヺー々一-鿿]+$');
  final endsWithKanji = RegExp(r'[々一-鿿]$');
  final out = <Token>[];
  for (final MapEntry(:key, :value) in list.entries) {
    if (!key.contains('|') || (value as num) < 2) continue;
    final [surface, raw] = key.split('|');
    if (!japanese.hasMatch(surface)) continue;
    if (kana.hasMatch(surface)) {
      out.add(Token(t: surface));
      continue;
    }
    // Kanji-Wörter brauchen genau eine Lesung in Hiragana.
    var reading = raw;
    if (!hira.hasMatch(reading)) continue;
    // „世話|せわする“: Die Lesung gehört zum Nomen ohne する.
    if (reading.endsWith('する') && endsWithKanji.hasMatch(surface)) {
      reading = reading.substring(0, reading.length - 2);
    }
    if (reading.isEmpty) continue;
    out.add(Token(t: surface, r: reading));
  }
  return out;
}

int _billable(String s) => s.runes.fold(0, (n, r) => n + (r > 0x2E80 ? 2 : 1));

Map<String, String> _readEnv(String path) {
  final f = File(path);
  if (!f.existsSync()) {
    stderr.writeln('Schlüsseldatei fehlt: $path');
    exit(1);
  }
  return {
    for (final line in f.readAsLinesSync())
      if (RegExp(r'^\s*([A-Z_]+)\s*=\s*(.*)$').firstMatch(line) case final m?)
        m.group(1)!: m.group(2)!.trim(),
  };
}
