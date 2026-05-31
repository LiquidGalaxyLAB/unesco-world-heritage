import '../../../data/repositories/unesco_sites_repository_impl.dart';
import '../../../data/services/unesco_sites_service.dart';
import '../../../domain/repositories/unesco_sites_repository.dart';
import 'view_models/heritage_site_detail_view_model.dart';
import 'view_models/heritage_sites_view_model.dart';

class HeritageSitesDependencies {
  HeritageSitesDependencies._();

  static UnescoSitesRepository createRepository() {
    final service = UnescoSitesService();
    return UnescoSitesRepositoryImpl(service);
  }

  static HeritageSitesViewModel createSitesViewModel() {
    return HeritageSitesViewModel(createRepository());
  }

  static HeritageSiteDetailViewModel createSiteDetailViewModel() {
    return HeritageSiteDetailViewModel(createRepository());
  }
}
