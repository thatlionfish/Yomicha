import 'dart:convert';

import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:shared_preferences/shared_preferences.dart';

/// Lernstand von „Kanji schreiben“ (Spezifikation 19). Liegt im selben
/// Speicher wie der übrige Lernstand (Schlüssel „yomicha.schreiben.…“) und
/// kommt deshalb mit in die Sicherung.
class SchreibStand {
  static const _p = 'yomicha.schreiben.';
  SharedPreferences? _prefs;
  void Function() _changed = () {};

  /// Gelernte Kanji → Tag (JJJJ-MM-TT) oder „v“ für mein Vorwissen.
  final Map<String, String> gelernt = {};

  /// FSRS-Karten: „k:“ plus Kanji und „w:“ plus Schreibung|Lesung.
  final Map<String, Map<String, dynamic>> _karten = {};

  /// Neue Kanji pro Lerntag (Mindestziel) und neue Wörter pro Tag (Obergrenze).
  int tagesziel = 4;
  int woerterProTag = 20;

  /// Heute: Tag, neue Wörter, zusätzlich gewünschte Kanji („Noch 4 Kanji“).
  String _tag = '';
  int _neueWoerter = 0;
  int _extra = 0;

  /// Auf diesem Gerät wurde schon mit dem Stift geschrieben: dann zählen
  /// Finger und Handballen im Schreibfeld nicht mehr.
  bool stiftGesehen = false;

  /// Die Frage nach dem bisherigen Stand ist beantwortet.
  bool vorwissenGefragt = false;

  /// Beim Schreiben die Wörter immer wieder vorlesen.
  bool vorlesen = true;

  /// Kanji, die mir in meinen gelesenen Texten schon begegnet sind, und die
  /// Texte, die dafür schon durchgesehen wurden.
  final Set<String> gelesen = {};
  final Set<String> gelesenAus = {};

  void load(SharedPreferences p, void Function() changed) {
    _prefs = p;
    _changed = changed;
    gelernt
      ..clear()
      ..addAll(_map(p.getString('${_p}gelernt')).cast<String, String>());
    _karten.clear();
    for (final e in _map(p.getString('${_p}karten')).entries) {
      _karten[e.key] = (e.value as Map).cast<String, dynamic>();
    }
    tagesziel = p.getInt('${_p}tagesziel') ?? 4;
    woerterProTag = p.getInt('${_p}woerterProTag') ?? 20;
    final heute = (p.getString('${_p}heute') ?? '').split(':');
    _tag = heute.isNotEmpty ? heute[0] : '';
    _neueWoerter = heute.length > 1 ? int.tryParse(heute[1]) ?? 0 : 0;
    _extra = heute.length > 2 ? int.tryParse(heute[2]) ?? 0 : 0;
    stiftGesehen = p.getBool('${_p}stift') ?? false;
    vorwissenGefragt = p.getBool('${_p}vorwissenGefragt') ?? false;
    vorlesen = p.getBool('${_p}vorlesen') ?? true;
    gelesen
      ..clear()
      ..addAll((p.getString('${_p}gelesen') ?? '').split(''));
    gelesenAus
      ..clear()
      ..addAll(p.getStringList('${_p}gelesenAus') ?? const []);
  }

  static Map<String, dynamic> _map(String? s) => s == null ? {} : jsonDecode(s) as Map<String, dynamic>;

  static String tagKey(DateTime d) => d.toIso8601String().substring(0, 10);

  // --- Kanji ---------------------------------------------------------------

  bool kann(String k) => gelernt.containsKey(k);

  /// Wie viele Kanji ich an diesem Tag neu gelernt habe.
  int kanjiAm(DateTime d) {
    final day = tagKey(d);
    return gelernt.values.where((v) => v == day).length;
  }

  void lerne(String k, DateTime now) {
    gelernt[k] = tagKey(now);
    _prefs?.setString('${_p}gelernt', jsonEncode(gelernt));
    _changed();
  }

  /// Übernimmt Kanji, die ich schon kann (ohne Tag – sie zählen nicht zum Tagesziel).
  void uebernimm(Iterable<String> kanji) {
    for (final k in kanji) {
      gelernt.putIfAbsent(k, () => 'v');
    }
    vorwissenGefragt = true;
    _prefs?.setString('${_p}gelernt', jsonEncode(gelernt));
    _prefs?.setBool('${_p}vorwissenGefragt', true);
    _changed();
  }

  void vorwissenBeantwortet() {
    vorwissenGefragt = true;
    _prefs?.setBool('${_p}vorwissenGefragt', true);
    _changed();
  }

  // --- Heute ---------------------------------------------------------------

  void _heute(DateTime now) {
    final day = tagKey(now);
    if (_tag == day) return;
    _tag = day;
    _neueWoerter = 0;
    _extra = 0;
  }

  void _saveHeute() => _prefs?.setString('${_p}heute', '$_tag:$_neueWoerter:$_extra');

  int neueWoerterAm(DateTime d) => _tag == tagKey(d) ? _neueWoerter : 0;
  int extraAm(DateTime d) => _tag == tagKey(d) ? _extra : 0;

  /// Neue Kanji, die heute dran sind (Mindestziel und gewünschte zusätzliche).
  int zielAm(DateTime d) => tagesziel + extraAm(d);

  void mehrKanji(DateTime now, int n) {
    _heute(now);
    _extra += n;
    _saveHeute();
    _changed();
  }

  // --- Karten (FSRS) -------------------------------------------------------

  Iterable<String> get kartenKeys => _karten.keys;

  bool hatKarte(String key) => _karten.containsKey(key);

  fsrs.Card karte(String key) {
    final m = _karten[key];
    if (m == null) return fsrs.Card(cardId: key.hashCode & 0x7fffffff);
    return fsrs.Card.fromMap({
      ...m,
      'stability': (m['stability'] as num?)?.toDouble(),
      'difficulty': (m['difficulty'] as num?)?.toDouble(),
    });
  }

  void speichere(String key, fsrs.Card card, DateTime now) {
    if (!_karten.containsKey(key) && key.startsWith('w:')) {
      _heute(now);
      _neueWoerter++;
      _saveHeute();
    }
    _karten[key] = card.toMap();
    _prefs?.setString('${_p}karten', jsonEncode(_karten));
    _changed();
  }

  // --- Einstellungen -------------------------------------------------------

  void setTagesziel(int n) {
    tagesziel = n.clamp(1, 12);
    _prefs?.setInt('${_p}tagesziel', tagesziel);
    _changed();
  }

  void setWoerterProTag(int n) {
    woerterProTag = n.clamp(5, 60);
    _prefs?.setInt('${_p}woerterProTag', woerterProTag);
    _changed();
  }

  void setVorlesen(bool an) {
    vorlesen = an;
    _prefs?.setBool('${_p}vorlesen', an);
    _changed();
  }

  /// Trägt die Kanji gelesener Texte ein ([texte]: Text → seine Kanji).
  void gelesenAusTexten(Map<String, Iterable<String>> texte) {
    if (texte.isEmpty) return;
    for (final e in texte.entries) {
      gelesenAus.add(e.key);
      gelesen.addAll(e.value);
    }
    _prefs?.setString('${_p}gelesen', gelesen.join());
    _prefs?.setStringList('${_p}gelesenAus', gelesenAus.toList());
    _changed();
  }

  void stift() {
    if (stiftGesehen) return;
    stiftGesehen = true;
    _prefs?.setBool('${_p}stift', true);
    _changed();
  }
}
