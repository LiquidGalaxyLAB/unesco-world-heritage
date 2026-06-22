import '../../domain/models/heritage_site.dart';
import '../../domain/repositories/unesco_sites_repository.dart';
import '../models/unesco_site_dto.dart';
import '../services/unesco_api_exceptions.dart';
import '../services/unesco_sites_service.dart';

class UnescoSitesRepositoryImpl implements UnescoSitesRepository {
  UnescoSitesRepositoryImpl(this._service);

  final UnescoSitesService _service;
  List<HeritageSite>? _cachedHomeSites;
  List<HeritageSite>? _cachedSites;

  @override
  Future<List<HeritageSite>> getHomeSites({int limit = 5}) async {
    final cachedHomeSites = _cachedHomeSites;
    if (cachedHomeSites != null && cachedHomeSites.length >= limit) {
      return List<HeritageSite>.unmodifiable(
        cachedHomeSites.take(limit).toList(growable: false),
      );
    }

    final propertyIds = await _service.fetchHomeSiteIds(limit: limit);
    final sites = <HeritageSite>[];
    for (final propertyId in propertyIds) {
      final dto = await _service.fetchSiteById(propertyId);
      sites.add(_mapToDomain(dto));
    }

    _cachedHomeSites = List<HeritageSite>.unmodifiable(sites);
    return List<HeritageSite>.unmodifiable(sites);
  }

  @override
  Future<List<HeritageSite>> getAllSites() async {
    final cachedSites = _cachedSites;
    if (cachedSites != null) {
      return List<HeritageSite>.unmodifiable(cachedSites);
    }

    final dtos = await _service.fetchAllSites();
    final sitesById = <int, HeritageSite>{};
    for (final dto in dtos) {
      sitesById[dto.propertyId] = _mapToDomain(dto);
    }

    final sites = sitesById.values.toList(growable: false);
    _cachedSites = sites;

    return List<HeritageSite>.unmodifiable(sites);
  }

  @override
  Future<List<HeritageSite>> getSitesPage({int offset = 0}) async {
    final dtos = await _service.fetchSitesPage(offset: offset);
    final sitesById = <int, HeritageSite>{};
    for (final dto in dtos) {
      sitesById[dto.propertyId] = _mapToDomain(dto);
    }

    return List<HeritageSite>.unmodifiable(
      sitesById.values.toList(growable: false),
    );
  }

  @override
  Future<HeritageSite?> getSiteById(int propertyId) async {
    final cachedSites = _cachedSites;
    if (cachedSites != null) {
      for (final site in cachedSites) {
        if (site.propertyId == propertyId) {
          if (site.mainImageUrl.isNotEmpty && site.shortDescription.isNotEmpty) {
            return site;
          }
          break;
        }
      }
    }

    try {
      return _mapToDomain(await _service.fetchSiteById(propertyId));
    } on UnescoSitesEmptyResultException {
      return null;
    }
  }

  @override
  Future<List<HeritageSite>> searchSites(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    final sites = await getAllSites();
    if (normalizedQuery.isEmpty) {
      return sites;
    }

    return sites
        .where(
          (site) =>
              site.name.toLowerCase().contains(normalizedQuery) ||
              site.country.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
  }

  @override
  Future<List<HeritageSite>> getSitesByCountry(String country) async {
    final normalizedCountry = country.trim().toLowerCase();
    final sites = await getAllSites();
    if (normalizedCountry.isEmpty) {
      return sites;
    }

    return sites
        .where((site) => site.country.toLowerCase() == normalizedCountry)
        .toList(growable: false);
  }

  @override
  Future<List<HeritageSite>> getSitesByCategory(
    HeritageCategory category,
  ) async {
    final sites = await getAllSites();
    return sites
        .where((site) => site.category == category)
        .toList(growable: false);
  }

  @override
  Future<void> refresh() async {
    _cachedHomeSites = null;
    _cachedSites = null;
    await getAllSites();
  }

  HeritageSite _mapToDomain(UnescoSiteDto dto) {
    return HeritageSite(
      propertyId: dto.propertyId,
      name: dto.name,
      country: dto.country,
      category: HeritageCategory.fromRaw(dto.rawCategory),
      rawCategory: dto.rawCategory,
      latitude: dto.latitude,
      longitude: dto.longitude,
      isoCodes: dto.isoCodes,
      description: dto.description,
      shortDescription: dto.shortDescription,
      dateInscribed: dto.dateInscribed,
      mainImageUrl: dto.mainImageUrl,
      imageUrls: dto.imageUrls,
      region: dto.region,
      isDanger: dto.isDanger,
    );
  }
}
