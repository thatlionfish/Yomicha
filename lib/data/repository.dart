import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'schreib_plan.dart';

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

  Future<SchreibPlan>? _plan;
  Future<Map<String, List<String>>>? _kana;

  /// Lernplan für „Kanji schreiben“.
  Future<SchreibPlan> schreibPlan() => _plan ??= () async {
    return SchreibPlan.fromJson(await _json('schreiben/plan.json') as Map<String, dynamic>);
  }();

  /// Striche der Kana (und von ー, 々) aus KanjiVG.
  Future<Map<String, List<String>>> kana() => _kana ??= () async {
    final j = await _json('schreiben/kana.json') as Map<String, dynamic>;
    return {for (final e in j.entries) e.key: (e.value as List).cast<String>()};
  }();

  /// Striche für jedes Zeichen eines Wortes (Kanji und Kana); fehlt ein
  /// Zeichen, steht es nicht in der Map.
  Future<Map<String, List<String>>> striche(Iterable<String> chars) async {
    final set = chars.toSet();
    final kana = await this.kana();
    final kanji = await kanjiFor(set.where((c) => !kana.containsKey(c)));
    return {
      for (final c in set)
        if (kana[c] case final k?) c: k else if (kanji[c]?.paths case final p? when p.isNotEmpty) c: p,
    };
  }

  Future<Map<String, KumaMood>>? _kuma;

  final _saetze = <String, Future<Map<String, Beispiel>>>{};

  /// Beispielsatz zu einem Wort aus „Kanji schreiben“ (null, wenn es noch keinen gibt).
  Future<Beispiel?> beispiel(String wort, String lesung) async {
    final k = kanjiOf(wort).where((c) => c != '々').firstOrNull;
    if (k == null) return null;
    final name = kanjiBucket(k);
    final bucket = await (_saetze[name] ??= () async {
      try {
        final j = await _json('schreiben/saetze/$name.json') as Map<String, dynamic>;
        return {for (final e in j.entries) e.key: Beispiel.fromJson(e.value as Map<String, dynamic>)};
      } catch (_) {
        return <String, Beispiel>{};
      }
    }());
    return bucket['$wort|$lesung'];
  }

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

  /// Meldungen der Teeküche, z. B. Kostengrenze oder ausgefallener Lauf
  /// (data/status.json, Spezifikation 16).
  Future<List<Notice>> notices() async {
    try {
      final j = await _json('status.json') as Map<String, dynamic>;
      return [
        for (final m in (j['meldungen'] as List? ?? const []).cast<Map<String, dynamic>>())
          Notice(DateTime.parse(m['datum'] as String), m['text'] as String),
      ];
    } catch (_) {
      return const [];
    }
  }

  String audioUrl(String path) => url(path).toString();
}
