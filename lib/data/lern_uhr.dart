import 'package:shared_preferences/shared_preferences.dart';

/// Nach 20 Minuten Lernen 5 Minuten Pause (Spezifikation 20).
///
/// Gezählt wird die Zeit in den Lernansichten (Lesen, Wiederholen, Schreiben,
/// Wochentest) zwischen zwei Berührungen; eine lange Lücke ohne Berühren zählt
/// höchstens zwei Minuten (z. B. beim Lesen), eine Lücke von fünf Minuten ist
/// schon eine Pause. Der Stand liegt im Speicher, damit Neuladen die Pause
/// nicht überspringt.
class LernUhr {
  static const _key = 'yomicha.lernuhr';
  static const lernzeit = Duration(minutes: 20);
  static const pausenzeit = Duration(minutes: 5);
  static const leerlauf = Duration(minutes: 2);

  SharedPreferences? _prefs;
  void Function() _changed = () {};

  /// Gelernt seit der letzten Pause.
  Duration gelernt = Duration.zero;
  DateTime? _zuletzt;
  DateTime? _gespeichert;

  /// Die Pause läuft bis dann.
  DateTime? pauseBis;

  void load(SharedPreferences p, void Function() changed) {
    _prefs = p;
    _changed = changed;
    final parts = (p.getString(_key) ?? '').split(':');
    int? at(int i) => i < parts.length ? int.tryParse(parts[i]) : null;
    gelernt = Duration(seconds: at(0) ?? 0);
    _zuletzt = at(1) == null || at(1) == 0 ? null : DateTime.fromMillisecondsSinceEpoch(at(1)!);
    pauseBis = at(2) == null || at(2) == 0 ? null : DateTime.fromMillisecondsSinceEpoch(at(2)!);
  }

  void _save(DateTime now, {bool sofort = false}) {
    if (!sofort && _gespeichert != null && now.difference(_gespeichert!) < const Duration(seconds: 5)) return;
    _gespeichert = now;
    _prefs?.setString(
      _key,
      '${gelernt.inSeconds}:${_zuletzt?.millisecondsSinceEpoch ?? 0}:${pauseBis?.millisecondsSinceEpoch ?? 0}',
    );
  }

  bool pausiert(DateTime now) => pauseBis != null && now.isBefore(pauseBis!);

  /// Wie lange die Pause noch dauert.
  Duration rest(DateTime now) => pausiert(now) ? pauseBis!.difference(now) : Duration.zero;

  /// Ist die Pause vorbei, beginnt die Zählung von vorn.
  void _pauseVorbei(DateTime now) {
    if (pauseBis == null || pausiert(now)) return;
    pauseBis = null;
    gelernt = Duration.zero;
    _zuletzt = null;
    _save(now, sofort: true);
  }

  /// Ich tue etwas in einer Lernansicht (Antippen, Schreiben, Blättern).
  void aktiv(DateTime now) {
    if (pausiert(now)) return;
    _pauseVorbei(now);
    if (_zuletzt case final z?) {
      final gap = now.difference(z);
      if (gap >= pausenzeit) {
        gelernt = Duration.zero;
      } else if (!gap.isNegative) {
        gelernt += gap < leerlauf ? gap : leerlauf;
      }
    }
    _zuletzt = now;
    _save(now);
  }

  /// Sind 20 Minuten voll, beginnt jetzt die Pause. true = Pause.
  bool pruefe(DateTime now) {
    if (pausiert(now)) return true;
    aktiv(now);
    if (gelernt < lernzeit) return false;
    pauseBis = now.add(pausenzeit);
    gelernt = Duration.zero;
    _zuletzt = null;
    _save(now, sofort: true);
    _changed();
    return true;
  }

  /// Die Pause ist um (vom Pausenbildschirm aufgerufen).
  void weiter(DateTime now) {
    _pauseVorbei(now);
    _changed();
  }
}
