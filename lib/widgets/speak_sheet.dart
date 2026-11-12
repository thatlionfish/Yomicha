import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../audio/player.dart';
import '../data/models.dart';
import '../data/progress.dart';
import '../speech/assessment.dart';
import '../speech/recorder.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import 'furigana.dart';

/// Gratis-Kontingent der Spracherkennung (F0): 5 Stunden pro Monat.
const speechFreeSeconds = 5 * 60 * 60;

/// Nachsprechen mit Aussprache-Bewertung (Spezifikation 7).
Future<void> showSpeakSheet(BuildContext context, {required TextDoc doc, int start = 0}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (_) => _SpeakSheet(doc: doc, start: start),
);

enum _Phase { bereit, aufnahme, bewertung, ergebnis }

class _SpeakSheet extends StatefulWidget {
  const _SpeakSheet({required this.doc, required this.start});
  final TextDoc doc;
  final int start;

  @override
  State<_SpeakSheet> createState() => _SpeakSheetState();
}

class _SpeakSheetState extends State<_SpeakSheet> {
  late int _i = widget.start.clamp(0, widget.doc.sentences.length - 1);
  final _recorder = Recorder();
  var _phase = _Phase.bereit;
  PronunciationResult? _result;
  String? _error;
  String? _myRecording;
  Timer? _ticker;
  var _seconds = 0;

  Sentence get _sentence => widget.doc.sentences[_i];

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _go(int delta) => setState(() {
    _i = (_i + delta).clamp(0, widget.doc.sentences.length - 1);
    _phase = _Phase.bereit;
    _result = null;
    _error = null;
    _myRecording = null;
  });

  void _playModel() {
    final a = _sentence.audio;
    if (a != null) playClip(AppScope.of(context).repo.audioUrl('${widget.doc.folder}/$a'));
  }

  Future<void> _record() async {
    stopAudio();
    setState(() {
      _error = null;
      _result = null;
    });
    if (!await _recorder.start()) {
      setState(() => _error = 'Kein Zugriff auf das Mikrofon. Bitte im Browser erlauben.');
      return;
    }
    _seconds = 0;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
      if (_seconds >= 20) _stop(); // Azure nimmt kurze Aufnahmen bis ca. 60 s
    });
    setState(() => _phase = _Phase.aufnahme);
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    final progress = AppScope.of(context).progress;
    setState(() => _phase = _Phase.bewertung);
    final rec = await _recorder.stop();
    if (rec == null) {
      setState(() {
        _phase = _Phase.bereit;
        _error = 'Die Aufnahme hat nicht geklappt.';
      });
      return;
    }
    final (url, wav, secs) = rec;
    _myRecording = url;
    progress.addSpeechSeconds(secs, DateTime.now());
    try {
      final r = await assess(
        key: progress.azureKey,
        region: progress.azureRegion,
        wav: wav,
        referenceText: _sentence.plain,
      );
      if (!mounted) return;
      setState(() {
        _result = r;
        _phase = _Phase.ergebnis;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _phase = _Phase.bereit;
      });
    }
  }

  /// Lesungen der Wörter, die nicht gut klangen – für die Tipps.
  String _badReadings(PronunciationResult r) {
    final plain = _sentence.plain;
    final out = StringBuffer();
    for (final w in r.words.where((w) => w.grade != WordGrade.gut)) {
      final at = plain.indexOf(w.word);
      if (at < 0) continue;
      var pos = 0;
      for (final t in _sentence.tokens) {
        final a = pos, b = pos + t.t.length;
        pos = b;
        if (a < at + w.word.length && b > at) out.write(t.reading);
      }
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    final used = progress.speechSecondsThisMonth(DateTime.now());
    final blocked = used >= speechFreeSeconds;
    final n = widget.doc.sentences.length;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Nachsprechen', style: serif(22), maxLines: 1, overflow: TextOverflow.ellipsis)),
                IconButton(onPressed: _i > 0 ? () => _go(-1) : null, icon: const Icon(Icons.chevron_left_rounded)),
                Text('${_i + 1}/$n', style: sans(14, color: YoColors.inkSoft)),
                IconButton(onPressed: _i < n - 1 ? () => _go(1) : null, icon: const Icon(Icons.chevron_right_rounded)),
              ],
            ),
            const SizedBox(height: 8),
            FuriganaFlow(
              sentences: [(_i, _sentence.tokens)],
              fontSize: 22,
              rules: const FuriganaRules(mode: FuriganaMode.alle, userJlpt: 5),
            ),
            const SizedBox(height: 16),
            if (progress.azureKey.isEmpty)
              _note('Für die Bewertung brauche ich deinen Azure-Schlüssel (Gratis-Stufe F0). '
                  'Trage ihn auf der Startseite unter Einstellungen → Nachsprechen ein. Er bleibt nur auf diesem Gerät.')
            else if (blocked)
              _note('Das Gratis-Kontingent für diesen Monat (5 Stunden) ist aufgebraucht. '
                  'Nachsprechen geht ab dem nächsten Monat wieder – so entstehen keine Kosten.')
            else ...[
              if (used >= speechFreeSeconds * 0.8)
                _note('Achtung: ${(100 * used / speechFreeSeconds).round()} % des Gratis-Kontingents sind diesen Monat verbraucht.'),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _sentence.audio == null || _phase == _Phase.aufnahme ? null : _playModel,
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('Vorbild'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: switch (_phase) {
                      _Phase.aufnahme => FilledButton.icon(
                        onPressed: _stop,
                        icon: const Icon(Icons.stop_rounded),
                        label: Text('Fertig ($_seconds s)'),
                      ),
                      _Phase.bewertung => const FilledButton(
                        onPressed: null,
                        child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      _ => FilledButton.icon(
                        onPressed: _record,
                        icon: const Icon(Icons.mic_rounded),
                        label: Text(_result == null ? 'Aufnehmen' : 'Nochmal'),
                      ),
                    },
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              _note(_error!),
            ],
            if (_result != null) ..._results(_result!),
          ],
        ),
      ),
    );
  }

  List<Widget> _results(PronunciationResult r) {
    final tips = pronunciationTips(_badReadings(r), fluency: r.fluency);
    return [
      const SizedBox(height: 18),
      Row(
        children: [
          for (final (label, v) in [('Genauigkeit', r.accuracy), ('Flüssigkeit', r.fluency), ('Vollständigkeit', r.completeness)])
            Expanded(
              child: Column(
                children: [
                  Text('${v.round()}', style: serif(26, weight: 460)),
                  Text(label, style: sans(12.5, color: YoColors.inkSoft)),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [for (final w in r.words) _WordChip(w)],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 12,
        children: [
          for (final g in WordGrade.values)
            Row(mainAxisSize: MainAxisSize.min, children: [
              _swatch(g),
              const SizedBox(width: 4),
              Text(g.label, style: sans(12, color: YoColors.inkSoft)),
            ]),
        ],
      ),
      if (_myRecording != null) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => playClip(_myRecording!),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Meine Aufnahme'),
            ),
            TextButton.icon(
              onPressed: _playModel,
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('Vorbild'),
            ),
          ],
        ),
      ],
      if (tips.isNotEmpty) ...[
        const SizedBox(height: 8),
        for (final t in tips)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 18, color: YoColors.chocolate),
                const SizedBox(width: 6),
                Expanded(child: Text(t, style: sans(14.5, height: 1.45))),
              ],
            ),
          ),
      ],
      const SizedBox(height: 8),
      Text(
        'Den Tonhöhenakzent kann Azure für Japanisch nicht bewerten – hör dafür das Vorbild und deine Aufnahme nacheinander an.',
        style: sans(12.5, color: YoColors.inkSoft),
      ),
    ];
  }

  Widget _note(String s) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: const BoxDecoration(color: YoColors.vanillaIce, borderRadius: organicRadius),
    child: Text(s, style: sans(14.5, height: 1.45)),
  );
}

Widget _swatch(WordGrade g) => Container(
  width: 14,
  height: 14,
  decoration: _decoration(g).copyWith(borderRadius: BorderRadius.circular(4)),
);

BoxDecoration _decoration(WordGrade g) => switch (g) {
  WordGrade.gut => BoxDecoration(
    color: YoColors.brightWhite,
    border: Border.all(color: YoColors.lemonGrass, width: 2),
  ),
  WordGrade.unsicher => const BoxDecoration(color: YoColors.sand),
  WordGrade.falsch => const BoxDecoration(color: YoColors.woodAsh),
  WordGrade.ausgelassen => BoxDecoration(
    color: YoColors.coconutMilk,
    border: Border.all(color: YoColors.inkSoft),
  ),
};

class _WordChip extends StatelessWidget {
  const _WordChip(this.w);
  final WordScore w;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '${w.grade.label} · ${w.accuracy.round()}',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: _decoration(w.grade).copyWith(borderRadius: organicRadius),
      child: Text(
        w.word,
        style: jp(18).copyWith(
          decoration: w.grade == WordGrade.ausgelassen ? TextDecoration.lineThrough : null,
        ),
      ),
    ),
  );
}
