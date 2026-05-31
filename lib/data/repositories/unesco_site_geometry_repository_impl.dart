import '../../domain/models/heritage_site_geometry.dart';
import '../../domain/repositories/unesco_site_geometry_repository.dart';
import '../models/unesco_site_geometry_dto.dart';
import '../services/unesco_api_exceptions.dart';
import '../services/unesco_site_geometry_service.dart';

class UnescoSiteGeometryRepositoryImpl
    implements UnescoSiteGeometryRepository {
  UnescoSiteGeometryRepositoryImpl(this._service);

  final UnescoSiteGeometryService _service;
  final Map<int, HeritageSiteGeometry> _cachedGeometries =
      <int, HeritageSiteGeometry>{};

  @override
  Future<HeritageSiteGeometry?> getSiteGeometry(int propertyId) async {
    final cachedGeometry = _cachedGeometries[propertyId];
    if (cachedGeometry != null) {
      return cachedGeometry;
    }

    try {
      final boundary = await _service.fetchBoundaryById(propertyId);
      final buffer = await _service.fetchBufferById(propertyId);
      final geometry = HeritageSiteGeometry(
        propertyId: propertyId,
        boundary: _mapPolygon(boundary),
        buffer: buffer == null ? null : _mapPolygon(buffer),
      );
      _cachedGeometries[propertyId] = geometry;
      return geometry;
    } on UnescoSitesEmptyResultException {
      return null;
    }
  }

  @override
  Future<List<HeritageSiteGeometry>> getSiteGeometries(
    Iterable<int> propertyIds,
  ) async {
    final geometries = <HeritageSiteGeometry>[];
    for (final propertyId in propertyIds) {
      final geometry = await getSiteGeometry(propertyId);
      if (geometry != null) {
        geometries.add(geometry);
      }
    }

    return List<HeritageSiteGeometry>.unmodifiable(geometries);
  }

  @override
  Future<void> refresh() async {
    _cachedGeometries.clear();
  }

  HeritagePolygonGeometry _mapPolygon(UnescoSiteGeometryDto dto) {
    return HeritagePolygonGeometry(
      rings: dto.rings
          .map(
            (ring) => ring
                .map(
                  (point) => HeritageGeoPoint(
                    latitude: point[0],
                    longitude: point[1],
                  ),
                )
                .toList(growable: false),
          )
          .toList(growable: false),
    );
  }
}
