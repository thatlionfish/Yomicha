import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/progress.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';

/// Wann ein Wort Furigana bekommt (Spezifikation 4.1 und 9.1).
class FuriganaRules {
  const FuriganaRules({
    required this.mode,
    required this.userJlpt,
    this.kanjiLevels = const {},
  });

  final FuriganaMode mode;

  /// JLPT-Zahl meiner Stufe: 4 = N4.
  final int userJlpt;

  /// JLPT-Stufe einzelner Kanji (aus den Kanji-Daten).
  final Map<String, int?> kanjiLevels;

  bool show(Token t, {bool revealed = false}) {
    if (!t.hasKanji) return false;
    if (revealed || mode == FuriganaMode.alle) return true;
    // Kanji oberhalb meiner Stufe haben in jeder Einstellung Furigana.
    for (final k in t.kanji) {
      final level = kanjiLevels[k];
      if (level == null || level < userJlpt) return true;
    }
    if (mode == FuriganaMode.ueberStufe) {
      final j = t.jlpt;
      return j == null || j < userJlpt;
    }
    return false;
  }
}

const _closing = '、。，．！？」』）〕］】…ー・,.!?';
const _opening = '「『（〔［【';

/// Fasst Wörter zu Einheiten zusammen, die nicht umbrechen dürfen:
/// Satzzeichen hängen am Wort davor, öffnende Klammern am Wort danach.
List<List<int>> groupUnits(List<Token> tokens) {
  final units = <List<int>>[];
  List<int>? pendingOpen;
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i].t;
    final closing = t.isNotEmpty && t.split('').every(_closing.contains);
    final opening = t.isNotEmpty && t.split('').every(_opening.contains);
    if (closing && units.isNotEmpty && pendingOpen == null) {
      units.last.add(i);
    } else if (opening) {
      (pendingOpen ??= []).add(i);
    } else {
      units.add([...?pendingOpen, i]);
      pendingOpen = null;
    }
  }
  if (pendingOpen != null) units.add(pendingOpen);
  return units;
}

/// Liest Ruby-Schreibweise: „{静岡|しずおか}は…“. Text außerhalb der
/// Klammern wird Zeichen für Zeichen zerlegt, damit er überall umbrechen kann.
List<Token> parseRuby(String s) {
  final re = RegExp(r'\{([^|{}]+)\|([^{}]+)\}');
  final out = <Token>[];
  var last = 0;
  void plain(String text) {
    for (final ch in text.split('')) {
      out.add(Token(t: ch));
    }
  }

  for (final m in re.allMatches(s)) {
    plain(s.substring(last, m.start));
    out.add(Token(t: m.group(1)!, r: m.group(2)!));
    last = m.end;
  }
  plain(s.substring(last));
  return out;
}

/// Eine Stelle im Text: Satz und Wort.
typedef WordRef = ({int sentence, int token});

/// Japanischer Text mit Furigana, Wort für Wort antippbar.
class FuriganaFlow extends StatelessWidget {
  const FuriganaFlow({
    super.key,
    required this.sentences,
    required this.fontSize,
    this.rules,
    this.revealed = const {},
    this.currentSentence,
    this.markedSentences = const {},
    this.selected,
    this.grammarHighlight,
    this.onTap,
    this.color,
  });

  /// (Satz-Index, Wörter) – mehrere Sätze ergeben einen Absatz.
  final List<(int, List<Token>)> sentences;
  final double fontSize;

  /// null = Furigana genau so, wie sie in den Daten stehen (Fragen).
  final FuriganaRules? rules;

  /// Wörter, deren Furigana ich aufgedeckt habe.
  final Set<WordRef> revealed;

  /// Satz, der gerade vorgelesen wird.
  final int? currentSentence;

  /// Sätze, die hervorgehoben werden (z. B. die Textstelle zur Antwort).
  final Set<int> markedSentences;
  final WordRef? selected;

  /// Wörter dieses Grammatikmusters sind unterstrichen.
  final String? grammarHighlight;
  final void Function(WordRef ref, Token token)? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final (s, tokens) in sentences) {
      for (final unit in groupUnits(tokens)) {
        children.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [for (final i in unit) _word(context, s, i, tokens[i])],
          ),
        );
      }
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: fontSize * 0.22,
      children: children,
    );
  }

  static double _width(String s, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  Widget _word(BuildContext context, int s, int i, Token t) {
    final ref = (sentence: s, token: i);
    final showRuby = rules == null ? t.hasKanji && t.r != null : rules!.show(t, revealed: revealed.contains(ref));
    final isCurrent = currentSentence == s;
    final isMarked = markedSentences.contains(s);
    final isSelected = selected == ref;
    final inGrammar = grammarHighlight != null && t.grammar == grammarHighlight;
    final rubySize = fontSize * 0.5;
    final base = jp(fontSize, color: color);
    final ruby = jp(rubySize, color: YoColors.inkSoft, height: 1.0);

    final underline = isSelected
        ? YoColors.chocolate
        : inGrammar || (t.grammar != null && grammarHighlight == null && onTap != null)
        ? YoColors.woodAsh
        : null;

    // Markierung und Unterstreichung nur hinter der Schrift, nicht hinter den Furigana.
    final decoration = BoxDecoration(
      color: isCurrent || isMarked
          ? YoColors.sand
          : isSelected
          ? YoColors.vanillaIce
          : null,
      border: underline == null
          ? null
          : Border(bottom: BorderSide(color: underline, width: isSelected ? 2 : 1.5)),
    );

    final Widget box = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final seg in t.segments)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: rubySize * 1.2,
                child: showRuby && seg.hasRuby ? _ruby(seg, base, ruby) : null,
              ),
              Container(
                padding: const EdgeInsets.only(bottom: 1),
                decoration: decoration,
                child: Text(seg.base, style: base, maxLines: 1, softWrap: false),
              ),
            ],
          ),
      ],
    );

    if (onTap == null || !t.isWord) return box;
    return _tappable(ref, t, box);
  }

  /// Furigana, die breiter als das Kanji sind, werden zusammengedrückt,
  /// damit das Wort im Satz nicht auseinanderfällt.
  Widget _ruby(RubySeg seg, TextStyle base, TextStyle ruby) {
    final text = Text(seg.reading, style: ruby, maxLines: 1, softWrap: false);
    final maxWidth = _width(seg.base, base) + fontSize * 0.3;
    if (_width(seg.reading, ruby) <= maxWidth) return Align(alignment: Alignment.bottomCenter, child: text);
    return SizedBox(
      width: maxWidth,
      child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomCenter, child: text),
    );
  }

  Widget _tappable(WordRef ref, Token t, Widget box) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap!(ref, t),
        child: box,
      ),
    );
  }
}

/// Kurzer japanischer Text in Ruby-Schreibweise, z. B. Fragen und Antworten.
class RubyText extends StatelessWidget {
  const RubyText(this.markup, {super.key, this.fontSize = 18, this.color});
  final String markup;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) => FuriganaFlow(
    sentences: [(0, parseRuby(markup))],
    fontSize: fontSize,
    color: color,
  );
}
