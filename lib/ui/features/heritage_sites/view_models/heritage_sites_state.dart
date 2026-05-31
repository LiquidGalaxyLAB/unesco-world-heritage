import '../../../../domain/models/heritage_site.dart';

class HeritageSitesState {
  const HeritageSitesState({
    this.sites = const <HeritageSite>[],
    this.filteredSites = const <HeritageSite>[],
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  final List<HeritageSite> sites;
  final List<HeritageSite> filteredSites;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  HeritageSitesState copyWith({
    List<HeritageSite>? sites,
    List<HeritageSite>? filteredSites,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HeritageSitesState(
      sites: sites ?? this.sites,
      filteredSites: filteredSites ?? this.filteredSites,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
