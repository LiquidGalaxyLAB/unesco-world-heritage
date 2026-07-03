import 'dart:math' as math;

import '../../domain/models/heritage_site_geometry.dart';
import '../../domain/repositories/unesco_site_geometry_repository.dart';
import 'package:string_similarity/string_similarity.dart';

import '../models/unesco_site_dto.dart';
import '../models/unesco_site_geometry_dto.dart';
import '../models/wdpa_site_candidate_dto.dart';
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
  Future<Set<int>>? _arcGisGeometrySiteIdsFuture;
  Future<List<WdpaSiteCandidateDto>>? _wdpaCandidatesFuture;
  final Map<int, HeritageSiteGeometry> _cachedGeometries =
      <int, HeritageSiteGeometry>{};
  static const double _wdpaMatchThreshold = 0.75;
  static const int _fallbackRingPointCount = 72;
  static const double _fallbackEllipsePadding = 1.55;
  static const double _minimumLongitudeScale = 0.2;

  @override
  Future<Set<int>> getArcGisGeometrySiteIds() async {
    final existingFuture = _arcGisGeometrySiteIdsFuture;
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _fetchArcGisGeometrySiteIdsInternal();
    _arcGisGeometrySiteIdsFuture = future;
    return future;
  }

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
      final geometry = await _fetchWdpaGeometry(site, propertyId);
      if (geometry != null) {
        _cachedGeometries[propertyId] = geometry;
        return geometry;
      }
    }

    if (site != null) {
      final geometry = await _fetchComponentFallbackGeometry(site, propertyId);
      if (geometry != null) {
        _cachedGeometries[propertyId] = geometry;
        return geometry;
      }
    }

    final geminiService = _geminiGeometryService;
    if (site != null &&
        geminiService != null &&
        await geminiService.isConfigured) {
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
    _arcGisGeometrySiteIdsFuture = null;
    _wdpaCandidatesFuture = null;
  }

  Future<Set<int>> _fetchArcGisGeometrySiteIdsInternal() async {
    final boundaryIds = await _fetchArcGisPropertyIdsOrEmpty(
      UnescoGeometryLayer.boundary,
    );
    final bufferIds = await _fetchArcGisPropertyIdsOrEmpty(
      UnescoGeometryLayer.buffer,
    );
    return Set<int>.unmodifiable({...boundaryIds, ...bufferIds});
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

  Future<Set<int>> _fetchArcGisPropertyIdsOrEmpty(
    UnescoGeometryLayer layer,
  ) async {
    try {
      return await _service.fetchPropertyIdsWithGeometry(layer: layer);
    } on UnescoSitesException {
      return const <int>{};
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

  Future<HeritageSiteGeometry?> _fetchWdpaGeometry(
    UnescoSiteDto site,
    int propertyId,
  ) async {
    final candidates = await _fetchWdpaCandidates();
    if (candidates.isEmpty) {
      return null;
    }

    final matchedCandidate = _findBestWdpaCandidate(site.name, candidates);
    if (matchedCandidate == null) {
      return null;
    }

    final geometries = await _fetchOrEmpty(
      () => _service.fetchWdpaGeometryBySiteId(matchedCandidate.siteId),
    );
    if (geometries.isEmpty) {
      return null;
    }

    return HeritageSiteGeometry(
      propertyId: propertyId,
      boundary: _mapPolygon(geometries),
    );
  }

  Future<HeritageSiteGeometry?> _fetchComponentFallbackGeometry(
    UnescoSiteDto site,
    int propertyId,
  ) async {
    final sitesService = _sitesService;
    if (sitesService == null) {
      return null;
    }

    final coordinates = await _fetchComponentCoordinatesOrEmpty(
      propertyId,
      sitesService,
    );
    final componentPoints = coordinates
        .map(
          (point) => HeritageGeoPoint(latitude: point[0], longitude: point[1]),
        )
        .toList(growable: false);
    final rings = componentPoints.isNotEmpty
        ? <List<HeritageGeoPoint>>[
            _buildFallbackRing(componentPoints, site.rawCategory),
          ]
        : <List<HeritageGeoPoint>>[
            _buildFallbackRing(<HeritageGeoPoint>[
              HeritageGeoPoint(
                latitude: site.latitude,
                longitude: site.longitude,
              ),
            ], site.rawCategory),
          ];
    final validRings = rings
        .where((ring) => ring.isNotEmpty)
        .toList(growable: false);
    if (validRings.isEmpty) {
      return null;
    }

    return HeritageSiteGeometry(
      propertyId: propertyId,
      boundary: HeritagePolygonGeometry(rings: validRings),
    );
  }

  Future<List<List<double>>> _fetchComponentCoordinatesOrEmpty(
    int propertyId,
    UnescoSitesService sitesService,
  ) async {
    try {
      return await sitesService.fetchSiteComponentCoordinates(propertyId);
    } on UnescoSitesException {
      return const <List<double>>[];
    }
  }

  Future<List<WdpaSiteCandidateDto>> _fetchWdpaCandidates() async {
    final existingFuture = _wdpaCandidatesFuture;
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _fetchWdpaCandidatesInternal();
    _wdpaCandidatesFuture = future;
    return future;
  }

  Future<List<WdpaSiteCandidateDto>> _fetchWdpaCandidatesInternal() async {
    try {
      return await _service.fetchWdpaSiteCandidates();
    } on UnescoSitesException {
      _wdpaCandidatesFuture = null;
      return const <WdpaSiteCandidateDto>[];
    }
  }

  WdpaSiteCandidateDto? _findBestWdpaCandidate(
    String siteName,
    List<WdpaSiteCandidateDto> candidates,
  ) {
    final normalizedSiteName = _normalizeName(siteName);
    if (normalizedSiteName.isEmpty) {
      return null;
    }

    final aliases = <_WdpaCandidateAlias>[];
    for (final candidate in candidates) {
      final normalizedAliases = <String>{
        _normalizeName(candidate.nameEnglish),
        _normalizeName(candidate.name),
      }..removeWhere((value) => value.isEmpty);

      for (final alias in normalizedAliases) {
        aliases.add(_WdpaCandidateAlias(candidate: candidate, alias: alias));
      }
    }

    if (aliases.isEmpty) {
      return null;
    }

    final match = StringSimilarity.findBestMatch(
      normalizedSiteName,
      aliases.map((alias) => alias.alias).toList(growable: false),
    );
    final rating = match.bestMatch.rating ?? 0;
    if (rating < _wdpaMatchThreshold) {
      return null;
    }

    return aliases[match.bestMatchIndex].candidate;
  }

  String _normalizeName(String value) {
    return value
        .toLowerCase()
        .replaceAll(
          RegExp(r'</?(strong|b|em|i|mark|code)\b[^>]*>', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'&[^;\s]+;'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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

  List<HeritageGeoPoint> _buildFallbackRing(
    List<HeritageGeoPoint> points,
    String rawCategory,
  ) {
    if (points.isEmpty) {
      return const <HeritageGeoPoint>[];
    }

    final minimumRadiusMeters = _minimumRadiusMeters(rawCategory);
    if (points.length == 1) {
      final point = points.first;
      return _buildEllipseRing(
        centerLatitude: point.latitude,
        centerLongitude: point.longitude,
        semiMajorMeters: minimumRadiusMeters,
        semiMinorMeters: minimumRadiusMeters,
      );
    }

    double minLatitude = double.infinity;
    double maxLatitude = double.negativeInfinity;
    double minLongitude = double.infinity;
    double maxLongitude = double.negativeInfinity;

    for (final point in points) {
      minLatitude = math.min(minLatitude, point.latitude);
      maxLatitude = math.max(maxLatitude, point.latitude);
      minLongitude = math.min(minLongitude, point.longitude);
      maxLongitude = math.max(maxLongitude, point.longitude);
    }

    final centerLatitude = (minLatitude + maxLatitude) / 2;
    final centerLongitude = (minLongitude + maxLongitude) / 2;
    final longitudeScale = math.max(
      _minimumLongitudeScale,
      math.cos(centerLatitude * math.pi / 180).abs(),
    );
    final metersPerLatitudeDegree = 111320.0;
    final metersPerLongitudeDegree = metersPerLatitudeDegree * longitudeScale;

    double maxLatitudeOffsetMeters = 0;
    double maxLongitudeOffsetMeters = 0;
    for (final point in points) {
      maxLatitudeOffsetMeters = math.max(
        maxLatitudeOffsetMeters,
        (point.latitude - centerLatitude).abs() * metersPerLatitudeDegree,
      );
      maxLongitudeOffsetMeters = math.max(
        maxLongitudeOffsetMeters,
        (point.longitude - centerLongitude).abs() * metersPerLongitudeDegree,
      );
    }

    final radiusMeters = math.max(
      math.max(maxLongitudeOffsetMeters, maxLatitudeOffsetMeters) *
          _fallbackEllipsePadding,
      minimumRadiusMeters,
    );

    return _buildEllipseRing(
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
      semiMajorMeters: radiusMeters,
      semiMinorMeters: radiusMeters,
    );
  }

  List<HeritageGeoPoint> _buildEllipseRing({
    required double centerLatitude,
    required double centerLongitude,
    required double semiMajorMeters,
    required double semiMinorMeters,
  }) {
    final longitudeScale = math.max(
      _minimumLongitudeScale,
      math.cos(centerLatitude * math.pi / 180).abs(),
    );
    final metersPerLatitudeDegree = 111320.0;
    final metersPerLongitudeDegree = metersPerLatitudeDegree * longitudeScale;

    final ring = <HeritageGeoPoint>[];
    for (var index = 0; index < _fallbackRingPointCount; index++) {
      final angle = (2 * math.pi * index) / _fallbackRingPointCount;
      final latitude =
          centerLatitude +
          (semiMinorMeters * math.sin(angle) / metersPerLatitudeDegree);
      final longitude =
          centerLongitude +
          (semiMajorMeters * math.cos(angle) / metersPerLongitudeDegree);
      ring.add(HeritageGeoPoint(latitude: latitude, longitude: longitude));
    }

    if (ring.isNotEmpty) {
      ring.add(ring.first);
    }

    return List<HeritageGeoPoint>.unmodifiable(ring);
  }

  double _minimumRadiusMeters(String rawCategory) {
    final normalizedCategory = rawCategory.trim().toLowerCase();
    switch (normalizedCategory) {
      case 'natural':
        return 2200;
      case 'mixed':
        return 1800;
      case 'cultural':
        return 1200;
      default:
        return 1500;
    }
  }
}

class _WdpaCandidateAlias {
  const _WdpaCandidateAlias({required this.candidate, required this.alias});

  final WdpaSiteCandidateDto candidate;
  final String alias;
}
