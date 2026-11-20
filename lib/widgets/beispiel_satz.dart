import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/schreib_plan.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import 'furigana.dart';

/// Beispielsatz zu einem Wort aus „Kanji schreiben“ mit Furigana; das Wort ist
/// unterstrichen. Beim Schreiben aus dem Kopf und bei der Lesungsfrage steht
/// statt des Wortes eine Lücke, und seine Kanji sind auch sonst im Satz verdeckt.
class BeispielSatz extends StatelessWidget {
  const BeispielSatz({super.key, required this.beispiel, required this.wort, this.luecke = false, this.fontSize = 19});
  final Beispiel beispiel;
  final String wort;
  final bool luecke;
  final double fontSize;

  static const _ziel = 'ziel';

  List<Token> _tokens() {
    final verdeckt = {for (final k in kanjiOf(wort)) if (k != '々') k};
    final out = <Token>[];
    var imZiel = false;
    var lueckeGesetzt = false;
    for (final t in parseRuby(beispiel.ruby)) {
      if (t.t == '[') {
        imZiel = true;
        continue;
      }
      if (t.t == ']') {
        imZiel = false;
        continue;
      }
      if (imZiel && luecke) {
        if (!lueckeGesetzt) out.add(const Token(t: '＿＿'));
        lueckeGesetzt = true;
        continue;
      }
      if (imZiel) {
        out.add(Token(t: t.t, r: t.r, grammar: _ziel));
      } else if (luecke && t.t.split('').any(verdeckt.contains)) {
        // Anderswo im Satz steht ein Kanji des Wortes: verdecken, ohne Lesung.
        out.add(Token(t: t.t.split('').map((c) => verdeckt.contains(c) ? '〇' : c).join()));
      } else {
        out.add(t);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      FuriganaFlow(
        sentences: [(0, _tokens())],
        fontSize: fontSize,
        grammarHighlight: luecke ? null : _ziel,
        color: luecke ? YoColors.inkSoft : null,
        alignment: WrapAlignment.center,
      ),
      if (!luecke) ...[
        const SizedBox(height: 4),
        Text(beispiel.de, style: sans(15, color: YoColors.inkSoft), textAlign: TextAlign.center),
      ],
    ],
  );
}
