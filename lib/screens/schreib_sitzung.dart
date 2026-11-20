import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

import '../app_scope.dart';
import '../audio/player.dart';
import '../data/audio_key.dart';
import '../data/models.dart';
import '../data/schreib_plan.dart';
import '../learn/review.dart' show review;
import '../learn/schreiben.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import '../widgets/kanji_card.dart';
import '../widgets/wort_schreiber.dart';
import 'words_screen.dart' show highlighted;

/// Eine Runde „Kanji schreiben“ (Spezifikation 19): zuerst die fälligen
/// Karten, dann die neuen Kanji des Tages (vorstellen, nachfahren, aus dem
/// Kopf) mit ihren Wörtern, dann weitere neue Wörter.
class SchreibSitzung extends StatefulWidget {
  const SchreibSitzung({super.key, required this.plan, required this.alle});
  final SchreibPlan plan;
  final List<SchreibWort> alle;

  @override
  State<SchreibSitzung> createState() => _SchreibSitzungState();
}

enum _Art { wiederholung, kanjiNeu, wortNeu }

class _Schritt {
  const _Schritt(this.art, this.karte);
  final _Art art;
  final SchreibKarte karte;
}

/// Wann eine Karte wiederkommt, z. B. „10 Min“ oder „3 Tage“.
String wannWieder(fsrs.Card c, DateTime now) {
  final d = c.due.difference(now.toUtc());
  if (d.inMinutes < 60) return 'in ${d.inMinutes < 1 ? 1 : d.inMinutes} Min';
  if (d.inHours < 24) return 'in ${d.inHours} Std';
  if (d.inDays < 14) return d.inDays == 1 ? 'morgen' : 'in ${d.inDays} Tagen';
  if (d.inDays < 60) return 'in ${(d.inDays / 7).round()} Wochen';
  return 'in ${(d.inDays / 30).round()} Monaten';
}

class _SchreibSitzungState extends State<SchreibSitzung> {
  final List<_Schritt> _queue = [];
  bool _built = false;
  int _pos = 0;
  int _phase = 0;

  // Daten zum aktuellen Schritt.
  bool _loading = true;
  Map<String, List<String>> _striche = const {};
  Map<String, KanjiInfo> _infos = const {};
  Map<String, KanjiInfo> _partInfo = const {};
  Map<String, String> _partNames = const {};
  List<String> _auswahl = const [];
  String? _gewaehlt;
  bool _lesungFalsch = false;
  fsrs.Rating? _rating;
  fsrs.Card? _karte;
  int _fehler = 0;
  int _hinweis = 0;

  int _wiederholt = 0;
  int _neueKanji = 0;
  int _neueWoerter = 0;

  late final Map<String, SchreibWort> _byKey = {for (final w in widget.alle) w.key: w};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_built) return;
    _built = true;
    _buildQueue();
    _load();
  }

  void _buildQueue() {
    final p = AppScope.of(context).progress;
    final st = p.schreiben;
    final now = DateTime.now();
    for (final k in faelligeKarten(st, _byKey, now)) {
      _queue.add(_Schritt(_Art.wiederholung, k));
    }
    final kanji = naechsteKanji(widget.plan, st, p.myWords.values, neueKanjiHeute(st, now));
    final words = neueWoerter(st, widget.alle, now, auch: kanji.toSet());
    final rest = <SchreibWort>[...words];
    for (var i = 0; i < kanji.length; i++) {
      _queue.add(_Schritt(_Art.kanjiNeu, SchreibKarte.kanji(kanji[i])));
      // Wörter, für die dieses Kanji das letzte neue ist, kommen gleich danach.
      for (final w in words) {
        final last = w.kanji.map(kanji.indexOf).fold(-1, (a, b) => a > b ? a : b);
        if (last == i) {
          _queue.add(_Schritt(_Art.wortNeu, SchreibKarte.wort(w)));
          rest.remove(w);
        }
      }
    }
    for (final w in rest) {
      _queue.add(_Schritt(_Art.wortNeu, SchreibKarte.wort(w)));
    }
  }

  _Schritt? get _step => _pos < _queue.length ? _queue[_pos] : null;

  Future<void> _load() async {
    final s = _step;
    if (s == null) return;
    setState(() => _loading = true);
    final repo = AppScope.of(context).repo;
    final chars = s.karte.text.split('');
    final striche = await repo.striche(chars);
    final infos = await repo.kanjiFor(chars.where(isKanji));
    final names = await repo.partNames();
    var partInfo = <String, KanjiInfo>{};
    if (s.art == _Art.kanjiNeu) {
      partInfo = await repo.kanjiFor(infos[s.karte.kanji]?.parts ?? const []);
    }
    var auswahl = const <String>[];
    if (s.karte.wort case final w? when s.art == _Art.wiederholung) {
      final andere = [
        for (final o in widget.alle)
          if (o.key != w.key && o.kanji.any(w.kanji.contains)) o.r,
      ];
      auswahl = lesungsAuswahl(w.r, andere.take(40), w.key.hashCode ^ DateTime.now().day);
    }
    if (!mounted) return;
    setState(() {
      _striche = striche;
      _infos = infos;
      _partNames = names;
      _partInfo = partInfo;
      _auswahl = auswahl;
      _loading = false;
      _phase = s.art == _Art.wiederholung && (s.karte.kanji != null || auswahl.length < 2) ? 1 : 0;
    });
    if (s.art == _Art.wortNeu) _play(s.karte.wort!);
  }

  void _play(SchreibWort w) {
    final repo = AppScope.of(context).repo;
    playClip(repo.audioUrl(wordAudioPath(Token(t: w.t, r: w.r))));
  }

  void _weiter() {
    setState(() {
      _pos++;
      _phase = 0;
      _gewaehlt = null;
      _lesungFalsch = false;
      _rating = null;
      _karte = null;
      _fehler = 0;
      _hinweis = 0;
    });
    _load();
  }

  /// Karte speichern; kommt sie gleich wieder (Lernschritt), steht sie ein
  /// paar Karten später nochmal in der Runde.
  fsrs.Card _save(SchreibKarte k, fsrs.Rating rating) {
    final st = AppScope.of(context).progress.schreiben;
    final now = DateTime.now();
    final card = review(st.karte(k.key), rating, now);
    st.speichere(k.key, card, now);
    if (card.due.difference(now.toUtc()) < const Duration(minutes: 20)) {
      final at = (_pos + 4).clamp(0, _queue.length);
      _queue.insert(at, _Schritt(_Art.wiederholung, k));
    }
    return card;
  }

  void _geschrieben(int fehler, int hinweis) {
    final s = _step!;
    final now = DateTime.now();
    final st = AppScope.of(context).progress.schreiben;
    switch (s.art) {
      case _Art.wiederholung:
        final rating = schreibBewertung(fehler: fehler, hinweis: hinweis, lesungFalsch: _lesungFalsch);
        final card = _save(s.karte, rating);
        setState(() {
          _wiederholt++;
          _rating = rating;
          _karte = card;
          _fehler = fehler;
          _hinweis = hinweis;
          _phase = 2;
        });
        if (s.karte.wort case final w?) _play(w);
      case _Art.kanjiNeu when _phase == 1:
        setState(() => _phase = 2);
      case _Art.kanjiNeu:
        final k = s.karte.kanji!;
        st.lerne(k, now);
        fsrs.Card? card;
        final rating = schreibBewertung(fehler: fehler, hinweis: hinweis);
        // Gibt es das Kanji allein als Wort, übt das Wort es mit.
        if (!widget.plan.allein.contains(k)) card = _save(s.karte, rating);
        setState(() {
          _neueKanji++;
          _rating = rating;
          _karte = card;
          _fehler = fehler;
          _hinweis = hinweis;
          _phase = 3;
        });
      case _Art.wortNeu:
        _save(s.karte, fsrs.Rating.good);
        _neueWoerter++;
        _weiter();
    }
  }

  Future<void> _hilfe(String kanji) {
    final scope = AppScope.of(context);
    return showKanjiCard(context, kanji: kanji, repo: scope.repo, progress: scope.progress, kompakt: true);
  }

  String _bedeutung(SchreibKarte k) {
    if (k.wort case final w?) return w.bedeutung;
    final info = _infos[k.kanji];
    return info?.de ?? info?.meanings.take(2).join(', ') ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final s = _step;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kanji schreiben'),
        actions: [
          if (s != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text('${_pos + 1} von ${_queue.length}', style: sans(14, color: YoColors.inkSoft))),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: s == null
                ? _summary()
                : _loading
                ? const Center(child: CircularProgressIndicator())
                : Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16), child: _body(s)),
          ),
        ),
      ),
    );
  }

  Widget _body(_Schritt s) {
    final progress = AppScope.of(context).progress;
    final st = progress.schreiben;
    final k = s.karte;
    Widget writer({required bool vorlage}) => Expanded(
      child: WortSchreiber(
        key: ValueKey('${k.key}-$_pos-$_phase'),
        wort: k.text,
        striche: _striche,
        vorlage: vorlage,
        nurStift: st.stiftGesehen,
        onStift: st.stift,
        hilfe: _hilfe,
        onFertig: _geschrieben,
      ),
    );

    switch ((s.art, _phase)) {
      // --- Wiederholung -----------------------------------------------------
      case (_Art.wiederholung, 0):
        return _lesungWaehlen(k.wort!);
      case (_Art.wiederholung, 1):
        return Column(
          children: [
            _prompt(k, lesung: true, label: k.kanji != null ? 'Schreibe das Kanji' : 'Schreibe das Wort'),
            const SizedBox(height: 12),
            writer(vorlage: false),
          ],
        );
      case (_Art.wiederholung, _):
        return _ergebnis(k);

      // --- Neues Kanji ------------------------------------------------------
      case (_Art.kanjiNeu, 0):
        return _kanjiVorstellung(k.kanji!);
      case (_Art.kanjiNeu, 1):
        return Column(
          children: [
            _prompt(k, lesung: true, label: 'Neues Kanji · Nachfahren'),
            const SizedBox(height: 12),
            writer(vorlage: true),
          ],
        );
      case (_Art.kanjiNeu, 2):
        return Column(
          children: [
            _prompt(k, lesung: true, label: 'Neues Kanji · Jetzt aus dem Kopf'),
            const SizedBox(height: 12),
            writer(vorlage: false),
          ],
        );
      case (_Art.kanjiNeu, _):
        return _ergebnis(k, neu: true);

      // --- Neues Wort -------------------------------------------------------
      case (_Art.wortNeu, 0):
        return _wortVorstellung(k.wort!);
      case (_Art.wortNeu, _):
        return Column(
          children: [
            _prompt(k, lesung: true, label: 'Neues Wort · Nachschreiben'),
            const SizedBox(height: 12),
            writer(vorlage: true),
          ],
        );
    }
    return const SizedBox.shrink();
  }

  /// Bedeutung, Lesung und Satz über dem Schreibfeld.
  Widget _prompt(SchreibKarte k, {required bool lesung, required String label}) {
    final info = _infos[k.kanji];
    final w = k.wort;
    return Column(
      children: [
        Text(label, style: sans(13.5, weight: 650, color: YoColors.inkSoft)),
        const SizedBox(height: 6),
        Text(_bedeutung(k), style: serif(26, weight: 460), textAlign: TextAlign.center, maxLines: 2),
        if (lesung && w != null) Text(w.r, style: jp(22, color: YoColors.inkSoft)),
        if (lesung && info != null)
          Text(
            [if (info.on.isNotEmpty) info.on.take(2).join('、'), if (info.kun.isNotEmpty) info.kun.take(2).join('、')].join('　·　'),
            style: jp(19, color: YoColors.inkSoft),
          ),
        if (w?.satz case final satz? when satz.contains(w!.t)) ...[
          const SizedBox(height: 6),
          Text(satz.replaceAll(w.t, '＿' * w.t.length), style: jp(17, color: YoColors.inkSoft), textAlign: TextAlign.center),
        ],
      ],
    );
  }

  Widget _lesungWaehlen(SchreibWort w) {
    return Column(
      children: [
        Text('Wie liest man das Wort?', style: sans(13.5, weight: 650, color: YoColors.inkSoft)),
        const SizedBox(height: 6),
        Text(w.bedeutung, style: serif(28, weight: 460), textAlign: TextAlign.center),
        if (w.satz case final satz? when satz.contains(w.t)) ...[
          const SizedBox(height: 8),
          Text(satz.replaceAll(w.t, '＿' * w.t.length), style: jp(18, color: YoColors.inkSoft), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 24),
        for (final o in _auswahl)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: _gewaehlt == null
                      ? null
                      : o == w.r
                      ? YoColors.vanillaIce
                      : null,
                  side: BorderSide(
                    color: _gewaehlt != null && o == w.r ? YoColors.chocolate : YoColors.woodAsh,
                    width: _gewaehlt != null && o == w.r ? 2 : 1,
                  ),
                ),
                onPressed: _gewaehlt != null
                    ? null
                    : () {
                        final right = o == w.r;
                        setState(() {
                          _gewaehlt = o;
                          _lesungFalsch = !right;
                        });
                        if (right) {
                          Timer(const Duration(milliseconds: 500), () {
                            if (mounted && _phase == 0) setState(() => _phase = 1);
                          });
                        }
                      },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      o,
                      style: jp(22, color: _gewaehlt != null && o == _gewaehlt && o != w.r ? YoColors.inkSoft : null).copyWith(
                        decoration: _gewaehlt != null && o == _gewaehlt && o != w.r ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (_gewaehlt != null && o == w.r) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_rounded, color: YoColors.chocolate),
                    ],
                  ],
                ),
              ),
            ),
          ),
        if (_lesungFalsch) ...[
          const SizedBox(height: 8),
          Text('Richtig ist ${w.r}. Die Karte kommt bald wieder.', style: sans(15)),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => setState(() => _phase = 1), child: const Text('Weiter zum Schreiben')),
        ],
      ],
    );
  }

  Widget _kanjiVorstellung(String kanji) {
    final scope = AppScope.of(context);
    return Column(
      children: [
        Text('Neues Kanji · ${_neueKanji + 1}', style: sans(13.5, weight: 650, color: YoColors.inkSoft)),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: KanjiDetails(
              key: ValueKey(kanji),
              kanji: kanji,
              info: _infos[kanji],
              partInfo: _partInfo,
              partNames: _partNames,
              repo: scope.repo,
              progress: scope.progress,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: () => setState(() => _phase = 1), child: const Text('Nachfahren')),
        ),
      ],
    );
  }

  Widget _wortVorstellung(SchreibWort w) {
    final scope = AppScope.of(context);
    return Column(
      children: [
        Text('Neues Wort', style: sans(13.5, weight: 650, color: YoColors.inkSoft)),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 18),
                Text(w.t, style: kanjiStyle(64)),
                Text(w.r, style: jp(24, color: YoColors.inkSoft)),
                const SizedBox(height: 8),
                Text(w.bedeutung, style: serif(24, weight: 460), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                IconButton.filledTonal(
                  tooltip: 'Aussprache',
                  onPressed: () => _play(w),
                  icon: const Icon(Icons.volume_up_rounded),
                ),
                if (w.satz case final satz?) ...[
                  const SizedBox(height: 14),
                  Text.rich(highlighted(satz, w.t, size: 19), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 18),
                KanjiButtons(word: w.t, repo: scope.repo, progress: scope.progress, center: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: () => setState(() => _phase = 1), child: const Text('Nachschreiben')),
        ),
      ],
    );
  }

  Widget _ergebnis(SchreibKarte k, {bool neu = false}) {
    final now = DateTime.now();
    final w = k.wort;
    final (titel, text) = switch (_rating) {
      fsrs.Rating.good || fsrs.Rating.easy => ('Gut geschrieben', _fehler == 0 ? 'Alle Striche richtig.' : 'Ein Strich daneben.'),
      fsrs.Rating.hard => ('Mit etwas Hilfe', _hinweis > 0 ? 'Mit Hinweis geschrieben.' : '$_fehler Striche daneben.'),
      _ => ('Nochmal üben', _lesungFalsch ? 'Die Lesung war nicht richtig.' : 'Das Zeichen sitzt noch nicht.'),
    };
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(titel, style: serif(26, weight: 460)),
                const SizedBox(height: 4),
                Text(
                  [
                    text,
                    if (_karte case final c?) 'Kommt ${wannWieder(c, now)} wieder.',
                    if (neu && _karte == null) 'Du übst es gleich mit dem Wort.',
                  ].join(' '),
                  style: sans(15, color: YoColors.inkSoft),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Text(k.text, style: kanjiStyle(72)),
                if (w != null) ...[
                  Text(w.r, style: jp(22, color: YoColors.inkSoft)),
                  const SizedBox(height: 6),
                  Text(w.bedeutung, style: sans(18, weight: 560), textAlign: TextAlign.center),
                  IconButton.filledTonal(
                    tooltip: 'Aussprache',
                    onPressed: () => _play(w),
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
                  if (w.satz case final satz?) ...[
                    const SizedBox(height: 10),
                    Text.rich(highlighted(satz, w.t, size: 18), textAlign: TextAlign.center),
                  ],
                ] else
                  Text(_bedeutung(k), style: sans(18, weight: 560)),
              ],
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _weiter, child: const Text('Weiter')),
        ),
      ],
    );
  }

  Widget _summary() {
    final st = AppScope.of(context).progress.schreiben;
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_queue.isEmpty ? 'Heute ist nichts mehr dran' : 'Geschafft für heute', style: serif(28, weight: 460)),
          const SizedBox(height: 10),
          Text(
            [
              if (_neueKanji > 0) '$_neueKanji neue Kanji',
              if (_neueWoerter > 0) '$_neueWoerter neue Wörter',
              if (_wiederholt > 0) '$_wiederholt Wiederholungen',
            ].join(' · '),
            style: sans(16, color: YoColors.inkSoft),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (neueKanjiHeute(st, now) == 0 && !isSunday(now))
            OutlinedButton(
              onPressed: () {
                st.mehrKanji(now, st.tagesziel);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(builder: (_) => SchreibSitzung(plan: widget.plan, alle: widget.alle)),
                );
              },
              child: Text('Noch ${st.tagesziel} Kanji lernen'),
            ),
          const SizedBox(height: 10),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fertig')),
        ],
      ),
    );
  }
}

bool isSunday(DateTime d) => d.weekday == DateTime.sunday;
