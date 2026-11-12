import 'package:flutter/widgets.dart';

import 'data/progress.dart';
import 'data/repository.dart';

/// Gibt Repository und Lernstand an alle Bildschirme weiter.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.repo, required this.progress, required super.child});

  final Repository repo;
  final Progress progress;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      repo != oldWidget.repo || progress != oldWidget.progress;
}

const topicLabels = {
  'tee': 'Tee',
  'mode': 'Mode',
  'welt': 'Weltgeschehen',
  'jlpt': 'JLPT-Thema',
};
