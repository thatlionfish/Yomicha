import 'dart:convert';

import 'package:http/http.dart' as http;

/// Wöchentliche Sicherung des Lernstands in meinem privaten GitHub-Repository
/// `Yomicha-lernstand` (Spezifikation 17). Pro Gerät eine Datei
/// (`sicherungen/ipad.json`); ältere Stände bleiben in der Versionsgeschichte.
/// Der Schlüssel (ein fein abgestimmtes Token nur für dieses Repository) liegt
/// nur auf dem Gerät.
class GithubSicherung {
  GithubSicherung(this.token, {http.Client? client}) : _client = client ?? http.Client();

  static const repo = 'thatlionfish/Yomicha-lernstand';
  static const ordner = 'sicherungen';

  /// So oft sichert die App von selbst.
  static const abstand = Duration(days: 7);

  final String token;
  final http.Client _client;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };

  Uri _url(String path) => Uri.parse('https://api.github.com/repos/$repo/contents/$path');

  /// Legt die Sicherung dieses Geräts ab (ersetzt die vorige).
  Future<void> hochladen(String geraet, String json, DateTime now) async {
    final path = '$ordner/$geraet.json';
    String? sha;
    final alt = await _client.get(_url(path), headers: _headers);
    if (alt.statusCode == 200) {
      sha = (jsonDecode(alt.body) as Map<String, dynamic>)['sha'] as String?;
    } else if (alt.statusCode != 404) {
      throw SicherungsFehler.status(alt.statusCode);
    }
    final res = await _client.put(
      _url(path),
      headers: _headers,
      body: jsonEncode({
        'message': 'Sicherung $geraet vom ${now.toIso8601String().substring(0, 10)}',
        'content': base64Encode(utf8.encode(json)),
        'sha': ?sha,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) throw SicherungsFehler.status(res.statusCode);
  }

  /// Alle Sicherungen: Gerät → Inhalt der Datei.
  Future<Map<String, String>> holen() async {
    final res = await _client.get(_url(ordner), headers: _headers);
    if (res.statusCode == 404) return {};
    if (res.statusCode != 200) throw SicherungsFehler.status(res.statusCode);
    final out = <String, String>{};
    for (final e in (jsonDecode(res.body) as List).cast<Map<String, dynamic>>()) {
      final name = e['name'] as String;
      if (e['type'] != 'file' || !name.endsWith('.json')) continue;
      final f = await _client.get(_url('$ordner/$name'), headers: {..._headers, 'Accept': 'application/vnd.github.raw+json'});
      if (f.statusCode != 200) throw SicherungsFehler.status(f.statusCode);
      out[name.substring(0, name.length - 5)] = utf8.decode(f.bodyBytes);
    }
    return out;
  }
}

class SicherungsFehler implements Exception {
  const SicherungsFehler(this.message);

  factory SicherungsFehler.status(int code) => SicherungsFehler(switch (code) {
    401 => 'Der GitHub-Schlüssel stimmt nicht oder ist abgelaufen.',
    403 || 404 => 'Der Schlüssel darf das Repository Yomicha-lernstand nicht lesen und schreiben.',
    _ => 'GitHub antwortet gerade nicht (Fehler $code).',
  });

  final String message;

  @override
  String toString() => message;
}
