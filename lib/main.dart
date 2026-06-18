import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'ui/features/settings/views/settings_view.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: HeritageApp()));
}

class HeritageApp extends StatelessWidget {
  const HeritageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNESCO World Heritage',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigationShell(),
    );
  }
}
