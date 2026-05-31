import 'package:flutter/foundation.dart';

import '../../../../domain/models/heritage_site.dart';
import '../../../../domain/repositories/unesco_sites_repository.dart';
import 'heritage_sites_state.dart';

class HeritageSitesViewModel extends ChangeNotifier {
  HeritageSitesViewModel(this._repository);

  final UnescoSitesRepository _repository;

  HeritageSitesState _state = const HeritageSitesState(isLoading: true);
  HeritageSitesState get state => _state;

  Future<void> loadSites() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      final sites = await _repository.getAllSites();
      _state = _state.copyWith(
        sites: sites,
        filteredSites: _filterSites(sites, _state.searchQuery),
        isLoading: false,
      );
    } catch (_) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load UNESCO heritage sites.',
      );
    }

    notifyListeners();
  }

  Future<void> refresh() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _repository.refresh();
      final sites = await _repository.getAllSites();
      _state = _state.copyWith(
        sites: sites,
        filteredSites: _filterSites(sites, _state.searchQuery),
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

  void search(String query) {
    _state = _state.copyWith(
      searchQuery: query,
      filteredSites: _filterSites(_state.sites, query),
    );
    notifyListeners();
  }

  void filterByCountry(String country) {
    final normalizedCountry = country.trim().toLowerCase();
    final sites = normalizedCountry.isEmpty
        ? _state.sites
        : _state.sites
            .where((site) => site.country.toLowerCase() == normalizedCountry)
            .toList(growable: false);

    _state = _state.copyWith(
      filteredSites: _filterSites(sites, _state.searchQuery),
    );
    notifyListeners();
  }

  void filterByCategory(HeritageCategory? category) {
    final sites = category == null
        ? _state.sites
        : _state.sites
            .where((site) => site.category == category)
            .toList(growable: false);

    _state = _state.copyWith(
      filteredSites: _filterSites(sites, _state.searchQuery),
    );
    notifyListeners();
  }

  void clearError() {
    _state = _state.copyWith(clearError: true);
    notifyListeners();
  }

  List<HeritageSite> _filterSites(List<HeritageSite> sites, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return List<HeritageSite>.unmodifiable(sites);
    }

    return sites
        .where(
          (site) =>
              site.name.toLowerCase().contains(normalizedQuery) ||
              site.country.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
  }
}
