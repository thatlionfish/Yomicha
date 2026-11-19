import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/progress.dart';
import '../learn/calendar.dart';
import '../learn/einstufung.dart';
import '../ui/colors.dart';
import '../ui/theme.dart';
import 'furigana.dart';
import 'kumachan.dart';
import 'stufen_vorschlag.dart';

/// Fragen im Prüfungsstil (Spezifikation 8): alle Fragen unter dem Text, nur
/// Japanisch, ohne Rückmeldung – Antworten lassen sich bis zum Abgeben ändern.
class ExamQuestions extends StatelessWidget {
  const ExamQuestions({super.key, required this.questions, required this.chosen, required this.onChoose});
  final List<Question> questions;

  /// Frage → gewählte Antwort.
  final Map<int, int> chosen;
  final void Function(int question, int option) onChoose;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (qi, q) in questions.indexed) ...[
        const SizedBox(height: 18),
        RubyText('問${qi + 1}　${q.q}', fontSize: 19),
        const SizedBox(height: 10),
        for (final (oi, o) in q.options.indexed) ...[
          ExamOption(
            number: oi + 1,
            markup: o,
            state: chosen[qi] == oi ? ExamOptionState.chosen : ExamOptionState.open,
            onTap: () => onChoose(qi, oi),
          ),
          const SizedBox(height: 8),
        ],
      ],
    ],
  );
}

enum ExamOptionState { open, chosen, right, wrong, other }

class ExamOption extends StatelessWidget {
  const ExamOption({super.key, required this.number, required this.markup, required this.state, this.onTap});
  final int number;
  final String markup;
  final ExamOptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = switch (state) {
      ExamOptionState.chosen => const BorderSide(color: YoColors.chocolate, width: 2.2),
      ExamOptionState.right => const BorderSide(color: YoColors.lemonGrass, width: 3),
      _ => const BorderSide(color: YoColors.sand, width: 1.4),
    };
    return Material(
      color: state == ExamOptionState.wrong ? YoColors.woodAsh : YoColors.brightWhite,
      shape: RoundedRectangleBorder(borderRadius: organicRadius, side: border),
      child: InkWell(
        customBorder: const RoundedRectangleBorder(borderRadius: organicRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              SizedBox(width: 26, child: Text('$number', style: sans(16, weight: 650, color: YoColors.inkSoft))),
              Expanded(child: RubyText(markup, fontSize: 18)),
              if (state == ExamOptionState.chosen) const Icon(Icons.radio_button_checked_rounded, color: YoColors.chocolate),
              if (state == ExamOptionState.right) const Icon(Icons.check_rounded, color: YoColors.chocolate),
            ],
          ),
        ),
      ),
    );
  }
}

/// Auswertung des Prüfungsdurchgangs: Ergebnis, jede Frage mit Lösung,
/// Erklärung und Textstelle, Lesetempo, Stufenvorschlag.
class ExamResult extends StatelessWidget {
  const ExamResult({
    super.key,
    required this.doc,
    required this.chosen,
    required this.seconds,
    required this.progress,
    required this.onStudy,
  });
  final TextDoc doc;
  final Map<int, int> chosen;
  final int seconds;
  final Progress progress;
  final VoidCallback onStudy;

  @override
  Widget build(BuildContext context) {
    final qs = doc.questions;
    final correct = [for (final (i, q) in qs.indexed) if (chosen[i] == q.answer) i].length;
    final ratio = qs.isEmpty ? 1.0 : correct / qs.length;
    final serie = streak(progress.readDays, DateTime.now());
    final speed = seconds >= 20 ? (doc.chars * 60 / seconds).round() : null;
    final mood = ratio == 1 ? 'perfekt' : ratio < 0.5 ? 'rueckschlag' : serie >= 3 ? 'serie' : 'fertig';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        if (progress.kuma != KumaMode.aus) ...[
          KumaMoment(mood: mood, height: 120),
          const SizedBox(height: 10),
        ],
        Text('$correct von ${qs.length} richtig', style: serif(30, weight: 420)),
        Text(
          [
            'Lesezeit ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} Min',
            if (speed != null) '$speed Zeichen pro Minute',
            if (serie >= 2) 'Lernserie $serie Tage',
          ].join(' · '),
          style: sans(15, color: YoColors.inkSoft),
        ),
        ListenableBuilder(
          listenable: progress,
          builder: (context, _) => switch (stufenVorschlag(progress)) {
            final v? => Padding(
              padding: const EdgeInsets.only(top: 16),
              child: StufenVorschlagCard(progress: progress, vorschlag: v),
            ),
            null => const SizedBox.shrink(),
          },
        ),
        for (final (qi, q) in qs.indexed) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Icon(
                chosen[qi] == q.answer ? Icons.check_circle_rounded : Icons.lightbulb_outline_rounded,
                color: chosen[qi] == q.answer ? YoColors.lemonGrass : YoColors.chocolate,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  chosen[qi] == q.answer ? 'Frage ${qi + 1}: richtig' : 'Frage ${qi + 1}: richtig ist ${q.answer + 1}',
                  style: sans(15.5, weight: 650),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RubyText(q.q, fontSize: 18),
          const SizedBox(height: 8),
          for (final (oi, o) in q.options.indexed)
            if (oi == q.answer || oi == chosen[qi]) ...[
              ExamOption(
                number: oi + 1,
                markup: o,
                state: oi == q.answer ? ExamOptionState.right : ExamOptionState.wrong,
              ),
              const SizedBox(height: 8),
            ],
          Text(q.explain, style: sans(15, height: 1.5)),
          if (q.evidence.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(color: YoColors.brightWhite, borderRadius: organicRadius),
              child: FuriganaFlow(
                sentences: [for (final i in [...q.evidence]..sort()) (i, doc.sentences[i].tokens)],
                fontSize: 18,
                rules: const FuriganaRules(mode: FuriganaMode.alle, userJlpt: 5),
                markedSentences: {q.evidence.first},
              ),
            ),
          ],
        ],
        const SizedBox(height: 26),
        Text(
          'Jetzt lernst du den Text: Wörter und Kanji antippen, Grammatik ansehen, vorlesen lassen. '
          'Was du antippst, kommt in „Meine Wörter“ – das zählt nicht gegen dich.',
          style: sans(14.5, height: 1.45, color: YoColors.inkSoft),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onStudy,
          icon: const Icon(Icons.menu_book_rounded),
          label: const Text('Text jetzt lernen'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const Text('Zur Startseite'),
        ),
      ],
    );
  }
}

/// Sätze, in denen die Antworten auf falsch beantwortete Fragen stehen.
Set<int> wrongEvidence(TextDoc doc, Iterable<int> wrongQuestions) => {
  for (final qi in wrongQuestions)
    if (qi < doc.questions.length) ...doc.questions[qi].evidence,
};
