import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  );
}

/// Ein Wort in „Meine Wörter“.
class MyWord {
  const MyWord({required this.t, required this.reading, required this.gloss, this.sentence, this.textId});
  final String t;
  final String reading;
  final String gloss;

  /// Der Satz, in dem ich das Wort gelesen habe.
  final String? sentence;
  final String? textId;

  String get key => '$t|$reading';

  Map<String, dynamic> toJson() => {'t': t, 'r': reading, 'g': gloss, 's': sentence, 'text': textId};

  factory MyWord.fromJson(Map<String, dynamic> j) => MyWord(
    t: j['t'] as String,
    reading: j['r'] as String,
    gloss: j['g'] as String,
    sentence: j['s'] as String?,
    textId: j['text'] as String?,
  );
}

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
  final Map<String, String> stories = {};
  final List<ReadRecord> reads = [];

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
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
    notifyListeners();
  }

  Set<DateTime> get readDays => {for (final r in reads) r.day};

  void setStufe(int s) {
    stufe = s;
    _prefs?.setInt('${_p}stufe', s);
    notifyListeners();
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
    if (myWords.remove(w.key) == null) myWords[w.key] = w;
    _saveWords();
    notifyListeners();
  }

  void addWords(Iterable<MyWord> words) {
    for (final w in words) {
      myWords[w.key] = w;
    }
    _saveWords();
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

  void addRead(ReadRecord r) {
    reads.add(r);
    _prefs?.setStringList('${_p}reads', [for (final x in reads) jsonEncode(x.toJson())]);
    notifyListeners();
  }
}
