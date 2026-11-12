import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../data/progress.dart';
import '../data/stufen.dart';
import '../learn/calendar.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import '../widgets/kumachan.dart';
import 'reading_screen.dart';
import 'sources_screen.dart';

/// Startseite: Texte des Tages, Countdown, Lernserie (Spezifikation 3).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.today});

  /// Nur für Tests: ein festes Datum.
  final DateTime? today;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<TextEntry>>? _index;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _index ??= AppScope.of(context).repo.index();
  }

  DateTime get _today => widget.today ?? DateTime.now();

  String get _greeting {
    final h = _today.hour;
    if (h < 11) return 'おはよう、Leoni';
    if (h < 18) return 'こんにちは、Leoni';
    return 'こんばんは、Leoni';
  }

  void _open(TextEntry e) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ReadingScreen(folder: e.folder)),
  );

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    return Scaffold(
      appBar: AppBar(
        title: Text('Yomicha', style: serif(24, weight: 460)),
        actions: [
          IconButton(
            tooltip: 'Einstellungen',
            onPressed: () => _settings(context),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: progress,
        builder: (context, _) {
          final rest = isRestDay(_today);
          final stufe = Stufe.of(progress.stufe);
          final days = learningDaysBetween(_today, examDate);
          final serie = streak(progress.readDays, _today);
          final readIds = {for (final r in progress.reads) r.id};
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  // Sonntags trinkt sie selbst Tee – auch wenn sie sonst nur „selten“ kommt.
                  if (progress.kuma == KumaMode.oft || (rest && progress.kuma != KumaMode.aus)) ...[
                    KumaMoment(mood: rest ? 'ruhetag' : 'begruessung'),
                    const SizedBox(height: 14),
                  ],
                  Text(_greeting, style: jp(26, weight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    '$days Lerntage bis zur N2 · Serie: $serie ${serie == 1 ? 'Tag' : 'Tage'}',
                    style: sans(15, color: YoColors.inkSoft),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Meine Stufe: ${stufe.nr} · ${stufe.name} ${stufe.kanji} (${stufe.label})',
                    style: sans(15, color: YoColors.inkSoft),
                  ),
                  const SizedBox(height: 22),
                  if (rest) ...[
                    _RestCard(),
                    const SizedBox(height: 22),
                    Text('Archiv – falls du doch Lust hast', style: sans(14, weight: 650, color: YoColors.inkSoft)),
                    const SizedBox(height: 8),
                  ],
                  FutureBuilder<List<TextEntry>>(
                    future: _index,
                    builder: (context, snap) {
                      if (snap.hasError) return Text('Texte konnten nicht geladen werden: ${snap.error}');
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final all = snap.data!;
                      if (all.isEmpty) return Text('Noch keine Texte.', style: sans(16));
                      final mine = all.where((e) => e.stufe == progress.stufe).toList();
                      final today = rest ? <TextEntry>[] : (mine.isEmpty ? all : mine).take(2).toList();
                      final rest_ = all.where((e) => !today.contains(e)).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (today.isNotEmpty) ...[
                            Text('Deine Texte für heute', style: sans(14, weight: 650, color: YoColors.inkSoft)),
                            const SizedBox(height: 8),
                            for (final e in today) ...[
                              _TextCard(entry: e, read: readIds.contains(e.id), big: true, onTap: () => _open(e)),
                              const SizedBox(height: 12),
                            ],
                          ],
                          if (rest_.isNotEmpty) ...[
                            if (!rest) ...[
                              const SizedBox(height: 10),
                              Text('Archiv', style: sans(14, weight: 650, color: YoColors.inkSoft)),
                              const SizedBox(height: 8),
                            ],
                            for (final e in rest_) ...[
                              _TextCard(entry: e, read: readIds.contains(e.id), onTap: () => _open(e)),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Meine Wörter: ${progress.myWords.length}',
                    style: sans(15, color: YoColors.inkSoft),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _settings(BuildContext context) {
    final progress = AppScope.of(context).progress;
    showModalBottomSheet<void>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => ListenableBuilder(
        listenable: progress,
        builder: (context, _) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text('Kumachan', style: serif(21)),
              const SizedBox(height: 8),
              SegmentedButton<KumaMode>(
                showSelectedIcon: false,
                segments: [
                  for (final m in KumaMode.values) ButtonSegment(value: m, label: Text(m.label)),
                ],
                selected: {progress.kuma},
                onSelectionChanged: (s) => progress.setKuma(s.first),
              ),
              const SizedBox(height: 4),
              Text(
                switch (progress.kuma) {
                  KumaMode.oft => 'Auf der Startseite, nach dem Text und als Hinweis bei einer falschen Antwort.',
                  KumaMode.selten => 'Nur nach dem Text – und sonntags beim Tee.',
                  KumaMode.aus => 'Kumachan macht Pause.',
                },
                style: sans(13.5, color: YoColors.inkSoft),
              ),
              const SizedBox(height: 22),
              Text('Meine Stufe', style: serif(21)),
              const SizedBox(height: 4),
              Text(
                'Bis die Einstufung gebaut ist, stelle ich sie hier ein.',
                style: sans(14, color: YoColors.inkSoft),
              ),
              const SizedBox(height: 8),
              for (final s in Stufe.all)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    s.nr == progress.stufe ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: YoColors.chocolate,
                  ),
                  title: Text('${s.nr} · ${s.name}  ${s.kanji}', style: sans(16)),
                  subtitle: Text(s.label, style: sans(13.5, color: YoColors.inkSoft)),
                  onTap: () => progress.setStufe(s.nr),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SourcesScreen()),
                  ),
                  child: const Text('Quellen und Lizenzen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: const BoxDecoration(color: YoColors.brightWhite, borderRadius: organicRadius),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('日曜日はお休み', style: jp(24, weight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text(
          'Heute ist Ruhetag. Es ist nichts zu erledigen, und deine Serie läuft weiter. '
          'Genieß deinen Tee.',
          style: sans(16, height: 1.5),
        ),
      ],
    ),
  );
}

class _TextCard extends StatelessWidget {
  const _TextCard({required this.entry, required this.read, required this.onTap, this.big = false});
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
