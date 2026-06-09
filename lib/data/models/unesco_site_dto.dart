class UnescoSiteDto {
  const UnescoSiteDto({
    required this.propertyId,
    required this.name,
    required this.country,
    required this.rawCategory,
    required this.latitude,
    required this.longitude,
    required this.isoCodes,
    required this.description,
    required this.dateInscribed,
    required this.mainImageUrl,
    required this.imageUrls,
  });

  factory UnescoSiteDto.fromRecord(Map<String, dynamic> record) {
    final propertyId = _readInt(record, const <String>['id_no', 'property_id']);
    if (propertyId == null) {
      throw const FormatException('Missing id_no.');
    }

    String? name = _readString(record, const <String>['name_en']);
    if (name != null) {
      name = name.replaceAll(RegExp(r'</?(strong|b|em|i|mark|code)\b[^>]*>', caseSensitive: false), '');
    }
    final rawCategory = _readString(record, const <String>['category']) ?? '';
    final coordinate = _readRecordCoordinate(record);
    if (name == null || coordinate == null) {
      throw const FormatException('Missing required UNESCO site fields.');
    }

    return UnescoSiteDto(
      propertyId: propertyId,
      name: name,
      country: _readCountry(record) ?? '',
      rawCategory: rawCategory,
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
      isoCodes: _readString(record, const <String>['iso_codes']) ?? '',
      description:
          _readString(record, const <String>[
            'description_en',
            'short_description_en',
          ]) ??
          '',
      dateInscribed:
          _readString(record, const <String>['date_inscribed']) ?? '',
      mainImageUrl: _readString(record, const <String>['main_image_url']) ?? '',
      imageUrls: _readImageUrls(record),
    );
  }

  factory UnescoSiteDto.fromFeature(Map<String, dynamic> feature) {
    final attributes = _asMap(feature['attributes']);
    final geometry = _asMap(feature['geometry']);
    final centroid = _asMap(feature['centroid']);

    final propertyId = _readInt(attributes, const <String>[
      'property_id',
      'id_no',
    ]);
    if (propertyId == null) {
      throw const FormatException('Missing property_id.');
    }

    String? name = _readString(attributes, const <String>[
      'property_name_en',
      'element_name_en',
      'name_en',
    ]);
    if (name != null) {
      name = name.replaceAll(RegExp(r'</?(strong|b|em|i|mark|code)\b[^>]*>', caseSensitive: false), '');
    }
    final country = _readString(attributes, const <String>[
      'property_states_name_en',
      'states_name_en',
      'country_en',
      'state_name_en',
    ]);
    final rawCategory =
        _readString(attributes, const <String>[
          'property_category',
          'category',
          'category_en',
        ]) ??
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
      isoCodes:
          _readString(attributes, const <String>[
            'property_iso3',
            'iso_codes',
            'property_iso2',
          ]) ??
          '',
      description:
          _readString(attributes, const <String>[
            'property_short_description_en',
            'short_description_en',
            'description_en',
          ]) ??
          '',
      dateInscribed:
          _readString(attributes, const <String>[
            'property_inscribed',
            'date_inscribed',
          ]) ??
          '',
      mainImageUrl:
          _readString(attributes, const <String>['main_image_url']) ?? '',
      imageUrls: _readImageUrls(attributes),
    );
  }

  final int propertyId;
  final String name;
  final String country;
  final String rawCategory;
  final double latitude;
  final double longitude;
  final String isoCodes;
  final String description;
  final String dateInscribed;
  final String mainImageUrl;
  final List<String> imageUrls;

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
      if (value is num) {
        return value.toString();
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
    final attributeLatitude = _readDouble(attributes, const <String>[
      'latitude',
      'lat',
      'coord_lat',
    ]);
    final attributeLongitude = _readDouble(attributes, const <String>[
      'longitude',
      'lon',
      'lng',
      'coord_lon',
    ]);
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

  static _Coordinate? _readRecordCoordinate(Map<String, dynamic> record) {
    final coordinates = _asMap(record['coordinates']);
    final latitude = _readDouble(coordinates, const <String>['lat']);
    final longitude = _readDouble(coordinates, const <String>['lon']);
    if (latitude != null && longitude != null) {
      return _Coordinate(latitude, longitude);
    }

    return _readCoordinate(
      record,
      const <String, dynamic>{},
      const <String, dynamic>{},
    );
  }

  static String? _readCountry(Map<String, dynamic> record) {
    final statesNames = record['states_names'];
    if (statesNames is List && statesNames.isNotEmpty) {
      return statesNames
          .whereType<Object>()
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .join(', ');
    }

    return _readString(record, const <String>['states_name_en', 'country_en']);
  }

  static List<String> _readImageUrls(Map<String, dynamic> map) {
    final urls = <String>{};
    final mainImageUrl = _readString(map, const <String>['main_image_url']);
    if (mainImageUrl != null) {
      urls.add(mainImageUrl);
    }

    final imagesUrls = map['images_urls'];
    if (imagesUrls is String) {
      for (final url in imagesUrls.split(',')) {
        final trimmedUrl = url.trim();
        if (trimmedUrl.isNotEmpty) {
          urls.add(trimmedUrl);
        }
      }
    } else if (imagesUrls is List) {
      for (final url in imagesUrls) {
        final trimmedUrl = url.toString().trim();
        if (trimmedUrl.isNotEmpty) {
          urls.add(trimmedUrl);
        }
      }
    }

    return List<String>.unmodifiable(urls);
  }
}

class _Coordinate {
  const _Coordinate(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}
