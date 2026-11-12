import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Lädt Texte und Kanji-Daten, die neben der App unter data/ liegen.
class Repository {
  Uri url(String path) => Uri.base.resolve('data/$path');

  Future<dynamic> _json(String path) async {
    final res = await http.get(url(path));
    if (res.statusCode != 200) {
      throw Exception('Konnte $path nicht laden (${res.statusCode}).');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<List<TextEntry>> index() async {
    final j = await _json('texte/index.json') as Map<String, dynamic>;
    final list = [
      for (final e in j['texts'] as List) TextEntry.fromJson(e as Map<String, dynamic>),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<TextDoc> text(String folder) async {
    final j = await _json('$folder/text.json') as Map<String, dynamic>;
    return TextDoc.fromJson(j, folder: folder);
  }

  final _buckets = <String, Future<Map<String, KanjiInfo>>>{};
  Future<Map<String, String>>? _parts;

  Future<Map<String, KanjiInfo>> _bucket(String name) => _buckets[name] ??= () async {
    try {
      final j = await _json('kanji/$name.json') as Map<String, dynamic>;
      return {
        for (final e in j.entries) e.key: KanjiInfo.fromJson(e.key, e.value as Map<String, dynamic>),
      };
    } catch (_) {
      return <String, KanjiInfo>{};
    }
  }();

  /// Kanji-Karte; null, wenn es für das Zeichen keine gibt.
  Future<KanjiInfo?> kanjiInfo(String kanji) async => (await _bucket(kanjiBucket(kanji)))[kanji];

  /// Kanji-Karten für mehrere Zeichen (lädt nur die nötigen Dateien).
  Future<Map<String, KanjiInfo>> kanjiFor(Iterable<String> chars) async {
    final set = chars.toSet();
    final out = <String, KanjiInfo>{};
    for (final name in {for (final c in set) kanjiBucket(c)}) {
      final b = await _bucket(name);
      for (final c in set) {
        if (b[c] case final k?) out[c] = k;
      }
    }
    return out;
  }

  /// Namen der Bestandteile (z. B. 艹 → grass).
  Future<Map<String, String>> partNames() => _parts ??= () async {
    try {
      final j = await _json('kanji/teile.json') as Map<String, dynamic>;
      return {for (final e in j.entries) e.key: e.value as String};
    } catch (_) {
      return <String, String>{};
    }
  }();

  Future<Map<String, KumaMood>>? _kuma;

  /// Kumachans Stimmungen mit Posen und Sprüchen.
  Future<Map<String, KumaMood>> kumaMoods() => _kuma ??= () async {
    try {
      final j = await _json('kuma/sprueche.json') as Map<String, dynamic>;
      return {
        for (final e in j.entries)
          if (e.value is Map<String, dynamic>) e.key: KumaMood.fromJson(e.value as Map<String, dynamic>),
      };
    } catch (_) {
      return <String, KumaMood>{};
    }
  }();

  String audioUrl(String path) => url(path).toString();
}
