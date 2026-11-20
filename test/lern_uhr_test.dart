import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yomicha/data/lern_uhr.dart';

Future<(LernUhr, SharedPreferences)> _uhr([Map<String, Object> werte = const {}]) async {
  SharedPreferences.setMockInitialValues(werte);
  final p = await SharedPreferences.getInstance();
  return (LernUhr()..load(p, () {}), p);
}

void main() {
  final t0 = DateTime(2026, 11, 20, 9);

  test('Zählt die Zeit zwischen zwei Berührungen; lange Lücken höchstens zwei Minuten', () async {
    final (uhr, _) = await _uhr();
    uhr.aktiv(t0);
    uhr.aktiv(t0.add(const Duration(seconds: 30)));
    expect(uhr.gelernt, const Duration(seconds: 30));
    // Vier Minuten lesen ohne zu tippen zählen als zwei.
    uhr.aktiv(t0.add(const Duration(minutes: 4, seconds: 30)));
    expect(uhr.gelernt, const Duration(minutes: 2, seconds: 30));
  });

  test('Fünf Minuten ohne Lernen sind schon eine Pause', () async {
    final (uhr, _) = await _uhr();
    uhr.aktiv(t0);
    uhr.aktiv(t0.add(const Duration(minutes: 1)));
    uhr.aktiv(t0.add(const Duration(minutes: 7)));
    expect(uhr.gelernt, Duration.zero);
  });

  test('Nach 20 Minuten beginnt die Pause, nach 5 Minuten geht es weiter', () async {
    final (uhr, prefs) = await _uhr();
    var t = t0;
    uhr.aktiv(t);
    for (var i = 0; i < 19; i++) {
      t = t.add(const Duration(minutes: 1));
      expect(uhr.pruefe(t), isFalse, reason: 'Minute ${i + 1}');
    }
    t = t.add(const Duration(minutes: 1, seconds: 5));
    expect(uhr.pruefe(t), isTrue);
    expect(uhr.pausiert(t.add(const Duration(minutes: 4))), isTrue);
    expect(uhr.rest(t.add(const Duration(minutes: 4))), const Duration(minutes: 1));

    // Neu laden überspringt die Pause nicht.
    final wieder = LernUhr()..load(prefs, () {});
    expect(wieder.pausiert(t.add(const Duration(minutes: 2))), isTrue);
    // Während der Pause zählt nichts.
    wieder.aktiv(t.add(const Duration(minutes: 3)));
    expect(wieder.gelernt, Duration.zero);

    // Danach beginnt die Zählung von vorn.
    final danach = t.add(const Duration(minutes: 5, seconds: 1));
    expect(wieder.pruefe(danach), isFalse);
    expect(wieder.pausiert(danach), isFalse);
    expect(wieder.gelernt, Duration.zero);
  });
}
