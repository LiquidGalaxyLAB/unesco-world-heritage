import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/utils/kml_builder.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/services/weather_service.dart';
import '../../../../data/services/lg_map_sync_service.dart';
import '../../../../domain/models/heritage_site.dart';
import '../../../../domain/models/heritage_site_geometry.dart';
import '../../../../domain/repositories/unesco_site_geometry_repository.dart';
import '../../../../domain/models/weather_data.dart';
import '../heritage_sites_dependencies.dart';
import '../view_models/heritage_site_detail_view_model.dart';
import '../../settings/view_models/settings_view_model.dart';
import '../../settings/views/widgets/lg_connection_header.dart';
import 'widgets/gemini_chat_bottom_sheet.dart';
import '../../../../data/services/gemini_service.dart';
import '../../../../data/services/speechmatics_tts_service.dart';

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
  bool _isMuted = false;
  bool _isOrbitActive = false;
  bool _isLgScenePrepared = false;
  bool _isRenderingOnLg = false;

  static const int _orbitTourDurationSeconds = 24;
  Timer? _orbitCompletionTimer;
  late final WebViewController _mapController;
  late final UnescoSiteGeometryRepository _geometryRepository;
  late final HeritageSiteDetailViewModel _detailViewModel;
  LGMapSyncService? _mapSyncService;
  bool _isLoadingWeather = true;
  WeatherData? _weatherData;
  Future<HeritageSiteGeometry?>? _siteGeometryFuture;
  late final SpeechmaticsTtsService _speechmaticsTts;
  // Single GeminiService instance reused for every story play on this page.
  // Avoids re-establishing the TLS/API connection on each call.
  late final GeminiService _geminiService;
  late final Future<String?> _storyFuture;
  VoidCallback? _detailViewModelListener;
  String? _bestTimeToVisit;
  // Futures cached so _buildLgRenderPayload can await them regardless of
  // whether the UI has already received the results via setState.
  late final Future<WeatherData?> _weatherFuture;
  late final Future<String?> _bestTimeFuture;

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
    _weatherFuture = _fetchWeather();
    _bestTimeFuture = _loadBestTimeToVisit();
    _speechmaticsTts = SpeechmaticsTtsService(
      onPlaybackComplete: () {
        if (mounted) setState(() => _isAudioPlaying = false);
      },
    );
    _geminiService = GeminiService();
    _storyFuture = _prepareStory(widget.site);

    _mapController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('MapSync', onMessageReceived: _onMapCameraChanged);

    _initializeMap();

    // Auto-start sync if LG is already connected when this view opens.
    if (widget.settingsViewModel.state.isConnected) {
      _ensureMapSyncStarted();
    }

    // Auto fly-to LG when the view opens (if already connected).
    if (widget.settingsViewModel.state.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _performFlyTo();
      });
    }
  }

  @override
  void didUpdateWidget(HeritageSiteDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasConnected = oldWidget.settingsViewModel.state.isConnected;
    final isConnected = widget.settingsViewModel.state.isConnected;
    if (!wasConnected && isConnected) {
      _ensureMapSyncStarted();
    } else if (wasConnected && !isConnected) {
      _mapSyncService?.stopSync();
    }
  }

  /// Lazily initialises the sync service and starts it.
  void _ensureMapSyncStarted() {
    _mapSyncService ??= LGMapSyncService(
      HeritageSitesDependencies.lgRigService,
    );
    _mapSyncService!.startSync();
  }

  /// Loads and parses [assets/whc_site_bestTimeVisit.json], then looks up
  /// the best-time-to-visit entry whose [id_no] matches this site's [propertyId].
  /// Returns the matched value (or null) so callers can await it directly.
  Future<String?> _loadBestTimeToVisit() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/whc_site_bestTimeVisit.json',
      );
      final list = jsonDecode(raw) as List<dynamic>;
      final propertyIdStr = widget.site.propertyId.toString();
      for (final entry in list) {
        if ((entry as Map<String, dynamic>)['id_no'] == propertyIdStr) {
          final rawTime = entry['best_time'] as String? ?? '';
          final value = rawTime.split(',').first.trim();
          if (mounted) {
            setState(() {
              _bestTimeToVisit = value;
            });
          }
          return value;
        }
      }
      // No match found.
    } catch (e) {
      debugPrint('BestTimeToVisit: failed to load – $e');
    }
    return null;
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
      window.siteMap = null;
      window.mapReady = false;
      window.sitePolygons = [];
      window._pendingPolygonCall = null;

      function initMap() {
        var location = {lat: ${widget.site.latitude}, lng: ${widget.site.longitude}};
        // The initial map positioning and later fitBounds calls are app-driven.
        // Do not let them overwrite the LG site's intentional 30 degree tilt.
        window.suppressNextCameraSync = true;
        window.siteMap = new google.maps.Map(document.getElementById('map'), {
          zoom: 7,
          center: location,
          mapTypeId: 'satellite',
          disableDefaultUI: true
        });
        window.mapReady = true;
        if (window._pendingPolygonCall) {
          window._pendingPolygonCall();
          window._pendingPolygonCall = null;
        }

        // Listen for camera changes and send to Flutter via MapSync channel.
        window.siteMap.addListener('idle', function() {
          if (window.suppressNextCameraSync) {
            window.suppressNextCameraSync = false;
            return;
          }
          if (window.MapSync) {
            var center = window.siteMap.getCenter();
            var zoom = window.siteMap.getZoom();
            var heading = window.siteMap.getHeading() || 0;
            var tilt = window.siteMap.getTilt() || 0;
            var payload = JSON.stringify({
              lat: center.lat(),
              lng: center.lng(),
              zoom: zoom,
              heading: heading,
              tilt: tilt
            });
            window.MapSync.postMessage(payload);
          }
        });
      }

      window.addSitePolygons = function(ringsJson, strokeColor, fillColor, strokeOpacity, fillOpacity) {
        function render() {
          try {
            var rings = JSON.parse(ringsJson);
            var bounds = new google.maps.LatLngBounds();
            for (var i = 0; i < rings.length; i++) {
              var path = [];
              for (var j = 0; j < rings[i].length; j++) {
                var latLng = new google.maps.LatLng(rings[i][j][0], rings[i][j][1]);
                path.push(latLng);
                bounds.extend(latLng);
              }
              if (path.length > 2) {
                var polygon = new google.maps.Polygon({
                  paths: [path],
                  strokeColor: strokeColor,
                  strokeOpacity: strokeOpacity,
                  strokeWeight: 3,
                  fillColor: fillColor,
                  fillOpacity: fillOpacity,
                  map: window.siteMap
                });
                window.sitePolygons.push(polygon);
              }
            }
            if (!bounds.isEmpty()) {
              window.suppressNextCameraSync = true;
              window.siteMap.fitBounds(bounds, 40);
            }
          } catch(e) {
            console.error('Error adding polygons:', e);
          }
        }
        if (window.mapReady) {
          render();
        } else {
          window._pendingPolygonCall = render;
        }
      };
    </script>
    <script async defer
      src="https://maps.googleapis.com/maps/api/js?key=$mapsApiKey&callback=initMap">
    </script>
  </body>
</html>
''';

    await _mapController.loadHtmlString(htmlContent);
  }

  /// Loads the JavaScript map host before sending the first boundary render.
  /// This prevents the initial site's polygon call from arriving before
  /// `window.addSitePolygons` has been defined in the WebView.
  Future<void> _initializeMap() async {
    await _loadMapHtml();
    if (!mounted) {
      return;
    }
    await _renderBoundaryPolygonOnMap();
  }

  /// Fetches the site geometry and renders 2D polygon boundaries on the
  /// phone's Google Map WebView using the Maps JavaScript API.
  Future<void> _renderBoundaryPolygonOnMap() async {
    try {
      final geometry = await _getSiteGeometry();
      if (geometry == null || geometry.boundary.isEmpty) {
        return;
      }

      // Convert rings to coordinate arrays: [[lat, lng], ...] per ring.
      final rings = geometry.boundary.rings.length > 1
          ? <List<HeritageGeoPoint>>[
              _findLargestRing(geometry.boundary) ??
                  geometry.boundary.rings.first,
            ]
          : geometry.boundary.rings;
      final ringsData = rings
          .map(
            (ring) => ring
                .map((point) => <double>[point.latitude, point.longitude])
                .toList(),
          )
          .toList();

      final ringsJson = jsonEncode(ringsData);
      final colors = _getMapPolygonColors(widget.site.category);

      // Escape single-quotes for the JS string literal.
      final escapedJson = ringsJson.replaceAll("'", "\\'");

      final jsCall =
          "window.addSitePolygons("
          "'$escapedJson', "
          "'${colors.strokeColor}', "
          "'${colors.fillColor}', "
          "${colors.strokeOpacity}, "
          "${colors.fillOpacity}"
          ");";

      await _mapController.runJavaScript(jsCall);
    } catch (e) {
      debugPrint('Error rendering boundary polygon on map: \$e');
    }
  }

  _MapPolygonColors _getMapPolygonColors(HeritageCategory category) {
    switch (category) {
      case HeritageCategory.cultural:
        return const _MapPolygonColors(
          strokeColor: '#FFCC33',
          fillColor: '#FFCC33',
          strokeOpacity: 1.0,
          fillOpacity: 0.25,
        );
      case HeritageCategory.mixed:
        return const _MapPolygonColors(
          strokeColor: '#00E5FF',
          fillColor: '#00E5FF',
          strokeOpacity: 1.0,
          fillOpacity: 0.25,
        );
      case HeritageCategory.natural:
        return const _MapPolygonColors(
          strokeColor: '#39FF14',
          fillColor: '#39FF14',
          strokeOpacity: 1.0,
          fillOpacity: 0.25,
        );
      case HeritageCategory.unknown:
        return const _MapPolygonColors(
          strokeColor: '#87CEEB',
          fillColor: '#87CEEB',
          strokeOpacity: 1.0,
          fillOpacity: 0.25,
        );
    }
  }

  Future<WeatherData?> _fetchWeather() async {
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
    return data;
  }

  Future<HeritageSiteGeometry?> _getSiteGeometry() {
    return _siteGeometryFuture ??= _geometryRepository.getSiteGeometry(
      widget.site.propertyId,
    );
  }

  Future<_LgRenderPayload> _buildLgRenderPayload() async {
    final resolvedSite =
        _detailViewModel.state.site?.propertyId == widget.site.propertyId
        ? _detailViewModel.state.site!
        : widget.site;
    final geometry = await _getSiteGeometry();
    final cameraProfile = _buildCameraProfile(
      site: resolvedSite,
      geometry: geometry,
    );
    final boundaryKml = _buildRenderableSiteKml(
      site: resolvedSite,
      geometry: geometry,
    );
    final orbitKml = KMLBuilder.createCityTour(
      tourName: 'Orbit',
      latitude: cameraProfile.center.latitude,
      longitude: cameraProfile.center.longitude,
      range: cameraProfile.orbitRange,
      tilt: cameraProfile.tilt,
      orbitDuration: 20,
    );
    final balloonDescription = resolvedSite.shortDescription.trim().isNotEmpty
        ? resolvedSite.shortDescription.trim()
        : resolvedSite.description.trim().isNotEmpty
        ? resolvedSite.description.trim()
        : 'No description available for this UNESCO World Heritage Site.';

    // Await both climate futures in parallel so the balloon always has data.
    final climateResults = await Future.wait([_weatherFuture, _bestTimeFuture]);
    final weather = climateResults[0] as WeatherData?;
    final bestTime = climateResults[1] as String?;

    final balloonKml = KMLBuilder.createSiteInfoBalloon(
      title: resolvedSite.name,
      description: balloonDescription,
      longitude: resolvedSite.longitude,
      latitude: resolvedSite.latitude,
      imageUrl: resolvedSite.mainImageUrl,
      temperature: weather != null ? '${weather.temperature.round()} °C' : null,
      windSpeed: weather != null ? '${weather.windSpeed.round()} km/h' : null,
      bestTimeToVisit: bestTime,
    );

    return _LgRenderPayload(
      cameraProfile: cameraProfile,
      boundaryKml: boundaryKml,
      orbitKml: orbitKml,
      balloonKml: balloonKml,
    );
  }

  Future<void> _playStory() async {
    setState(() {
      _isAudioPlaying = true;
    });

    final currentSite = _detailViewModel.state.site ?? widget.site;
    final box = Hive.box<String>('stories');
    final cacheKey = 'site_story_${currentSite.propertyId}';

    String? story = box.get(cacheKey) ?? await _storyFuture;

    if (story == null) {
      try {
        // Reuse the shared instance — avoids a new TLS handshake every call.
        final prompt =
            'Tell me a short interesting narrative about ${currentSite.name}. Include what site it is, where it is located (${currentSite.country}), the best time to visit, and one interesting fact. Keep it short and engaging.';
        final response = await _geminiService.sendMessage(prompt);
        if (response.startsWith('Error:')) {
          story = currentSite.shortDescription.trim().isNotEmpty
              ? currentSite.shortDescription.trim()
              : currentSite.description.trim().isNotEmpty
              ? currentSite.description.trim()
              : 'No description available for this UNESCO World Heritage Site.';
        } else {
          story = response;
          await box.put(cacheKey, story);
        }
      } catch (e) {
        story = currentSite.shortDescription.trim().isNotEmpty
            ? currentSite.shortDescription.trim()
            : currentSite.description.trim().isNotEmpty
            ? currentSite.description.trim()
            : 'No description available for this UNESCO World Heritage Site.';
      }
    }

    if (!mounted) return;

    if (_isAudioPlaying) {
      if (_isMuted) {
        await _speechmaticsTts.stop();
        if (mounted) setState(() => _isAudioPlaying = false);
        return;
      }
      // Guard the stop()→speak() transition so the completion handler does
      // not fire _isAudioPlaying = false between the two calls, which was
      // causing the orbit glitch and the Play/Pause button flicker.
      await _speechmaticsTts.stop();
      try {
        await _speechmaticsTts.speak(story!);
      } catch (error) {
        if (mounted) {
          setState(() => _isAudioPlaying = false);
          _showSnackBar('Could not play the Speechmatics audio story. $error');
        }
      }
    }
  }

  Future<String> _prepareStory(HeritageSite site) async {
    final box = Hive.box<String>('stories');
    final cacheKey = 'site_story_${site.propertyId}';
    final cachedStory = box.get(cacheKey);
    if (cachedStory != null) return cachedStory;

    final fallback = site.shortDescription.trim().isNotEmpty
        ? site.shortDescription.trim()
        : site.description.trim().isNotEmpty
        ? site.description.trim()
        : 'No description available for this UNESCO World Heritage Site.';

    try {
      final prompt =
          'Tell me a short interesting narrative about ${site.name}. Include what site it is, where it is located (${site.country}), the best time to visit, and one interesting fact. Keep it short and engaging.';
      final story = await _geminiService.sendMessage(prompt);
      if (story.startsWith('Error:')) return fallback;

      await box.put(cacheKey, story);
      return story;
    } catch (_) {
      return fallback;
    }
  }

  /// Core LG render logic shared by both the automatic trigger and any
  /// manual invocations. Does NOT show dialogs.
  Future<void> _performFlyTo() async {
    if (_isRenderingOnLg) return;
    if (!widget.settingsViewModel.state.isConnected) return;

    setState(() {
      _isRenderingOnLg = true;
    });

    // Map sync sends the phone map's 2-D tilt (normally 0 degrees). Pause it
    // until the LG scene's final 30 degree fly-to has completed.
    final shouldResumeMapSync = _mapSyncService?.isSyncing ?? false;
    _mapSyncService?.stopSync();

    try {
      // Clear the previous site and its balloon before awaiting geometry and
      // climate data for the next one.
      final clearSiteKmlFuture = widget.settingsViewModel.clearSiteKml();
      final clearBalloonFuture = widget.settingsViewModel
          .clearRightmostScreen();
      final payload = await _buildLgRenderPayload();

      await Future.wait([
        () async {
          await clearSiteKmlFuture;
          await widget.settingsViewModel.renderKmlOnLiquidGalaxy(
            fileName: 'site_${widget.site.propertyId}.kml',
            kml: payload.boundaryKml,
            latitude: payload.cameraProfile.center.latitude,
            longitude: payload.cameraProfile.center.longitude,
            range: payload.cameraProfile.flyToRange,
            orbitFileName: 'site_${widget.site.propertyId}_orbit.kml',
            orbitKml: payload.orbitKml,
            tilt: payload.cameraProfile.tilt,
            altitude: payload.cameraProfile.altitude,
            startOrbitAfterRender: false,
            clearExistingKml: false,
          );
        }(),
        () async {
          await clearBalloonFuture;
          await widget.settingsViewModel.renderKmlOnRightmostScreen(
            kml: payload.balloonKml,
          );
        }(),
      ]);
      if (mounted) {
        setState(() {
          _isOrbitActive = false;
          _isLgScenePrepared = true;
        });
        // Orbit is not auto-started. The user starts it explicitly via the
        // Orbit toggle button.
      }
    } catch (error) {
      _showSnackBar(error.toString());
    } finally {
      if (shouldResumeMapSync && widget.settingsViewModel.state.isConnected) {
        _mapSyncService?.startSync();
      }
      if (mounted) {
        setState(() {
          _isRenderingOnLg = false;
        });
      }
    }
  }

  Future<void> _handleFlyToPressed() async {
    if (_isRenderingOnLg) return;

    if (!widget.settingsViewModel.state.isConnected) {
      _showSnackBar('Connect to Liquid Galaxy first.');
      return;
    }

    // Audio story is available via the Play button in the Explore card.
    // No prompt is shown here.
    await _performFlyTo();
  }

  Future<void> _handleOrbitPressed() async {
    if (_isRenderingOnLg) {
      return;
    }

    if (_isOrbitActive) {
      await _handleStopOrbitPressed();
      return;
    }

    if (!widget.settingsViewModel.state.isConnected) {
      _showSnackBar('Connect to Liquid Galaxy first.');
      return;
    }

    if (!_isLgScenePrepared) {
      _showSnackBar('Tap Fly To first.');
      return;
    }

    // Re-anchor the camera to the site before replaying the orbit tour.
    // This prevents the jarring snap/glitch caused by the KML tour always
    // restarting from its first keyframe position.
    setState(() {
      _isRenderingOnLg = true;
    });

    try {
      final payload = await _buildLgRenderPayload();
      await widget.settingsViewModel.flyToOnLiquidGalaxy(
        latitude: payload.cameraProfile.center.latitude,
        longitude: payload.cameraProfile.center.longitude,
        range: payload.cameraProfile.flyToRange,
        tilt: payload.cameraProfile.tilt,
        altitude: payload.cameraProfile.altitude,
      );
      // Allow the camera animation to settle before starting the tour.
      await Future<void>.delayed(const Duration(seconds: 3));
      await widget.settingsViewModel.startOrbitOnLiquidGalaxy();
      if (mounted) {
        setState(() {
          _isOrbitActive = true;
        });
      }
    } catch (error) {
      _showSnackBar(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isRenderingOnLg = false;
        });
      }
    }

    // Start the countdown so the button resets when the tour ends.
    if (mounted && _isOrbitActive) {
      _startOrbitCompletionTimer();
    }
  }

  Future<void> _handleStopOrbitPressed() async {
    final shouldStop = await _showStopOrbitDialog();
    if (shouldStop != true) {
      return;
    }
    // User confirmed stop — cancel the auto-reset timer.
    _cancelOrbitCompletionTimer();

    if (!widget.settingsViewModel.state.isConnected) {
      _showSnackBar('Connect to Liquid Galaxy first.');
      return;
    }

    setState(() {
      _isRenderingOnLg = true;
    });

    try {
      await widget.settingsViewModel.stopOrbitOnLiquidGalaxy();
      if (mounted) {
        setState(() {
          _isOrbitActive = false;
        });
      }
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

  Future<bool?> _showStopOrbitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainerHighest,
          title: const Text('Do you want to stop the orbit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  /// Starts the orbit silently (no dialog) then prompts the user about the
  /// audio story. Called automatically after fly-to completes.
  Future<void> _autoStartOrbit() async {
    if (_isRenderingOnLg || _isOrbitActive) return;
    if (!widget.settingsViewModel.state.isConnected) return;

    setState(() => _isRenderingOnLg = true);

    try {
      await widget.settingsViewModel.startOrbitOnLiquidGalaxy();
      if (mounted) {
        setState(() => _isOrbitActive = true);
      }
    } catch (error) {
      _showSnackBar(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isRenderingOnLg = false);
      }
    }

    // Start the countdown so the button resets when the tour ends.
    if (mounted && _isOrbitActive) {
      _startOrbitCompletionTimer();
    }
  }

  /// Starts a one-shot timer that resets [_isOrbitActive] to false once the
  /// orbit KML tour finishes playing on Liquid Galaxy. Cancels any previous
  /// timer first so restarting orbit always gets a fresh countdown.
  void _startOrbitCompletionTimer() {
    _orbitCompletionTimer?.cancel();
    _orbitCompletionTimer = Timer(
      const Duration(seconds: _orbitTourDurationSeconds),
      () {
        if (mounted && _isOrbitActive) {
          setState(() => _isOrbitActive = false);
        }
      },
    );
  }

  /// Cancels the orbit completion timer (called on manual stop or dispose).
  void _cancelOrbitCompletionTimer() {
    _orbitCompletionTimer?.cancel();
    _orbitCompletionTimer = null;
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

  /// Returns the bounding box of the **densest cluster** of rings in
  /// [geometry] for multi-component (>1 ring) sites.
  ///
  /// Strategy:
  /// 1. Compute the centroid (mean lat/lng) of all ring centroids.
  /// 2. For each ring centroid compute its distance to the overall centroid.
  /// 3. Compute the median distance; keep only rings whose centroid is within
  ///    2× the median distance — this discards outlier satellite polygons.
  /// 4. Return the combined bounding box of those clustered rings so the
  ///    camera zooms in on where most KMLs actually are.
  ///
  /// Falls back to the overall geometry bounds if clustering produces no
  /// valid result (e.g. all rings are equidistant from the centroid).
  /// Returns the bounding box of the **single largest ring** in [geometry].
  ///
  /// "Largest" is defined by the area of the ring's own bounding box
  /// (latSpan × lngSpan in degree²), which is a fast proxy for ring size
  /// without needing a full polygon-area calculation.
  ///
  /// Falls back to the full geometry bounds when no ring has ≥4 points.
  _GeometryBounds _findLargestRingBounds(HeritagePolygonGeometry geometry) {
    final largest = _findLargestRing(geometry);
    if (largest == null) return _calculateGeometryBounds(geometry);

    var minLat = double.infinity;
    var maxLat = double.negativeInfinity;
    var minLng = double.infinity;
    var maxLng = double.negativeInfinity;
    for (final p in largest) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    return _GeometryBounds(
      minLatitude: minLat,
      maxLatitude: maxLat,
      minLongitude: minLng,
      maxLongitude: maxLng,
    );
  }

  List<HeritageGeoPoint>? _findLargestRing(HeritagePolygonGeometry geometry) {
    List<HeritageGeoPoint>? largest;
    double largestArea = -1;

    for (final ring in geometry.rings) {
      if (ring.length < 4) continue;
      var minLat = double.infinity;
      var maxLat = double.negativeInfinity;
      var minLng = double.infinity;
      var maxLng = double.negativeInfinity;
      for (final p in ring) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      if (!minLat.isFinite || !minLng.isFinite) continue;
      final area = (maxLat - minLat) * (maxLng - minLng);
      if (area > largestArea) {
        largestArea = area;
        largest = ring;
      }
    }

    return largest;
  }

  _GeometryBounds _findClusterBounds(HeritagePolygonGeometry geometry) {
    if (geometry.rings.isEmpty) return const _GeometryBounds.empty();

    // --- Step 1: compute per-ring centroids ---
    // Store (centroid, ring) pairs so the ring reference is preserved even
    // when rings with <4 points are skipped.
    final centroidRingPairs =
        <({_LatLngCenter centroid, List<HeritageGeoPoint> ring})>[];
    for (final ring in geometry.rings) {
      if (ring.length < 4) continue;
      var minLat = double.infinity;
      var maxLat = double.negativeInfinity;
      var minLng = double.infinity;
      var maxLng = double.negativeInfinity;
      for (final p in ring) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      if (minLat.isFinite && minLng.isFinite) {
        centroidRingPairs.add((
          centroid: _LatLngCenter((minLat + maxLat) / 2, (minLng + maxLng) / 2),
          ring: ring,
        ));
      }
    }

    if (centroidRingPairs.isEmpty) return const _GeometryBounds.empty();

    // --- Step 2: overall centroid ---
    final overallLat =
        centroidRingPairs
            .map((e) => e.centroid.latitude)
            .reduce((a, b) => a + b) /
        centroidRingPairs.length;
    final overallLng =
        centroidRingPairs
            .map((e) => e.centroid.longitude)
            .reduce((a, b) => a + b) /
        centroidRingPairs.length;

    // --- Step 3: distances from overall centroid (in degree-units) ---
    final distances = centroidRingPairs
        .map((e) {
          final dLat = e.centroid.latitude - overallLat;
          final dLng = e.centroid.longitude - overallLng;
          return math.sqrt(dLat * dLat + dLng * dLng);
        })
        .toList(growable: false);

    final sortedDistances = distances.toList()..sort();
    final median = sortedDistances[sortedDistances.length ~/ 2];
    // Threshold: include rings within 2× median distance; minimum 0.01°
    // so tightly-packed sites (median ≈ 0) don't degenerate.
    final threshold = math.max(median * 2.0, 0.01);

    // --- Step 4: build bounds from all points of clustered rings ---
    var minLat = double.infinity;
    var maxLat = double.negativeInfinity;
    var minLng = double.infinity;
    var maxLng = double.negativeInfinity;
    var clusteredCount = 0;

    for (var i = 0; i < centroidRingPairs.length; i++) {
      if (distances[i] > threshold) continue;
      // Expand bounds using all actual ring points for accurate coverage.
      for (final p in centroidRingPairs[i].ring) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      clusteredCount++;
    }

    if (clusteredCount == 0 || !minLat.isFinite || !minLng.isFinite) {
      // Fallback: use overall geometry bounds.
      return _calculateGeometryBounds(geometry);
    }

    return _GeometryBounds(
      minLatitude: minLat,
      maxLatitude: maxLat,
      minLongitude: minLng,
      maxLongitude: maxLng,
    );
  }

  _SiteCameraProfile _buildCameraProfile({
    required HeritageSite site,
    HeritageSiteGeometry? geometry,
  }) {
    // Determine rig size once so both flyToRange and tilt use the same value.
    final int screens = widget.settingsViewModel.state.settings?.screens ?? 3;
    final bool isLargeRig = screens > 3;

    final hasBoundary = geometry != null && !geometry.boundary.isEmpty;
    final isCircularFallback = geometry?.boundary.isFallbackCircle ?? false;
    // For multi-component sites (more than one ring) zoom the camera in on
    // the single largest KML polygon (by bounding-box area) so the view
    // centres on the primary feature rather than the full scattered extent.
    // Single-component sites use the full-bounds path unchanged.
    final bounds = hasBoundary
        ? (geometry!.boundary.rings.length > 1
              ? _findLargestRingBounds(geometry.boundary)
              : _calculateGeometryBounds(geometry.boundary))
        : const _GeometryBounds.empty();
    final center = bounds.isValid
        ? _calculateGeometryCenter(bounds)
        : _LatLngCenter(site.latitude, site.longitude);
    final orbitRange = bounds.isValid
        ? _calculateAdaptiveOrbitRange(bounds, center.latitude)
        : _fallbackOrbitRange(site.category);

    // Both 3-screen and 5-screen rigs use 30° tilt so the camera lands at
    // a very low, near-ground-level angle — giving a truly 3D perspective
    // where extruded KML walls appear as tall structures consistently
    // across all rig sizes.
    const double tilt = 30.0;

    // With a 30° tilt the camera footprint on the ground is narrower so a
    // slightly larger multiplier works well. 0.55 for large rigs and 0.60
    // for 3-screen rigs keeps the site filling the central screens.
    // The minimum flyTo range is 1800 m so the camera never clips into terrain.
    final double flyToFactor = isLargeRig ? 0.55 : 0.60;
    const double flyToMin = 1800;
    // For circular fallback sites (single-point / missing boundary) dive the
    // camera in very close so the extruded circle walls appear large and the
    // view feels near-ground-level.  Non-fallback sites keep the standard
    // 1 800 m minimum so no terrain clipping occurs.
    final flyToRange = isCircularFallback
        ? _clampRange(
            orbitRange * (isLargeRig ? 0.40 : 0.45),
            min: 400,
            max: 2500,
          )
        : _clampRange(orbitRange * flyToFactor, min: flyToMin, max: 12000);

    // Circular fallback sites use a look-at altitude of 50 m so the camera
    // arrives just above the surface after the fly-to animation ends.
    // Real-boundary sites keep the default 150 m look-at altitude.
    final double cameraAltitude = isCircularFallback ? 50.0 : 150.0;

    return _SiteCameraProfile(
      center: center,
      flyToRange: flyToRange,
      orbitRange: orbitRange,
      tilt: tilt,
      altitude: cameraAltitude,
    );
  }

  double _calculateAdaptiveOrbitRange(
    _GeometryBounds bounds,
    double centerLatitude,
  ) {
    final latSpanDegrees = (bounds.maxLatitude - bounds.minLatitude).abs();
    final lngSpanDegrees = (bounds.maxLongitude - bounds.minLongitude).abs();
    if (latSpanDegrees == 0 && lngSpanDegrees == 0) {
      return _fallbackOrbitRange(widget.site.category);
    }

    final longitudeScale = math.max(
      0.2,
      math.cos(centerLatitude * math.pi / 180).abs(),
    );
    final latSpanMeters = latSpanDegrees * 111320;
    final lngSpanMeters = lngSpanDegrees * 111320 * longitudeScale;
    final maxSpanMeters = math.max(latSpanMeters, lngSpanMeters);
    final diagonalMeters = math.sqrt(
      (latSpanMeters * latSpanMeters) + (lngSpanMeters * lngSpanMeters),
    );
    final framingSpanMeters = math.max(maxSpanMeters, diagonalMeters * 0.9);

    return _clampRange(framingSpanMeters * 1.22, min: 2500, max: 450000);
  }

  double _fallbackOrbitRange(HeritageCategory category) {
    switch (category) {
      case HeritageCategory.natural:
        return 6500;
      case HeritageCategory.mixed:
        return 5000;
      case HeritageCategory.cultural:
        return 3500;
      case HeritageCategory.unknown:
        return 5000;
    }
  }

  double _clampRange(double value, {required double min, required double max}) {
    return value.clamp(min, max).toDouble();
  }

  String _buildRenderableSiteKml({
    required HeritageSite site,
    HeritageSiteGeometry? geometry,
  }) {
    if (geometry != null && !geometry.boundary.isEmpty) {
      final int screens = widget.settingsViewModel.state.settings?.screens ?? 3;
      final bool isLargeRig = screens > 3;
      final rings = geometry.boundary.rings.length > 1
          ? <List<HeritageGeoPoint>>[
              _findLargestRing(geometry.boundary) ??
                  geometry.boundary.rings.first,
            ]
          : geometry.boundary.rings;
      return KMLBuilder.buildBoundaryKml(
        name: site.name,
        rings: rings
            .map(
              (ring) => ring
                  .map((point) => <double>[point.latitude, point.longitude])
                  .toList(growable: false),
            )
            .toList(growable: false),
        category: site.category,
        isLargeRig: isLargeRig,
        isCircularFallback: geometry.boundary.isFallbackCircle,
      );
    }

    return KMLBuilder()
        .addHeader()
        .addPlacemark(
          name: site.name,
          longitude: site.longitude,
          latitude: site.latitude,
          description: site.shortDescription.trim().isNotEmpty
              ? site.shortDescription.trim()
              : null,
        )
        .build();
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Handles incoming camera position updates from the WebView map.
  /// Sync is always active when LG is connected – no manual toggle needed.
  void _onMapCameraChanged(JavaScriptMessage message) {
    final syncService = _mapSyncService;
    if (syncService == null) return;

    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      syncService.onCameraChanged(
        latitude: (data['lat'] as num).toDouble(),
        longitude: (data['lng'] as num).toDouble(),
        zoom: (data['zoom'] as num).toDouble(),
        heading: (data['heading'] as num?)?.toDouble() ?? 0,
        tilt: (data['tilt'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      debugPrint('MapSync: failed to parse camera data – $e');
    }
  }

  @override
  void dispose() {
    _cancelOrbitCompletionTimer();
    _mapSyncService?.dispose();
    _speechmaticsTts.dispose();
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
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: Row(
                          children: [
                            _buildLgActionButton(
                              icon: _isRenderingOnLg
                                  ? Icons.hourglass_top_rounded
                                  : _isOrbitActive
                                  ? Icons.pause_rounded
                                  : Icons.travel_explore_rounded,
                              label: _isOrbitActive ? 'Stop Orbit' : 'Orbit',
                              onPressed: _isRenderingOnLg
                                  ? null
                                  : _handleOrbitPressed,
                            ),
                          ],
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
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Explore ${currentSite.name}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(
                            color: AppColors.outlineVariant,
                            height: 1,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    if (_isAudioPlaying) {
                                      setState(() {
                                        _isAudioPlaying = false;
                                      });
                                      await _speechmaticsTts.stop();
                                    } else {
                                      _playStory();
                                    }
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        theme.colorScheme.primaryContainer,
                                    foregroundColor:
                                        theme.colorScheme.onPrimaryContainer,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  icon: Icon(
                                    _isAudioPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                  ),
                                  label: Text(
                                    _isAudioPlaying ? 'Pause' : 'Play',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    setState(() {
                                      _isMuted = !_isMuted;
                                      if (_isMuted) _isAudioPlaying = false;
                                    });
                                    if (_isMuted) await _speechmaticsTts.stop();
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.surfaceVariant,
                                    foregroundColor: AppColors.onSurface,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  icon: Icon(
                                    _isMuted
                                        ? Icons.volume_off
                                        : Icons.volume_up,
                                  ),
                                  label: Text(_isMuted ? 'Unmute' : 'Mute'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    await _speechmaticsTts.stop();
                                    await _playStory();
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.surfaceVariant,
                                    foregroundColor: AppColors.onSurface,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  icon: const Icon(Icons.replay),
                                  label: const Text('Replay'),
                                ),
                              ),
                            ],
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

  Widget _buildLgActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surfaceContainerHighest,
        foregroundColor: AppColors.onSurface,
        disabledBackgroundColor: AppColors.surfaceContainerHighest.withValues(
          alpha: 0.85,
        ),
        disabledForegroundColor: AppColors.onSurfaceVariant,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
            value: _bestTimeToVisit ?? 'N/A',
            label: 'Best Time to Visit',
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

class _SiteCameraProfile {
  const _SiteCameraProfile({
    required this.center,
    required this.flyToRange,
    required this.orbitRange,
    required this.tilt,
    required this.altitude,
  });

  final _LatLngCenter center;
  final double flyToRange;
  final double orbitRange;
  final double tilt;

  /// Look-at altitude (metres above ground). 50 m for circular-fallback sites
  /// to land the camera near ground level; 150 m for real-boundary sites.
  final double altitude;
}

class _LgRenderPayload {
  const _LgRenderPayload({
    required this.cameraProfile,
    required this.boundaryKml,
    required this.orbitKml,
    required this.balloonKml,
  });

  final _SiteCameraProfile cameraProfile;
  final String boundaryKml;
  final String orbitKml;
  final String balloonKml;
}

class _MapPolygonColors {
  const _MapPolygonColors({
    required this.strokeColor,
    required this.fillColor,
    required this.strokeOpacity,
    required this.fillOpacity,
  });

  final String strokeColor;
  final String fillColor;
  final double strokeOpacity;
  final double fillOpacity;
}
