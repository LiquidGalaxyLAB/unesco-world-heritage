import '../../domain/models/lg_connection_settings.dart';
import '../../domain/repositories/lg_settings_repository.dart';
import '../services/settings_storage_service.dart';

class LGSettingsRepositoryImpl implements LGSettingsRepository {
  LGSettingsRepositoryImpl(this._storageService);

  final SettingsStorageService _storageService;

  @override
  Future<void> saveConnectionSettings(LGConnectionSettings settings) async {
    await _storageService.save(
      host: settings.host,
      username: settings.username,
      password: settings.password,
      port: settings.port,
      screens: settings.screens,
    );
  }

  @override
  Future<LGConnectionSettings?> loadConnectionSettings() async {
    final rawSettings = await _storageService.load();
    if (rawSettings == null) {
      return null;
    }

    return LGConnectionSettings(
      host: rawSettings[SettingsStorageService.hostKey]! as String,
      username: rawSettings[SettingsStorageService.usernameKey]! as String,
      password: rawSettings[SettingsStorageService.passwordKey]! as String,
      port: rawSettings[SettingsStorageService.portKey]! as int,
      screens: rawSettings[SettingsStorageService.screensKey]! as int,
    );
  }

  @override
  Future<void> clearConnectionSettings() async {
    await _storageService.clear();
  }
}
