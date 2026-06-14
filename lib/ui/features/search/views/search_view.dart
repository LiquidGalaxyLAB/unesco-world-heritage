import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../heritage_sites/view_models/heritage_sites_view_model.dart';
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadNextPage);
  }

  @override
  void dispose() {
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

    final siteCount = widget.sitesViewModel.state.filteredSites.length;
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
                        builder: (context) => FilterBottomSheet(viewModel: widget.sitesViewModel),
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
            const SizedBox(height: 24),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.sitesViewModel,
                builder: (context, child) {
                  final state = widget.sitesViewModel.state;
                  if (state.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final sites = state.filteredSites;
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
