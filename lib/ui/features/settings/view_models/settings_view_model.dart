import 'package:flutter/foundation.dart';

import '../../../../data/services/lg_rig_service.dart';
import '../../../../domain/models/lg_connection_settings.dart';
import '../../../../domain/repositories/lg_settings_repository.dart';
import 'settings_state.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(this._settingsRepository, this._lgRigService);

  final LGSettingsRepository _settingsRepository;
  final LGRigService _lgRigService;

  SettingsState _state = const SettingsState(isLoading: true);
  SettingsState get state => _state;

  Future<void> loadSettings() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final settings = await _settingsRepository.loadConnectionSettings();
      _state = _state.copyWith(settings: settings, isLoading: false);
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
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _settingsRepository.saveConnectionSettings(settings);
      await _lgRigService.connect(settings);
      _state = _state.copyWith(
        settings: settings,
        isConnected: true,
        isLoading: false,
      );
      notifyListeners();

      await _lgRigService.clearKml();
      await _lgRigService.clearBalloon();
      await _lgRigService.showLogoOverlay();
    } catch (error) {
      if (_lgRigService.isConnected) {
        _state = _state.copyWith(
          settings: settings,
          isConnected: true,
          isLoading: false,
          errorMessage:
              'Connected to Liquid Galaxy, but post-connect setup failed. $error',
        );
      } else {
        _state = _state.copyWith(
          isConnected: false,
          isLoading: false,
          errorMessage: 'Unable to connect using these settings. $error',
        );
      }
    }
    notifyListeners();
  }

  Future<void> clearSettings() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _lgRigService.disconnect();
      await _settingsRepository.clearConnectionSettings();
      _state = const SettingsState();
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to clear connection settings. $error',
      );
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _lgRigService.disconnect();
      _state = _state.copyWith(isConnected: false, isLoading: false);
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to disconnect. $error',
      );
    }
    notifyListeners();
  }

  void clearError() {
    _state = _state.copyWith(clearError: true);
    notifyListeners();
  }

  Future<void> sendRelaunchCommand() async {
    if (!state.isConnected) return;
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _lgRigService.relaunch();
      _state = _state.copyWith(isLoading: false);
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to relaunch Liquid Galaxy. $error',
      );
    }
    notifyListeners();
  }

  Future<void> sendRebootCommand() async {
    if (!state.isConnected) return;
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _lgRigService.reboot();
      await _lgRigService.disconnect();
      _state = _state.copyWith(isLoading: false, isConnected: false);
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to reboot Liquid Galaxy. $error',
      );
    }
    notifyListeners();
  }

  Future<void> sendPoweroffCommand() async {
    if (!state.isConnected) return;
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _lgRigService.powerOff();
      await _lgRigService.disconnect();
      _state = _state.copyWith(isLoading: false, isConnected: false);
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to power off Liquid Galaxy. $error',
      );
    }
    notifyListeners();
  }

  Future<void> sendClearKmlCommand() async {
    if (!state.isConnected) return;
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _lgRigService.clearKml();
      _state = _state.copyWith(isLoading: false);
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to clear KML. $error',
      );
    }
    notifyListeners();
  }

  Future<void> sendClearLogoCommand() async {
    if (!state.isConnected) return;
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _lgRigService.clearLogoOverlay();
      _state = _state.copyWith(isLoading: false);
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to clear logo overlay. $error',
      );
    }
    notifyListeners();
  }

  Future<void> sendSetRefreshCommand() async {
    if (!state.isConnected) return;
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _lgRigService.setRefresh();
      _state = _state.copyWith(isLoading: false);
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to set refresh on LG. $error',
      );
    }
    notifyListeners();
  }

  Future<void> sendResetRefreshCommand() async {
    if (!state.isConnected) return;
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _lgRigService.resetRefresh();
      _state = _state.copyWith(isLoading: false);
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to reset refresh on LG. $error',
      );
    }
    notifyListeners();
  }

  Future<void> startOrbitOnLiquidGalaxy() async {
    if (!state.isConnected) {
      throw const LGLocalConnectionError('Not connected to Liquid Galaxy');
    }

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _lgRigService.startOrbit();
      _state = _state.copyWith(isLoading: false);
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to start orbit on Liquid Galaxy. $error',
      );
      notifyListeners();
      rethrow;
    }

    notifyListeners();
  }

  Future<void> stopOrbitOnLiquidGalaxy() async {
    if (!state.isConnected) {
      throw const LGLocalConnectionError('Not connected to Liquid Galaxy');
    }

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _lgRigService.stopOrbit();
      _state = _state.copyWith(isLoading: false);
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to stop orbit on Liquid Galaxy. $error',
      );
      notifyListeners();
      rethrow;
    }

    notifyListeners();
  }

  Future<void> renderKmlOnLiquidGalaxy({
    required String fileName,
    required String kml,
    required double latitude,
    required double longitude,
    required double range,
    String? orbitFileName,
    String? orbitKml,
    double altitude = 150,
    double tilt = 60,
    double bearing = 0,
    bool startOrbitAfterRender = true,
  }) async {
    if (!state.isConnected) {
      throw const LGLocalConnectionError('Not connected to Liquid Galaxy');
    }

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _lgRigService.stopOrbit();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await _lgRigService.clearMaster();
      await _lgRigService.flyTo(
        latitude: latitude,
        longitude: longitude,
        altitude: altitude,
        zoom: range,
        tilt: tilt,
        bearing: bearing,
      );
      await Future<void>.delayed(const Duration(seconds: 3));
      await _lgRigService.sendKml(fileName, kml);
      if (orbitFileName != null &&
          orbitFileName.trim().isNotEmpty &&
          orbitKml != null &&
          orbitKml.trim().isNotEmpty) {
        await _lgRigService.uploadKml(orbitFileName, orbitKml);
        await _lgRigService.appendKml(orbitFileName);
        if (startOrbitAfterRender) {
          await Future<void>.delayed(const Duration(seconds: 2));
          await _lgRigService.startOrbit();
        }
      }
      _state = _state.copyWith(isLoading: false);
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to render KML on Liquid Galaxy. $error',
      );
      notifyListeners();
      rethrow;
    }

    notifyListeners();
  }

  Future<void> renderKmlOnLeftmostScreen({
    required String kml,
    required double latitude,
    required double longitude,
    required double range,
    double altitude = 150,
    double tilt = 60,
    double bearing = 0,
    bool startOrbitAfterRender = true,
  }) async {
    if (!state.isConnected) {
      throw const LGLocalConnectionError('Not connected to Liquid Galaxy');
    }

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _lgRigService.flyTo(
        latitude: latitude,
        longitude: longitude,
        altitude: altitude,
        zoom: range,
        tilt: tilt,
        bearing: bearing,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _lgRigService.sendKmlToLeftmostScreen(kml);
      _state = _state.copyWith(isLoading: false);
    } catch (error) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to render KML on Liquid Galaxy. $error',
      );
      notifyListeners();
      rethrow;
    }

    notifyListeners();
  }

  Future<void> renderKmlOnRightmostScreen({required String kml}) async {
    if (!state.isConnected) {
      throw const LGLocalConnectionError('Not connected to Liquid Galaxy');
    }

    try {
      await _lgRigService.resetRefresh();
      await _lgRigService.setRefresh();
      await _lgRigService.clearBalloon();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _lgRigService.sendKmlToRightmostScreen(kml);
    } catch (error) {
      _state = _state.copyWith(
        errorMessage: 'Failed to render KML on Liquid Galaxy. $error',
      );
      notifyListeners();
      rethrow;
    }
  }
}
