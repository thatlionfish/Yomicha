import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import '../widgets/text_card.dart';
import 'reading_screen.dart';

/// Wie lange Texte im Archiv bleiben (gleicher Wert wie `aufbewahren_tage`
/// in tool/teekueche/config.json). Die Wörter in „Meine Wörter“ bleiben immer.
const keepDays = 90;

const _months = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

/// Archiv: ältere Texte meiner Stufe, nach Monaten, mit Filter.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key, required this.texts});
  final List<TextEntry> texts;

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  var _unreadOnly = false;
  String? _topic;

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    return Scaffold(
      appBar: AppBar(title: const Text('Archiv')),
      body: ListenableBuilder(
        listenable: progress,
        builder: (context, _) {
          final readIds = {for (final r in progress.reads) r.id};
          final list = widget.texts
              .where((e) => !_unreadOnly || !readIds.contains(e.id))
              .where((e) => _topic == null || e.topic == _topic)
              .toList();
          final groups = <String, List<TextEntry>>{};
          for (final e in list) {
            groups.putIfAbsent('${_months[e.date.month - 1]} ${e.date.year}', () => []).add(e);
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Ungelesen'),
                        selected: _unreadOnly,
                        onSelected: (v) => setState(() => _unreadOnly = v),
                      ),
                      for (final t in topicLabels.entries)
                        FilterChip(
                          label: Text(t.value),
                          selected: _topic == t.key,
                          onSelected: (v) => setState(() => _topic = v ? t.key : null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Texte bleiben $keepDays Tage im Archiv, dann räumt die Teeküche sie weg. '
                    'Deine Wörter bleiben immer – mit Satz, Lesung und Aussprache.',
                    style: sans(13.5, color: YoColors.inkSoft),
                  ),
                  if (list.isEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Keine Texte für diese Auswahl.', style: sans(16)),
                  ],
                  for (final g in groups.entries) ...[
                    const SizedBox(height: 18),
                    Text(g.key, style: sans(14, weight: 650, color: YoColors.inkSoft)),
                    const SizedBox(height: 8),
                    for (final e in g.value) ...[
                      TextCard(
                        entry: e,
                        read: readIds.contains(e.id),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => ReadingScreen(folder: e.folder)),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
