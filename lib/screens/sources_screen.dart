import 'package:flutter/material.dart';

import '../ui/colors.dart';
import '../ui/theme.dart';

/// Quellen und Lizenzen (Spezifikation 15). Die Angaben für KanjiVG und
/// KANJIDIC2 sind von deren Lizenzen vorgeschrieben.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  static const _sections = [
    (
      'Texte und Aufnahmen',
      'Eigene Texte, geschrieben mit Claude, unter CC BY-SA 4.0. Die Stimmen stammen von '
          'Microsoft Azure AI Speech (Nanami, Kumachan: Aoi). Bei Nachrichten stehen die Quellen unter dem Text.',
    ),
    (
      'KanjiVG',
      'Zerlegung und Strichfolge der Kanji. Copyright © 2009–2026 Ulrich Apel, '
          'kanjivg.tagaini.net, Lizenz CC BY-SA 3.0.',
    ),
    (
      'KANJIDIC2',
      'This publication has included material from the KANJIDIC2 dictionary file. This file is the '
          'property of the Electronic Dictionary Research and Development Group, and is used in conformance '
          'with the Group\'s licence (CC BY-SA 4.0).',
    ),
    (
      'JLPT-Stufen',
      'Nach den JLPT-Listen von Jonathan Waller, über open-anki-jlpt-decks (Wörter) und kanji-data '
          '(Kanji), beide MIT. Offizielle JLPT-Listen gibt es seit 2010 nicht; die Stufen sind Näherungen.',
    ),
    (
      'Heisig',
      'Die Heisig-Nummern verweisen auf James W. Heisig, Remembering the Kanji (6. Auflage). '
          'Schlüsselwörter und Geschichten in Yomicha sind eigene, nicht die aus dem Buch.',
    ),
    (
      'Schriften',
      'Zen Old Mincho, Klee One, Fraunces und Nunito – alle unter der SIL Open Font License 1.1.',
    ),
    (
      'Wortzerlegung',
      'Sudachi (Apache 2.0) prüft in der Teeküche die Lesungen. Es läuft nicht in der App.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quellen und Lizenzen')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            for (final (title, text) in _sections) ...[
              Text(title, style: sans(16, weight: 650)),
              const SizedBox(height: 4),
              Text(text, style: sans(15, height: 1.5)),
              const SizedBox(height: 18),
            ],
            Text(
              'Code: MIT. Daten und Texte: CC BY-SA 4.0. Yomicha sammelt keine Daten; '
              'der Lernstand bleibt auf deinen Geräten.',
              style: sans(13.5, color: YoColors.inkSoft),
            ),
          ],
        ),
      ),
    ),
  );
}
