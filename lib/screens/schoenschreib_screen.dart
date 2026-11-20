import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../learn/schoenschrift.dart';
import '../learn/strich_pruefung.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import '../widgets/lern_pause.dart';
import '../widgets/schoenschrift_kachel.dart';
import '../widgets/schreibfeld.dart';

/// Schönschreiben (Spezifikation 19): ein Zeichen in Ruhe immer wieder
/// schreiben, mit Pinselstrich und Vergleich mit der Vorlage – ohne Bewertung
/// für die Wiederholung. Die Strichfolge wird trotzdem geprüft.
class SchoenschreibScreen extends StatefulWidget {
  const SchoenschreibScreen({super.key, required this.zeichen, required this.paths, this.bedeutung});
  final String zeichen;
  final List<String> paths;
  final String? bedeutung;

  @override
  State<SchoenschreibScreen> createState() => _SchoenschreibScreenState();
}

class _SchoenschreibScreenState extends State<SchoenschreibScreen> {
  var _feld = GlobalKey<SchreibfeldState>();
  var _vorlage = true;
  ZeichenNote? _note;
  int? _beste;
  var _versuche = 0;
  String? _meldung;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onStrich(StrichErgebnis r) => setState(() {
    _meldung = switch (r.urteil) {
      StrichUrteil.richtig => null,
      StrichUrteil.richtung => 'Andersherum: Der Strich beginnt am anderen Ende.',
      StrichUrteil.reihenfolge => 'Dieser Strich kommt erst später.',
      StrichUrteil.falsch => 'Nicht ganz – versuch es nochmal.',
    };
  });

  void _fertig(int _) {
    final note = _feld.currentState?.bewerte(widget.zeichen);
    if (note == null) return;
    // Den letzten Strich kurz stehen lassen, dann der Vergleich.
    _timer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _note = note;
        _versuche++;
        _beste = max(_beste ?? 0, note.note);
        _meldung = null;
      });
    });
  }

  void _nochmal() {
    _timer?.cancel();
    setState(() {
      _note = null;
      _meldung = null;
      _feld = GlobalKey<SchreibfeldState>();
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context).progress.schreiben;
    final note = _note;
    return LernPause(
      child: Scaffold(
        appBar: AppBar(title: Text('Schönschreiben · ${widget.zeichen}')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  children: [
                    if (widget.bedeutung case final b?) Text(b, style: serif(22, weight: 460), textAlign: TextAlign.center),
                    Text(
                      note == null
                          ? 'Langsam und bewusst: Lage, Länge und Schwung jedes Strichs zählen.'
                          : '${note.urteil} · Schönschrift ${note.note}',
                      style: note == null ? sans(14, color: YoColors.inkSoft) : sans(17, weight: 650),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: note == null
                              ? Schreibfeld(
                                  key: _feld,
                                  paths: widget.paths,
                                  vorlage: _vorlage,
                                  pinsel: st.pinsel,
                                  nurStift: st.stiftGesehen,
                                  onStift: st.stift,
                                  onStrich: _onStrich,
                                  onFertig: _fertig,
                                )
                              : LayoutBuilder(
                                  builder: (context, c) => SchoenschriftKachel(note: note, size: c.biggest.shortestSide, mitText: false),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 26,
                      child: Center(
                        child: Text(
                          note == null
                              ? _meldung ?? ''
                              : note.alleGut
                              ? 'Alle Striche nah an der Vorlage.'
                              : 'Strich ${note.schlechtester + 1}: ${note.hinweise[note.schlechtester]}',
                          style: sans(14.5, color: YoColors.inkSoft),
                        ),
                      ),
                    ),
                    if (note == null)
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              _feld.currentState?.rueckgaengig();
                              setState(() => _meldung = null);
                            },
                            icon: const Icon(Icons.undo_rounded),
                            label: const Text('Rückgängig'),
                          ),
                          TextButton.icon(
                            onPressed: _nochmal,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Neu'),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Vorlage', style: sans(14.5)),
                              Switch(value: _vorlage, onChanged: (v) => setState(() => _vorlage = v)),
                            ],
                          ),
                        ],
                      )
                    else
                      FilledButton.icon(
                        onPressed: _nochmal,
                        icon: const Icon(Icons.brush_outlined),
                        label: const Text('Nochmal'),
                      ),
                    if (_versuche > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Beste Note: $_beste · $_versuche ${_versuche == 1 ? 'Versuch' : 'Versuche'}',
                        style: sans(13.5, color: YoColors.inkSoft),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
