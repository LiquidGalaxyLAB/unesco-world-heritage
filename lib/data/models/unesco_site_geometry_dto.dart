class UnescoSiteGeometryDto {
  const UnescoSiteGeometryDto({
    required this.propertyId,
    required this.rings,
  });

  factory UnescoSiteGeometryDto.fromFeature(Map<String, dynamic> feature) {
    final attributes = _asMap(feature['attributes']);
    final geometry = _asMap(feature['geometry']);

    final propertyId = _readInt(attributes['property_id']) ??
        _readInt(attributes['site_id']) ??
        0;
    if (propertyId == 0) {
      throw const FormatException('Missing property_id.');
    }

    final ringsJson = geometry['rings'];
    if (ringsJson is! List || ringsJson.isEmpty) {
      throw const FormatException('Missing geometry rings.');
    }

    final rings = <List<List<double>>>[];
    for (final ringJson in ringsJson) {
      if (ringJson is! List || ringJson.isEmpty) {
        continue;
      }

      final ring = <List<double>>[];
      for (final pointJson in ringJson) {
        if (pointJson is! List || pointJson.length < 2) {
          throw const FormatException('Invalid geometry coordinate.');
        }

        final longitude = _readDouble(pointJson[0]);
        final latitude = _readDouble(pointJson[1]);
        if (latitude == null || longitude == null) {
          throw const FormatException('Invalid geometry coordinate value.');
        }

        ring.add(<double>[latitude, longitude]);
      }

      if (ring.isNotEmpty) {
        rings.add(ring);
      }
    }

    if (rings.isEmpty) {
      throw const FormatException('No valid geometry rings found.');
    }

    return UnescoSiteGeometryDto(
      propertyId: propertyId,
      rings: rings,
    );
  }

  final int propertyId;
  final List<List<List<double>>> rings;

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
