import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/progress.dart';
import '../data/stufen.dart';
import '../learn/calendar.dart';
import '../learn/goal.dart';
import '../learn/review.dart';
import '../learn/weekly.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import '../widgets/goal_chart.dart';

/// Fortschritt (Spezifikation 9.4 und 13): Zielkurve bis zur N2 und Statistik.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    return Scaffold(
      appBar: AppBar(title: const Text('Fortschritt')),
      body: ListenableBuilder(
        listenable: progress,
        builder: (context, _) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final (start, startStufe) = progress.stufeHistory.first;
          final target = targetStufe(start, startStufe, today);
          final weeks = weeksAhead(start, startStufe, today, progress.stufe);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  Text(planStatus(weeks), style: serif(28, weight: 420)),
                  const SizedBox(height: 4),
                  Text(
                    'Ziel heute: Stufe ${fmtStufe(target)} · deine Stufe: ${progress.stufe} ${Stufe.of(progress.stufe).name}',
                    style: sans(15, color: YoColors.inkSoft),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
                    decoration: const BoxDecoration(color: YoColors.brightWhite, borderRadius: organicRadius),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(padding: EdgeInsets.only(left: 8, bottom: 8), child: GoalLegend()),
                        GoalChart(history: progress.stufeHistory, today: today),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Tippe auf das Diagramm, um einen Tag anzusehen.', style: sans(12.5, color: YoColors.inkSoft)),
                  const SizedBox(height: 18),
                  _Table(rows: [
                    ('Start', '${fmtDate(start)} · Stufe $startStufe ${Stufe.of(startStufe).name}'),
                    ('Heute', 'Ziel ${fmtStufe(target)} · du ${progress.stufe}'),
                    ('31.8.2027', 'Stufe 6 Gyokuro (N2)'),
                    ('30.11.2027', 'Stufe 7 Matcha – prüfungsreif'),
                    ('5.12.2027', 'JLPT N2'),
                  ]),
                  const SizedBox(height: 22),
                  Text('Lernstatistik', style: serif(21)),
                  const SizedBox(height: 8),
                  _Table(rows: _stats(progress, now)),
                  const SizedBox(height: 14),
                  Text(
                    'Bis die automatische Einstufung fertig ist, stellst du deine Stufe in den Einstellungen ein. '
                    'Jeder Wechsel erscheint hier in der Kurve.',
                    style: sans(13.5, color: YoColors.inkSoft),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<(String, String)> _stats(Progress p, DateTime now) {
    final reads = p.reads;
    final questions = reads.fold(0, (n, r) => n + r.total);
    final correct = reads.fold(0, (n, r) => n + r.correct);
    final timed = reads.where((r) => !r.usedAudio && r.seconds >= 20).toList();
    final chars = timed.fold(0, (n, r) => n + r.chars);
    final secs = timed.fold(0, (n, r) => n + r.seconds);
    final counts = {for (final s in WordStatus.values) s: 0};
    for (final w in p.myWords.values) {
      counts[statusOf(p, w.key)] = counts[statusOf(p, w.key)]! + 1;
    }
    return [
      ('Gelesene Texte', '${{for (final r in reads) r.id}.length}'),
      ('Fragen richtig', questions == 0 ? '–' : '${(100 * correct / questions).round()} % ($correct von $questions)'),
      ('Lesetempo', secs == 0 ? '–' : '${(chars * 60 / secs).round()} Zeichen pro Minute'),
      ('Lernserie', '${streak(p.readDays, now)} Lerntage'),
      ('Meine Wörter', '${p.myWords.length} · ${counts[WordStatus.sicher]} sicher'),
      (
        'Wochentests',
        p.weeklyResults.isEmpty
            ? 'noch keiner – samstags'
            : [
                for (final r in p.weeklyResults.reversed.take(4))
                  'KW ${isoWeek(r.weekStart)}: ${r.correct}/${r.total}',
              ].join(' · '),
      ),
      ('Bis zur Prüfung', '${learningDaysBetween(now, examDate)} Lerntage'),
    ];
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: YoColors.vanillaIce, borderRadius: organicRadius),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 120, child: Text(k, style: sans(14, weight: 650))),
                Expanded(child: Text(v, style: sans(14.5))),
              ],
            ),
          ),
      ],
    ),
  );
}
