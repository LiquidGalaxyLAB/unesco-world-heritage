import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/services/weather_service.dart';
import '../../../../domain/models/heritage_site.dart';
import '../../../../domain/models/weather_data.dart';
import '../heritage_sites_dependencies.dart';
import '../../settings/view_models/settings_view_model.dart';
import '../../settings/views/widgets/lg_connection_header.dart';

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
  late final WebViewController _mapController;
  bool _isLoadingWeather = true;
  WeatherData? _weatherData;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
    const String mapsApiKey = String.fromEnvironment('MAPS_API_KEY', defaultValue: '');
    
    final htmlContent = '''
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
      final geometryRepo = HeritageSitesDependencies.createGeometryRepository();
      final geometry = await geometryRepo.getSiteGeometry(widget.site.propertyId);
      
      if (geometry != null && !geometry.boundary.isEmpty) {
        double sumLat = 0;
        double sumLng = 0;
        int count = 0;
        
        for (final ring in geometry.boundary.rings) {
          for (final point in ring) {
            sumLat += point.latitude;
            sumLng += point.longitude;
            count++;
          }
        }
        
        if (count > 0) {
          targetLat = sumLat / count;
          targetLng = sumLng / count;
        }
      }
    } catch (_) {
      // Fallback to default coordinates on error
    }

    final service = WeatherService();
    final data = await service.fetchCurrentWeather(
      targetLat,
      targetLng,
    );
    if (mounted) {
      setState(() {
        _weatherData = data;
        _isLoadingWeather = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                            icon: const Icon(Icons.play_arrow_rounded, color: AppColors.onSurface),
                            onPressed: () {
                              // Fly to location
                            },
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
                  child: LgConnectionHeader(viewModel: widget.settingsViewModel),
                ),
                
                const SizedBox(height: 12),
                
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    widget.site.name,
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
                          onTap: () => setState(() => _selectedTab = 'Overview'),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
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
                              'Explore ${widget.site.name}',
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
                                _isAudioPlaying ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                                color: AppColors.onSurface,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isAudioPlaying = !_isAudioPlaying;
                                });
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
            onPressed: () {},
            icon: Image.asset(
              'assets/images/google_gemini_icon.png',
              width: 24,
              height: 24,
            ),
            label: const Text('Ask Gemini'),
            style: ElevatedButton.styleFrom(
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.3),
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

  Widget _buildTab({required String title, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceVariant : AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.onSurface : AppColors.onSurfaceVariant,
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
    final tempValue = weather != null ? '${weather.temperature.round()} °C' : '-- °C';
    final feelsLike = weather != null ? 'Feels like ${weather.feelsLike.round()}°C' : 'Feels like --°C';
    final windValue = weather != null ? '${weather.windSpeed.round()} km/h' : '-- km/h';
    final windDir = weather != null ? 'Direction: ${weather.windDirection}°' : 'Direction: --°';

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
            color: Colors.black.withOpacity(0.1),
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
