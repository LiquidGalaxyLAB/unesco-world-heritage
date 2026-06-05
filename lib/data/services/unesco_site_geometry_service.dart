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
  static const String _wdpaNaturalSitesEndpoint =
      'https://services5.arcgis.com/Mj0hjvkNtV7NRhA7/ArcGIS/rest/services/WDPA_v0/FeatureServer/1/query';

  final http.Client _client;

  Future<List<UnescoSiteGeometryDto>> fetchBoundaryById(int propertyId) {
    return _fetchGeometries(
      propertyId: propertyId,
      layer: UnescoGeometryLayer.boundary,
    );
  }

  Future<List<UnescoSiteGeometryDto>> fetchBufferById(int propertyId) {
    return _fetchGeometries(
      propertyId: propertyId,
      layer: UnescoGeometryLayer.buffer,
    );
  }

  Future<List<UnescoSiteGeometryDto>> fetchWdpaNaturalSiteGeometries({
    required String siteName,
    required String isoCodes,
  }) async {
    final normalizedName = siteName.trim();
    if (normalizedName.isEmpty) {
      return const <UnescoSiteGeometryDto>[];
    }

    final json = await _getJson(
      _buildWdpaUri(siteName: normalizedName, isoCodes: isoCodes),
    );
    return _parseFeatures(json);
  }

  Future<List<UnescoSiteGeometryDto>> _fetchGeometries({
    required int propertyId,
    required UnescoGeometryLayer layer,
  }) async {
    final json = await _getJson(
      _buildUri(propertyId: propertyId, layer: layer),
    );
    return _parseFeatures(json);
  }

  Uri _buildUri({required int propertyId, required UnescoGeometryLayer layer}) {
    return Uri.parse('$_serviceBaseUrl/${layer.layerId}/query').replace(
      queryParameters: <String, String>{
        'f': 'json',
        'where': 'property_id=$propertyId',
        'outFields': 'property_id',
        'outSR': '4326',
        'returnGeometry': 'true',
        'resultRecordCount': '2000',
      },
    );
  }

  Uri _buildWdpaUri({required String siteName, required String isoCodes}) {
    final nameTokens = _buildSearchTokens(siteName);
    final nameWhere = nameTokens
        .map(
          (token) =>
              "(UPPER(name_eng) LIKE '%${_escapeSql(token.toUpperCase())}%' "
              "OR UPPER(name) LIKE '%${_escapeSql(token.toUpperCase())}%')",
        )
        .join(' AND ');
    final isoWhere = _buildIsoWhere(isoCodes);
    final where = <String>[
      "(UPPER(desig_eng) LIKE '%WORLD HERITAGE%')",
      if (nameWhere.isNotEmpty) nameWhere,
      if (isoWhere.isNotEmpty) isoWhere,
    ].join(' AND ');

    return Uri.parse(_wdpaNaturalSitesEndpoint).replace(
      queryParameters: <String, String>{
        'f': 'json',
        'where': where,
        'outFields': 'site_id,name_eng,name,desig_eng,iso3',
        'outSR': '4326',
        'returnGeometry': 'true',
        'resultRecordCount': '2000',
      },
    );
  }

  List<String> _buildSearchTokens(String siteName) {
    final words = siteName
        .replaceAll(RegExp(r'[^A-Za-z0-9 -]'), ' ')
        .split(RegExp(r'\s+'))
        .map((word) => word.trim())
        .where((word) => word.length >= 4)
        .where(
          (word) => !const <String>{
            'the',
            'and',
            'site',
            'heritage',
            'world',
            'national',
            'park',
          }.contains(word.toLowerCase()),
        )
        .toList(growable: false);

    if (words.isEmpty) {
      return <String>[siteName];
    }

    return words.take(3).toList(growable: false);
  }

  String _buildIsoWhere(String isoCodes) {
    final codes = isoCodes
        .split(RegExp(r'[,; ]+'))
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.length >= 2)
        .toList(growable: false);
    if (codes.isEmpty) {
      return '';
    }

    final clauses = codes
        .map((code) => "UPPER(iso3) LIKE '%${_escapeSql(code)}%'")
        .join(' OR ');
    return '($clauses)';
  }

  String _escapeSql(String value) => value.replaceAll("'", "''");

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
