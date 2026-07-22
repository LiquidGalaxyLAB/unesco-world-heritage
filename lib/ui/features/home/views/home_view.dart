import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../domain/models/heritage_site.dart';
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

  Position? _currentPosition;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();

    _mapController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
      
    _loadMapHtml();

    _scrollController.addListener(_loadNextPage);

    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLoadingLocation = false);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        // Fallback to last known position if current position times out or fails
        position = await Geolocator.getLastKnownPosition();
      }

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
        // Push the resolved coordinates into the session-level VM cache.
        // position may be null if getLastKnownPosition() returned nothing.
        if (position != null) {
          widget.sitesViewModel.updateUserLocation(
            position.latitude,
            position.longitude,
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _loadMapHtml() async {
    final prefs = await SharedPreferences.getInstance();
    final configuredMapsApiKey =
        prefs.getString('google_map_api_key')?.trim() ?? '';
    final mapsApiKey = configuredMapsApiKey.isNotEmpty
        ? configuredMapsApiKey
        : dotenv.env['GOOGLE_MAPS_API_KEY']?.trim() ?? '';

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

                      // Show shimmer until both the full dataset AND GPS are
                      // ready so nearest sites can be computed correctly.
                      // Skip shimmer immediately if we have session-cached
                      // nearest sites (navigating back = instant display).
                      if ((state.isLoading || _isLoadingLocation || !state.allSitesLoaded) &&
                          state.nearestSites.isEmpty) {
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

                      // Use session-cached nearest sites from the VM.
                      final List<HeritageSite> displaySites;
                      final List<int> displayDistances;

                      if (state.nearestSites.isNotEmpty) {
                        displaySites = state.nearestSites;
                        displayDistances = state.nearestDistancesKm;
                      } else {
                        // Fallback: GPS unavailable — show homeSites.
                        if (state.homeSites.isEmpty) {
                          return const Center(
                              child: Text('No sites available.'));
                        }
                        final visibleSiteCount =
                            _visibleSiteCount < state.homeSites.length
                            ? _visibleSiteCount
                            : state.homeSites.length;
                        displaySites = state.homeSites
                            .take(visibleSiteCount)
                            .toList(growable: false);
                        const dummyDistances = [100, 180, 250, 310, 420];
                        displayDistances = List.generate(
                            displaySites.length,
                            (i) => i < dummyDistances.length
                                ? dummyDistances[i]
                                : (i + 1) * 80);
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: displaySites.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final site = displaySites[index];
                          final distance = displayDistances[index];

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
                              siteName: site.name,
                            ),
                          );
                        },
                      );
                    },
                  ),

                  if (_currentPosition == null && _visibleSiteCount <
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
