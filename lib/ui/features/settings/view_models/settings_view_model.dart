import 'package:flutter/foundation.dart';

import '../../../../domain/models/lg_connection_settings.dart';
import '../../../../domain/repositories/lg_settings_repository.dart';
import 'settings_state.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(this._settingsRepository);

  final LGSettingsRepository _settingsRepository;

  SettingsState _state = const SettingsState(isLoading: true);
  SettingsState get state => _state;

  Future<void> loadSettings() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final settings = await _settingsRepository.loadConnectionSettings();
      _state = _state.copyWith(
        settings: settings,
        isLoading: false,
      );
    } catch (_) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load saved connection settings.',
      );
    }
    notifyListeners();
  }

  Future<void> saveSettings(LGConnectionSettings settings) async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _settingsRepository.saveConnectionSettings(settings);
      _state = _state.copyWith(settings: settings, isLoading: false);
    } catch (_) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to save connection settings.',
      );
    }
    notifyListeners();
  }

  Future<void> connect(LGConnectionSettings settings) async {
    // For now, "connect" mirrors the source flow: persist settings first.
    // Actual LG transport connectivity will be integrated later.
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _settingsRepository.saveConnectionSettings(settings);
      _state = _state.copyWith(
        settings: settings,
        isConnected: true,
        isLoading: false,
      );
    } catch (_) {
      _state = _state.copyWith(
        isConnected: false,
        isLoading: false,
        errorMessage: 'Unable to connect using these settings.',
      );
    }
    notifyListeners();
  }

  Future<void> clearSettings() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _settingsRepository.clearConnectionSettings();
      _state = const SettingsState();
    } catch (_) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to clear connection settings.',
      );
    }
    notifyListeners();
  }

  void disconnect() {
    _state = _state.copyWith(isConnected: false);
    notifyListeners();
  }

  void clearError() {
    _state = _state.copyWith(clearError: true);
    notifyListeners();
  }
}
