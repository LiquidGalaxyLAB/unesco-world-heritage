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
  Future<List<WdpaSiteCandidateDto>>? _wdpaCandidatesFuture;
  final Map<int, HeritageSiteGeometry> _cachedGeometries =
      <int, HeritageSiteGeometry>{};
  static const double _wdpaMatchThreshold = 0.75;

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
    _wdpaCandidatesFuture = null;
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
}

class _WdpaCandidateAlias {
  const _WdpaCandidateAlias({required this.candidate, required this.alias});

  final WdpaSiteCandidateDto candidate;
  final String alias;
}
