import '../../../data/repositories/lg_settings_repository_impl.dart';
import '../../../data/services/lg_rig_service.dart';
import '../../../data/services/settings_storage_service.dart';
import '../../../domain/repositories/lg_settings_repository.dart';
import 'view_models/settings_view_model.dart';

class SettingsDependencies {
  SettingsDependencies._();

  static SettingsViewModel createViewModel() {
    final SettingsStorageService storageService = SettingsStorageService();
    final LGRigService lgRigService = LGRigService();
    final LGSettingsRepository repository = LGSettingsRepositoryImpl(
      storageService,
    );
    return SettingsViewModel(repository, lgRigService);
  }
}
