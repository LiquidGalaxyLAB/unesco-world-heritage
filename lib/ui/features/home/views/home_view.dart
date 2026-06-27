import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../settings/view_models/settings_view_model.dart';
import '../../settings/views/widgets/lg_connection_header.dart';
import '../../heritage_sites/view_models/heritage_sites_view_model.dart';
import '../../heritage_sites/views/heritage_site_detail_view.dart';
import '../../search/views/widgets/heritage_card.dart';

class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
    required this.settingsViewModel,
    required this.sitesViewModel,
  });

  final SettingsViewModel settingsViewModel;
  final HeritageSitesViewModel sitesViewModel;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static const int _pageSize = 10;

  late final WebViewController _mapController;
  final ScrollController _scrollController = ScrollController();
  int _visibleSiteCount = _pageSize;

  @override
  void initState() {
    super.initState();

    _mapController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
      
    _loadMapHtml();

    _scrollController.addListener(_loadNextPage);
  }

  Future<void> _loadMapHtml() async {
    final prefs = await SharedPreferences.getInstance();
    final mapsApiKey = prefs.getString('google_map_api_key') ?? '';

    final htmlContent =
        '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <meta charset="utf-8">
    <style>
      html, body { height: 100%; margin: 0; padding: 0; background-color: #1E1E1E; }
      #map { height: 100%; }
    </style>
  </head>
  <body>
    <div id="map"></div>
    <script>
      function initMap() {
        var map = new google.maps.Map(document.getElementById('map'), {
          zoom: 2,
          center: {lat: 20.0, lng: 0.0},
          mapTypeId: 'satellite',
          disableDefaultUI: true
        });
      }
    </script>
    <script async defer
      src="https://maps.googleapis.com/maps/api/js?key=$mapsApiKey&callback=initMap">
    </script>
  </body>
</html>
''';

    await _mapController.loadHtmlString(htmlContent);
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  void dispose() {
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

    final siteCount = widget.sitesViewModel.state.homeSites.length;
    if (_visibleSiteCount >= siteCount) {
      return;
    }

    setState(() {
      final nextPageSize = _visibleSiteCount + _pageSize;
      _visibleSiteCount = nextPageSize < siteCount ? nextPageSize : siteCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.30,
            pinned: true,
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                var top = constraints.biggest.height;
                var isCollapsed =
                    top <=
                    kToolbarHeight + MediaQuery.of(context).padding.top + 10;

                return FlexibleSpaceBar(
                  title: isCollapsed
                      ? const Text(
                          'Unesco World Heritage',
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                  centerTitle: false,
                  titlePadding: const EdgeInsetsDirectional.only(
                    start: 24,
                    bottom: 16,
                  ),
                  collapseMode: CollapseMode.parallax,
                  background: WebViewWidget(controller: _mapController),
                );
              },
            ),
            backgroundColor: AppColors.surfaceContainerHigh,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LG Connected Status
                  LgConnectionHeader(viewModel: widget.settingsViewModel),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Discover Sites Near You',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Heritage Cards List
                  ListenableBuilder(
                    listenable: widget.sitesViewModel,
                    builder: (context, _) {
                      final state = widget.sitesViewModel.state;

                      if (state.isLoading) {
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: 5,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) =>
                              const HeritageCardSkeleton(),
                        );
                      }

                      if (state.homeSites.isEmpty) {
                        return const Center(child: Text('No sites available.'));
                      }

                      final visibleSiteCount =
                          _visibleSiteCount < state.homeSites.length
                          ? _visibleSiteCount
                          : state.homeSites.length;
                      final displaySites = state.homeSites
                          .take(visibleSiteCount)
                          .toList(growable: false);

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: displaySites.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final site = displaySites[index];
                          // Dummy distance logic for UI
                          final dummyDistances = [100, 180, 250, 310, 420];
                          final distance = index < dummyDistances.length
                              ? dummyDistances[index]
                              : (index + 1) * 80;

                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => HeritageSiteDetailView(
                                    site: site,
                                    settingsViewModel: widget.settingsViewModel,
                                  ),
                                ),
                              );
                            },
                            child: HeritageCard(
                              title: site.name,
                              location: '$distance km away',
                              imageUrl: site.mainImageUrl,
                              category: _capitalize(site.category.name),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  if (_visibleSiteCount <
                      widget.sitesViewModel.state.homeSites.length) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ],

                  // Extra padding for bottom nav bar
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
