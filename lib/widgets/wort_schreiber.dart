import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../learn/strich_pruefung.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import 'kanji_card.dart';
import 'schreibfeld.dart';

/// Schreibt ein ganzes Wort Zeichen für Zeichen, so wie es im Text steht:
/// Kanji und Kana (Okurigana) (Spezifikation 19).
///
/// Hinweise in drei Stufen: 1 Bausteine und meine Geschichte (nur bei Kanji),
/// 2 der nächste Strich blass mit Anfangspunkt, 3 das ganze Zeichen blass.
class WortSchreiber extends StatefulWidget {
  const WortSchreiber({
    super.key,
    required this.wort,
    required this.striche,
    required this.onFertig,
    this.vorlage = false,
    this.nurStift = false,
    this.onStift,
    this.hilfe,
  });

  final String wort;

  /// Striche je Zeichen; Zeichen ohne Striche stehen schon da.
  final Map<String, List<String>> striche;

  /// Nachschreiben mit Vorlage (beim ersten Mal).
  final bool vorlage;
  final bool nurStift;
  final VoidCallback? onStift;

  /// Hinweis 1 bei einem Kanji: Bausteine und Geschichte zeigen.
  final Future<void> Function(String kanji)? hilfe;

  /// Das Wort ist fertig: falsche Striche und höchste Hinweisstufe.
  final void Function(int fehler, int hinweis) onFertig;

  @override
  State<WortSchreiber> createState() => _WortSchreiberState();
}

class _WortSchreiberState extends State<WortSchreiber> {
  late List<String> _chars;
  int _i = 0;
  int _fehler = 0;
  int _hinweisMax = 0;
  int _hinweis = 0;
  int _miss = 0;
  bool _fertig = false;
  String? _meldung;
  Timer? _timer;

  /// Zähler für „Zeichen neu“: ein neuer Schlüssel baut das Feld neu.
  int _neu = 0;

  bool _writable(int i) => widget.striche[_chars[i]]?.isNotEmpty == true;
  bool _isKanji(String c) => isKanji(c) && c != '々';

  @override
  void initState() {
    super.initState();
    _chars = widget.wort.split('');
    _i = _firstFrom(0);
    if (_i >= _chars.length) {
      _fertig = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFertig(0, 0));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _firstFrom(int i) {
    while (i < _chars.length && !_writable(i)) {
      i++;
    }
    return i;
  }

  void _onStrich(StrichErgebnis r) {
    setState(() {
      switch (r.urteil) {
        case StrichUrteil.richtig:
          _meldung = null;
          _miss = 0;
        case StrichUrteil.richtung:
          _meldung = 'Andersherum: Der Strich beginnt am anderen Ende.';
        case StrichUrteil.reihenfolge:
          _meldung = 'Dieser Strich kommt erst später.';
        case StrichUrteil.falsch:
          _meldung = 'Nicht ganz – versuch es nochmal.';
      }
      if (r.urteil != StrichUrteil.richtig) {
        _miss++;
        _fehler++;
      }
      // Ab zwei Fehlversuchen zeigt das Feld den Strich blass: wie Hinweis 2.
      if (_miss >= 2) _hinweisMax = max(_hinweisMax, 2);
    });
  }

  void _onZeichen(int _) {
    _timer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      final next = _firstFrom(_i + 1);
      setState(() {
        _i = next;
        _hinweis = 0;
        _miss = 0;
        _meldung = null;
        _fertig = next >= _chars.length;
      });
      if (_fertig) widget.onFertig(_fehler, _hinweisMax);
    });
  }

  Future<void> _hint() async {
    if (_fertig) return;
    final c = _chars[_i];
    var level = _hinweis + 1;
    if (level == 1 && (!_isKanji(c) || widget.hilfe == null)) level = 2;
    if (level > 3) return;
    setState(() {
      _hinweis = level;
      _hinweisMax = max(_hinweisMax, level);
    });
    if (level == 1) await widget.hilfe!(c);
  }

  String get _hintLabel => switch (_hinweis) {
    0 => 'Hinweis',
    1 => 'Nächster Strich',
    2 => 'Ganzes Zeichen',
    _ => 'Ganzes Zeichen',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < _chars.length; i++)
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == _i && !_fertig ? YoColors.brightWhite : YoColors.vanillaIce,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(
                    color: i == _i && !_fertig ? YoColors.chocolate : YoColors.woodAsh,
                    width: i == _i && !_fertig ? 2 : 1,
                  ),
                ),
                child: i < _i || _fertig || !_writable(i) ? Text(_chars[i], style: kanjiStyle(30)) : null,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: _fertig
                  ? Container(
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: YoColors.brightWhite, borderRadius: organicRadius),
                      child: FittedBox(child: Text(widget.wort, style: kanjiStyle(72))),
                    )
                  : Schreibfeld(
                      key: ValueKey('${widget.wort}-$_i-$_neu'),
                      paths: widget.striche[_chars[_i]]!,
                      vorlage: widget.vorlage,
                      hinweis: _hinweis,
                      nurStift: widget.nurStift,
                      onStift: widget.onStift,
                      onStrich: _onStrich,
                      onFertig: _onZeichen,
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 26,
          child: Center(child: Text(_meldung ?? '', style: sans(14.5, color: YoColors.inkSoft))),
        ),
        if (!_fertig)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!widget.vorlage)
                TextButton.icon(
                  onPressed: _hinweis >= 3 ? null : _hint,
                  icon: const Icon(Icons.lightbulb_outline_rounded),
                  label: Text(_hintLabel),
                ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _neu++;
                  _miss = 0;
                }),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Zeichen neu'),
              ),
            ],
          ),
      ],
    );
  }
}
