import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/unesco_site_dto.dart';
import 'unesco_api_exceptions.dart';

class UnescoSitesService {
  UnescoSitesService({http.Client? client}) : _client = client ?? http.Client();

  static const int pageSize = 1000;
  static const String _endpoint =
      'https://services6.arcgis.com/eMd5K6XXEvJETxfQ/ArcGIS/rest/services/prd_whc_sites_dossiers_elements_v2_view/FeatureServer/1/query';

  final http.Client _client;

  Future<List<UnescoSiteDto>> fetchAllSites() async {
    final sites = <UnescoSiteDto>[];
    var offset = 0;

    while (true) {
      final page = await fetchSitesPage(offset: offset);
      if (page.isEmpty) {
        break;
      }

      sites.addAll(page);
      if (page.length < pageSize) {
        break;
      }

      offset += pageSize;
    }

    if (sites.isEmpty) {
      throw const UnescoSitesEmptyResultException(
        'No UNESCO heritage sites were returned.',
      );
    }

    return sites;
  }

  Future<List<UnescoSiteDto>> fetchSitesPage({int offset = 0}) async {
    final json = await _getJson(
      _buildUri(
        where: '1=1',
        resultOffset: offset,
        resultRecordCount: pageSize,
      ),
    );
    return _parseFeatures(json);
  }

  Future<UnescoSiteDto> fetchSiteById(int propertyId) async {
    final json = await _getJson(
      _buildUri(
        where: 'property_id=$propertyId',
        resultOffset: 0,
        resultRecordCount: 1,
      ),
    );
    final sites = _parseFeatures(json);
    if (sites.isEmpty) {
      throw UnescoSitesEmptyResultException(
        'UNESCO heritage site $propertyId was not found.',
      );
    }

    return sites.first;
  }

  Uri _buildUri({
    required String where,
    required int resultOffset,
    required int resultRecordCount,
  }) {
    return Uri.parse(_endpoint).replace(
      queryParameters: <String, String>{
        'f': 'json',
        'where': where,
        'outFields': '*',
        'outSR': '4326',
        'returnGeometry': 'true',
        'returnCentroid': 'true',
        'resultOffset': '$resultOffset',
        'resultRecordCount': '$resultRecordCount',
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

  List<UnescoSiteDto> _parseFeatures(Map<String, dynamic> json) {
    final features = json['features'];
    if (features is! List) {
      throw const UnescoSitesParseException(
        'UNESCO response is missing features.',
      );
    }

    try {
      return features
          .map(
            (feature) => UnescoSiteDto.fromFeature(
              Map<String, dynamic>.from(feature as Map),
            ),
          )
          .toList(growable: false);
    } on FormatException catch (error) {
      throw UnescoSitesParseException(error.message);
    } catch (error) {
      throw UnescoSitesParseException('Unable to parse UNESCO sites: $error');
    }
  }
}
