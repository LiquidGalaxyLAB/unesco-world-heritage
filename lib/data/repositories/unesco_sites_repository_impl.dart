import '../../domain/models/heritage_site.dart';
import '../../domain/repositories/unesco_sites_repository.dart';
import '../models/unesco_site_dto.dart';
import '../services/unesco_sites_service.dart';

class UnescoSitesRepositoryImpl implements UnescoSitesRepository {
  UnescoSitesRepositoryImpl(this._service);

  final UnescoSitesService _service;
  List<HeritageSite>? _cachedSites;

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

    final sites = sitesById.values.toList(growable: false)
      ..sort(_compareByNameThenId);
    _cachedSites = sites;

    return List<HeritageSite>.unmodifiable(sites);
  }

  @override
  Future<HeritageSite?> getSiteById(int propertyId) async {
    final cachedSites = _cachedSites;
    if (cachedSites != null) {
      for (final site in cachedSites) {
        if (site.propertyId == propertyId) {
          return site;
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
    );
  }

  int _compareByNameThenId(HeritageSite left, HeritageSite right) {
    final nameComparison = left.name.toLowerCase().compareTo(
          right.name.toLowerCase(),
        );
    if (nameComparison != 0) {
      return nameComparison;
    }

    return left.propertyId.compareTo(right.propertyId);
  }
}
