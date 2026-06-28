import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/unesco_site_dto.dart';
import 'unesco_api_exceptions.dart';
import 'wikipedia_image_service.dart';

class UnescoSitesService {
  UnescoSitesService({
    http.Client? client,
    WikipediaImageService? wikipediaImageService,
  }) : _client = client ?? http.Client(),
       _wikipediaImageService =
           wikipediaImageService ?? WikipediaImageService(client: client);

  static const int pageSize = 100;
  static const String _recordsEndpoint =
      'https://data.unesco.org/api/explore/v2.1/catalog/datasets/whc001/records';
  static const String _arcGisFallbackEndpoint =
      'https://services6.arcgis.com/eMd5K6XXEvJETxfQ/ArcGIS/rest/services/prd_whc_sites_dossiers_elements_v2_view/FeatureServer/1/query';

  final http.Client _client;
  final WikipediaImageService _wikipediaImageService;

  Future<List<int>> fetchHomeSiteIds({int limit = 5}) async {
    if (limit <= 0) {
      return const <int>[];
    }

    final propertyIds = <int>{};
    for (var offset = 0; propertyIds.length < limit; offset += pageSize) {
      final json = await _getJson(
        _buildArcGisUri(
          where: '1=1',
          resultOffset: offset,
          resultRecordCount: pageSize,
          outFields: 'property_id,property_name_en',
          returnGeometry: false,
          returnCentroid: false,
          orderByFields: 'OBJECTID ASC',
        ),
      );

      final features = json['features'];
      if (features is! List || features.isEmpty) {
        break;
      }

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
        final name = UnescoSiteDto.readNameFromMap(
          Map<String, dynamic>.from(attributes),
          const <String>['property_name_en', 'element_name_en', 'name_en'],
        );
        if (propertyId == null || name == null) {
          continue;
        }

        propertyIds.add(propertyId);
        if (propertyIds.length == limit) {
          break;
        }
      }

      if (features.length < pageSize &&
          json['exceededTransferLimit'] != true) {
        break;
      }
    }

    return List<int>.unmodifiable(propertyIds);
  }

  Future<List<UnescoSiteDto>> fetchAllSites() async {
    final sites = <UnescoSiteDto>[];
    var offset = 0;

    final firstPage = await _fetchSitesPageInternal(
      offset: offset,
      enrichMissingImages: false,
    );
    sites.addAll(firstPage.sites);

    if (firstPage.totalCount > pageSize) {
      final futures = <Future<_PageResult>>[];
      for (int i = pageSize; i < firstPage.totalCount; i += pageSize) {
        futures.add(
          _fetchSitesPageInternal(offset: i, enrichMissingImages: false),
        );
      }
      final results = await Future.wait(futures);
      for (final result in results) {
        sites.addAll(result.sites);
      }
    } else if (firstPage.totalCount == 0 && firstPage.rawCount == pageSize) {
      // Fallback for APIs that don't return total_count
      offset += pageSize;
      while (true) {
        final result = await _fetchSitesPageInternal(
          offset: offset,
          enrichMissingImages: false,
        );
        if (result.rawCount == 0) {
          break;
        }

        sites.addAll(result.sites);
        if (result.rawCount < pageSize) {
          break;
        }

        offset += pageSize;
      }
    }

    if (sites.isEmpty) {
      throw const UnescoSitesEmptyResultException(
        'No UNESCO heritage sites were returned.',
      );
    }

    return sites;
  }

  Future<List<UnescoSiteDto>> fetchSitesPage({int offset = 0}) async {
    final result = await _fetchSitesPageInternal(
      offset: offset,
      enrichMissingImages: false,
    );
    return result.sites;
  }

  Future<_PageResult> _fetchSitesPageInternal({
    int offset = 0,
    bool enrichMissingImages = true,
  }) async {
    _PageResult result;
    try {
      final json = await _getJson(_buildRecordsUri(offset: offset));
      result = _parseRecords(json);
    } on UnescoSitesException {
      final json = await _getJson(
        _buildArcGisUri(
          where: '1=1',
          resultOffset: offset,
          resultRecordCount: pageSize,
        ),
      );
      result = _parseFeatures(json);
    }

    if (!enrichMissingImages) {
      return result;
    }

    return _addMissingImages(result);
  }

  Future<UnescoSiteDto> fetchSiteById(int propertyId) async {
    List<UnescoSiteDto> sites;
    try {
      final json = await _getJson(_buildRecordByIdUri(propertyId));
      sites = _parseRecords(json).sites;
    } on UnescoSitesException {
      final json = await _getJson(
        _buildArcGisUri(
          where: 'property_id=$propertyId',
          resultOffset: 0,
          resultRecordCount: 1,
        ),
      );
      sites = _parseFeatures(json).sites;
    }

    if (sites.isEmpty) {
      throw UnescoSitesEmptyResultException(
        'UNESCO heritage site $propertyId was not found.',
      );
    }

    return _enrichSiteMetadata(sites.first);
  }

  Future<_PageResult> _addMissingImages(_PageResult result) async {
    final sites = await Future.wait(result.sites.map(_enrichSiteMetadata));
    return _PageResult(sites, result.rawCount, totalCount: result.totalCount);
  }

  Future<UnescoSiteDto> _enrichSiteMetadata(UnescoSiteDto site) async {
    var resolvedSite = site;

    if (resolvedSite.mainImageUrl.isEmpty && resolvedSite.imageUrls.isNotEmpty) {
      resolvedSite = resolvedSite.copyWith(
        mainImageUrl: resolvedSite.imageUrls.first,
        imageUrls: resolvedSite.imageUrls,
      );
    }

    String? wikipediaSummary;
    if (resolvedSite.shortDescription.isEmpty || resolvedSite.description.isEmpty) {
      wikipediaSummary = await _wikipediaImageService.fetchShortDescription(
        resolvedSite.name,
      );
      if (wikipediaSummary != null && wikipediaSummary.isNotEmpty) {
        resolvedSite = resolvedSite.copyWith(
          shortDescription: resolvedSite.shortDescription.isEmpty
              ? wikipediaSummary
              : resolvedSite.shortDescription,
          description: resolvedSite.description.isEmpty
              ? wikipediaSummary
              : resolvedSite.description,
        );
      }
    }

    if (resolvedSite.mainImageUrl.isNotEmpty) {
      return resolvedSite;
    }

    final imageUrl = await _wikipediaImageService.fetchImageUrl(resolvedSite.name);
    if (imageUrl == null) {
      return resolvedSite;
    }

    return resolvedSite.copyWith(
      mainImageUrl: imageUrl,
      imageUrls: {imageUrl, ...resolvedSite.imageUrls}
          .toSet()
          .toList(growable: false),
    );
  }

  Uri _buildRecordsUri({required int offset}) {
    return Uri.parse(_recordsEndpoint).replace(
      queryParameters: <String, String>{
        'limit': '$pageSize',
        'offset': '$offset',
      },
    );
  }

  Uri _buildRecordByIdUri(int propertyId) {
    return Uri.parse(_recordsEndpoint).replace(
      queryParameters: <String, String>{
        'where': "id_no='$propertyId'",
        'limit': '1',
      },
    );
  }

  Uri _buildArcGisUri({
    required String where,
    required int resultOffset,
    required int resultRecordCount,
    String outFields = '*',
    bool returnGeometry = true,
    bool returnCentroid = true,
    String? orderByFields,
  }) {
    final queryParameters = <String, String>{
      'f': 'json',
      'where': where,
      'outFields': outFields,
      'outSR': '4326',
      'returnGeometry': '$returnGeometry',
      'returnCentroid': '$returnCentroid',
      'resultOffset': '$resultOffset',
      'resultRecordCount': '$resultRecordCount',
    };
    if (orderByFields != null && orderByFields.isNotEmpty) {
      queryParameters['orderByFields'] = orderByFields;
    }

    return Uri.parse(_arcGisFallbackEndpoint).replace(
      queryParameters: queryParameters,
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

  _PageResult _parseRecords(Map<String, dynamic> json) {
    final records = json['results'];
    if (records is! List) {
      throw const UnescoSitesParseException(
        'UNESCO records response is missing results.',
      );
    }

    final parsedSites = <UnescoSiteDto>[];
    for (final record in records) {
      if (record is! Map) continue;
      try {
        parsedSites.add(
          UnescoSiteDto.fromRecord(Map<String, dynamic>.from(record)),
        );
      } catch (_) {
        // Skip invalid records to prevent the whole page from failing.
      }
    }
    return _PageResult(
      parsedSites,
      records.length,
      totalCount: json['total_count'] as int? ?? 0,
    );
  }

  _PageResult _parseFeatures(Map<String, dynamic> json) {
    final features = json['features'];
    if (features is! List) {
      throw const UnescoSitesParseException(
        'UNESCO response is missing features.',
      );
    }

    final parsedSites = <UnescoSiteDto>[];
    for (final feature in features) {
      if (feature is! Map) continue;
      try {
        parsedSites.add(
          UnescoSiteDto.fromFeature(Map<String, dynamic>.from(feature)),
        );
      } catch (_) {
        // Skip invalid records to prevent the whole page from failing.
      }
    }
    return _PageResult(parsedSites, features.length);
  }
}

class _PageResult {
  const _PageResult(this.sites, this.rawCount, {this.totalCount = 0});
  final List<UnescoSiteDto> sites;
  final int rawCount;
  final int totalCount;
}
