import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yomicha/data/audio_key.dart';
import 'package:yomicha/data/models.dart';
import 'package:yomicha/widgets/furigana.dart';
import 'package:yomicha/widgets/kuma_poses.g.dart';

/// Kumachans Sprüche (web/data/kuma/sprueche.json) und Posen.
void main() {
  final j = jsonDecode(File('web/data/kuma/sprueche.json').readAsStringSync()) as Map<String, dynamic>;
  final moods = {
    for (final e in j.entries)
      if (e.value is Map<String, dynamic>) e.key: KumaMood.fromJson(e.value as Map<String, dynamic>),
  };

  test('Alle Stimmungen aus der Spezifikation sind da', () {
    expect(
      moods.keys,
      containsAll(['begruessung', 'fertig', 'perfekt', 'rueckschlag', 'hinweis', 'serie', 'ruhetag', 'aufstieg']),
    );
  });

  test('Jede Stimmung hat bekannte Posen und Sprüche mit Aufnahme', () {
    final names = KumaPose.values.asNameMap();
    for (final MapEntry(:key, :value) in moods.entries) {
      expect(value.lines, isNotEmpty, reason: key);
      for (final p in value.poses) {
        expect(names.containsKey(p), isTrue, reason: '$key: Pose $p');
      }
      for (final l in value.lines) {
        expect(l.de, isNotEmpty, reason: l.ja);
        expect(parseRuby(l.ja).map((t) => t.t).join(), isNot(contains('{')), reason: l.ja);
        expect(File('web/data/${kumaAudioPath(l.ja)}').existsSync(), isTrue, reason: 'Aufnahme fehlt: ${l.ja}');
      }
    }
  });

  test('Jedes Bild jeder Pose gibt es', () {
    for (final p in KumaPose.values) {
      expect(p.frames, hasLength(p.ms.length), reason: p.name);
      for (final f in p.frames) {
        expect(File('assets/kuma/$f').existsSync(), isTrue, reason: f);
      }
    }
  });
}
