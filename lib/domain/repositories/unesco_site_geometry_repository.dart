import '../models/heritage_site_geometry.dart';

abstract class UnescoSiteGeometryRepository {
  Future<HeritageSiteGeometry?> getSiteGeometry(int propertyId);

  Future<List<HeritageSiteGeometry>> getSiteGeometries(
    Iterable<int> propertyIds,
  );

  Future<void> refresh();
}
