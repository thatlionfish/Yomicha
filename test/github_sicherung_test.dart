import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomicha/data/github_sicherung.dart';
import 'package:yomicha/data/progress.dart';

/// Ein kleines GitHub: Dateien im Repository, mit sha und Versionen.
class _FakeGithub {
  final files = <String, String>{};
  final versions = <String, int>{};
  final requests = <http.Request>[];
  int? fail;

  MockClient get client => MockClient((req) async {
    requests.add(req);
    if (fail != null) return http.Response('', fail!);
    expect(req.headers['Authorization'], 'Bearer geheim');
    final path = req.url.path.replaceFirst('/repos/${GithubSicherung.repo}/contents/', '');
    if (req.method == 'GET' && path == GithubSicherung.ordner) {
      final list = [
        for (final f in files.keys)
          if (f.startsWith('${GithubSicherung.ordner}/')) {'name': f.split('/').last, 'type': 'file'},
      ];
      return list.isEmpty ? http.Response('', 404) : http.Response(jsonEncode(list), 200);
    }
    if (req.method == 'GET') {
      final f = files[path];
      if (f == null) return http.Response('', 404);
      if (req.headers['Accept'] == 'application/vnd.github.raw+json') return http.Response.bytes(utf8.encode(f), 200);
      return http.Response(jsonEncode({'sha': 'sha${versions[path]}'}), 200);
    }
    if (req.method == 'PUT') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final exists = files.containsKey(path);
      // Wie GitHub: Eine bestehende Datei braucht die aktuelle sha.
      if (exists && body['sha'] != 'sha${versions[path]}') return http.Response('', 409);
      files[path] = utf8.decode(base64Decode(body['content'] as String));
      versions[path] = (versions[path] ?? 0) + 1;
      return http.Response('{}', exists ? 200 : 201);
    }
    return http.Response('', 405);
  });
}

Future<Progress> _progress() async {
  SharedPreferences.setMockInitialValues({});
  final p = Progress();
  await p.load();
  return p;
}

void main() {
  final t0 = DateTime(2026, 11, 21, 8);

  test('Ohne Schlüssel passiert nichts', () async {
    final p = await _progress();
    final gh = _FakeGithub();
    expect(await p.cloudSichern(t0, geraet: 'ipad', client: gh.client), isFalse);
    expect(gh.requests, isEmpty);
  });

  test('Einmal pro Woche von selbst, jederzeit von Hand; ersetzt die Datei des Geräts', () async {
    final p = await _progress();
    p.setGithubToken(' geheim ');
    p.addWords(const [MyWord(t: '暑い', reading: 'あつい', gloss: 'heiß')]);
    final gh = _FakeGithub();

    expect(await p.cloudSichern(t0, geraet: 'ipad', client: gh.client), isTrue);
    expect(gh.files.keys, ['sicherungen/ipad.json']);
    expect(p.cloudBackup, t0);
    expect(p.lastBackup, t0, reason: 'zählt auch als Sicherung für die Erinnerung');

    // Drei Tage später: noch nicht fällig.
    expect(await p.cloudSichern(t0.add(const Duration(days: 3)), geraet: 'ipad', client: gh.client), isFalse);
    // Von Hand geht es trotzdem – mit der sha der vorigen Fassung.
    expect(await p.cloudSichern(t0.add(const Duration(days: 3)), geraet: 'ipad', client: gh.client, nurWennFaellig: false), isTrue);
    expect(gh.versions['sicherungen/ipad.json'], 2);
    // Nach einer Woche wieder von selbst.
    expect(await p.cloudSichern(t0.add(const Duration(days: 10)), geraet: 'ipad', client: gh.client), isTrue);

    // Der Schlüssel kommt nicht mit in die Sicherung.
    final saved = gh.files['sicherungen/ipad.json']!;
    expect(saved, isNot(contains('geheim')));
    expect(Progress.previewBackup(saved).words, 1);
  });

  test('Fehler werden gemeldet, nicht verschluckt', () async {
    final p = await _progress();
    p.setGithubToken('geheim');
    final gh = _FakeGithub()..fail = 401;
    expect(await p.cloudSichern(t0, geraet: 'ipad', client: gh.client), isFalse);
    expect(p.cloudFehler, contains('abgelaufen'));
    expect(p.cloudBackup, isNull);
    gh.fail = null;
    expect(await p.cloudSichern(t0, geraet: 'ipad', client: gh.client), isTrue);
    expect(p.cloudFehler, isNull);
  });

  test('Zurückholen: alle Geräte, mit Inhalt', () async {
    final gh = _FakeGithub();
    gh.files['sicherungen/ipad.json'] = '{"app":"yomicha"}';
    gh.files['sicherungen/iphone.json'] = '{"app":"yomicha","x":1}';
    final alle = await GithubSicherung('geheim', client: gh.client).holen();
    expect(alle.keys.toSet(), {'ipad', 'iphone'});
    expect(alle['iphone'], contains('"x":1'));
    expect(await GithubSicherung('geheim', client: _FakeGithub().client).holen(), isEmpty);
  });
}
