import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/unesco_site_geometry_dto.dart';
import 'unesco_api_exceptions.dart';

enum UnescoGeometryLayer {
  boundary(1),
  buffer(2);

  const UnescoGeometryLayer(this.layerId);

  final int layerId;
}

class UnescoSiteGeometryService {
  UnescoSiteGeometryService({http.Client? client})
      : _client = client ?? http.Client();

  static const String _serviceBaseUrl =
      'https://services6.arcgis.com/eMd5K6XXEvJETxfQ/ArcGIS/rest/services/prd_whc_sites_dossiers_elements_v2_view/FeatureServer';

  final http.Client _client;

  Future<UnescoSiteGeometryDto> fetchBoundaryById(int propertyId) async {
    final geometries = await _fetchGeometries(
      propertyId: propertyId,
      layer: UnescoGeometryLayer.boundary,
    );
    if (geometries.isEmpty) {
      throw UnescoSitesEmptyResultException(
        'UNESCO boundary $propertyId was not found.',
      );
    }

    return geometries.first;
  }

  Future<UnescoSiteGeometryDto?> fetchBufferById(int propertyId) async {
    final geometries = await _fetchGeometries(
      propertyId: propertyId,
      layer: UnescoGeometryLayer.buffer,
    );
    if (geometries.isEmpty) {
      return null;
    }

    return geometries.first;
  }

  Future<List<UnescoSiteGeometryDto>> _fetchGeometries({
    required int propertyId,
    required UnescoGeometryLayer layer,
  }) async {
    final json = await _getJson(_buildUri(propertyId: propertyId, layer: layer));
    return _parseFeatures(json);
  }

  Uri _buildUri({
    required int propertyId,
    required UnescoGeometryLayer layer,
  }) {
    return Uri.parse('$_serviceBaseUrl/${layer.layerId}/query').replace(
      queryParameters: <String, String>{
        'f': 'json',
        'where': 'property_id=$propertyId',
        'outFields': 'property_id',
        'outSR': '4326',
        'returnGeometry': 'true',
        'resultRecordCount': '1',
      },
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    http.Response response;
    try {
      response = await _client.get(uri);
    } catch (error) {
      throw UnescoSitesNetworkException('Request failed: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UnescoSitesNetworkException(
        'Request failed with status ${response.statusCode}.',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const FormatException('Expected a JSON object.');
    } catch (error) {
      throw UnescoSitesParseException('Invalid UNESCO response: $error');
    }
  }

  List<UnescoSiteGeometryDto> _parseFeatures(Map<String, dynamic> json) {
    final features = json['features'];
    if (features is! List) {
      throw const UnescoSitesParseException(
        'UNESCO geometry response is missing features.',
      );
    }

    try {
      return features
          .map(
            (feature) => UnescoSiteGeometryDto.fromFeature(
              Map<String, dynamic>.from(feature as Map),
            ),
          )
          .toList(growable: false);
    } on FormatException catch (error) {
      throw UnescoSitesParseException(error.message);
    } catch (error) {
      throw UnescoSitesParseException(
        'Unable to parse UNESCO geometry: $error',
      );
    }
  }
}
