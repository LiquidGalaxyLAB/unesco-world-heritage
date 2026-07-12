import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'lg_rig_service.dart';

/// Service that synchronizes the phone's map camera position with the
/// Liquid Galaxy rig in real time.
///
/// When enabled, any pan, zoom, or rotation on the in-app Google Map is
/// mirrored on the LG by sending `flytoview=<LookAt>` commands via SSH.
///
/// Updates are **debounced** to avoid flooding the LG with commands on
/// every pixel-level camera change.
class LGMapSyncService {
  LGMapSyncService(this._lgRigService);

  final LGRigService _lgRigService;

  /// Duration to wait after the last camera event before sending the
  /// flyTo command.  Keeps the SSH channel from being overwhelmed while
  /// still providing responsive mirroring.
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  Timer? _debounceTimer;
  bool _isSyncing = false;

  /// Whether the sync is currently active.
  bool get isSyncing => _isSyncing;

  /// Start live synchronization.
  void startSync() {
    _isSyncing = true;
  }

  /// Stop live synchronization and cancel any pending updates.
  void stopSync() {
    _isSyncing = false;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Called whenever the map camera changes.
  ///
  /// Converts the Google Maps JavaScript API zoom level to a Google Earth
  /// KML `range` (camera distance from the ground in meters) and sends the
  /// corresponding LookAt command to the LG rig.
  ///
  /// [latitude]  – camera center latitude.
  /// [longitude] – camera center longitude.
  /// [zoom]      – Google Maps JS API zoom level (0 ≈ whole world, 21 ≈ building).
  /// [heading]   – map heading / bearing in degrees.
  /// [tilt]      – camera tilt in degrees.
  void onCameraChanged({
    required double latitude,
    required double longitude,
    required double zoom,
    double heading = 0,
    double tilt = 0,
  }) {
    if (!_isSyncing || !_lgRigService.isConnected) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _sendFlyTo(
        latitude: latitude,
        longitude: longitude,
        zoom: zoom,
        heading: heading,
        tilt: tilt,
      );
    });
  }

  /// Converts the Google Maps zoom level to a Google Earth KML `range` value.
  ///
  /// Google Maps zoom level relates to the ground resolution / altitude
  /// roughly as:
  ///   altitude ≈ C / 2^zoom
  ///
  /// Where C ≈ 35,200,000 meters at the equator.  The KML `range` is the
  /// distance from the camera to the LookAt point.  For a nadir (straight-
  /// down) view, range ≈ altitude.  For tilted views the relationship is
  /// `altitude = range * cos(tilt)`, but Google Earth handles the tilt
  /// internally, so we pass the range directly.
  static double zoomToRange(double zoom) {
    // Clamp zoom to a sane range to avoid overflow / underflow.
    final clampedZoom = zoom.clamp(0.0, 25.0);
    return 35200000.0 / math.pow(2, clampedZoom);
  }

  Future<void> _sendFlyTo({
    required double latitude,
    required double longitude,
    required double zoom,
    required double heading,
    required double tilt,
  }) async {
    if (!_lgRigService.isConnected) return;

    final range = zoomToRange(zoom);

    try {
      await _lgRigService.flyTo(
        latitude: latitude,
        longitude: longitude,
        altitude: 0,
        zoom: range,
        tilt: tilt,
        bearing: heading,
      );
    } catch (e) {
      debugPrint('LGMapSyncService: flyTo failed – $e');
    }
  }

  /// Clean up resources.
  void dispose() {
    stopSync();
  }
}
