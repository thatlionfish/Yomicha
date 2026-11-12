import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../data/stufen.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';

/// Karte eines Textes (Startseite, Archiv).
class TextCard extends StatelessWidget {
  const TextCard({super.key, required this.entry, required this.read, required this.onTap, this.big = false});
  final TextEntry entry;
  final bool read;
  final bool big;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stufe = Stufe.of(entry.stufe);
    return Material(
      color: YoColors.brightWhite,
      shape: const RoundedRectangleBorder(borderRadius: organicRadius),
      child: InkWell(
        customBorder: const RoundedRectangleBorder(borderRadius: organicRadius),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(big ? 20 : 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, style: jp(big ? 24 : 19, weight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(entry.titleDe, style: sans(15)),
                    const SizedBox(height: 6),
                    Text(
                      '${topicLabels[entry.topic] ?? entry.topic} · ${stufe.name} (${stufe.label}) · ≈ ${entry.minutes} Min',
                      style: sans(13.5, color: YoColors.inkSoft),
                    ),
                  ],
                ),
              ),
              if (read) const Icon(Icons.check_rounded, color: YoColors.chocolate),
              const Icon(Icons.chevron_right_rounded, color: YoColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
