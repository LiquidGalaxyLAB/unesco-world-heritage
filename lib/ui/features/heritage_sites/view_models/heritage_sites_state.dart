import '../../../../domain/models/heritage_site.dart';

class HeritageSitesState {
  const HeritageSitesState({
    this.homeSites = const <HeritageSite>[],
    this.sites = const <HeritageSite>[],
    this.filteredSites = const <HeritageSite>[],
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
    this.selectedRegions = const <String>{},
    this.selectedStates = const <String>{},
    this.selectedCategories = const <HeritageCategory>{},
    this.startYear,
    this.endYear,
    this.showDangerSites = false,
  });

  final List<HeritageSite> homeSites;
  final List<HeritageSite> sites;
  final List<HeritageSite> filteredSites;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;
  final Set<String> selectedRegions;
  final Set<String> selectedStates;
  final Set<HeritageCategory> selectedCategories;
  final int? startYear;
  final int? endYear;
  final bool showDangerSites;

  HeritageSitesState copyWith({
    List<HeritageSite>? homeSites,
    List<HeritageSite>? sites,
    List<HeritageSite>? filteredSites,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    Set<String>? selectedRegions,
    Set<String>? selectedStates,
    Set<HeritageCategory>? selectedCategories,
    int? startYear,
    int? endYear,
    bool? showDangerSites,
  }) {
    return HeritageSitesState(
      homeSites: homeSites ?? this.homeSites,
      sites: sites ?? this.sites,
      filteredSites: filteredSites ?? this.filteredSites,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      selectedRegions: selectedRegions ?? this.selectedRegions,
      selectedStates: selectedStates ?? this.selectedStates,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      startYear: startYear ?? this.startYear,
      endYear: endYear ?? this.endYear,
      showDangerSites: showDangerSites ?? this.showDangerSites,
    );
  }
}
