import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yomicha/data/models.dart';
import 'package:yomicha/learn/strich_pruefung.dart';
import 'package:yomicha/widgets/stroke_order.dart';

List<List<Offset>> strokesOf(String kanji) {
  final f = File('web/data/kanji/${kanjiBucket(kanji)}.json');
  final j = (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)[kanji] as Map<String, dynamic>;
  return [for (final d in (j['paths'] as List).cast<String>()) samplePath(parseSvgPath(d))];
}

/// Ein „von Hand“ gezogener Strich: der echte Strich, etwas verschoben und
/// leicht zittrig, mit anderer Punktzahl.
List<Offset> hand(List<Offset> t, {Offset shift = const Offset(3, -2), int seed = 1}) {
  final r = Random(seed);
  final dense = resample(t, 60);
  return [for (final p in dense) p + shift + Offset(r.nextDouble() * 2 - 1, r.nextDouble() * 2 - 1)];
}

void main() {
  test('Abtasten und Gleichverteilen', () {
    final pts = resample([Offset.zero, const Offset(10, 0), const Offset(10, 10)], 5);
    expect(pts.length, 5);
    expect(pts.first, Offset.zero);
    expect((pts[2] - const Offset(10, 0)).distance, lessThan(0.01));
    expect((pts.last - const Offset(10, 10)).distance, lessThan(0.01));
  });

  test('十: richtiger Strich, Richtung, Reihenfolge', () {
    final s = strokesOf('十');
    expect(s.length, 2);
    expect(pruefeStrich(hand(s[0]), s, 0).urteil, StrichUrteil.richtig);
    // Waagerecht von rechts nach links: verkehrt herum.
    expect(pruefeStrich(hand(s[0]).reversed.toList(), s, 0).urteil, StrichUrteil.richtung);
    // Zuerst senkrecht: falsche Reihenfolge.
    final order = pruefeStrich(hand(s[1]), s, 0);
    expect(order.urteil, StrichUrteil.reihenfolge);
    expect(order.strich, 1);
    expect(pruefeStrich(hand(s[1]), s, 1).urteil, StrichUrteil.richtig);
  });

  test('Ein Strich an der falschen Stelle zählt nicht', () {
    final s = strokesOf('十');
    expect(pruefeStrich(hand(s[0], shift: const Offset(0, 35)), s, 0).urteil, StrichUrteil.falsch);
    // Nur ein Tupfer statt eines langen Strichs.
    expect(pruefeStrich([s[0][10], s[0][11]], s, 0).urteil, StrichUrteil.falsch);
  });

  test('Ganze Kanji Strich für Strich', () {
    for (final k in ['確', '若', '心', '彼', '野']) {
      final s = strokesOf(k);
      for (var i = 0; i < s.length; i++) {
        expect(pruefeStrich(hand(s[i], seed: i), s, i).urteil, StrichUrteil.richtig, reason: '$k Strich ${i + 1}');
      }
    }
  });
}
