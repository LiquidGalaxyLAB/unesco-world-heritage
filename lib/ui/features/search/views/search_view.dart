import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/heritage_site.dart';
import '../../heritage_sites/view_models/heritage_sites_view_model.dart';
import '../../heritage_sites/view_models/heritage_sites_state.dart';
import '../../settings/view_models/settings_view_model.dart';
import '../../settings/views/widgets/lg_connection_header.dart';
import '../../heritage_sites/views/heritage_site_detail_view.dart';
import 'widgets/filter_bottom_sheet.dart';
import 'widgets/heritage_card.dart';

class SearchView extends StatefulWidget {
  const SearchView({
    super.key,
    required this.viewModel,
    required this.sitesViewModel,
  });

  final SettingsViewModel viewModel;
  final HeritageSitesViewModel sitesViewModel;

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _visibleSiteCount = _pageSize;

  List<String> _cachedStates = [];
  int _cachedSitesCount = -1;

  void _updateCachedStates(List<HeritageSite> sites) {
    if (sites.length == _cachedSitesCount) return;
    _cachedSitesCount = sites.length;

    final uniqueStates = <String>{};
    for (final site in sites) {
      if (site.country.isNotEmpty) {
        final parts = site.country.split(',');
        for (final p in parts) {
          final st = p.trim();
          if (st.isNotEmpty) uniqueStates.add(st);
        }
      }
    }
    _cachedStates = uniqueStates.toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadNextPage);
  }

  @override
  void dispose() {
    if (widget.sitesViewModel.state.searchQuery.isNotEmpty) {
      widget.sitesViewModel.search('');
    }
    _searchController.dispose();
    _scrollController
      ..removeListener(_loadNextPage)
      ..dispose();
    super.dispose();
  }

  void _loadNextPage() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 400) {
      return;
    }

    final siteCount = _displaySites(widget.sitesViewModel.state).length;
    if (_visibleSiteCount >= siteCount) {
      return;
    }

    setState(() {
      final nextPageSize = _visibleSiteCount + _pageSize;
      _visibleSiteCount = nextPageSize < siteCount ? nextPageSize : siteCount;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _visibleSiteCount = _pageSize;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    widget.sitesViewModel.search(query);
  }

  bool _shouldShowHomeSites(HeritageSitesState state) {
    return state.searchQuery.trim().isEmpty &&
        state.selectedRegions.isEmpty &&
        state.selectedStates.isEmpty &&
        state.selectedCategories.isEmpty &&
        state.startYear == null &&
        state.endYear == null &&
        !state.showDangerSites;
  }

  List<HeritageSite> _displaySites(HeritageSitesState state) {
    if (!_shouldShowHomeSites(state)) {
      return state.filteredSites;
    }

    final homeSiteIds = state.homeSites.map((site) => site.propertyId).toSet();
    final remainingSites = state.filteredSites
        .where((site) => !homeSiteIds.contains(site.propertyId))
        .toList(growable: false);

    return List<HeritageSite>.unmodifiable([
      ...state.homeSites,
      ...remainingSites,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Discover new sites',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LgConnectionHeader(viewModel: widget.viewModel),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SearchBar(
                controller: _searchController,
                onChanged: _onSearchChanged,
                hintText: 'Search Heritage Sites...',
                hintStyle: const WidgetStatePropertyAll(
                  TextStyle(color: AppColors.onSurfaceVariant),
                ),
                textStyle: WidgetStatePropertyAll(
                  theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                leading: const Icon(
                  Icons.search_rounded,
                  color: AppColors.onSurfaceVariant,
                ),
                trailing: [
                  IconButton(
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.onSurfaceVariant,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) =>
                            FilterBottomSheet(viewModel: widget.sitesViewModel),
                      );
                    },
                  ),
                ],
                backgroundColor: WidgetStatePropertyAll(
                  AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                ),
                elevation: const WidgetStatePropertyAll(0),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: AppColors.outlineVariant, width: 0.5),
                ),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: widget.sitesViewModel,
              builder: (context, _) {
                final state = widget.sitesViewModel.state;
                if (state.sites.isEmpty) {
                  return const SizedBox(height: 40);
                }

                _updateCachedStates(state.sites);
                final statesList = _cachedStates;
                final selectedStates = state.selectedStates;

                return SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: statesList.length + 1,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isAllSites = index == 0;
                      final stateName = isAllSites
                          ? 'All Sites'
                          : statesList[index - 1];
                      final isSelected = isAllSites
                          ? selectedStates.isEmpty
                          : selectedStates.contains(stateName);

                      return ChoiceChip(
                        label: Text(
                          stateName,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.onPrimaryContainer
                                : AppColors.onSurfaceVariant,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        showCheckmark: false,
                        selectedColor: const Color(0xFF376A7C),
                        backgroundColor: AppColors.surfaceContainerHigh
                            .withValues(alpha: 0.5),
                        side: const BorderSide(
                          color: AppColors.outlineVariant,
                          width: 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected: (selected) {
                          if (isAllSites) {
                            if (!isSelected) {
                              widget.sitesViewModel.applyFilters(states: {});
                            }
                          } else {
                            if (selected) {
                              widget.sitesViewModel.filterByCountry(stateName);
                            } else {
                              widget.sitesViewModel.applyFilters(states: {});
                            }
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.sitesViewModel,
                builder: (context, child) {
                  final state = widget.sitesViewModel.state;
                  if (state.isLoading) {
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                      itemCount: 5,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 20),
                      itemBuilder: (context, index) =>
                          const HeritageCardSkeleton(),
                    );
                  }

                  final sites = _displaySites(state);
                  final visibleSiteCount = _visibleSiteCount < sites.length
                      ? _visibleSiteCount
                      : sites.length;
                  return ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                    itemCount: visibleSiteCount,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final site = sites[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => HeritageSiteDetailView(
                                site: site,
                                settingsViewModel: widget.viewModel,
                              ),
                            ),
                          );
                        },
                        child: HeritageCard(
                          title: site.name,
                          location: site.country,
                          imageUrl: site.mainImageUrl,
                          category: site.rawCategory,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
