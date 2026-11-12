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
//
// Standard ist der Aufbau-Zugang werkstatt/azure-aufbau.env (S0, Startguthaben).
// Ab dem 6.12.2026 nur noch den Gratis-Zugang F0 verwenden.
// Den Schlüssel nie ausgeben, nie committen.
import 'dart:convert';
import 'dart:io';

import 'package:yomicha/data/audio_key.dart';
import 'package:yomicha/data/models.dart';

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
  out.parent.createSync(recursive: true);
  final client = HttpClient();
  try {
    // Der Gratis-Zugang F0 erlaubt nur wenige Anfragen pro Minute:
    // bei 429 warten und es erneut versuchen.
    for (var attempt = 1; ; attempt++) {
      final req = await client.postUrl(
        Uri.parse('https://$region.tts.speech.microsoft.com/cognitiveservices/v1'),
      );
      req.headers
        ..set('Ocp-Apim-Subscription-Key', key)
        ..set('X-Microsoft-OutputFormat', format)
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
        stderr.writeln('FEHLER ${res.statusCode} bei ${out.path}: $body');
        exitCode = 1;
        billed -= chars;
        return;
      }
      final sink = out.openWrite();
      await res.pipe(sink);
      stdout.writeln('  ✓ ${out.path}');
      return;
    }
  } finally {
    client.close();
  }
}

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
