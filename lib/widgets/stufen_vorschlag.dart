import 'package:flutter/material.dart';

import '../data/progress.dart';
import '../data/stufen.dart';
import '../learn/einstufung.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';

/// Vorschlag für einen Stufenwechsel (Spezifikation 9.3) – ich bestätige ihn.
class StufenVorschlagCard extends StatelessWidget {
  const StufenVorschlagCard({super.key, required this.progress, required this.vorschlag});
  final Progress progress;
  final StufenVorschlag vorschlag;

  @override
  Widget build(BuildContext context) {
    final v = vorschlag;
    final up = v.richtung == Richtung.hoch;
    final nach = Stufe.of(v.nach);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: YoColors.brightWhite,
        borderRadius: organicRadius,
        border: Border(left: BorderSide(color: YoColors.lemonGrass, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: YoColors.chocolate),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  up
                      ? 'Bereit für Stufe ${nach.nr} · ${nach.name} ${nach.kanji}?'
                      : 'Lieber zurück zu Stufe ${nach.nr} · ${nach.name} ${nach.kanji}?',
                  style: serif(19),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(v.grund, style: sans(14.5, height: 1.4)),
          const SizedBox(height: 4),
          Text(
            up
                ? 'Die Texte werden etwas länger und schwerer (${nach.label}). Du kannst jederzeit zurück.'
                : 'Dort festigst du den Stoff und steigst später wieder auf (${nach.label}).',
            style: sans(13.5, color: YoColors.inkSoft),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => progress.setStufe(v.nach),
                child: Text(up ? 'Aufsteigen' : 'Zurück zu Stufe ${nach.nr}'),
              ),
              OutlinedButton(
                onPressed: () => progress.pauseVorschlag(v.von, textsOnStufe(progress).length),
                child: Text(up ? 'Noch nicht' : 'Ich bleibe'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
