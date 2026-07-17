import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../domain/models/heritage_site.dart';
import '../../../../domain/repositories/unesco_site_geometry_repository.dart';
import '../../../../domain/repositories/unesco_sites_repository.dart';
import 'heritage_sites_state.dart';

class HeritageSitesViewModel extends ChangeNotifier {
  HeritageSitesViewModel(this._repository, this._geometryRepository);

  static const int _initialPageOffset = 0;
  final UnescoSitesRepository _repository;
  final UnescoSiteGeometryRepository _geometryRepository;
  Future<void>? _backgroundLoadFuture;
  Set<int> _arcGisGeometrySiteIds = const <int>{};

  HeritageSitesState _state = const HeritageSitesState(isLoading: true);
  HeritageSitesState get state => _state;

  Future<void> loadSites() async {
    if (_backgroundLoadFuture != null && _state.sites.isNotEmpty) {
      return;
    }

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final homeSitesFuture = _repository.getHomeSites();
      final initialSitesFuture = _repository.getSitesPage(
        offset: _initialPageOffset,
      );
      final arcGisGeometrySiteIdsFuture = _loadArcGisGeometrySiteIds();
      final homeSites = await homeSitesFuture;
      final initialSites = await initialSitesFuture;
      _arcGisGeometrySiteIds = await arcGisGeometrySiteIdsFuture;
      _state = _state.copyWith(
        homeSites: homeSites,
        sites: initialSites,
        filteredSites: _buildFilteredSites(sites: initialSites),
        isLoading: false,
      );
      notifyListeners();

      _backgroundLoadFuture ??= _loadRemainingSites();
    } catch (_) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load UNESCO heritage sites.',
      );
    }

    notifyListeners();
  }

  Future<void> refresh() async {
    _backgroundLoadFuture = null;
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await Future.wait<void>([
        _repository.refresh(),
        _geometryRepository.refresh(),
      ]);
      final homeSites = await _repository.getHomeSites();
      final sites = await _repository.getAllSites();
      _arcGisGeometrySiteIds = await _loadArcGisGeometrySiteIds();
      _state = _state.copyWith(
        homeSites: homeSites,
        sites: sites,
        filteredSites: _buildFilteredSites(sites: sites),
        isLoading: false,
        allSitesLoaded: true,
      );
      // Recompute nearest sites with the refreshed full dataset.
      _computeAndCacheNearestSites();
    } catch (_) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to refresh UNESCO heritage sites.',
      );
    }

    notifyListeners();
  }

  Future<void> _loadRemainingSites() async {
    try {
      final sites = await _repository.getAllSites();
      _state = _state.copyWith(
        sites: sites,
        filteredSites: _buildFilteredSites(sites: sites),
        allSitesLoaded: true,
      );
      // Recompute nearest sites now that we have the full dataset.
      _computeAndCacheNearestSites();
      notifyListeners();
    } catch (_) {
      if (_state.sites.isEmpty) {
        _state = _state.copyWith(
          errorMessage: 'Failed to load UNESCO heritage sites.',
        );
        notifyListeners();
      }
    }
  }

  /// Called by the home view whenever GPS resolves. Stores the coordinates in
  /// session state and immediately recomputes nearest sites if the full dataset
  /// is already available.
  void updateUserLocation(double latitude, double longitude) {
    _state = _state.copyWith(
      userLatitude: latitude,
      userLongitude: longitude,
    );
    _computeAndCacheNearestSites();
    notifyListeners();
  }

  /// Sorts [state.sites] by Haversine distance from the stored GPS coordinates
  /// and persists the top-5 in [state.nearestSites]. No-op until both GPS and
  /// the full dataset are available.
  void _computeAndCacheNearestSites() {
    final lat = _state.userLatitude;
    final lng = _state.userLongitude;
    if (lat == null || lng == null) return;
    if (!_state.allSitesLoaded) return;
    final sites = _state.sites;
    if (sites.isEmpty) return;

    final withDist = sites.map((site) {
      final distKm =
          _distanceKm(lat, lng, site.latitude, site.longitude).round();
      return {'site': site, 'dist': distKm};
    }).toList()
      ..sort((a, b) =>
          (a['dist'] as int).compareTo(b['dist'] as int));

    final top = withDist.take(5).toList();
    _state = _state.copyWith(
      nearestSites: top.map((e) => e['site'] as HeritageSite).toList(),
      nearestDistancesKm: top.map((e) => e['dist'] as int).toList(),
    );
  }

  /// Haversine great-circle distance in kilometres.
  double _distanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double deg) => deg * math.pi / 180;

  void search(String query) {
    _state = _state.copyWith(
      searchQuery: query,
      filteredSites: _buildFilteredSites(sites: _state.sites, query: query),
    );
    notifyListeners();
  }

  void applyFilters({
    Set<String>? regions,
    Set<String>? states,
    Set<HeritageCategory>? categories,
    int? startYear,
    int? endYear,
    bool? showDangerSites,
  }) {
    final newRegions = regions ?? _state.selectedRegions;
    final newStates = states ?? _state.selectedStates;
    final newCategories = categories ?? _state.selectedCategories;
    final newStartYear = startYear ?? _state.startYear;
    final newEndYear = endYear ?? _state.endYear;
    final newShowDangerSites = showDangerSites ?? _state.showDangerSites;

    _state = _state.copyWith(
      selectedRegions: newRegions,
      selectedStates: newStates,
      selectedCategories: newCategories,
      startYear: newStartYear,
      endYear: newEndYear,
      showDangerSites: newShowDangerSites,
      filteredSites: _buildFilteredSites(
        sites: _state.sites,
        query: _state.searchQuery,
        regions: newRegions,
        states: newStates,
        categories: newCategories,
        startYear: newStartYear,
        endYear: newEndYear,
        showDangerSites: newShowDangerSites,
      ),
    );
    notifyListeners();
  }

  void filterByCountry(String country) {
    applyFilters(states: {country});
  }

  void filterByCategory(HeritageCategory? category) {
    if (category == null) {
      applyFilters(categories: {});
    } else {
      applyFilters(categories: {category});
    }
  }

  void clearError() {
    _state = _state.copyWith(clearError: true);
    notifyListeners();
  }

  Future<Set<int>> _loadArcGisGeometrySiteIds() async {
    try {
      return await _geometryRepository.getArcGisGeometrySiteIds();
    } catch (_) {
      return const <int>{};
    }
  }

  List<HeritageSite> _buildFilteredSites({
    required List<HeritageSite> sites,
    String? query,
    Set<String>? regions,
    Set<String>? states,
    Set<HeritageCategory>? categories,
    int? startYear,
    int? endYear,
    bool? showDangerSites,
  }) {
    return _rankSites(
      _filterSites(
        sites: sites,
        query: query ?? _state.searchQuery,
        regions: regions ?? _state.selectedRegions,
        states: states ?? _state.selectedStates,
        categories: categories ?? _state.selectedCategories,
        startYear: startYear ?? _state.startYear,
        endYear: endYear ?? _state.endYear,
        showDangerSites: showDangerSites ?? _state.showDangerSites,
      ),
    );
  }

  List<HeritageSite> _filterSites({
    required List<HeritageSite> sites,
    required String query,
    required Set<String> regions,
    required Set<String> states,
    required Set<HeritageCategory> categories,
    required int? startYear,
    required int? endYear,
    required bool showDangerSites,
  }) {
    return sites
        .where((site) {
          if (query.isNotEmpty) {
            final normalizedQuery = query.trim().toLowerCase();
            if (!site.name.toLowerCase().contains(normalizedQuery) &&
                !site.country.toLowerCase().contains(normalizedQuery)) {
              return false;
            }
          }

          if (regions.isNotEmpty && !regions.contains(site.region)) {
            return false;
          }

          if (states.isNotEmpty && query.isEmpty) {
            final siteStates = site.country
                .split(',')
                .map((s) => s.trim())
                .toList();
            if (!siteStates.any((s) => states.contains(s))) {
              return false;
            }
          }

          if (categories.isNotEmpty && !categories.contains(site.category)) {
            return false;
          }

          if (startYear != null || endYear != null) {
            final year = int.tryParse(site.dateInscribed);
            if (year != null) {
              if (startYear != null && year < startYear) return false;
              if (endYear != null && year > endYear) return false;
            }
          }

          if (showDangerSites && !site.isDanger) {
            return false;
          }

          return true;
        })
        .toList(growable: false);
  }

  List<HeritageSite> _rankSites(List<HeritageSite> sites) {
    if (_arcGisGeometrySiteIds.isEmpty || sites.length < 2) {
      return List<HeritageSite>.unmodifiable(sites);
    }

    final prioritizedSites = <HeritageSite>[];
    final remainingSites = <HeritageSite>[];

    for (final site in sites) {
      if (_arcGisGeometrySiteIds.contains(site.propertyId)) {
        prioritizedSites.add(site);
      } else {
        remainingSites.add(site);
      }
    }

    return List<HeritageSite>.unmodifiable([
      ...prioritizedSites,
      ...remainingSites,
    ]);
  }
}
