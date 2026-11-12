import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:shared_preferences/shared_preferences.dart';

/// Furigana-Einstellung (Spezifikation 4.1).
enum FuriganaMode {
  /// Nur auf Antippen – Kanji oberhalb meiner Stufe haben trotzdem Furigana.
  aus('Nur auf Antippen'),

  /// Furigana für alle Wörter oberhalb meiner Stufe.
  ueberStufe('Über meiner Stufe'),

  /// Furigana überall.
  alle('Alle');

  const FuriganaMode(this.label);
  final String label;
}

/// Wie oft Kumachan erscheint (Spezifikation 13).
enum KumaMode {
  /// Startseite, nach dem Text und als Hinweis bei einer falschen Antwort.
  oft('Oft'),

  /// Nur nach dem Text.
  selten('Selten'),

  /// Nie.
  aus('Aus');

  const KumaMode(this.label);
  final String label;
}

/// Ergebnis eines gelesenen Textes.
class ReadRecord {
  const ReadRecord({
    required this.id,
    required this.day,
    required this.seconds,
    required this.chars,
    required this.correct,
    required this.total,
    required this.lookups,
    required this.rating,
    required this.usedAudio,
    this.wrong = const [],
    this.textStufe,
    this.words,
  });
  final String id;
  final DateTime day;
  final int seconds;
  final int chars;
  final int correct;
  final int total;
  final int lookups;

  /// -1 zu leicht, 0 passt, 1 zu schwer.
  final int rating;
  final bool usedAudio;

  /// Fragen (Index), die falsch beantwortet wurden – für den Wochentest.
  final List<int> wrong;

  /// Stufe des Textes, wie gespeichert (ältere Einträge haben keine).
  final int? textStufe;

  /// Stufe des Textes; ältere Einträge: aus der Kennung („…-2“).
  int? get stufe => textStufe ?? int.tryParse(RegExp(r'-(\d)$').firstMatch(id)?.group(1) ?? '');

  /// Inhaltswörter im Text (mit Bedeutung) – für den Anteil nachgeschlagener Wörter.
  final int? words;

  /// Anteil nachgeschlagener Wörter; ältere Einträge ohne Wortzahl: geschätzt.
  double get lookupShare => lookups / ((words ?? (chars / 3).round()).clamp(1, 1 << 20));

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day.toIso8601String().substring(0, 10),
    'seconds': seconds,
    'chars': chars,
    'correct': correct,
    'total': total,
    'lookups': lookups,
    'rating': rating,
    'audio': usedAudio,
    'wrong': wrong,
    if (textStufe != null) 'stufe': textStufe,
    if (words != null) 'words': words,
  };

  factory ReadRecord.fromJson(Map<String, dynamic> j) => ReadRecord(
    id: j['id'] as String,
    day: DateTime.parse(j['day'] as String),
    seconds: j['seconds'] as int,
    chars: j['chars'] as int,
    correct: j['correct'] as int,
    total: j['total'] as int,
    lookups: j['lookups'] as int,
    rating: j['rating'] as int,
    usedAudio: j['audio'] as bool? ?? false,
    wrong: [for (final w in (j['wrong'] as List? ?? const [])) (w as num).toInt()],
    textStufe: (j['stufe'] as num?)?.toInt(),
    words: (j['words'] as num?)?.toInt(),
  );
}

/// Ergebnis eines Wochentests: richtig/gesamt pro Bereich.
class WeeklyResult {
  const WeeklyResult({required this.weekStart, required this.sections});

  /// Montag der Woche.
  final DateTime weekStart;

  /// Bereich → (richtig, gesamt).
  final Map<String, (int, int)> sections;

  int get correct => sections.values.fold(0, (n, s) => n + s.$1);
  int get total => sections.values.fold(0, (n, s) => n + s.$2);

  Map<String, dynamic> toJson() => {
    'week': weekStart.toIso8601String().substring(0, 10),
    'sections': {for (final e in sections.entries) e.key: [e.value.$1, e.value.$2]},
  };

  factory WeeklyResult.fromJson(Map<String, dynamic> j) => WeeklyResult(
    weekStart: DateTime.parse(j['week'] as String),
    sections: {
      for (final e in (j['sections'] as Map<String, dynamic>).entries)
        e.key: (((e.value as List)[0] as num).toInt(), ((e.value as List)[1] as num).toInt()),
    },
  );
}

/// Ein Wort in „Meine Wörter“.
class MyWord {
  const MyWord({required this.t, required this.reading, required this.gloss, this.sentence, this.textId, this.added});
  final String t;
  final String reading;
  final String gloss;

  /// Der Satz, in dem ich das Wort gelesen habe.
  final String? sentence;
  final String? textId;

  /// Wann das Wort gespeichert wurde.
  final DateTime? added;

  String get key => '$t|$reading';

  MyWord withAdded(DateTime d) =>
      MyWord(t: t, reading: reading, gloss: gloss, sentence: sentence, textId: textId, added: added ?? d);

  Map<String, dynamic> toJson() => {
    't': t,
    'r': reading,
    'g': gloss,
    's': sentence,
    'text': textId,
    if (added != null) 'a': added!.toIso8601String().substring(0, 10),
  };

  factory MyWord.fromJson(Map<String, dynamic> j) => MyWord(
    t: j['t'] as String,
    reading: j['r'] as String,
    gloss: j['g'] as String,
    sentence: j['s'] as String?,
    textId: j['text'] as String?,
    added: j['a'] == null ? null : DateTime.parse(j['a'] as String),
  );
}

/// Ergebnis der Einstufung zu Beginn (Spezifikation 9.2).
class EinstufungErgebnis {
  const EinstufungErgebnis({
    required this.day,
    required this.wortschatz,
    required this.lesen,
    required this.vorschlag,
    required this.gewaehlt,
  });
  final DateTime day;

  /// Wortschatz als JLPT-Zahl (5 = N5 … 2 = N2), null = unter N5.
  final int? wortschatz;

  /// Lesen als Stufe (1–6).
  final int lesen;

  /// Vorgeschlagene und gewählte Startstufe.
  final int vorschlag;
  final int gewaehlt;

  Map<String, dynamic> toJson() => {
    'day': day.toIso8601String().substring(0, 10),
    'wortschatz': wortschatz,
    'lesen': lesen,
    'vorschlag': vorschlag,
    'gewaehlt': gewaehlt,
  };

  factory EinstufungErgebnis.fromJson(Map<String, dynamic> j) => EinstufungErgebnis(
    day: DateTime.parse(j['day'] as String),
    wortschatz: (j['wortschatz'] as num?)?.toInt(),
    lesen: (j['lesen'] as num).toInt(),
    vorschlag: (j['vorschlag'] as num).toInt(),
    gewaehlt: (j['gewaehlt'] as num).toInt(),
  );
}

/// Sicherung, die sich nicht lesen ließ.
class BackupError implements Exception {
  const BackupError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Was in einer Sicherungsdatei steckt (für die Rückfrage vor dem Zurückholen).
typedef BackupPreview = ({DateTime saved, int words, int reads});

/// Lernstand – nur auf diesem Gerät (Abgleich folgt, Spezifikation 17).
/// Alle Einträge beginnen mit „yomicha.“, weil sich alle Apps unter
/// thatlionfish.github.io denselben Speicher teilen.
class Progress extends ChangeNotifier {
  static const _p = 'yomicha.';
  SharedPreferences? _prefs;

  int stufe = 2;
  FuriganaMode furigana = FuriganaMode.aus;
  double rate = 1.0;
  KumaMode kuma = KumaMode.oft;
  final Map<String, MyWord> myWords = {};

  /// FSRS-Karten der Wörter (Wort-Schlüssel → Karte als Map).
  final Map<String, Map<String, dynamic>> _cards = {};

  /// Neue Karten heute (Datum, Anzahl) – höchstens 10 pro Tag.
  String _newDay = '';
  int _newCount = 0;

  /// Stufenverlauf (Datum, Stufe) für die Zielkurve – der erste Eintrag ist der Start.
  final List<(DateTime, int)> stufeHistory = [];

  /// Ergebnisse der Wochentests, älteste zuerst.
  final List<WeeklyResult> weeklyResults = [];

  /// Azure für das Nachsprechen – nur auf diesem Gerät gespeichert.
  String azureKey = '';
  String azureRegion = 'switzerlandnorth';
  final Map<String, int> _speechSeconds = {};
  final Map<String, String> stories = {};
  final List<ReadRecord> reads = [];

  /// Wann ich den Lernstand zuletzt als Datei gesichert habe.
  DateTime? lastBackup;

  /// Ergebnis der Einstufung zu Beginn; null = noch nicht gemacht.
  EinstufungErgebnis? einstufung;

  /// Nach „Noch nicht“ beim Stufenvorschlag: (Stufe, gelesene Texte damals).
  (int, int)? vorschlagPause;

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    lastBackup = DateTime.tryParse(p.getString('${_p}lastBackup') ?? '');
    final e = p.getString('${_p}einstufung');
    einstufung = e == null ? null : EinstufungErgebnis.fromJson(jsonDecode(e) as Map<String, dynamic>);
    final pause = p.getString('${_p}vorschlagPause')?.split(':');
    vorschlagPause = pause == null || pause.length != 2 ? null : (int.parse(pause[0]), int.parse(pause[1]));
    stufe = p.getInt('${_p}stufe') ?? 2;
    furigana = FuriganaMode.values.asNameMap()[p.getString('${_p}furigana')] ?? FuriganaMode.aus;
    rate = p.getDouble('${_p}rate') ?? 1.0;
    kuma = KumaMode.values.asNameMap()[p.getString('${_p}kuma')] ?? KumaMode.oft;
    for (final s in p.getStringList('${_p}words') ?? const <String>[]) {
      final w = MyWord.fromJson(jsonDecode(s) as Map<String, dynamic>);
      myWords[w.key] = w;
    }
    final st = p.getString('${_p}stories');
    if (st != null) {
      stories.addAll((jsonDecode(st) as Map<String, dynamic>).cast<String, String>());
    }
    for (final s in p.getStringList('${_p}reads') ?? const <String>[]) {
      reads.add(ReadRecord.fromJson(jsonDecode(s) as Map<String, dynamic>));
    }
    final cards = p.getString('${_p}cards');
    if (cards != null) {
      for (final e in (jsonDecode(cards) as Map<String, dynamic>).entries) {
        _cards[e.key] = (e.value as Map).cast<String, dynamic>();
      }
    }
    _newDay = p.getString('${_p}newDay') ?? '';
    _newCount = p.getInt('${_p}newCount') ?? 0;
    azureKey = p.getString('${_p}azureKey') ?? '';
    azureRegion = p.getString('${_p}azureRegion') ?? 'switzerlandnorth';
    for (final s in p.getStringList('${_p}stufeHistory') ?? const <String>[]) {
      final [d, n] = s.split('=');
      stufeHistory.add((DateTime.parse(d), int.parse(n)));
    }
    if (stufeHistory.isEmpty) _recordStufe(DateTime.now(), stufe);
    for (final s in p.getStringList('${_p}weekly') ?? const <String>[]) {
      weeklyResults.add(WeeklyResult.fromJson(jsonDecode(s) as Map<String, dynamic>));
    }
    final speech = p.getString('${_p}speechSeconds');
    if (speech != null) {
      _speechSeconds.addAll((jsonDecode(speech) as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt())));
    }
    notifyListeners();
  }

  // --- Wiederholung (FSRS) -------------------------------------------------

  /// Karte eines Wortes; neue Wörter bekommen eine neue Karte.
  fsrs.Card cardFor(String key) {
    final m = _cards[key];
    if (m == null) return fsrs.Card(cardId: key.hashCode & 0x7fffffff);
    // Im Browser werden ganze Zahlen ohne „.0“ gespeichert – zurück zu double.
    return fsrs.Card.fromMap({
      ...m,
      'stability': (m['stability'] as num?)?.toDouble(),
      'difficulty': (m['difficulty'] as num?)?.toDouble(),
    });
  }

  bool isNewCard(String key) => _cards[key] == null;

  void saveCard(String key, fsrs.Card card, DateTime now) {
    if (_cards[key] == null) {
      final day = _dayKey(now);
      if (_newDay != day) {
        _newDay = day;
        _newCount = 0;
      }
      _newCount++;
      _prefs?.setString('${_p}newDay', _newDay);
      _prefs?.setInt('${_p}newCount', _newCount);
    }
    _cards[key] = card.toMap();
    _prefs?.setString('${_p}cards', jsonEncode(_cards));
    notifyListeners();
  }

  /// Wie viele neue Wörter heute schon dran waren.
  int newCardsOn(DateTime day) => _newDay == _dayKey(day) ? _newCount : 0;

  static String _dayKey(DateTime d) => d.toIso8601String().substring(0, 10);

  void removeWord(String key) {
    myWords.remove(key);
    _cards.remove(key);
    _saveWords();
    _prefs?.setString('${_p}cards', jsonEncode(_cards));
    notifyListeners();
  }

  // --- Nachsprechen ---------------------------------------------------------

  void setAzure(String key, String region) {
    azureKey = key.trim();
    azureRegion = region.trim().isEmpty ? 'switzerlandnorth' : region.trim();
    _prefs?.setString('${_p}azureKey', azureKey);
    _prefs?.setString('${_p}azureRegion', azureRegion);
    notifyListeners();
  }

  /// Aufgenommene Sekunden in diesem Monat (Gratis-Kontingent: 5 Stunden).
  int speechSecondsThisMonth(DateTime now) => _speechSeconds[now.toIso8601String().substring(0, 7)] ?? 0;

  void addSpeechSeconds(int seconds, DateTime now) {
    final month = now.toIso8601String().substring(0, 7);
    _speechSeconds[month] = (_speechSeconds[month] ?? 0) + seconds;
    _prefs?.setString('${_p}speechSeconds', jsonEncode(_speechSeconds));
    notifyListeners();
  }

  Set<DateTime> get readDays => {for (final r in reads) r.day};

  void setStufe(int s) {
    stufe = s;
    _prefs?.setInt('${_p}stufe', s);
    _recordStufe(DateTime.now(), s);
    notifyListeners();
  }

  /// Seit wann ich auf meiner jetzigen Stufe bin.
  DateTime get stufeSince => stufeHistory.isEmpty ? DateTime(2000) : stufeHistory.last.$1;

  void setEinstufung(EinstufungErgebnis e) {
    einstufung = e;
    _prefs?.setString('${_p}einstufung', jsonEncode(e.toJson()));
    setStufe(e.gewaehlt);
  }

  /// „Noch nicht“: Die App fragt erst nach ein paar weiteren Texten wieder.
  void pauseVorschlag(int stufe, int readsSoFar) {
    vorschlagPause = (stufe, readsSoFar);
    _prefs?.setString('${_p}vorschlagPause', '$stufe:$readsSoFar');
    notifyListeners();
  }

  void _recordStufe(DateTime now, int s) {
    final day = DateTime(now.year, now.month, now.day);
    if (stufeHistory.isNotEmpty && stufeHistory.last.$2 == s) return;
    if (stufeHistory.isNotEmpty && stufeHistory.last.$1 == day) {
      // Mehrere Wechsel am selben Tag: nur der letzte zählt.
      stufeHistory[stufeHistory.length - 1] = (day, s);
    } else {
      stufeHistory.add((day, s));
    }
    _prefs?.setStringList('${_p}stufeHistory', [
      for (final (d, n) in stufeHistory) '${_dayKey(d)}=$n',
    ]);
  }

  void setFurigana(FuriganaMode m) {
    furigana = m;
    _prefs?.setString('${_p}furigana', m.name);
    notifyListeners();
  }

  void setKuma(KumaMode m) {
    kuma = m;
    _prefs?.setString('${_p}kuma', m.name);
    notifyListeners();
  }

  void setRate(double r) {
    rate = r;
    _prefs?.setDouble('${_p}rate', r);
    notifyListeners();
  }

  bool hasWord(String key) => myWords.containsKey(key);

  void toggleWord(MyWord w) {
    if (myWords.containsKey(w.key)) {
      removeWord(w.key);
      return;
    }
    myWords[w.key] = w.withAdded(DateTime.now());
    _saveWords();
    notifyListeners();
  }

  void addWords(Iterable<MyWord> words) {
    final now = DateTime.now();
    for (final w in words) {
      myWords.putIfAbsent(w.key, () => w.withAdded(now));
    }
    _saveWords();
    notifyListeners();
  }

  /// Ergebnis des Wochentests (pro Woche nur das letzte).
  WeeklyResult? weeklyFor(DateTime weekStart) {
    for (final r in weeklyResults.reversed) {
      if (r.weekStart == weekStart) return r;
    }
    return null;
  }

  void addWeekly(WeeklyResult r) {
    weeklyResults.removeWhere((x) => x.weekStart == r.weekStart);
    weeklyResults.add(r);
    _prefs?.setStringList('${_p}weekly', [for (final x in weeklyResults) jsonEncode(x.toJson())]);
    notifyListeners();
  }

  void _saveWords() => _prefs?.setStringList(
    '${_p}words',
    [for (final w in myWords.values) jsonEncode(w.toJson())],
  );

  void setStory(String kanji, String story) {
    if (story.trim().isEmpty) {
      stories.remove(kanji);
    } else {
      stories[kanji] = story;
    }
    _prefs?.setString('${_p}stories', jsonEncode(stories));
    notifyListeners();
  }

  // --- Sicherung (Spezifikation 17) ----------------------------------------

  /// Bleibt auf dem Gerät: der Azure-Schlüssel gehört nicht in eine Datei.
  static const _notInBackup = {'azureKey', 'azureRegion', 'lastBackup'};

  bool _inBackup(String prefKey) =>
      prefKey.startsWith(_p) && !_notInBackup.contains(prefKey.substring(_p.length));

  /// Der ganze Lernstand als JSON: Wörter, Karten, gelesene Texte, Stufe,
  /// Wochentests, Einstellungen – ohne Azure-Schlüssel.
  String backupJson(DateTime now) {
    final p = _prefs!;
    return const JsonEncoder.withIndent(' ').convert({
      'app': 'yomicha',
      'version': 1,
      'saved': now.toIso8601String(),
      'data': {
        for (final k in p.getKeys().toList()..sort())
          if (_inBackup(k)) k.substring(_p.length): p.get(k),
      },
    });
  }

  void markBackedUp(DateTime now) {
    lastBackup = now;
    _prefs?.setString('${_p}lastBackup', now.toIso8601String());
    notifyListeners();
  }

  static Map<String, dynamic> _parseBackup(String json) {
    const wrong = BackupError('Das ist keine Sicherung von Yomicha.');
    final Object? root;
    try {
      root = jsonDecode(json);
    } on FormatException {
      throw wrong;
    }
    if (root is! Map<String, dynamic> || root['app'] != 'yomicha' || root['data'] is! Map<String, dynamic>) {
      throw wrong;
    }
    return root;
  }

  /// Was die Sicherung enthält, ohne etwas zu ändern.
  static BackupPreview previewBackup(String json) {
    final root = _parseBackup(json);
    final data = root['data'] as Map<String, dynamic>;
    return (
      saved: DateTime.tryParse(root['saved'] as String? ?? '') ?? DateTime(2000),
      words: (data['words'] as List?)?.length ?? 0,
      reads: (data['reads'] as List?)?.length ?? 0,
    );
  }

  /// Ersetzt den Lernstand auf diesem Gerät durch die Sicherung. Der
  /// Azure-Schlüssel auf dem Gerät bleibt.
  Future<void> restoreBackup(String json) async {
    final data = _parseBackup(json)['data'] as Map<String, dynamic>;
    final p = _prefs!;
    for (final k in p.getKeys().toList()) {
      if (_inBackup(k)) await p.remove(k);
    }
    for (final MapEntry(:key, :value) in data.entries) {
      if (_notInBackup.contains(key)) continue;
      final k = '$_p$key';
      switch (value) {
        case final bool v:
          await p.setBool(k, v);
        case final int v:
          await p.setInt(k, v);
        case final double v:
          await p.setDouble(k, v);
        case final String v:
          await p.setString(k, v);
        case final List<dynamic> v:
          await p.setStringList(k, [for (final x in v) '$x']);
      }
    }
    myWords.clear();
    _cards.clear();
    _newDay = '';
    _newCount = 0;
    stufeHistory.clear();
    weeklyResults.clear();
    _speechSeconds.clear();
    stories.clear();
    reads.clear();
    await load();
  }

  /// Speichert einen gelesenen Text. Er zählt schon nach „Fertig“ (ohne
  /// Fragen, `total` 0); das Ergebnis der Fragen ersetzt diesen Eintrag.
  /// Derselbe Text am selben Tag steht nur einmal da, und ein späteres
  /// „Fertig“ ohne Fragen löscht keine Antworten.
  void addRead(ReadRecord r) {
    final i = reads.indexWhere((x) => x.id == r.id && x.day == r.day);
    if (i >= 0) {
      if (r.total == 0 && reads[i].total > 0) return;
      reads[i] = r;
    } else {
      reads.add(r);
    }
    _prefs?.setStringList('${_p}reads', [for (final x in reads) jsonEncode(x.toJson())]);
    notifyListeners();
  }
}
