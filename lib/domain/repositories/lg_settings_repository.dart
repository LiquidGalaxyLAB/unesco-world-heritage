import '../models/lg_connection_settings.dart';

abstract class LGSettingsRepository {
  Future<void> saveConnectionSettings(LGConnectionSettings settings);
  Future<LGConnectionSettings?> loadConnectionSettings();
  Future<void> clearConnectionSettings();
}
