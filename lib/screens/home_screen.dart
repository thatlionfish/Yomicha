import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../data/progress.dart';
import '../data/stufen.dart';
import '../learn/calendar.dart';
import '../learn/library.dart';
import '../learn/review.dart';
import '../learn/weekly.dart';
import '../ui/app_icon.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import '../widgets/kumachan.dart';
import '../widgets/text_card.dart';
import 'archive_screen.dart';
import 'progress_screen.dart';
import 'reading_screen.dart';
import 'sources_screen.dart';
import 'weekly_screen.dart';
import 'words_screen.dart';

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
  Future<List<Notice>>? _notices;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _index ??= AppScope.of(context).repo.index();
    _notices ??= AppScope.of(context).repo.notices();
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(size: 36, background: false, zoom: 1.25),
            const SizedBox(width: 8),
            Text('Yomicha', style: serif(24, weight: 460)),
          ],
        ),
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
                  FutureBuilder<List<Notice>>(
                    future: _notices,
                    builder: (context, snap) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final n in snap.data ?? const <Notice>[])
                          if (_today.difference(n.date).inDays < 7)
                            Container(
                              margin: const EdgeInsets.only(top: 14),
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                color: YoColors.vanillaIce,
                                borderRadius: organicRadius,
                                border: Border(left: BorderSide(color: YoColors.woodAsh, width: 4)),
                              ),
                              child: Text('Teeküche: ${n.text}', style: sans(14.5)),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (rest) ...[
                    _RestCard(),
                    const SizedBox(height: 22),
                  ],
                  FutureBuilder<List<TextEntry>>(
                    future: _index,
                    builder: (context, snap) {
                      if (snap.hasError) return Text('Texte konnten nicht geladen werden: ${snap.error}');
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final shown = textsForStufe(visibleTexts(snap.data!, _today), progress.stufe);
                      var today = shown.where((e) => sameDay(e.date, _today)).take(2).toList();
                      var label = 'Deine Texte für heute';
                      if (today.isEmpty && !rest) {
                        // Keine neuen Texte (Teeküche ausgefallen): die neuesten ungelesenen.
                        today = shown.where((e) => !readIds.contains(e.id)).take(2).toList();
                        label = 'Noch nicht gelesen';
                      }
                      if (rest) today = const [];
                      final older = shown.length - today.length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (today.isNotEmpty) ...[
                            Text(label, style: sans(14, weight: 650, color: YoColors.inkSoft)),
                            const SizedBox(height: 8),
                            for (final e in today) ...[
                              TextCard(entry: e, read: readIds.contains(e.id), big: true, onTap: () => _open(e)),
                              const SizedBox(height: 12),
                            ],
                          ],
                          const SizedBox(height: 6),
                          ?_weeklyTile(progress),
                          _Tile(
                            icon: Icons.style_rounded,
                            title: 'Meine Wörter',
                            subtitle: _wordsLine(progress),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const WordsScreen()),
                            ),
                          ),
                          _Tile(
                            icon: Icons.inventory_2_outlined,
                            title: 'Archiv',
                            subtitle: older <= 0 ? 'Noch keine älteren Texte' : '$older ältere ${older == 1 ? 'Text' : 'Texte'}',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => ArchiveScreen(texts: shown)),
                            ),
                          ),
                          _Tile(
                            icon: Icons.show_chart_rounded,
                            title: 'Fortschritt',
                            subtitle: 'Zielkurve bis zur N2 am 5.12.2027',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => const ProgressScreen()),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Wochentest: samstags für die laufende Woche, Montag bis Freitag zum
  /// Nachholen der vergangenen (nur wenn noch nicht gemacht).
  Widget? _weeklyTile(Progress progress) {
    final week = testWeek(_today);
    if (week == null) return null;
    final done = progress.weeklyFor(week);
    final saturday = _today.weekday == DateTime.saturday;
    if (done != null && !saturday) return null;
    return _Tile(
      icon: Icons.quiz_outlined,
      title: 'Wochentest · KW ${isoWeek(week)}',
      subtitle: done != null
          ? 'Erledigt: ${done.correct} von ${done.total} – nochmal machen?'
          : saturday
          ? 'Etwa 15 Fragen zu dieser Woche · ca. 10 Min'
          : 'Von letzter Woche – jetzt nachholen',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => WeeklyScreen(weekStart: week)),
      ),
    );
  }

  String _wordsLine(Progress progress) {
    final n = progress.myWords.length;
    if (n == 0) return 'Noch keine Wörter gespeichert';
    if (isRestDay(_today)) return '$n Wörter · sonntags ist nichts fällig';
    final due = dueToday(progress, _today).length;
    return due == 0 ? '$n Wörter · heute nichts fällig' : 'Heute zu wiederholen: $due';
  }

  void _settings(BuildContext context) {
    final progress = AppScope.of(context).progress;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: 640, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      builder: (context) => ListenableBuilder(
        listenable: progress,
        builder: (context, _) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
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
              Text('Nachsprechen', style: serif(21)),
              const SizedBox(height: 4),
              const _AzureSettings(),
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

/// Azure-Schlüssel fürs Nachsprechen – nur auf diesem Gerät gespeichert.
class _AzureSettings extends StatefulWidget {
  const _AzureSettings();

  @override
  State<_AzureSettings> createState() => _AzureSettingsState();
}

class _AzureSettingsState extends State<_AzureSettings> {
  late final _key = TextEditingController(text: AppScope.of(context).progress.azureKey);
  late final _region = TextEditingController(text: AppScope.of(context).progress.azureRegion);
  var _saved = false;

  @override
  void dispose() {
    _key.dispose();
    _region.dispose();
    super.dispose();
  }

  InputDecoration _field(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: YoColors.coconutMilk,
    border: const OutlineInputBorder(borderRadius: organicRadius, borderSide: BorderSide.none),
  );

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Für die Aussprache-Bewertung: der Schlüssel deines Azure-Speech-Zugangs in der Gratis-Stufe F0 '
          '(Azure-Portal → Speech-Zugang → „Schlüssel und Endpunkt“). Er bleibt nur auf diesem Gerät.',
          style: sans(13.5, color: YoColors.inkSoft),
        ),
        const SizedBox(height: 8),
        TextField(controller: _key, obscureText: true, autocorrect: false, decoration: _field('Schlüssel')),
        const SizedBox(height: 8),
        TextField(controller: _region, autocorrect: false, decoration: _field('Region (z. B. switzerlandnorth)')),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton(
              onPressed: () {
                progress.setAzure(_key.text, _region.text);
                setState(() => _saved = true);
              },
              child: const Text('Speichern'),
            ),
            const SizedBox(width: 12),
            if (_saved || progress.azureKey.isNotEmpty)
              Text(
                'Gespeichert · diesen Monat ${(progress.speechSecondsThisMonth(DateTime.now()) / 60).ceil()} von 300 Gratis-Minuten',
                style: sans(13, color: YoColors.inkSoft),
              ),
          ],
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: YoColors.vanillaIce,
      shape: const RoundedRectangleBorder(borderRadius: organicRadius),
      child: InkWell(
        customBorder: const RoundedRectangleBorder(borderRadius: organicRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: YoColors.chocolate),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: sans(16, weight: 650)),
                    Text(subtitle, style: sans(13.5, color: YoColors.inkSoft)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: YoColors.inkSoft),
            ],
          ),
        ),
      ),
    ),
  );
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
