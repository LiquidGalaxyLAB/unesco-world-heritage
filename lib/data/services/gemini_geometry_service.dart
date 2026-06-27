import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/unesco_site_geometry_dto.dart';
import 'unesco_api_exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiGeometryService {
  GeminiGeometryService({http.Client? client})
    : _client = client ?? http.Client();

  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  final http.Client _client;

  Future<String> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('gemini_api_key') ?? '';
  }

  Future<bool> get isConfigured async {
    final key = await _getApiKey();
    return key.trim().isNotEmpty;
  }

  Future<List<UnescoSiteGeometryDto>> fetchGeneratedGeometry({
    required int propertyId,
    required String siteName,
    required String country,
    required double latitude,
    required double longitude,
  }) async {
    final apiKey = await _getApiKey();
    if (apiKey.trim().isEmpty) {
      return const <UnescoSiteGeometryDto>[];
    }

    final response = await _client.post(
      Uri.parse(
        _endpoint,
      ).replace(queryParameters: <String, String>{'key': apiKey}),
      headers: const <String, String>{'content-type': 'application/json'},
      body: jsonEncode(<String, Object?>{
        'contents': <Object>[
          <String, Object>{
            'parts': <Object>[
              <String, String>{
                'text': _buildPrompt(
                  propertyId: propertyId,
                  siteName: siteName,
                  country: country,
                  latitude: latitude,
                  longitude: longitude,
                ),
              },
            ],
          },
        ],
        'generationConfig': <String, Object>{
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UnescoSitesNetworkException(
        'Gemini geometry request failed with status ${response.statusCode}.',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      final text = _extractText(Map<String, dynamic>.from(decoded as Map));
      final geometryJson = jsonDecode(text);
      return _parseGeometryJson(propertyId, geometryJson);
    } catch (error) {
      throw UnescoSitesParseException(
        'Unable to parse Gemini geometry response: $error',
      );
    }
  }

  String _buildPrompt({
    required int propertyId,
    required String siteName,
    required String country,
    required double latitude,
    required double longitude,
  }) {
    return '''
Return approximate polygon coordinates for the UNESCO World Heritage Site.
Use official or well-known public boundary knowledge where possible.
If you are uncertain, return a small closed bounding polygon around the known coordinate.
Respond only with JSON shaped exactly like:
{"rings":[[[longitude,latitude],[longitude,latitude],[longitude,latitude],[longitude,latitude],[longitude,latitude]]]}

UNESCO id_no/property_id: $propertyId
Name: $siteName
Country: $country
Known coordinate: longitude $longitude, latitude $latitude
''';
  }

  String _extractText(Map<String, dynamic> json) {
    final candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const FormatException('Missing Gemini candidates.');
    }

    final candidate = Map<String, dynamic>.from(candidates.first as Map);
    final content = Map<String, dynamic>.from(candidate['content'] as Map);
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw const FormatException('Missing Gemini content parts.');
    }

    final part = Map<String, dynamic>.from(parts.first as Map);
    final text = part['text'];
    if (text is! String || text.trim().isEmpty) {
      throw const FormatException('Missing Gemini text.');
    }

    return text.trim();
  }

  List<UnescoSiteGeometryDto> _parseGeometryJson(
    int propertyId,
    Object? geometryJson,
  ) {
    if (geometryJson is! Map) {
      throw const FormatException('Expected Gemini geometry object.');
    }

    return <UnescoSiteGeometryDto>[
      UnescoSiteGeometryDto.fromFeature(<String, dynamic>{
        'attributes': <String, dynamic>{'property_id': propertyId},
        'geometry': Map<String, dynamic>.from(geometryJson),
      }),
    ];
  }
}
