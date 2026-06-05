import '../../domain/models/heritage_site_geometry.dart';
import '../../domain/repositories/unesco_site_geometry_repository.dart';
import '../models/unesco_site_dto.dart';
import '../models/unesco_site_geometry_dto.dart';
import '../services/gemini_geometry_service.dart';
import '../services/unesco_api_exceptions.dart';
import '../services/unesco_site_geometry_service.dart';
import '../services/unesco_sites_service.dart';

class UnescoSiteGeometryRepositoryImpl implements UnescoSiteGeometryRepository {
  UnescoSiteGeometryRepositoryImpl(
    this._service, {
    UnescoSitesService? sitesService,
    GeminiGeometryService? geminiGeometryService,
  }) : _sitesService = sitesService,
       _geminiGeometryService = geminiGeometryService;

  final UnescoSiteGeometryService _service;
  final UnescoSitesService? _sitesService;
  final GeminiGeometryService? _geminiGeometryService;
  final Map<int, HeritageSiteGeometry> _cachedGeometries =
      <int, HeritageSiteGeometry>{};

  @override
  Future<HeritageSiteGeometry?> getSiteGeometry(int propertyId) async {
    final cachedGeometry = _cachedGeometries[propertyId];
    if (cachedGeometry != null) {
      return cachedGeometry;
    }

    final boundaryLayer = await _fetchOrEmpty(
      () => _service.fetchBoundaryById(propertyId),
    );
    final bufferLayer = await _fetchOrEmpty(
      () => _service.fetchBufferById(propertyId),
    );

    if (boundaryLayer.isNotEmpty || bufferLayer.isNotEmpty) {
      final geometry = HeritageSiteGeometry(
        propertyId: propertyId,
        boundary: _mapPolygon(
          boundaryLayer.isNotEmpty ? boundaryLayer : bufferLayer,
        ),
        buffer: bufferLayer.isEmpty ? null : _mapPolygon(bufferLayer),
      );
      _cachedGeometries[propertyId] = geometry;
      return geometry;
    }

    final site = await _fetchSite(propertyId);
    if (site != null && _isNaturalOrMixed(site.rawCategory)) {
      final wdpaGeometries = await _fetchOrEmpty(
        () => _service.fetchWdpaNaturalSiteGeometries(
          siteName: site.name,
          isoCodes: site.isoCodes,
        ),
      );
      if (wdpaGeometries.isNotEmpty) {
        final geometry = HeritageSiteGeometry(
          propertyId: propertyId,
          boundary: _mapPolygon(wdpaGeometries),
        );
        _cachedGeometries[propertyId] = geometry;
        return geometry;
      }
    }

    final geminiService = _geminiGeometryService;
    if (site != null && geminiService != null && geminiService.isConfigured) {
      final geminiGeometries = await _fetchOrEmpty(
        () => geminiService.fetchGeneratedGeometry(
          propertyId: propertyId,
          siteName: site.name,
          country: site.country,
          latitude: site.latitude,
          longitude: site.longitude,
        ),
      );
      if (geminiGeometries.isNotEmpty) {
        final geometry = HeritageSiteGeometry(
          propertyId: propertyId,
          boundary: _mapPolygon(geminiGeometries),
        );
        _cachedGeometries[propertyId] = geometry;
        return geometry;
      }
    }

    return null;
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

  Future<List<UnescoSiteGeometryDto>> _fetchOrEmpty(
    Future<List<UnescoSiteGeometryDto>> Function() fetch,
  ) async {
    try {
      return await fetch();
    } on UnescoSitesException {
      return const <UnescoSiteGeometryDto>[];
    }
  }

  Future<UnescoSiteDto?> _fetchSite(int propertyId) async {
    final sitesService = _sitesService;
    if (sitesService == null) {
      return null;
    }

    try {
      return await sitesService.fetchSiteById(propertyId);
    } on UnescoSitesException {
      return null;
    }
  }

  bool _isNaturalOrMixed(String rawCategory) {
    final category = rawCategory.trim().toLowerCase();
    return category == 'natural' || category == 'mixed';
  }

  HeritagePolygonGeometry _mapPolygon(List<UnescoSiteGeometryDto> dtos) {
    return HeritagePolygonGeometry(
      rings: dtos
          .expand((dto) => dto.rings)
          .map(_mapRing)
          .toList(growable: false),
    );
  }

  List<HeritageGeoPoint> _mapRing(List<List<double>> ring) {
    return ring
        .map(
          (point) => HeritageGeoPoint(latitude: point[0], longitude: point[1]),
        )
        .toList(growable: false);
  }
}
