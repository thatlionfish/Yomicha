import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/progress.dart';
import '../data/stufen.dart';
import '../learn/einstufung.dart';
import '../learn/einstufung_daten.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import '../widgets/furigana.dart';

/// Einstufung zu Beginn (Spezifikation 9.2): Wortschatz-Check, bis zu drei
/// Mini-Texte, dann die Startstufe mit Begründung.
class EinstufungScreen extends StatefulWidget {
  const EinstufungScreen({super.key, this.woerter = einstufungWoerter, this.texte = einstufungTexte});
  final List<PruefWort> woerter;
  final List<MiniText> texte;

  @override
  State<EinstufungScreen> createState() => _EinstufungScreenState();
}

enum _Phase { start, woerter, texte, ergebnis }

/// Nach einer JLPT-Stufe mit weniger als 40 % bekannt: die schwereren auslassen.
const _abbruch = 0.4;

class _EinstufungScreenState extends State<EinstufungScreen> {
  var _phase = _Phase.start;

  // Wortschatz
  late final List<PruefWort> _words = [
    for (final j in [5, 4, 3, 2]) ...([for (final w in widget.woerter) if (w.jlpt == j) w]..shuffle(Random(j))),
  ];
  var _i = 0;
  final _answers = <WortAntwort>[];
  List<String>? _check;
  String? _checkChosen;

  // Texte
  var _t = 0;
  final _texts = <TextAntwort>[];
  final _watch = Stopwatch();
  var _read = false;
  double _cpm = 0;
  final _chosen = <int, int>{};
  List<List<String>> _options = const [];

  int? _picked;

  PruefWort get _word => _words[_i];
  MiniText get _text => widget.texte[_t];

  // --- Wortschatz ---------------------------------------------------------

  /// Jedes vierte Wort: Wer „kenne ich“ sagt, wählt die Bedeutung.
  bool get _isCheck => (_i + 1) % 4 == 0;

  void _know(bool known) {
    if (known && _isCheck) {
      final others = [for (final w in _words) if (w.jlpt == _word.jlpt && w != _word) w.de]..shuffle(Random(_i));
      setState(() => _check = [_word.de, ...others.take(3)]..shuffle(Random(_i + 100)));
      return;
    }
    _answers.add(WortAntwort(jlpt: _word.jlpt, kenne: known));
    _nextWord();
  }

  void _checkAnswer(String de) {
    if (_checkChosen != null) return;
    setState(() => _checkChosen = de);
    _answers.add(WortAntwort(jlpt: _word.jlpt, kenne: true, geprueft: de == _word.de));
  }

  void _nextWord() {
    final level = _word.jlpt;
    setState(() {
      _check = null;
      _checkChosen = null;
      _i++;
      final levelDone = _i >= _words.length || _words[_i].jlpt != level;
      if (_i >= _words.length || (levelDone && knownShare(_answers, level) < _abbruch)) _startTexts();
    });
  }

  // --- Texte ----------------------------------------------------------------

  void _startTexts() {
    _phase = _Phase.texte;
    _t = 0;
    _beginText();
  }

  void _beginText() {
    _read = false;
    _chosen.clear();
    _options = [
      for (final (q, f) in _text.fragen.indexed) [...f.antworten]..shuffle(Random(_t * 10 + q)),
    ];
    _watch
      ..reset()
      ..start();
  }

  void _doneReading() {
    _watch.stop();
    final minutes = max(_watch.elapsedMilliseconds, 1000) / 60000;
    setState(() {
      _read = true;
      _cpm = _text.chars / minutes;
    });
  }

  void _nextText() {
    final right = [
      for (final (q, f) in _text.fragen.indexed)
        if (_options[q][_chosen[q]!] == f.antworten.first) q,
    ].length;
    final result = TextAntwort(jlpt: _text.jlpt, richtig: right, fragen: _text.fragen.length, zeichenProMinute: _cpm);
    setState(() {
      _texts.add(result);
      if (!result.verstanden || _t + 1 >= widget.texte.length) {
        _phase = _Phase.ergebnis;
      } else {
        _t++;
        _beginText();
      }
    });
  }

  // --- Oberfläche -----------------------------------------------------------

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Einstufung')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: switch (_phase) {
          _Phase.start => _start(),
          _Phase.woerter => _wordView(),
          _Phase.texte => _textView(),
          _Phase.ergebnis => _result(context),
        },
      ),
    ),
  );

  Widget _start() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
    children: [
      Text('Welche Stufe passt zu dir?', style: serif(26)),
      const SizedBox(height: 12),
      for (final (n, line) in [
        ('1', 'Wortschatz: ${_words.length} Wörter von N5 bis N2. Sag ehrlich, ob du sie kennst, also Lesung und Bedeutung. Ab und zu fragt die App die Bedeutung nach.'),
        ('2', 'Lesen: bis zu drei kurze Texte (N4, N3, N2) mit je zwei Fragen. Die Lesezeit wird gemessen, ohne Vorlesen.'),
        ('3', 'Ergebnis: deine Startstufe mit Begründung. Du kannst sie ändern.'),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 26, child: Text(n, style: sans(16, weight: 700, color: YoColors.inkSoft))),
              Expanded(child: Text(line, style: sans(16, height: 1.45))),
            ],
          ),
        ),
      const SizedBox(height: 6),
      Text('Dauer: etwa 10 Minuten. Brichst du ab, bleibt alles, wie es war.', style: sans(14, color: YoColors.inkSoft)),
      const SizedBox(height: 22),
      FilledButton(
        onPressed: () => setState(() => _phase = _Phase.woerter),
        child: const Text('Los geht’s'),
      ),
    ],
  );

  Widget _wordView() {
    final w = _word;
    final check = _check;
    return ListView(
      key: ValueKey('wort-$_i'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text('Wortschatz · ${_i + 1} von ${_words.length}', style: sans(14, weight: 650, color: YoColors.inkSoft)),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: (_i + 1) / _words.length, color: YoColors.chocolate, backgroundColor: YoColors.sand),
        const SizedBox(height: 40),
        Center(child: Text(w.t, style: jp(52, weight: FontWeight.w500))),
        const SizedBox(height: 40),
        if (check == null) ...[
          Text('Kennst du dieses Wort?', textAlign: TextAlign.center, style: sans(16, color: YoColors.inkSoft)),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => _know(true), child: const Text('Kenne ich')),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => _know(false), child: const Text('Kenne ich nicht')),
        ] else ...[
          Text('Was bedeutet es?', textAlign: TextAlign.center, style: sans(16, color: YoColors.inkSoft)),
          const SizedBox(height: 14),
          for (final de in check) ...[
            _option(
              child: Text(de, style: sans(17)),
              state: _checkChosen == null
                  ? _Opt.open
                  : de == w.de
                  ? _Opt.right
                  : de == _checkChosen
                  ? _Opt.wrong
                  : _Opt.other,
              onTap: () => _checkAnswer(de),
            ),
            const SizedBox(height: 10),
          ],
          if (_checkChosen != null) ...[
            const SizedBox(height: 6),
            Text('${w.t} (${w.r}) = ${w.de}', textAlign: TextAlign.center, style: jp(18)),
            const SizedBox(height: 14),
            FilledButton(onPressed: _nextWord, child: const Text('Weiter')),
          ],
        ],
      ],
    );
  }

  Widget _textView() {
    final text = _text;
    final allChosen = _chosen.length == text.fragen.length;
    return ListView(
      // Jeder Text beginnt oben.
      key: ValueKey('text-$_t'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text('Lesen · Text ${_t + 1} · ${jlptName(text.jlpt)}', style: sans(14, weight: 650, color: YoColors.inkSoft)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(color: YoColors.brightWhite, borderRadius: organicRadius),
          child: RubyText(text.text, fontSize: 20),
        ),
        const SizedBox(height: 16),
        if (!_read)
          FilledButton(onPressed: _doneReading, child: const Text('Fertig gelesen'))
        else ...[
          for (final (q, f) in text.fragen.indexed) ...[
            const SizedBox(height: 10),
            RubyText('${q + 1}. ${f.frage}', fontSize: 18),
            const SizedBox(height: 10),
            for (final (a, markup) in _options[q].indexed) ...[
              _option(
                child: RubyText(markup, fontSize: 17),
                state: _chosen[q] == null
                    ? _Opt.open
                    : markup == f.antworten.first
                    ? _Opt.right
                    : _chosen[q] == a
                    ? _Opt.wrong
                    : _Opt.other,
                onTap: () => setState(() => _chosen[q] ??= a),
              ),
              const SizedBox(height: 8),
            ],
          ],
          if (allChosen) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: _nextText, child: const Text('Weiter')),
          ],
        ],
      ],
    );
  }

  Widget _result(BuildContext context) {
    final progress = AppScope.of(context).progress;
    final ws = wortschatzStufe(_answers);
    final ls = leseStufe(_texts);
    final vorschlag = startStufe(ws, ls);
    final picked = _picked ?? vorschlag;
    final s = Stufe.of(vorschlag);
    final shares = [
      for (final j in [5, 4, 3, 2])
        if (_answers.any((a) => a.jlpt == j)) 'N$j ${(100 * knownShare(_answers, j)).round()} %',
    ];
    return ListView(
      key: const ValueKey('ergebnis'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text('Dein Ergebnis', style: serif(28)),
        const SizedBox(height: 14),
        _line('Wortschatz', 'etwa ${jlptName(ws)}', shares.join(' · ')),
        _line(
          'Lesen',
          'etwa Stufe $ls · ${Stufe.of(ls).name}',
          [
            for (final t in _texts)
              '${jlptName(t.jlpt)}: ${t.richtig} von ${t.fragen} richtig, ${t.zeichenProMinute.round()} Zeichen/Min',
          ].join('\n'),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            color: YoColors.vanillaIce,
            borderRadius: organicRadius,
            border: Border(left: BorderSide(color: YoColors.lemonGrass, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vorschlag: Stufe ${s.nr} · ${s.name} ${s.kanji}', style: serif(21)),
              const SizedBox(height: 4),
              Text(
                'Wortschatz ${jlptName(ws)} und Lesen auf Stufe $ls ergeben zusammen Stufe ${s.nr} (${s.label}). '
                'Von dort steigst du auf, sobald die Texte leicht fallen.',
                style: sans(14.5, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Mit welcher Stufe startest du?', style: sans(15, weight: 650)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final st in Stufe.all)
              ChoiceChip(
                label: Text('${st.nr} · ${st.name}'),
                selected: picked == st.nr,
                onSelected: (_) => setState(() => _picked = st.nr),
              ),
          ],
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: () {
            final now = DateTime.now();
            progress.setEinstufung(
              EinstufungErgebnis(
                day: DateTime(now.year, now.month, now.day),
                wortschatz: ws,
                lesen: ls,
                vorschlag: vorschlag,
                gewaehlt: picked,
              ),
            );
            Navigator.of(context).maybePop();
          },
          child: Text('Mit Stufe $picked starten'),
        ),
      ],
    );
  }

  Widget _line(String label, String value, String detail) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value', style: sans(17, weight: 650)),
        if (detail.isNotEmpty) Text(detail, style: sans(14, color: YoColors.inkSoft, height: 1.4)),
      ],
    ),
  );

  Widget _option({required Widget child, required _Opt state, required VoidCallback onTap}) => Material(
    color: state == _Opt.wrong ? YoColors.woodAsh : YoColors.brightWhite,
    shape: RoundedRectangleBorder(
      borderRadius: organicRadius,
      side: state == _Opt.right
          ? const BorderSide(color: YoColors.lemonGrass, width: 3)
          : const BorderSide(color: YoColors.sand, width: 1.4),
    ),
    child: InkWell(
      customBorder: const RoundedRectangleBorder(borderRadius: organicRadius),
      onTap: state == _Opt.open ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(child: child),
            if (state == _Opt.right) const Icon(Icons.check_rounded, color: YoColors.chocolate),
          ],
        ),
      ),
    ),
  );
}

enum _Opt { open, right, wrong, other }
