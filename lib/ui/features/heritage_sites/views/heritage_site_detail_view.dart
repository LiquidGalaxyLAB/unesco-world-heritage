import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/utils/kml_builder.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/services/weather_service.dart';
import '../../../../domain/models/heritage_site.dart';
import '../../../../domain/models/heritage_site_geometry.dart';
import '../../../../domain/repositories/unesco_site_geometry_repository.dart';
import '../../../../domain/models/weather_data.dart';
import '../heritage_sites_dependencies.dart';
import '../view_models/heritage_site_detail_view_model.dart';
import '../../settings/view_models/settings_view_model.dart';
import '../../settings/views/widgets/lg_connection_header.dart';
import 'widgets/gemini_chat_bottom_sheet.dart';

class HeritageSiteDetailView extends StatefulWidget {
  const HeritageSiteDetailView({
    super.key,
    required this.site,
    required this.settingsViewModel,
  });

  final HeritageSite site;
  final SettingsViewModel settingsViewModel;

  @override
  State<HeritageSiteDetailView> createState() => _HeritageSiteDetailViewState();
}

class _HeritageSiteDetailViewState extends State<HeritageSiteDetailView> {
  String _selectedTab = 'Overview';
  bool _isAudioPlaying = false;
  bool _isRenderingOnLg = false;
  late final WebViewController _mapController;
  late final UnescoSiteGeometryRepository _geometryRepository;
  late final HeritageSiteDetailViewModel _detailViewModel;
  bool _isLoadingWeather = true;
  WeatherData? _weatherData;
  Future<HeritageSiteGeometry?>? _siteGeometryFuture;
  final FlutterTts _flutterTts = FlutterTts();
  VoidCallback? _detailViewModelListener;

  @override
  void initState() {
    super.initState();
    _geometryRepository = HeritageSitesDependencies.createGeometryRepository();
    _detailViewModel = HeritageSitesDependencies.createSiteDetailViewModel();
    _detailViewModelListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    _detailViewModel.addListener(_detailViewModelListener!);
    _detailViewModel.loadSite(widget.site.propertyId);
    _fetchWeather();
    _initTts();
    const String mapsApiKey = String.fromEnvironment(
      'MAPS_API_KEY',
      defaultValue: '',
    );

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
        var location = {lat: ${widget.site.latitude}, lng: ${widget.site.longitude}};
        var map = new google.maps.Map(document.getElementById('map'), {
          zoom: 7,
          center: location,
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

    _mapController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(htmlContent);
  }

  Future<void> _fetchWeather() async {
    double targetLat = widget.site.latitude;
    double targetLng = widget.site.longitude;

    try {
      final geometry = await _getSiteGeometry();

      if (geometry != null && !geometry.boundary.isEmpty) {
        final center = _calculateGeometryCenter(
          _calculateGeometryBounds(geometry.boundary),
        );
        targetLat = center.latitude;
        targetLng = center.longitude;
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
        });
      }
    }

    final service = WeatherService();
    final data = await service.fetchCurrentWeather(targetLat, targetLng);
    if (mounted) {
      setState(() {
        _weatherData = data;
        _isLoadingWeather = false;
      });
    }
  }

  Future<HeritageSiteGeometry?> _getSiteGeometry() {
    return _siteGeometryFuture ??= _geometryRepository.getSiteGeometry(
      widget.site.propertyId,
    );
  }

  Future<void> _handlePlayPressed() async {
    if (_isRenderingOnLg) {
      return;
    }

    if (!widget.settingsViewModel.state.isConnected) {
      _showSnackBar('Connect to Liquid Galaxy first.');
      return;
    }

    setState(() {
      _isRenderingOnLg = true;
    });

    try {
      final resolvedSite =
          _detailViewModel.state.site?.propertyId == widget.site.propertyId
          ? _detailViewModel.state.site!
          : widget.site;
      final geometry = await _getSiteGeometry();
      if (geometry == null || geometry.boundary.isEmpty) {
        _showSnackBar('No boundary geometry available for this site.');
        return;
      }

      final boundaryKml = KMLBuilder.buildBoundaryKml(
        name: resolvedSite.name,
        rings: geometry.boundary.rings
            .map(
              (ring) => ring
                  .map((point) => <double>[point.latitude, point.longitude])
                  .toList(growable: false),
            )
            .toList(growable: false),
      );
      final orbitCenter = _calculateGeometryCenter(
        _calculateGeometryBounds(geometry.boundary),
      );
      final orbitKml = KMLBuilder.createCityTour(
        tourName: 'Orbit',
        latitude: orbitCenter.latitude,
        longitude: orbitCenter.longitude,
        range: 12000,
        tilt: 60,
        orbitDuration: 30,
      );
      final balloonDescription = resolvedSite.shortDescription.trim().isNotEmpty
          ? resolvedSite.shortDescription.trim()
          : resolvedSite.description.trim().isNotEmpty
          ? resolvedSite.description.trim()
          : 'No description available for this UNESCO World Heritage Site.';
      final balloonKml = KMLBuilder.createSiteInfoBalloon(
        title: resolvedSite.name,
        description: balloonDescription,
        longitude: resolvedSite.longitude,
        latitude: resolvedSite.latitude,
        imageUrl: resolvedSite.mainImageUrl,
      );

      await widget.settingsViewModel.renderKmlOnLiquidGalaxy(
        fileName: 'site_${widget.site.propertyId}.kml',
        kml: boundaryKml,
        latitude: orbitCenter.latitude,
        longitude: orbitCenter.longitude,
        range: 9000,
        orbitFileName: 'site_${widget.site.propertyId}_orbit.kml',
        orbitKml: orbitKml,
      );
      await widget.settingsViewModel.renderKmlOnRightmostScreen(
        kml: balloonKml,
      );
    } catch (error) {
      _showSnackBar(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isRenderingOnLg = false;
        });
      }
    }
  }

  _GeometryBounds _calculateGeometryBounds(HeritagePolygonGeometry geometry) {
    if (geometry.rings.isEmpty) {
      return _GeometryBounds.empty();
    }

    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLng = double.infinity;
    double maxLng = double.negativeInfinity;

    for (final ring in geometry.rings) {
      for (final point in ring) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }
    }

    if (!minLat.isFinite || !minLng.isFinite) {
      return _GeometryBounds.empty();
    }

    return _GeometryBounds(
      minLatitude: minLat,
      maxLatitude: maxLat,
      minLongitude: minLng,
      maxLongitude: maxLng,
    );
  }

  _LatLngCenter _calculateGeometryCenter(_GeometryBounds bounds) {
    if (!bounds.isValid) {
      return _LatLngCenter(widget.site.latitude, widget.site.longitude);
    }

    return _LatLngCenter(
      (bounds.minLatitude + bounds.maxLatitude) / 2,
      (bounds.minLongitude + bounds.maxLongitude) / 2,
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);

    await _flutterTts.setSharedInstance(true);
    await _flutterTts
        .setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ]);

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isAudioPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    final listener = _detailViewModelListener;
    if (listener != null) {
      _detailViewModel.removeListener(listener);
    }
    _detailViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentSite = _detailViewModel.state.site ?? widget.site;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Content
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Map Placeholder
                Container(
                  height: 350,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        child: WebViewWidget(controller: _mapController),
                      ),
                      // Play Button
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isRenderingOnLg
                                  ? Icons.hourglass_top_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppColors.onSurface,
                            ),
                            onPressed: _isRenderingOnLg
                                ? null
                                : _handlePlayPressed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // LG Connected Status
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: LgConnectionHeader(
                    viewModel: widget.settingsViewModel,
                  ),
                ),

                const SizedBox(height: 12),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    currentSite.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Segmented Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTab(
                          title: 'Overview',
                          isSelected: _selectedTab == 'Overview',
                          onTap: () =>
                              setState(() => _selectedTab = 'Overview'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTab(
                          title: 'Climate',
                          isSelected: _selectedTab == 'Climate',
                          onTap: () => setState(() => _selectedTab = 'Climate'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (_selectedTab == 'Overview') ...[
                  // Chips
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChip(
                          assetPath: 'assets/images/location_icon.png',
                          label: widget.site.country.split(',').first.trim(),
                        ),
                        _buildChip(
                          assetPath: _getCategoryIcon(widget.site.category),
                          label: widget.site.rawCategory,
                        ),
                        _buildChip(
                          assetPath: 'assets/images/danger_icon.png',
                          label: widget.site.isDanger ? 'True' : 'False',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Inscription Year Chip
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildChip(
                      assetPath: 'assets/images/inscription_icon.png',
                      label: 'Inscription Year: ${widget.site.dateInscribed}',
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Explore Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Explore ${currentSite.name}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceVariant,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isAudioPlaying
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_off_rounded,
                                color: AppColors.onSurface,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isAudioPlaying = !_isAudioPlaying;
                                });
                                if (_isAudioPlaying) {
                                  _flutterTts.speak(currentSite.description);
                                } else {
                                  _flutterTts.stop();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  _buildClimateTab(theme),
                ],

                const SizedBox(height: 24), // Standard bottom padding
              ],
            ),
          ),

          // Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: ElevatedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) =>
                    GeminiChatBottomSheet(siteName: widget.site.name),
              );
            },
            icon: Image.asset(
              'assets/images/google_gemini_icon.png',
              width: 24,
              height: 24,
            ),
            label: const Text('Ask Gemini'),
            style: ElevatedButton.styleFrom(
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.3),
              backgroundColor: AppColors.surfaceContainerHighest,
              foregroundColor: AppColors.onSurface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              textStyle: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.surfaceVariant
              : AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? AppColors.onSurface
                : AppColors.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _getCategoryIcon(HeritageCategory category) {
    switch (category) {
      case HeritageCategory.cultural:
        return 'assets/images/cultural_site_icon.png';
      case HeritageCategory.natural:
        return 'assets/images/natural_site_icon.png';
      case HeritageCategory.mixed:
        return 'assets/images/mixed_site_icon.png';
      default:
        return 'assets/images/natural_site_icon.png';
    }
  }

  Widget _buildChip({required String assetPath, required String label}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(assetPath, width: 18, height: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClimateTab(ThemeData theme) {
    if (_isLoadingWeather) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            _buildShimmerCard(),
            const SizedBox(width: 16),
            _buildShimmerCard(),
            const SizedBox(width: 16),
            _buildShimmerCard(),
          ],
        ),
      );
    }

    final weather = _weatherData;
    final tempValue = weather != null
        ? '${weather.temperature.round()} °C'
        : '-- °C';
    final feelsLike = weather != null
        ? 'Feels like ${weather.feelsLike.round()}°C'
        : 'Feels like --°C';
    final windValue = weather != null
        ? '${weather.windSpeed.round()} km/h'
        : '-- km/h';
    final windDir = weather != null
        ? 'Direction: ${weather.windDirection}°'
        : 'Direction: --°';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildClimateCard(
            theme: theme,
            icon: Icons.cloud_outlined,
            value: tempValue,
            label: feelsLike,
          ),
          const SizedBox(width: 16),
          _buildClimateCard(
            theme: theme,
            icon: Icons.air_rounded,
            value: windValue,
            label: windDir,
          ),
          const SizedBox(width: 16),
          _buildClimateCard(
            theme: theme,
            icon: Icons.travel_explore_rounded,
            value: 'Nov - Feb',
            label: 'Best Season',
          ),
        ],
      ),
    );
  }

  Widget _buildClimateCard({
    required ThemeData theme,
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      width: 130,
      height: 160,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer(
      duration: const Duration(milliseconds: 1400),
      color: AppColors.onSurface,
      colorOpacity: 0.12,
      child: Container(
        width: 130,
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _LatLngCenter {
  const _LatLngCenter(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class _GeometryBounds {
  const _GeometryBounds({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  const _GeometryBounds.empty()
    : minLatitude = double.nan,
      maxLatitude = double.nan,
      minLongitude = double.nan,
      maxLongitude = double.nan;

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  bool get isValid =>
      minLatitude.isFinite &&
      maxLatitude.isFinite &&
      minLongitude.isFinite &&
      maxLongitude.isFinite;
}
