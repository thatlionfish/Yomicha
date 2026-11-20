import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

import '../app_scope.dart';
import '../data/progress.dart';
import '../data/schreib_plan.dart';
import '../learn/calendar.dart';
import '../learn/schreiben.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import '../widgets/kanji_card.dart';
import 'schreib_sitzung.dart';

/// Daten für „Kanji schreiben“: Plan und alle Wörter (JLPT und meine).
typedef SchreibDaten = ({SchreibPlan plan, Set<String> kana});

/// „Kanji schreiben“ (Spezifikation 19): was heute dran ist, wie weit ich bis
/// zur N2 bin, alle Kanji N5–N2 im Überblick und die Einstellungen.
class SchreibenScreen extends StatefulWidget {
  const SchreibenScreen({super.key});

  @override
  State<SchreibenScreen> createState() => _SchreibenScreenState();
}

class _SchreibenScreenState extends State<SchreibenScreen> {
  Future<SchreibDaten>? _daten;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = AppScope.of(context).repo;
    _daten ??= () async {
      final plan = await repo.schreibPlan();
      final kana = await repo.kana();
      return (plan: plan, kana: kana.keys.toSet());
    }();
  }

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    return Scaffold(
      appBar: AppBar(title: const Text('Kanji schreiben')),
      body: FutureBuilder(
        future: _daten,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Der Lernplan ließ sich nicht laden. Bist du online?', style: sans(16)),
              ),
            );
          }
          final d = snap.data;
          if (d == null) return const Center(child: CircularProgressIndicator());
          return ListenableBuilder(
            listenable: progress,
            builder: (context, _) => _content(context, progress, d),
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, Progress progress, SchreibDaten d) {
    final st = progress.schreiben;
    final now = DateTime.now();
    final plan = d.plan;
    final alle = alleWoerter(plan, progress.myWords.values, d.kana);
    final byKey = {for (final w in alle) w.key: w};
    final due = faelligeKarten(st, byKey, now).length;
    final neuKanji = neueKanjiHeute(st, now);
    final neuWoerter = neueWoerter(st, alle, now).length;
    final offen = plan.reihenfolge.where((k) => !st.kann(k)).length;
    final rest = isRestDay(now);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            if (!st.vorwissenGefragt && plan.vorwissen.isNotEmpty) ...[
              _VorwissenCard(plan: plan),
              const SizedBox(height: 14),
            ],
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: YoColors.brightWhite, borderRadius: organicRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rest ? 'Sonntag ist Ruhetag' : 'Heute', style: serif(24, weight: 460)),
                  const SizedBox(height: 6),
                  if (rest)
                    Text('Keine neuen Kanji, nichts fällig. Morgen geht es weiter.', style: sans(15.5, height: 1.45))
                  else ...[
                    _line(Icons.add_circle_outline_rounded, neuKanji == 0
                        ? 'Neue Kanji: geschafft (${st.kanjiAm(now)} heute)'
                        : 'Neue Kanji: noch $neuKanji von ${st.zielAm(now)}'),
                    _line(Icons.edit_note_rounded, 'Neue Wörter: bis zu ${neuWoerter + _lessonWords(plan, alle, progress, neuKanji)}'),
                    _line(Icons.replay_rounded, due == 0 ? 'Nichts zu wiederholen' : 'Wiederholen: $due'),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: neuKanji + neuWoerter + due == 0 && st.vorwissenGefragt
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(builder: (_) => SchreibSitzung(plan: plan, alle: alle)),
                                ),
                          child: Text(st.kanjiAm(now) == 0 && due > 0 ? 'Los geht’s' : 'Schreiben'),
                        ),
                        const SizedBox(width: 10),
                        if (neuKanji == 0)
                          OutlinedButton(
                            onPressed: () => st.mehrKanji(now, st.tagesziel),
                            child: Text('Noch ${st.tagesziel} Kanji'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              offen == 0
                  ? 'Alle Kanji bis N2 gelernt.'
                  : 'Noch $offen Kanji bis N2 · bei ${st.tagesziel} am Tag fertig am '
                        '${_date(fertigAm(offen, st.tagesziel, rest ? now.add(const Duration(days: 1)) : now))}',
              style: sans(15, color: YoColors.inkSoft),
            ),
            const SizedBox(height: 20),
            _Uebersicht(plan: plan, progress: progress),
            const SizedBox(height: 24),
            Text('Einstellungen', style: sans(14, weight: 650, color: YoColors.inkSoft)),
            const SizedBox(height: 6),
            _Stepper(
              label: 'Neue Kanji pro Lerntag (mindestens)',
              value: st.tagesziel,
              onChanged: st.setTagesziel,
            ),
            _Stepper(
              label: 'Neue Wörter pro Tag (höchstens)',
              value: st.woerterProTag,
              step: 5,
              onChanged: st.setWoerterProTag,
            ),
            const SizedBox(height: 6),
            Text(
              st.stiftGesehen
                  ? 'Apple Pencil erkannt: Finger und Handballen zählen im Schreibfeld nicht.'
                  : 'Mit dem Apple Pencil schreiben: Sobald der Stift einmal geschrieben hat, zählen Finger und Handballen nicht mehr.',
              style: sans(14, color: YoColors.inkSoft, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  /// Wörter, die mit den neuen Kanji von heute dazukommen (Schätzung).
  int _lessonWords(SchreibPlan plan, List<SchreibWort> alle, Progress progress, int n) {
    if (n == 0) return 0;
    final kanji = naechsteKanji(plan, progress.schreiben, progress.myWords.values, n).toSet();
    final now = DateTime.now();
    return neueWoerter(progress.schreiben, alle, now, auch: kanji).length -
        neueWoerter(progress.schreiben, alle, now).length;
  }

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Icon(icon, size: 20, color: YoColors.inkSoft),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: sans(15.5))),
      ],
    ),
  );

  static String _date(DateTime d) => '${d.day}.${d.month}.${d.year}';
}

class _VorwissenCard extends StatelessWidget {
  const _VorwissenCard({required this.plan});
  final SchreibPlan plan;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context).progress.schreiben;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(color: YoColors.vanillaIce, borderRadius: organicRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dein bisheriger Stand', style: serif(21, weight: 460)),
          const SizedBox(height: 6),
          Text(
            'In deiner bisherigen Schreib-App hast du ${plan.vorwissen.length} Kanji gelernt: '
            'N5, N4 und N3 bis 配. Die übernehme ich als gelernt; ihre Wörter kommen nach und nach in die Übung.',
            style: sans(15, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: () => st.uebernimm(plan.vorwissen), child: const Text('Übernehmen')),
              TextButton(onPressed: st.vorwissenBeantwortet, child: const Text('Bei null anfangen')),
            ],
          ),
        ],
      ),
    );
  }
}

enum _KanjiStand { offen, gelernt, sicher }

/// Noch nicht gelernte Kanji: blasse Tinte.
const _offenInk = Color(0x9973655A);

/// Alle Kanji N5–N2 nach Stufen; gelernte auf hellem Grund, sichere mit
/// grünem Strich darunter.
class _Uebersicht extends StatelessWidget {
  const _Uebersicht({required this.plan, required this.progress});
  final SchreibPlan plan;
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final st = progress.schreiben;
    // Stabilität je Kanji: aus der Kanji-Karte oder der besten Wort-Karte.
    final stab = <String, double>{};
    for (final key in st.kartenKeys) {
      final c = st.karte(key);
      if (c.state != fsrs.State.review) continue;
      final s = c.stability ?? 0;
      final chars = key.startsWith('k:') ? [key.substring(2)] : kanjiOfWord(key.substring(2).split('|').first);
      for (final k in chars) {
        if (s > (stab[k] ?? 0)) stab[k] = s;
      }
    }
    _KanjiStand stand(String k) => !st.kann(k)
        ? _KanjiStand.offen
        : (stab[k] ?? 0) >= 21
        ? _KanjiStand.sicher
        : _KanjiStand.gelernt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final n in const [5, 4, 3, 2]) ...[
          () {
            final ks = [for (final k in plan.reihenfolge) if (plan.stufe[k] == n) k];
            final done = ks.where(st.kann).length;
            return Text('N$n · $done von ${ks.length}', style: sans(14, weight: 650, color: YoColors.inkSoft));
          }(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final k in plan.reihenfolge)
                if (plan.stufe[k] == n) _cell(context, k, stand(k)),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }

  Widget _cell(BuildContext context, String k, _KanjiStand s) => InkWell(
    borderRadius: const BorderRadius.all(Radius.circular(8)),
    onTap: () => showKanjiCard(context, kanji: k, repo: AppScope.of(context).repo, progress: progress),
    child: Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: s == _KanjiStand.offen ? null : YoColors.brightWhite,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: s == _KanjiStand.sicher ? const Border(bottom: BorderSide(color: YoColors.lemonGrass, width: 3)) : null,
      ),
      child: Text(
        k,
        style: kanjiStyle(21).copyWith(color: s == _KanjiStand.offen ? _offenInk : YoColors.chocolate),
      ),
    ),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.onChanged, this.step = 1});
  final String label;
  final int value;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: sans(15.5))),
      IconButton(
        tooltip: 'Weniger',
        onPressed: () => onChanged(value - step),
        icon: const Icon(Icons.remove_circle_outline_rounded),
      ),
      SizedBox(width: 32, child: Text('$value', style: sans(17, weight: 650), textAlign: TextAlign.center)),
      IconButton(
        tooltip: 'Mehr',
        onPressed: () => onChanged(value + step),
        icon: const Icon(Icons.add_circle_outline_rounded),
      ),
    ],
  );
}
