import 'dart:math' as math;

import '../../domain/models/heritage_site.dart';

/// Creates a lightweight, ground-clamped KML boundary for LG fallback use.
///
/// This builder is intentionally separate from [KMLBuilder] so the existing
/// 2-D and 3-D KML generation paths remain unchanged.
class FallbackKmlBuilder {
  static const int _maxComponentCount = 30;
  static const int _maxRingPointCount = 80;

  /// Builds a normalized 2-D KML boundary with no altitude extrusion.
  ///
  /// The input is normalized, rounded to three decimal places, de-duplicated,
  /// and decimated for fast LG loading. If no valid boundary is available, a
  /// ground-clamped point is emitted at the supplied fallback coordinates.
  static String buildNormalized2dKml({
    required String name,
    required List<List<List<double>>> rings,
    required double fallbackLatitude,
    required double fallbackLongitude,
    HeritageCategory? category,
  }) {
    final safeName = _escapeXml(name);
    final normalizedRings = rings
        .map(_normalizeRing)
        .where((ring) => ring.length >= 4)
        .toList(growable: false);
    final renderedRings = _sampleRings(normalizedRings);
    final colors = _colorsFor(category);

    final placemarks = <String>[];
    for (var index = 0; index < renderedRings.length; index++) {
      final coordinates = _buildCoordinates(renderedRings[index]);
      if (coordinates.isEmpty) {
        continue;
      }

      placemarks.add('''
    <Placemark>
      <name>${index == 0 ? safeName : '$safeName ${index + 1}'}</name>
      <styleUrl>#fallback_boundary</styleUrl>
      <Polygon>
        <tessellate>1</tessellate>
        <altitudeMode>clampToGround</altitudeMode>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>$coordinates</coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>''');
    }

    if (placemarks.isEmpty) {
      placemarks.add('''
    <Placemark>
      <name>$safeName</name>
      <Point>
        <altitudeMode>clampToGround</altitudeMode>
        <coordinates>$fallbackLongitude,$fallbackLatitude,0</coordinates>
      </Point>
    </Placemark>''');
    }

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>$safeName fallback</name>
    <Style id="fallback_boundary">
      <LineStyle>
        <color>${colors.line}</color>
        <width>3</width>
      </LineStyle>
      <PolyStyle>
        <color>${colors.fill}</color>
      </PolyStyle>
    </Style>
    ${placemarks.join()}
  </Document>
</kml>''';
  }

  static List<List<List<double>>> _sampleRings(List<List<List<double>>> rings) {
    if (rings.length <= _maxComponentCount) {
      return rings;
    }

    final step = math.max(1, (rings.length / _maxComponentCount).ceil());
    final sampled = <List<List<double>>>[];
    for (
      var index = 0;
      index < rings.length && sampled.length < _maxComponentCount - 1;
      index += step
    ) {
      sampled.add(rings[index]);
    }
    sampled.add(rings.last);
    return List<List<List<double>>>.unmodifiable(sampled);
  }

  static List<List<double>> _normalizeRing(List<List<double>> ring) {
    final rounded = ring
        .where(
          (point) =>
              point.length >= 2 && point[0].isFinite && point[1].isFinite,
        )
        .map((point) => <double>[_round(point[0]), _round(point[1])])
        .toList(growable: false);
    if (rounded.isEmpty) {
      return const <List<double>>[];
    }

    final decimated = _decimateRing(rounded);
    final normalized = <List<double>>[];
    for (final point in decimated) {
      if (normalized.isEmpty ||
          normalized.last[0] != point[0] ||
          normalized.last[1] != point[1]) {
        normalized.add(<double>[point[0], point[1]]);
      }
    }

    if (normalized.length < 2) {
      return const <List<double>>[];
    }

    final first = normalized.first;
    final last = normalized.last;
    if (first[0] != last[0] || first[1] != last[1]) {
      normalized.add(<double>[first[0], first[1]]);
    }

    final distinctVertices = <String>{
      for (final point in normalized.take(normalized.length - 1))
        '${point[0]},${point[1]}',
    };
    return distinctVertices.length >= 3
        ? List<List<double>>.unmodifiable(normalized)
        : const <List<double>>[];
  }

  static List<List<double>> _decimateRing(List<List<double>> ring) {
    if (ring.length <= _maxRingPointCount) {
      return ring;
    }

    final result = <List<double>>[ring.first];
    final interior = ring.sublist(1, ring.length - 1);
    final step = math.max(
      1,
      (interior.length / (_maxRingPointCount - 2)).ceil(),
    );
    for (var index = 0; index < interior.length; index += step) {
      result.add(interior[index]);
      if (result.length >= _maxRingPointCount - 1) {
        break;
      }
    }
    result.add(ring.last);
    return result;
  }

  static String _buildCoordinates(List<List<double>> ring) =>
      ring.map((point) => '${point[1]},${point[0]},0').join(' ');

  static double _round(double value) => (value * 1000).roundToDouble() / 1000;

  static String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static _FallbackKmlColors _colorsFor(HeritageCategory? category) {
    switch (category) {
      case HeritageCategory.cultural:
        return const _FallbackKmlColors(line: 'ff33ccff', fill: '6633ccff');
      case HeritageCategory.mixed:
        return const _FallbackKmlColors(line: 'ffffe500', fill: '66ffe500');
      case HeritageCategory.natural:
        return const _FallbackKmlColors(line: 'ff14ff39', fill: '6614ff39');
      default:
        return const _FallbackKmlColors(line: 'ffebce87', fill: '66ebce87');
    }
  }
}

class _FallbackKmlColors {
  const _FallbackKmlColors({required this.line, required this.fill});

  final String line;
  final String fill;
}
