import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

import '../app_scope.dart';
import '../audio/player.dart';
import '../data/audio_key.dart';
import '../data/models.dart';
import '../data/schreib_plan.dart';
import '../learn/review.dart' show review;
import '../learn/schoenschrift.dart';
import '../learn/schreiben.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import '../widgets/beispiel_satz.dart';
import '../widgets/kanji_card.dart';
import '../widgets/lern_pause.dart';
import '../widgets/schoenschrift_kachel.dart';
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
  const _Schritt(this.art, this.karte, {this.nochmal = false});
  final _Art art;
  final SchreibKarte karte;

  /// Kommt in dieser Runde nochmal dran (Lernschritt) – zählt nicht mit.
  final bool nochmal;
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

  /// Schönschrift-Vergleich der zuletzt geschriebenen Zeichen.
  List<ZeichenNote> _noten = const [];

  int _wiederholt = 0;
  int _neueKanji = 0;
  int _neueWoerter = 0;

  /// Vorlesen: beim Schreiben in Dauerschleife, danach einmal Wort und Satz.
  Schleife? _schleife;
  Future<List<TextEntry>>? _index;
  final Map<String, String?> _satzAudio = {};

  /// Beispielsätze der Teeküche (Spezifikation 19, Stufe 2), je Wort.
  final Map<String, Beispiel?> _beispiele = {};

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

  /// Fortschritt ohne die Karten, die nochmal drankommen: Die Zahl wächst nicht.
  int get _gesamt => _queue.where((s) => !s.nochmal).length;
  int get _erledigt => _queue.take(_pos).where((s) => !s.nochmal).length;

  @override
  void dispose() {
    _schleife?.stop();
    super.dispose();
  }

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
    if (s.karte.wort case final w? when !_beispiele.containsKey(w.key)) {
      _beispiele[w.key] = await repo.beispiel(w.t, w.r);
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
    if (s.karte.wort case final w?) _satzUrl(w);
    if (s.art == _Art.wortNeu && !_pause) _play(s.karte.wort!);
    _ton();
  }

  bool get _pause => AppScope.of(context).progress.lernUhr.pausiert(DateTime.now());

  Vortrag _vortrag(SchreibWort w) =>
      (url: AppScope.of(context).repo.audioUrl(wordAudioPath(Token(t: w.t, r: w.r))), text: w.r);

  void _play(SchreibWort w) {
    _schleife?.stop();
    final v = _vortrag(w);
    playClip(v.url, sprich: v.text);
  }

  /// Die Aufnahme des Satzes, in dem ich das Wort gelesen habe.
  Future<void> _satzUrl(SchreibWort w) async {
    if (w.textId == null || w.satz == null || _satzAudio.containsKey(w.key)) return;
    _satzAudio[w.key] = null;
    try {
      final repo = AppScope.of(context).repo;
      final index = await (_index ??= repo.index());
      final e = index.where((e) => e.id == w.textId).firstOrNull;
      if (e == null) return;
      final doc = await repo.text(e.folder);
      final s = doc.sentences.where((s) => s.plain == w.satz).firstOrNull;
      if (s?.audio case final a?) _satzAudio[w.key] = repo.audioUrl('${doc.folder}/$a');
    } catch (_) {
      // Ohne Aufnahme liest die Sprachausgabe den Satz.
    }
  }

  /// Was beim Schreiben immer wieder vorgelesen wird: das Wort – bei einem
  /// Kanji seine ersten Wörter (oder eine Lesung, wenn es keine gibt).
  List<Vortrag> _stuecke(SchreibKarte k) {
    if (k.wort case final w?) return [_vortrag(w)];
    final kanji = k.kanji!;
    final woerter = [
      for (final w in widget.alle)
        if (w.kanji.contains(kanji)) w,
    ].take(3);
    if (woerter.isNotEmpty) return [for (final w in woerter) _vortrag(w)];
    final info = _infos[kanji];
    final lesung = [...?info?.kun, ...?info?.on].map((r) => r.replaceAll('.', '').replaceAll('-', '')).firstOrNull;
    return lesung == null || lesung.isEmpty ? const [] : [(url: '', text: lesung)];
  }

  bool get _schreibt => switch ((_step?.art, _phase)) {
    (_Art.wiederholung, 1) || (_Art.kanjiNeu, 1) || (_Art.kanjiNeu, 2) || (_Art.wortNeu, 1) => true,
    _ => false,
  };

  /// Ton passend zur Phase: beim Schreiben die Schleife, sonst still.
  void _ton() {
    _schleife?.stop();
    _schleife = null;
    final s = _step;
    if (s == null || _loading || !_schreibt || _pause) return;
    if (!AppScope.of(context).progress.schreiben.vorlesen) return;
    _schleife = Schleife(_stuecke(s.karte))..start();
  }

  void _zu(int phase) {
    setState(() => _phase = phase);
    _ton();
  }

  /// Fertig geschrieben: einmal das Wort und den Beispielsatz.
  void _nachSchreiben(SchreibKarte k) {
    _schleife?.stop();
    _schleife = null;
    final w = k.wort;
    if (w == null || _pause) return;
    final satz = w.satz;
    final b = _beispiele[w.key];
    final repo = AppScope.of(context).repo;
    _schleife = Schleife([
      _vortrag(w),
      if (satz != null && satz.isNotEmpty)
        (url: _satzAudio[w.key] ?? '', text: satz)
      else if (b != null)
        (url: repo.audioUrl(satzAudioPath(b.ruby)), text: b.text),
    ], endlos: false)..start();
  }

  void _weiter() {
    _schleife?.stop();
    _schleife = null;
    // Zwischen zwei Karten: Sind 20 Minuten um, kommt jetzt die Pause.
    AppScope.of(context).progress.lernUhr.pruefe(DateTime.now());
    setState(() {
      _pos++;
      _phase = 0;
      _gewaehlt = null;
      _lesungFalsch = false;
      _rating = null;
      _karte = null;
      _fehler = 0;
      _hinweis = 0;
      _noten = const [];
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
      _queue.insert(at, _Schritt(_Art.wiederholung, k, nochmal: true));
    }
    return card;
  }

  void _geschrieben(int fehler, int hinweis, List<ZeichenNote> noten) {
    final s = _step!;
    _noten = noten;
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
        _nachSchreiben(s.karte);
      case _Art.kanjiNeu when _phase == 1:
        _zu(2);
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
        _schleife?.stop();
      case _Art.wortNeu:
        final card = _save(s.karte, fsrs.Rating.good);
        setState(() {
          _neueWoerter++;
          _rating = fsrs.Rating.good;
          _karte = card;
          _fehler = fehler;
          _hinweis = hinweis;
          _phase = 2;
        });
        _nachSchreiben(s.karte);
    }
  }

  Future<void> _hilfe(String kanji) {
    final scope = AppScope.of(context);
    return showKanjiCard(context, kanji: kanji, repo: scope.repo, progress: scope.progress, kompakt: true);
  }

  String _bedeutung(SchreibKarte k) {
    if (k.wort case final w?) return _wb(w);
    final info = _infos[k.kanji];
    return info?.de ?? info?.meanings.take(2).join(', ') ?? '';
  }

  /// Bedeutung eines Wortes: deutsch aus dem Plan, sonst aus dem Beispielsatz, sonst englisch.
  String _wb(SchreibWort w) => w.de ?? _beispiele[w.key]?.bedeutung ?? w.en;

  /// Satz zum Wort: mein Satz aus dem Text, sonst der Beispielsatz der Teeküche.
  /// [luecke]: Das Wort steht als Lücke da (beim Schreiben aus dem Kopf, bei der Lesungsfrage).
  Widget? _satz(SchreibWort w, {required bool luecke, double size = 18}) {
    if (w.satz case final satz? when satz.contains(w.t)) {
      return luecke
          ? Text(
              verdecke(satz.replaceAll(w.t, '＿' * w.t.length), w.t),
              style: jp(size, color: YoColors.inkSoft),
              textAlign: TextAlign.center,
            )
          : Text.rich(highlighted(satz, w.t, size: size), textAlign: TextAlign.center);
    }
    if (_beispiele[w.key] case final b?) {
      return BeispielSatz(beispiel: b, wort: w.t, luecke: luecke, fontSize: size);
    }
    if (w.satz case final satz? when !luecke) {
      return Text.rich(highlighted(satz, w.t, size: size), textAlign: TextAlign.center);
    }
    return null;
  }

  String get _zaehler {
    final s = _step!;
    if (s.nochmal) return _erledigt >= _gesamt ? 'Nochmal · noch ${_queue.length - _pos}' : 'Nochmal';
    return '${_erledigt + 1} von $_gesamt';
  }

  @override
  Widget build(BuildContext context) {
    final s = _step;
    final st = AppScope.of(context).progress.schreiben;
    return LernPause(
      onEnde: _ton,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kanji schreiben'),
          actions: [
            IconButton(
              tooltip: st.vorlesen ? 'Vorlesen aus' : 'Vorlesen an',
              onPressed: () {
                st.setVorlesen(!st.vorlesen);
                setState(() {});
                _ton();
              },
              icon: Icon(st.vorlesen ? Icons.volume_up_rounded : Icons.volume_off_rounded),
            ),
            if (s != null)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: Text(_zaehler, style: sans(14, color: YoColors.inkSoft))),
              ),
          ],
          bottom: s == null
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _gesamt == 0 ? 0 : _erledigt / _gesamt,
                    minHeight: 3,
                    backgroundColor: YoColors.sand,
                    color: YoColors.chocolate,
                  ),
                ),
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
        pinsel: st.pinsel,
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
      case (_Art.wortNeu, 1):
        return Column(
          children: [
            _prompt(k, lesung: true, label: 'Neues Wort · Nachschreiben'),
            const SizedBox(height: 12),
            writer(vorlage: true),
          ],
        );
      case (_Art.wortNeu, _):
        return _ergebnis(k, neuesWort: true);
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
        Text(verdecke(_bedeutung(k), k.text), style: serif(26, weight: 460), textAlign: TextAlign.center, maxLines: 2),
        if (lesung && w != null) Text(w.r, style: jp(22, color: YoColors.inkSoft)),
        if (lesung && info != null)
          Text(
            [if (info.on.isNotEmpty) info.on.take(2).join('、'), if (info.kun.isNotEmpty) info.kun.take(2).join('、')].join('　·　'),
            style: jp(19, color: YoColors.inkSoft),
          ),
        if (w != null)
          if (_satz(w, luecke: true, size: 17) case final satz?) ...[const SizedBox(height: 6), satz],
      ],
    );
  }

  Widget _lesungWaehlen(SchreibWort w) {
    return Column(
      children: [
        Text('Wie liest man das Wort?', style: sans(13.5, weight: 650, color: YoColors.inkSoft)),
        const SizedBox(height: 6),
        Text(verdecke(_wb(w), w.t), style: serif(28, weight: 460), textAlign: TextAlign.center),
        if (_satz(w, luecke: true) case final satz?) ...[const SizedBox(height: 8), satz],
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
                            if (mounted && _phase == 0) _zu(1);
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
          FilledButton(onPressed: () => _zu(1), child: const Text('Weiter zum Schreiben')),
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
          child: FilledButton(onPressed: () => _zu(1), child: const Text('Nachfahren')),
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
                Text(_wb(w), style: serif(24, weight: 460), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                IconButton.filledTonal(
                  tooltip: 'Wort und Satz vorlesen',
                  onPressed: () => _nachSchreiben(SchreibKarte.wort(w)),
                  icon: const Icon(Icons.volume_up_rounded),
                ),
                if (_satz(w, luecke: false, size: 19) case final satz?) ...[const SizedBox(height: 14), satz],
                const SizedBox(height: 18),
                KanjiButtons(word: w.t, repo: scope.repo, progress: scope.progress, center: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: () => _zu(1), child: const Text('Nachschreiben')),
        ),
      ],
    );
  }

  Widget _ergebnis(SchreibKarte k, {bool neu = false, bool neuesWort = false}) {
    final now = DateTime.now();
    final w = k.wort;
    final (titel, text) = switch (_rating) {
      _ when neuesWort => ('Neues Wort geschrieben', ''),
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
                    if (text.isNotEmpty) text,
                    if (_karte case final c?) 'Kommt ${wannWieder(c, now)} wieder.',
                    if (neu && _karte == null) 'Du übst es gleich mit dem Wort.',
                  ].join(' '),
                  style: sans(15, color: YoColors.inkSoft),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                if (_noten.isNotEmpty) ...[
                  SchoenschriftReihe(noten: _noten),
                  const SizedBox(height: 14),
                  Text(k.text, style: kanjiStyle(48)),
                ] else
                  Text(k.text, style: kanjiStyle(72)),
                if (w != null) ...[
                  Text(w.r, style: jp(22, color: YoColors.inkSoft)),
                  const SizedBox(height: 6),
                  Text(_wb(w), style: sans(18, weight: 560), textAlign: TextAlign.center),
                  IconButton.filledTonal(
                    tooltip: 'Wort und Satz vorlesen',
                    onPressed: () => _nachSchreiben(k),
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
                  if (_satz(w, luecke: false) case final satz?) ...[const SizedBox(height: 10), satz],
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
