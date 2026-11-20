import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../data/progress.dart';
import '../data/schreib_plan.dart';
import '../learn/calendar.dart';
import '../learn/library.dart';
import '../learn/review.dart';
import '../learn/schreiben.dart';
import '../learn/weekly.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import 'reading_screen.dart';
import 'review_screen.dart';
import 'schreib_sitzung.dart';
import 'schreiben_screen.dart';
import 'weekly_screen.dart';

/// Eine Aufgabe für heute.
class TagesAufgabe {
  const TagesAufgabe({
    required this.id,
    required this.icon,
    required this.titel,
    required this.info,
    required this.minuten,
    required this.erledigt,
    required this.oeffnen,
  });
  final String id;
  final IconData icon;
  final String titel;
  final String info;

  /// Ungefähre Dauer, solange die Aufgabe offen ist.
  final int minuten;
  final bool erledigt;
  final Widget Function() oeffnen;
}

/// „Heute lernen“ (Spezifikation 21): alles, was heute dran ist, um meine
/// Ziele zu schaffen – Texte, Wörter, Kanji schreiben, samstags der
/// Wochentest. „Los geht’s“ öffnet eins nach dem anderen; breche ich eine
/// Aufgabe ab, lande ich wieder hier.
class TagesplanScreen extends StatefulWidget {
  const TagesplanScreen({super.key, this.today});

  /// Nur für Tests: ein festes Datum.
  final DateTime? today;

  @override
  State<TagesplanScreen> createState() => _TagesplanScreenState();
}

typedef _Daten = ({List<TextEntry> index, SchreibPlan? plan, Set<String> kana});

class _TagesplanScreenState extends State<TagesplanScreen> {
  Future<_Daten>? _daten;

  /// Aufgaben, die heute schon einmal auf der Liste standen (bleiben mit Haken stehen).
  final Set<String> _gesehen = {};
  bool _laeuft = false;
  bool _gestartet = false;

  DateTime get _today => widget.today ?? DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_daten != null) return;
    final repo = AppScope.of(context).repo;
    _daten = () async {
      final index = await repo.index();
      SchreibPlan? plan;
      var kana = <String>{};
      try {
        plan = await repo.schreibPlan();
        kana = (await repo.kana()).keys.toSet();
      } catch (_) {
        // Ohne Lernplan fehlt nur das Schreiben.
      }
      return (index: index, plan: plan, kana: kana);
    }();
  }

  List<TagesAufgabe> _aufgaben(Progress p, _Daten d) {
    final today = _today;
    if (isRestDay(today)) return const [];
    final out = <TagesAufgabe>[];
    final readIds = {for (final r in p.reads) r.id};

    // 1. Lesen
    for (final e in heutigeTexte(d.index, stufe: p.stufe, read: readIds, today: today)) {
      out.add(
        TagesAufgabe(
          id: 'text:${e.id}',
          icon: Icons.menu_book_outlined,
          titel: 'Lesen: ${e.titleDe}',
          info: '${e.title} · ca. ${e.minutes} Min',
          minuten: e.minutes,
          erledigt: readIds.contains(e.id),
          oeffnen: () => ReadingScreen(folder: e.folder),
        ),
      );
    }

    // 2. Meine Wörter wiederholen
    final due = dueToday(p, today);
    out.add(
      TagesAufgabe(
        id: 'woerter',
        icon: Icons.style_rounded,
        titel: 'Meine Wörter wiederholen',
        info: due.isEmpty ? 'Alles wiederholt' : '${due.length} ${due.length == 1 ? 'Wort' : 'Wörter'}',
        minuten: (due.length * 12 / 60).ceil(),
        erledigt: due.isEmpty,
        oeffnen: () => ReviewScreen(cards: dueToday(p, _today)),
      ),
    );

    // 3. Kanji schreiben
    if (d.plan case final plan?) {
      final st = p.schreiben;
      if (!st.vorwissenGefragt && st.gelernt.isEmpty) {
        out.add(
          TagesAufgabe(
            id: 'schreiben',
            icon: Icons.draw_outlined,
            titel: 'Kanji schreiben',
            info: 'Einmal einrichten: deinen bisherigen Stand übernehmen',
            minuten: 2,
            erledigt: false,
            oeffnen: () => const SchreibenScreen(),
          ),
        );
      } else {
        final alle = alleWoerter(plan, p.myWords.values, d.kana);
        final byKey = {for (final w in alle) w.key: w};
        final neu = neueKanjiHeute(st, today);
        final wdh = faelligeKarten(st, byKey, today).length;
        final woerter = neueWoerter(st, alle, today).length;
        final offen = neu + wdh + woerter;
        out.add(
          TagesAufgabe(
            id: 'schreiben',
            icon: Icons.draw_outlined,
            titel: 'Kanji schreiben',
            info: offen == 0
                ? 'Geschafft · ${st.kanjiAm(today)} neue Kanji'
                : [
                    if (neu > 0) '$neu neue Kanji',
                    if (woerter > 0) 'bis zu $woerter neue Wörter',
                    if (wdh > 0) '$wdh wiederholen',
                  ].join(' · '),
            minuten: (neu * 3 + woerter * 0.7 + wdh * 0.5).ceil(),
            erledigt: offen == 0,
            oeffnen: () => SchreibSitzung(plan: plan, alle: alleWoerter(plan, p.myWords.values, d.kana)),
          ),
        );
      }
    }

    // 4. Wochentest (samstags, oder nachholen)
    if (testWeek(today) case final week?) {
      final done = p.weeklyFor(week);
      if (done == null || _gesehen.contains('woche')) {
        out.add(
          TagesAufgabe(
            id: 'woche',
            icon: Icons.quiz_outlined,
            titel: 'Wochentest · KW ${isoWeek(week)}',
            info: done != null
                ? 'Erledigt: ${done.correct} von ${done.total}'
                : today.weekday == DateTime.saturday
                ? 'Etwa 15 Fragen zu dieser Woche'
                : 'Von letzter Woche – nachholen',
            minuten: 10,
            erledigt: done != null,
            oeffnen: () => WeeklyScreen(weekStart: week),
          ),
        );
      }
    }

    // Was heute schon dran war, bleibt mit Haken stehen; was nie offen war, fällt weg.
    final sichtbar = [
      for (final a in out)
        if (!a.erledigt || _gesehen.contains(a.id) || a.id.startsWith('text:') || a.id == 'schreiben') a,
    ];
    _gesehen.addAll(sichtbar.map((a) => a.id));
    return sichtbar;
  }

  /// Öffnet die offenen Aufgaben nacheinander. Ist eine danach noch offen
  /// (abgebrochen), geht es hier weiter.
  Future<void> _los(_Daten d) async {
    if (_laeuft) return;
    setState(() => _laeuft = _gestartet = true);
    final p = AppScope.of(context).progress;
    final nav = Navigator.of(context);
    try {
      String? zuletzt;
      while (mounted) {
        final next = _aufgaben(p, d).where((a) => !a.erledigt).firstOrNull;
        if (next == null || next.id == zuletzt) break;
        zuletzt = next.id;
        await nav.push(MaterialPageRoute<void>(builder: (_) => next.oeffnen()));
      }
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    return Scaffold(
      appBar: AppBar(title: const Text('Heute lernen')),
      body: FutureBuilder(
        future: _daten,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Die Aufgaben ließen sich nicht laden. Bist du online?', style: sans(16)),
              ),
            );
          }
          final d = snap.data;
          if (d == null) return const Center(child: CircularProgressIndicator());
          return ListenableBuilder(
            listenable: progress,
            builder: (context, _) => _content(progress, d),
          );
        },
      ),
    );
  }

  Widget _content(Progress p, _Daten d) {
    final aufgaben = _aufgaben(p, d);
    final offen = aufgaben.where((a) => !a.erledigt).toList();
    final minuten = offen.fold(0, (n, a) => n + a.minuten);
    final rest = isRestDay(_today);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              rest
                  ? 'Sonntag ist Ruhetag'
                  : offen.isEmpty
                  ? 'Alles geschafft für heute'
                  : 'Noch ${offen.length} ${offen.length == 1 ? 'Aufgabe' : 'Aufgaben'} · etwa $minuten Min',
              style: serif(24, weight: 460),
            ),
            const SizedBox(height: 6),
            Text(
              rest
                  ? 'Heute ist nichts dran. Morgen geht es weiter.'
                  : offen.isEmpty
                  ? 'Deine Ziele für heute sind erreicht. お疲れさま！'
                  : 'Alles, was heute dran ist, nacheinander. Nach 20 Minuten Lernen kommen 5 Minuten Pause.',
              style: sans(15, color: YoColors.inkSoft, height: 1.45),
            ),
            const SizedBox(height: 18),
            for (final a in aufgaben) ...[
              _AufgabeTile(
                a: a,
                naechste: offen.isNotEmpty && a == offen.first,
                onTap: _laeuft
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => a.oeffnen())),
              ),
              const SizedBox(height: 10),
            ],
            if (offen.isNotEmpty) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _laeuft ? null : () => _los(d),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  !_gestartet && offen.length == aufgaben.length ? 'Los geht’s' : 'Weiter mit „${offen.first.titel}“',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AufgabeTile extends StatelessWidget {
  const _AufgabeTile({required this.a, required this.naechste, required this.onTap});
  final TagesAufgabe a;
  final bool naechste;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: a.erledigt ? YoColors.coconutMilk : YoColors.vanillaIce,
    shape: RoundedRectangleBorder(
      borderRadius: organicRadius,
      side: naechste ? const BorderSide(color: YoColors.chocolate, width: 1.5) : BorderSide.none,
    ),
    child: InkWell(
      customBorder: const RoundedRectangleBorder(borderRadius: organicRadius),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(a.icon, color: a.erledigt ? YoColors.inkSoft : YoColors.chocolate),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.titel, style: sans(16, weight: 650, color: a.erledigt ? YoColors.inkSoft : null)),
                  Text(a.info, style: sans(13.5, color: YoColors.inkSoft)),
                ],
              ),
            ),
            if (a.erledigt)
              const Icon(Icons.check_circle_rounded, color: YoColors.chocolate)
            else
              const Icon(Icons.chevron_right_rounded, color: YoColors.inkSoft),
          ],
        ),
      ),
    ),
  );
}
