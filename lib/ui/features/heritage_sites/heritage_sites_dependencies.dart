import '../../../data/repositories/unesco_site_geometry_repository_impl.dart';
import '../../../data/repositories/unesco_sites_repository_impl.dart';
import '../../../data/services/gemini_geometry_service.dart';
import '../../../data/services/lg_rig_service.dart';
import '../../../data/services/unesco_site_geometry_service.dart';
import '../../../data/services/unesco_sites_service.dart';
import '../../../domain/repositories/unesco_site_geometry_repository.dart';
import '../../../domain/repositories/unesco_sites_repository.dart';
import '../settings/settings_dependencies.dart';
import 'view_models/heritage_site_detail_view_model.dart';
import 'view_models/heritage_sites_view_model.dart';

class HeritageSitesDependencies {
  HeritageSitesDependencies._();

  /// Shared [LGRigService] instance — delegates to the singleton managed by
  /// [SettingsDependencies] so that the same SSH connection established via
  /// the settings screen is used for map sync.
  static LGRigService get lgRigService => SettingsDependencies.lgRigService;

  static UnescoSitesRepository createRepository() {
    final service = UnescoSitesService();
    return UnescoSitesRepositoryImpl(service);
  }

  static UnescoSiteGeometryRepository createGeometryRepository() {
    final geometryService = UnescoSiteGeometryService();
    final sitesService = UnescoSitesService();
    final geminiGeometryService = GeminiGeometryService();
    return UnescoSiteGeometryRepositoryImpl(
      geometryService,
      sitesService: sitesService,
      geminiGeometryService: geminiGeometryService,
    );
  }

  static HeritageSitesViewModel createSitesViewModel() {
    return HeritageSitesViewModel(
      createRepository(),
      createGeometryRepository(),
    );
  }

  static HeritageSiteDetailViewModel createSiteDetailViewModel() {
    return HeritageSiteDetailViewModel(createRepository());
  }
}
