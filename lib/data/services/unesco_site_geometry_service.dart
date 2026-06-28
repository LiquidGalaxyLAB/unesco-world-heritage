import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/unesco_site_dto.dart';
import '../models/unesco_site_geometry_dto.dart';
import '../models/wdpa_site_candidate_dto.dart';
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
  static const int _arcGisPageSize = 2000;
  static const int _wdpaPageSize = 2000;

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

  Future<Set<int>> fetchPropertyIdsWithGeometry({
    required UnescoGeometryLayer layer,
  }) async {
    final propertyIds = <int>{};
    for (var offset = 0; ; offset += _arcGisPageSize) {
      final json = await _getJson(
        _buildPropertyIdsUri(layer: layer, offset: offset),
      );
      final page = _parsePropertyIdPage(json);
      if (page.rawCount == 0) {
        break;
      }

      propertyIds.addAll(page.propertyIds);
      if (page.rawCount < _arcGisPageSize &&
          json['exceededTransferLimit'] != true) {
        break;
      }
    }

    return Set<int>.unmodifiable(propertyIds);
  }

  Future<List<WdpaSiteCandidateDto>> fetchWdpaSiteCandidates() async {
    final candidates = <WdpaSiteCandidateDto>[];
    for (var offset = 0; ; offset += _wdpaPageSize) {
      final json = await _getJson(_buildWdpaCandidatesUri(offset: offset));
      final page = _parseWdpaCandidates(json);
      if (page.isEmpty) {
        break;
      }

      candidates.addAll(page);
      if (page.length < _wdpaPageSize &&
          json['exceededTransferLimit'] != true) {
        break;
      }
    }

    final uniqueCandidates = <int, WdpaSiteCandidateDto>{};
    for (final candidate in candidates) {
      uniqueCandidates[candidate.siteId] = candidate;
    }
    return uniqueCandidates.values.toList(growable: false);
  }

  Future<List<UnescoSiteGeometryDto>> fetchWdpaGeometryBySiteId(
    int siteId,
  ) async {
    final json = await _getJson(_buildWdpaGeometryUri(siteId));
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

  Uri _buildWdpaCandidatesUri({required int offset}) {
    return Uri.parse(_wdpaNaturalSitesEndpoint).replace(
      queryParameters: <String, String>{
        'f': 'json',
        'where': "desig_type='International'",
        'outFields': 'site_id,name_eng,name',
        'outSR': '4326',
        'returnGeometry': 'false',
        'resultOffset': '$offset',
        'resultRecordCount': '$_wdpaPageSize',
      },
    );
  }

  Uri _buildWdpaGeometryUri(int siteId) {
    return Uri.parse(_wdpaNaturalSitesEndpoint).replace(
      queryParameters: <String, String>{
        'f': 'json',
        'where': 'site_id=$siteId',
        'outFields': 'site_id',
        'outSR': '4326',
        'returnGeometry': 'true',
        'resultRecordCount': '2000',
      },
    );
  }

  Uri _buildPropertyIdsUri({
    required UnescoGeometryLayer layer,
    required int offset,
  }) {
    return Uri.parse('$_serviceBaseUrl/${layer.layerId}/query').replace(
      queryParameters: <String, String>{
        'f': 'json',
        'where': 'property_id IS NOT NULL',
        'outFields': 'property_id',
        'returnGeometry': 'false',
        'returnCentroid': 'false',
        'resultOffset': '$offset',
        'resultRecordCount': '$_arcGisPageSize',
        'orderByFields': 'property_id ASC',
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

  List<WdpaSiteCandidateDto> _parseWdpaCandidates(Map<String, dynamic> json) {
    final features = json['features'];
    if (features is! List) {
      throw const UnescoSitesParseException(
        'WDPA response is missing features.',
      );
    }

    final candidates = <WdpaSiteCandidateDto>[];
    for (final feature in features) {
      if (feature is! Map) {
        continue;
      }

      try {
        candidates.add(
          WdpaSiteCandidateDto.fromFeature(Map<String, dynamic>.from(feature)),
        );
      } on FormatException {
        continue;
      }
    }

    return candidates;
  }
}

class _PropertyIdPageResult {
  const _PropertyIdPageResult(this.propertyIds, this.rawCount);

  final Set<int> propertyIds;
  final int rawCount;
}

extension on UnescoSiteGeometryService {
  _PropertyIdPageResult _parsePropertyIdPage(Map<String, dynamic> json) {
    final features = json['features'];
    if (features is! List) {
      throw const UnescoSitesParseException(
        'UNESCO geometry response is missing features.',
      );
    }

    final propertyIds = <int>{};
    for (final feature in features) {
      if (feature is! Map) {
        continue;
      }

      final attributes = feature['attributes'];
      if (attributes is! Map) {
        continue;
      }

      final propertyId = UnescoSiteDto.readPropertyIdFromMap(
        Map<String, dynamic>.from(attributes),
      );
      if (propertyId != null) {
        propertyIds.add(propertyId);
      }
    }

    return _PropertyIdPageResult(propertyIds, features.length);
  }
}
