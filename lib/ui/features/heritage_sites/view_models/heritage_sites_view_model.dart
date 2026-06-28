import 'dart:async';

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
      );
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
      );
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
