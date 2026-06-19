import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/features/settings/settings_dependencies.dart';
import '../../ui/features/settings/view_models/settings_view_model.dart';
import '../../ui/features/heritage_sites/heritage_sites_dependencies.dart';
import '../../ui/features/heritage_sites/view_models/heritage_sites_view_model.dart';
import '../../data/services/gemini_service.dart';

final settingsViewModelProvider = Provider<SettingsViewModel>((ref) {
  final vm = SettingsDependencies.createViewModel();
  vm.loadSettings();
  return vm;
});

final heritageSitesViewModelProvider = Provider<HeritageSitesViewModel>((ref) {
  final vm = HeritageSitesDependencies.createSitesViewModel();
  vm.loadSites();
  return vm;
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});
