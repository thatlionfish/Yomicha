import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yomicha/data/models.dart';
import 'package:yomicha/widgets/stroke_order.dart';

Map<String, KanjiInfo> _bucket(String kanji) {
  final f = File('web/data/kanji/${kanjiBucket(kanji)}.json');
  final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  return {for (final e in j.entries) e.key: KanjiInfo.fromJson(e.key, e.value as Map<String, dynamic>)};
}

void main() {
  test('茶: Daten aus KanjiVG und KANJIDIC2', () {
    final k = _bucket('茶')['茶']!;
    expect(k.heisig, 267);
    expect(k.strokes, 9);
    expect(k.paths, hasLength(9));
    expect(k.parts, ['艹', '人', '木']);
    expect(k.keyword, isNot(contains('radical')));
  });

  test('Jedes Kanji aus den Texten hat eine Karte mit Strichfolge', () {
    final texts = Directory('web/data/texte').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('text.json'));
    for (final f in texts) {
      final kanji = {for (final ch in f.readAsStringSync().split('')) if (isKanji(ch)) ch};
      for (final k in kanji) {
        final info = _bucket(k)[k];
        expect(info, isNotNull, reason: k);
        expect(info!.paths.length, info.strokes, reason: 'Striche von $k');
      }
    }
  });

  test('Bestandteile haben Namen', () {
    final names = (jsonDecode(File('web/data/kanji/teile.json').readAsStringSync()) as Map).cast<String, String>();
    expect(names['艹'], 'grass');
    expect(names['亻'], 'person');
    expect(names.values.where((n) => n.startsWith('radical')), isEmpty);
  });

  test('SVG-Pfade von KanjiVG liegen im Feld 109 × 109', () {
    for (final d in _bucket('茶')['茶']!.paths) {
      final b = parseSvgPath(d).getBounds();
      expect(b.left, greaterThanOrEqualTo(0));
      expect(b.right, lessThanOrEqualTo(109));
      expect(b.top, greaterThanOrEqualTo(0));
      expect(b.bottom, lessThanOrEqualTo(109));
    }
    expect(strokeStart('M18.5,27.02c2.2,0.53'), const Offset(18.5, 27.02));
  });
}
