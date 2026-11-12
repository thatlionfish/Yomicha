import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'data/progress.dart';
import 'data/repository.dart';
import 'screens/home_screen.dart';
import 'ui/theme.dart';
import 'widgets/splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final progress = Progress();
  await progress.load();
  runApp(YomichaApp(repo: Repository(), progress: progress));
}

class YomichaApp extends StatelessWidget {
  const YomichaApp({super.key, required this.repo, required this.progress, this.home});

  final Repository repo;
  final Progress progress;

  /// Nur für Tests.
  final Widget? home;

  @override
  Widget build(BuildContext context) => AppScope(
    repo: repo,
    progress: progress,
    child: MaterialApp(
      title: 'Yomicha',
      debugShowCheckedModeBanner: false,
      theme: buildYoTheme(),
      home: home ?? const SplashGate(child: HomeScreen()),
    ),
  );
}
