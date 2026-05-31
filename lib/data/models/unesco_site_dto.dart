class UnescoSiteDto {
  const UnescoSiteDto({
    required this.propertyId,
    required this.name,
    required this.country,
    required this.rawCategory,
    required this.latitude,
    required this.longitude,
  });

  factory UnescoSiteDto.fromFeature(Map<String, dynamic> feature) {
    final attributes = _asMap(feature['attributes']);
    final geometry = _asMap(feature['geometry']);
    final centroid = _asMap(feature['centroid']);

    final propertyId = _readInt(
      attributes,
      const <String>['property_id', 'id_no'],
    );
    if (propertyId == null) {
      throw const FormatException('Missing property_id.');
    }

    final name = _readString(
      attributes,
      const <String>['property_name_en', 'element_name_en', 'name_en'],
    );
    final country = _readString(
      attributes,
      const <String>['states_name_en', 'country_en', 'state_name_en'],
    );
    final rawCategory = _readString(
          attributes,
          const <String>['category', 'category_en'],
        ) ??
        '';

    final coordinate = _readCoordinate(attributes, geometry, centroid);
    if (name == null || country == null || coordinate == null) {
      throw const FormatException('Missing required UNESCO site fields.');
    }

    return UnescoSiteDto(
      propertyId: propertyId,
      name: name,
      country: country,
      rawCategory: rawCategory,
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
    );
  }

  final int propertyId;
  final String name;
  final String country;
  final String rawCategory;
  final double latitude;
  final double longitude;

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static String? _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static int? _readInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static double? _readDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static _Coordinate? _readCoordinate(
    Map<String, dynamic> attributes,
    Map<String, dynamic> geometry,
    Map<String, dynamic> centroid,
  ) {
    final attributeLatitude = _readDouble(
      attributes,
      const <String>['latitude', 'lat', 'coord_lat'],
    );
    final attributeLongitude = _readDouble(
      attributes,
      const <String>['longitude', 'lon', 'lng', 'coord_lon'],
    );
    if (attributeLatitude != null && attributeLongitude != null) {
      return _Coordinate(attributeLatitude, attributeLongitude);
    }

    final centroidY = _readDouble(centroid, const <String>['y']);
    final centroidX = _readDouble(centroid, const <String>['x']);
    if (centroidY != null && centroidX != null) {
      return _Coordinate(centroidY, centroidX);
    }

    final geometryY = _readDouble(geometry, const <String>['y']);
    final geometryX = _readDouble(geometry, const <String>['x']);
    if (geometryY != null && geometryX != null) {
      return _Coordinate(geometryY, geometryX);
    }

    return _readFirstRingCoordinate(geometry);
  }

  static _Coordinate? _readFirstRingCoordinate(Map<String, dynamic> geometry) {
    final rings = geometry['rings'];
    if (rings is! List || rings.isEmpty) {
      return null;
    }

    final firstRing = rings.first;
    if (firstRing is! List || firstRing.isEmpty) {
      return null;
    }

    final firstPoint = firstRing.first;
    if (firstPoint is! List || firstPoint.length < 2) {
      return null;
    }

    final longitude = _readCoordinateValue(firstPoint[0]);
    final latitude = _readCoordinateValue(firstPoint[1]);
    if (latitude == null || longitude == null) {
      return null;
    }

    return _Coordinate(latitude, longitude);
  }

  static double? _readCoordinateValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}

class _Coordinate {
  const _Coordinate(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}
