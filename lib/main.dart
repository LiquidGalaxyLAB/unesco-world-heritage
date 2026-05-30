import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'ui/features/settings/views/settings_view.dart';

void main() {
  runApp(const HeritageApp());
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
