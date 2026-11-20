import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/progress.dart';
import '../data/repository.dart';
import '../screens/schoenschreib_screen.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import 'stroke_order.dart';

/// Kanji-Karte mit Zerlegung nach Heisig (Spezifikation 5).
Future<void> showKanjiCard(
  BuildContext context, {
  required String kanji,
  required Repository repo,
  required Progress progress,
  TextDoc? doc,
  bool kompakt = false,
}) async {
  final info = await repo.kanjiInfo(kanji);
  final names = await repo.partNames();
  final parts = info == null ? <String, KanjiInfo>{} : await repo.kanjiFor(info.parts);
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: KanjiDetails(
          kanji: kanji,
          info: info,
          partInfo: parts,
          partNames: names,
          repo: repo,
          progress: progress,
          doc: doc,
          kompakt: kompakt,
        ),
      ),
    ),
  );
}

/// Die Kanji eines Wortes als Knöpfe; ein Tipp öffnet die Kanji-Karte mit
/// Bedeutung und Bausteinen – im Text, in der Wiederholung und in „Meine Wörter“.
class KanjiButtons extends StatelessWidget {
  const KanjiButtons({
    super.key,
    required this.word,
    required this.repo,
    required this.progress,
    this.doc,
    this.center = false,
  });

  final String word;
  final Repository repo;
  final Progress progress;
  final TextDoc? doc;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final kanji = kanjiOf(word);
    if (kanji.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Kanji', style: sans(13.5, weight: 650, color: YoColors.inkSoft)),
        const SizedBox(height: 6),
        Wrap(
          alignment: center ? WrapAlignment.center : WrapAlignment.start,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final k in kanji)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 64),
                  padding: const EdgeInsets.all(8),
                ),
                onPressed: () => showKanjiCard(context, kanji: k, repo: repo, progress: progress, doc: doc),
                child: Text(k, style: kanjiStyle(32)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Lehrbuchschrift für große Kanji (handschriftgetreue Striche).
TextStyle kanjiStyle(double size) => TextStyle(
  fontFamily: 'KleeOne',
  fontSize: size,
  height: 1.1,
  color: YoColors.chocolate,
);

/// Inhalt der Kanji-Karte: Bedeutung, Lesungen, Zerlegung, Strichfolge und
/// meine Geschichte. [kompakt] zeigt nur Zerlegung und Geschichte (Hinweis
/// beim Schreiben).
class KanjiDetails extends StatefulWidget {
  const KanjiDetails({
    super.key,
    required this.kanji,
    required this.info,
    required this.partInfo,
    required this.partNames,
    required this.repo,
    required this.progress,
    this.doc,
    this.kompakt = false,
  });

  final String kanji;
  final KanjiInfo? info;
  final Map<String, KanjiInfo> partInfo;
  final Map<String, String> partNames;
  final Repository repo;
  final Progress progress;
  final TextDoc? doc;
  final bool kompakt;

  @override
  State<KanjiDetails> createState() => _KanjiDetailsState();
}

class _KanjiDetailsState extends State<KanjiDetails> {
  late final _story = TextEditingController(text: widget.progress.stories[widget.kanji] ?? '');

  /// Im Hinweis ([KanjiDetails.kompakt]) steht das Kanji selbst nicht da.
  String _verdeckt(String text) => widget.kompakt ? text.replaceAll(widget.kanji, '〇') : text;

  @override
  void dispose() {
    _story.dispose();
    super.dispose();
  }

  String _partName(String p) => widget.partNames[p] ?? widget.partInfo[p]?.keyword ?? '';

  @override
  Widget build(BuildContext context) {
    final k = widget.info;
    final seen = <String>{};
    final words = [
      for (final s in widget.doc?.sentences ?? const <Sentence>[])
        for (final t in s.tokens)
          if (t.t.contains(widget.kanji) && t.isWord && seen.add(t.t)) t,
    ];
    final meaning = k == null ? '' : (k.de ?? k.meanings.take(3).join(', '));

    final kompakt = widget.kompakt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!kompakt) Row(
          children: [
            Container(
              width: 112,
              height: 112,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: YoColors.vanillaIce, borderRadius: organicRadius),
              child: Text(widget.kanji, style: kanjiStyle(80)),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k?.keyword ?? '–', style: serif(26, weight: 460)),
                  if (meaning.isNotEmpty) Text(meaning, style: sans(16, color: YoColors.inkSoft)),
                  const SizedBox(height: 8),
                  if (k != null)
                    Text(
                      [
                        if (k.heisig != null) 'Heisig ${k.heisig}',
                        if (k.jlpt != null) 'N${k.jlpt}',
                        '${k.strokes} Striche',
                      ].join(' · '),
                      style: sans(13.5, color: YoColors.inkSoft),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (k == null) ...[
          const SizedBox(height: 16),
          Text('Für dieses Zeichen gibt es noch keine Karte.', style: sans(15)),
        ] else ...[
          if (!kompakt) ...[
            const SizedBox(height: 18),
            _row('On', k.on.join('、')),
            _row('Kun', k.kun.join('、')),
          ],
          if (k.parts.isNotEmpty) ...[
            const SizedBox(height: 18),
            _label('Zerlegung'),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 8,
              children: [
                // Als Hinweis beim Schreiben darf das Kanji selbst nicht dastehen.
                if (!kompakt) Text('${widget.kanji} =', style: kanjiStyle(24)),
                for (var i = 0; i < k.parts.length; i++) ...[
                  if (i > 0) Text('+', style: sans(18, color: YoColors.inkSoft)),
                  _PartChip(
                    part: k.parts[i],
                    name: _partName(k.parts[i]),
                    onTap: widget.partInfo.containsKey(k.parts[i])
                        ? () => showKanjiCard(
                            context,
                            kanji: k.parts[i],
                            repo: widget.repo,
                            progress: widget.progress,
                            doc: widget.doc,
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ],
          if (k.paths.isNotEmpty && !kompakt) ...[
            const SizedBox(height: 18),
            _label('Strichfolge'),
            const SizedBox(height: 8),
            StrokeOrder(paths: k.paths),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SchoenschreibScreen(zeichen: widget.kanji, paths: k.paths, bedeutung: meaning),
                ),
              ),
              icon: const Icon(Icons.brush_outlined),
              label: const Text('Schönschreiben'),
            ),
          ],
          const SizedBox(height: 18),
          _label('Merkgeschichte'),
          if (k.story != null) ...[
            const SizedBox(height: 6),
            Text('Vorschlag: ${_verdeckt(k.story!)}', style: sans(15, height: 1.5)),
          ],
          const SizedBox(height: 8),
          // Beim Hinweis während des Schreibens: meine Geschichte nur zum Lesen,
          // das Kanji darin verdeckt.
          if (kompakt && _story.text.trim().isNotEmpty)
            Text(_verdeckt(_story.text), style: sans(15.5, height: 1.5))
          else
            TextField(
              controller: _story,
              minLines: 2,
              maxLines: 5,
              style: sans(15.5),
              decoration: const InputDecoration(
                hintText: 'Meine eigene Geschichte …',
                filled: true,
                fillColor: YoColors.coconutMilk,
                border: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide.none),
              ),
              onChanged: (s) => widget.progress.setStory(widget.kanji, s),
            ),
        ],
        if (words.isNotEmpty && !kompakt) ...[
          const SizedBox(height: 18),
          _label('Kommt vor in'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final t in words)
                Text.rich(TextSpan(children: [
                  TextSpan(text: t.t, style: jp(18)),
                  TextSpan(text: '  ${t.reading}', style: jp(14, color: YoColors.inkSoft)),
                ])),
            ],
          ),
        ],
        if (!kompakt) ...[
          const SizedBox(height: 18),
          Text(
            'Zerlegung und Strichfolge: KanjiVG (CC BY-SA 3.0). Lesungen und Heisig-Nummer: '
            'KANJIDIC2 (CC BY-SA 4.0). Die Schlüsselwörter sind eigene, nicht Heisigs.',
            style: sans(12.5, color: YoColors.inkSoft),
          ),
        ],
      ],
    );
  }

  Widget _label(String s) => Text(s, style: sans(13.5, weight: 650, color: YoColors.inkSoft));

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 44, child: Text(label, style: sans(14, weight: 650, color: YoColors.inkSoft))),
        Expanded(child: Text(value.isEmpty ? '–' : value, style: jp(17))),
      ],
    ),
  );
}

class _PartChip extends StatelessWidget {
  const _PartChip({required this.part, required this.name, this.onTap});
  final String part;
  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: YoColors.vanillaIce,
    shape: const RoundedRectangleBorder(borderRadius: organicRadius),
    child: InkWell(
      customBorder: const RoundedRectangleBorder(borderRadius: organicRadius),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(part, style: kanjiStyle(24)),
            if (name.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(name, style: sans(14, weight: 600)),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 18, color: YoColors.inkSoft),
            ],
          ],
        ),
      ),
    ),
  );
}
