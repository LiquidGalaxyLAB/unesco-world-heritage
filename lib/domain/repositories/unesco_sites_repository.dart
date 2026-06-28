import '../models/heritage_site.dart';

abstract class UnescoSitesRepository {
  Future<List<HeritageSite>> getHomeSites({int limit = 6});

  Future<List<HeritageSite>> getAllSites();

  Future<List<HeritageSite>> getSitesPage({int offset = 0});

  Future<HeritageSite?> getSiteById(int propertyId);

  Future<List<HeritageSite>> searchSites(String query);

  Future<List<HeritageSite>> getSitesByCountry(String country);

  Future<List<HeritageSite>> getSitesByCategory(HeritageCategory category);

  Future<void> refresh();
}
