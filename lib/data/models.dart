/// Datenformat der Texte, wie es die Teeküche schreibt (Spezifikation 11, 17).
library;

final _kanjiRe = RegExp(r'[㐀-䶿一-鿿豈-﫿々]');
final _punctRe = RegExp(r'^[、。！？「」『』（）・…,.!?\s]+$');

bool isKanji(String ch) => _kanjiRe.hasMatch(ch);

/// Ein Teil eines Wortes mit seiner Lesung; bei Kana ist die Lesung leer.
class RubySeg {
  const RubySeg(this.base, this.reading);
  final String base;
  final String reading;

  bool get hasRuby => reading.isNotEmpty;
}

/// Ein Wort (bzw. ein Wort mit seinen Endungen) im Text.
class Token {
  const Token({
    required this.t,
    this.r,
    this.ruby,
    this.base,
    this.jlpt,
    this.gloss,
    this.grammar,
    this.say,
    this.audio,
  });

  /// Schreibung im Text.
  final String t;

  /// Lesung des ganzen Wortes in Hiragana.
  final String? r;

  /// Lesung verteilt auf die Kanji, z. B. [[飲, の], [みます, ""]].
  final List<RubySeg>? ruby;

  /// Grundform, wenn das Wort gebeugt ist (飲みます → 飲む).
  final String? base;

  /// JLPT-Stufe des Wortes: 5 (N5) … 1 (N1); null = nicht in den Listen.
  final int? jlpt;

  /// Deutsche Bedeutung, passend zu diesem Satz.
  final String? gloss;

  /// ID eines Grammatikmusters, zu dem das Wort gehört.
  final String? grammar;

  /// Feste Lesung für die Stimme, falls sie das Kanji sonst falsch liest.
  final String? say;

  /// Eigene Aufnahme des Wortes (Pfad unter data/).
  final String? audio;

  bool get hasKanji => _kanjiRe.hasMatch(t);
  bool get isPunct => _punctRe.hasMatch(t);

  /// Kann man das Wort antippen?
  bool get isWord => gloss != null || r != null;

  /// Die Kanji des Wortes, ohne Wiederholungen.
  List<String> get kanji => [
    for (final ch in t.split('').toSet())
      if (isKanji(ch)) ch,
  ];

  /// Lesung für die Wortleiste: aus [r] oder aus den Teilen.
  String get reading =>
      r ??
      (ruby == null
          ? t
          : ruby!.map((s) => s.hasRuby ? s.reading : s.base).join());

  /// Teile mit Furigana. Ohne [ruby] bekommt das ganze Wort die Lesung.
  List<RubySeg> get segments {
    if (ruby != null) return ruby!;
    if (r != null && hasKanji) return [RubySeg(t, r!)];
    return [RubySeg(t, '')];
  }

  factory Token.fromJson(Map<String, dynamic> j) => Token(
    t: j['t'] as String,
    r: j['r'] as String?,
    ruby: (j['ruby'] as List?)
        ?.map((s) => RubySeg((s as List)[0] as String, s[1] as String))
        .toList(),
    base: j['b'] as String?,
    jlpt: j['j'] as int?,
    gloss: j['g'] as String?,
    grammar: j['gr'] as String?,
    say: j['say'] as String?,
    audio: j['audio'] as String?,
  );
}

class Sentence {
  const Sentence({required this.tokens, this.newParagraph = false, this.audio});
  final List<Token> tokens;

  /// Beginnt mit diesem Satz ein neuer Absatz?
  final bool newParagraph;

  /// Aufnahme dieses Satzes (Dateiname im Ordner des Textes).
  final String? audio;

  String get plain => tokens.map((t) => t.t).join();

  factory Sentence.fromJson(Map<String, dynamic> j) => Sentence(
    tokens: [
      for (final t in j['tokens'] as List) Token.fromJson(t as Map<String, dynamic>),
    ],
    newParagraph: j['p'] as bool? ?? false,
    audio: j['audio'] as String?,
  );
}

class GrammarPoint {
  const GrammarPoint({
    required this.id,
    required this.pattern,
    required this.jlpt,
    required this.de,
    this.example,
    this.exampleDe,
  });
  final String id;
  final String pattern;
  final int jlpt;
  final String de;

  /// Beispielsatz in Ruby-Schreibweise ({漢字|かんじ}).
  final String? example;
  final String? exampleDe;

  factory GrammarPoint.fromJson(Map<String, dynamic> j) => GrammarPoint(
    id: j['id'] as String,
    pattern: j['pattern'] as String,
    jlpt: j['j'] as int,
    de: j['de'] as String,
    example: j['ex'] as String?,
    exampleDe: j['exDe'] as String?,
  );
}

class Question {
  const Question({
    required this.kind,
    required this.q,
    required this.options,
    required this.answer,
    required this.explain,
    this.qDe,
    this.evidence = const [],
  });

  /// „inhalt“ oder „sprache“.
  final String kind;

  /// Frage und Antworten in Ruby-Schreibweise ({漢字|かんじ}).
  final String q;
  final String? qDe;
  final List<String> options;

  /// Index der richtigen Antwort.
  final int answer;

  /// Erklärung auf Deutsch.
  final String explain;

  /// Sätze (Index), in denen die Antwort steht.
  final List<int> evidence;

  factory Question.fromJson(Map<String, dynamic> j) => Question(
    kind: j['kind'] as String,
    q: j['q'] as String,
    qDe: j['qDe'] as String?,
    options: [for (final o in j['options'] as List) o as String],
    answer: j['answer'] as int,
    explain: j['explain'] as String,
    evidence: [for (final e in (j['evidence'] as List? ?? const [])) e as int],
  );
}

class Source {
  const Source(this.name, this.url);
  final String name;
  final String url;
}

/// Ein Text in einer Stufe.
class TextDoc {
  const TextDoc({
    required this.id,
    required this.folder,
    required this.date,
    required this.topic,
    required this.type,
    required this.stufe,
    required this.title,
    required this.titleDe,
    required this.sentences,
    required this.grammar,
    required this.questions,
    this.sources = const [],
    this.versions = const {},
  });

  final String id;

  /// Ordner unter data/, z. B. texte/2026/11/2026-11-12-hojicha-2.
  final String folder;
  final DateTime date;
  final String topic;
  final String type;
  final int stufe;
  final List<Token> title;
  final String titleDe;
  final List<Sentence> sentences;
  final Map<String, GrammarPoint> grammar;
  final List<Question> questions;
  final List<Source> sources;

  /// Derselbe Inhalt in anderen Stufen: Stufe → Ordner.
  final Map<int, String> versions;

  int get chars => sentences.fold(0, (n, s) => n + s.plain.length);

  /// Absätze als Listen von Satz-Indizes.
  List<List<int>> get paragraphs {
    final out = <List<int>>[];
    for (var i = 0; i < sentences.length; i++) {
      if (out.isEmpty || sentences[i].newParagraph) out.add([]);
      out.last.add(i);
    }
    return out;
  }

  factory TextDoc.fromJson(Map<String, dynamic> j, {required String folder}) =>
      TextDoc(
        id: j['id'] as String,
        folder: folder,
        date: DateTime.parse(j['date'] as String),
        topic: j['topic'] as String,
        type: j['type'] as String,
        stufe: j['stufe'] as int,
        title: [
          for (final t in j['title'] as List) Token.fromJson(t as Map<String, dynamic>),
        ],
        titleDe: j['titleDe'] as String,
        sentences: [
          for (final s in j['sentences'] as List)
            Sentence.fromJson(s as Map<String, dynamic>),
        ],
        grammar: {
          for (final g in (j['grammar'] as List? ?? const []))
            (g as Map<String, dynamic>)['id'] as String: GrammarPoint.fromJson(g),
        },
        questions: [
          for (final q in (j['questions'] as List? ?? const []))
            Question.fromJson(q as Map<String, dynamic>),
        ],
        sources: [
          for (final s in (j['sources'] as List? ?? const []))
            Source((s as Map)['name'] as String, s['url'] as String),
        ],
        versions: {
          for (final e in ((j['versions'] as Map?) ?? const {}).entries)
            int.parse(e.key as String): e.value as String,
        },
      );
}

/// Eintrag im Verzeichnis aller Texte (data/texte/index.json).
class TextEntry {
  const TextEntry({
    required this.id,
    required this.folder,
    required this.date,
    required this.topic,
    required this.stufe,
    required this.title,
    required this.titleDe,
    required this.minutes,
  });
  final String id;
  final String folder;
  final DateTime date;
  final String topic;
  final int stufe;
  final String title;
  final String titleDe;
  final int minutes;

  factory TextEntry.fromJson(Map<String, dynamic> j) => TextEntry(
    id: j['id'] as String,
    folder: j['folder'] as String,
    date: DateTime.parse(j['date'] as String),
    topic: j['topic'] as String,
    stufe: j['stufe'] as int,
    title: j['title'] as String,
    titleDe: j['titleDe'] as String,
    minutes: j['minutes'] as int,
  );
}

/// Kanji-Karte (Spezifikation 5), gebaut aus KanjiVG und KANJIDIC2.
class KanjiInfo {
  const KanjiInfo({
    required this.kanji,
    required this.keyword,
    required this.strokes,
    this.de,
    this.meanings = const [],
    this.on = const [],
    this.kun = const [],
    this.jlpt,
    this.heisig,
    this.parts = const [],
    this.paths = const [],
    this.story,
  });
  final String kanji;

  /// Eigenes englisches Schlüsselwort (nicht Heisigs).
  final String keyword;
  final int strokes;

  /// Deutsche Bedeutung (eigene Ergänzung).
  final String? de;

  /// Englische Bedeutungen aus KANJIDIC2.
  final List<String> meanings;
  final List<String> on;
  final List<String> kun;

  /// JLPT-Stufe: 5 (N5) … 1 (N1).
  final int? jlpt;

  /// Nummer in Heisigs Remembering the Kanji (6. Auflage), aus KANJIDIC2.
  final int? heisig;

  /// Bestandteile (erste Ebene der Zerlegung, aus KanjiVG).
  final List<String> parts;

  /// Striche in der richtigen Reihenfolge (SVG-Pfade, Feld 109 × 109).
  final List<String> paths;

  /// Vorschlag für eine Merkgeschichte (Englisch).
  final String? story;

  factory KanjiInfo.fromJson(String k, Map<String, dynamic> j) => KanjiInfo(
    kanji: k,
    keyword: j['keyword'] as String? ?? '',
    strokes: j['strokes'] as int? ?? 0,
    de: j['de'] as String?,
    meanings: _strings(j['meanings']),
    on: _strings(j['on']),
    kun: _strings(j['kun']),
    jlpt: j['j'] as int?,
    heisig: j['heisig'] as int?,
    parts: _strings(j['parts']),
    paths: _strings(j['paths']),
    story: j['story'] as String?,
  );
}

/// Ein Spruch von Kumachan.
class KumaLine {
  const KumaLine(this.ja, this.de);

  /// Japanisch in Ruby-Schreibweise.
  final String ja;
  final String de;
}

/// Eine Stimmung von Kumachan: passende Posen und Sprüche.
class KumaMood {
  const KumaMood(this.poses, this.lines);
  final List<String> poses;
  final List<KumaLine> lines;

  factory KumaMood.fromJson(Map<String, dynamic> j) => KumaMood(
    _strings(j['posen']),
    [
      for (final l in (j['sprueche'] as List).cast<Map<String, dynamic>>())
        KumaLine(l['ja'] as String, l['de'] as String),
    ],
  );
}

List<String> _strings(Object? list) => [for (final s in (list as List? ?? const [])) s as String];

/// Datei der Kanji-Karte: gebündelt nach Codepunkt (U+xx00–U+xxFF).
String kanjiBucket(String kanji) => (kanji.runes.first >> 8).toRadixString(16);
