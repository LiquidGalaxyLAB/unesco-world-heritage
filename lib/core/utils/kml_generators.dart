import 'dart:convert';
import 'package:http/http.dart' as http;

/// Holds the parsed result of a UNESCO site fetch.
class UnescoSite {
  final String name;
  final String safeFilename;
  final String geometryType;
  final List<List<double>> coordinates; // flat list of [lon, lat] pairs
  final Map<String, dynamic> properties;

  // Wikipedia enrichment (may be null if not found)
  final String? imageUrl;
  final String? description;

  const UnescoSite({
    required this.name,
    required this.safeFilename,
    required this.geometryType,
    required this.coordinates,
    required this.properties,
    this.imageUrl,
    this.description,
  });

  /// Centre [lat, lon] of the polygon bounding box.
  List<double> get centre {
    if (coordinates.isEmpty) return [0, 0];
    final lat = coordinates.map((c) => c[1]).reduce((a, b) => a + b) / coordinates.length;
    final lon = coordinates.map((c) => c[0]).reduce((a, b) => a + b) / coordinates.length;
    return [lat, lon];
  }
}

class KmlGenerators {
  static const String _arcGisUrl =
      'https://services6.arcgis.com/eMd5K6XXEvJETxfQ/ArcGIS/rest/services/'
      'prd_whc_sites_dossiers_elements_v2_view/FeatureServer/1/query'
      '?where=1%3D1&outFields=*&f=pgeojson&resultRecordCount=5';

  // ── Wikipedia REST summary endpoint ────────────────────────────────────────
  static String _wikiUrl(String title) =>
      'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(title.replaceAll(' ', '_'))}';

  /// Fetches the first available UNESCO World Heritage polygon from ArcGIS,
  /// then enriches it with a Wikipedia image + description.
  static Future<UnescoSite> fetchFirstUnescoSite() async {
    // 1. ArcGIS
    final response = await http.get(Uri.parse(_arcGisUrl));
    if (response.statusCode != 200) {
      throw Exception('ArcGIS API error: ${response.statusCode}');
    }

    final geoJson = jsonDecode(response.body) as Map<String, dynamic>;
    final features = geoJson['features'] as List<dynamic>;
    if (features.isEmpty) {
      throw Exception('No UNESCO polygon features returned by the API.');
    }

    final first = features[0] as Map<String, dynamic>;
    final props = first['properties'] as Map<String, dynamic>;
    final geometry = first['geometry'] as Map<String, dynamic>;

    final siteName =
        props['element_name_en'] as String? ??
        props['name_en'] as String? ??
        props['site_name'] as String? ??
        props['name'] as String? ??
        'UNESCO_Site';

    final safeFilename = siteName
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '')
        .trim()
        .replaceAll(' ', '_');

    final geoType = geometry['type'] as String;
    final rawCoords = geometry['coordinates'];

    List<List<double>> coords = [];
    if (geoType == 'Polygon') {
      final ring = rawCoords[0] as List<dynamic>;
      coords = ring
          .map<List<double>>((p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()])
          .toList();
    } else if (geoType == 'MultiPolygon') {
      final ring = rawCoords[0][0] as List<dynamic>;
      coords = ring
          .map<List<double>>((p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()])
          .toList();
    }

    // 2. Wikipedia enrichment (best-effort — never throws)
    String? imageUrl;
    String? description;
    try {
      final wikiResp = await http
          .get(Uri.parse(_wikiUrl(siteName)))
          .timeout(const Duration(seconds: 6));

      if (wikiResp.statusCode == 200) {
        final wikiJson = jsonDecode(wikiResp.body) as Map<String, dynamic>;
        imageUrl = (wikiJson['thumbnail'] as Map<String, dynamic>?)?['source'] as String?;
        // Use extract_html or extract – pick the first sentence only
        final extract = wikiJson['extract'] as String?;
        if (extract != null && extract.isNotEmpty) {
          // Trim to ~250 chars for the balloon
          description = extract.length > 250
              ? '${extract.substring(0, 247)}…'
              : extract;
        }
      }
    } catch (_) {
      // Wikipedia fetch is optional; silently skip
    }

    return UnescoSite(
      name: siteName,
      safeFilename: safeFilename,
      geometryType: geoType,
      coordinates: coords,
      properties: props,
      imageUrl: imageUrl,
      description: description,
    );
  }

  // ── KML generators ─────────────────────────────────────────────────────────

  /// 2D flat KML (clampToGround) — blue polygon like the image.
  static String generateUnesco2dKml(UnescoSite site) {
    final coordStr = site.coordinates.map((p) => '${p[0]},${p[1]},0').join(' ');
    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>${site.name} 2D Boundary</name>
    <Style id="flat_boundary">
      <LineStyle>
        <color>ffff5500</color>
        <width>3</width>
      </LineStyle>
      <PolyStyle>
        <color>881565C0</color>
      </PolyStyle>
    </Style>
    <Placemark>
      <name>${site.name}</name>
      <styleUrl>#flat_boundary</styleUrl>
      <Polygon>
        <tessellate>1</tessellate>
        <altitudeMode>clampToGround</altitudeMode>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>$coordStr</coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>
  </Document>
</kml>''';
  }

  /// 3D extruded KML — golden glowing wall at 150 m (exact Colab match).
  static String generateUnesco3dKml(UnescoSite site) {
    const double height = 150;
    final coordStr = site.coordinates.map((p) => '${p[0]},${p[1]},$height').join(' ');
    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>${site.name}_3D_Boundary</name>
    <Style id="glowing_wall">
      <LineStyle>
        <color>ffebce87</color>
        <width>4</width>
      </LineStyle>
      <PolyStyle>
        <color>88ebce87</color>
      </PolyStyle>
    </Style>
    <Placemark>
      <name>${site.name}</name>
      <styleUrl>#glowing_wall</styleUrl>
      <Polygon>
        <extrude>1</extrude>
        <altitudeMode>relativeToGround</altitudeMode>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>$coordStr</coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>
  </Document>
</kml>''';
  }

  /// Info balloon KML for the rightmost LG screen.
  /// Shows a small site image (if available) + description.
  static String generateUnescoInfoBalloonKml(UnescoSite site) {
    final centre = site.centre;

    // Build the inline HTML for the balloon
    final imageHtml = site.imageUrl != null
        ? '<img src="${site.imageUrl}" '
          'style="width:260px;height:160px;object-fit:cover;'
          'border-radius:8px;margin-bottom:10px;display:block;"/>'
        : '';

    final descHtml = site.description != null
        ? '<p style="color:#cccccc;font-size:12px;'
          'line-height:1.5;margin:0;">${site.description}</p>'
        : '';

    final coordsStr = '${centre[1]},${centre[0]},0';

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
<Document>
  <name>${site.name} Info</name>
  <Style id="info_balloon">
    <BalloonStyle>
      <bgColor>ff1a1a2e</bgColor>
      <textColor>ffffffff</textColor>
      <text><![CDATA[
        <div style="font-family:Arial,sans-serif;padding:12px;width:280px;
                    background:#1a1a2e;border-radius:10px;">
          $imageHtml
          <h2 style="color:#FFD700;font-size:15px;margin:0 0 8px 0;
                     line-height:1.3;">${site.name}</h2>
          <p style="color:#87CEEB;font-size:11px;margin:0 0 8px 0;">
            🌍 UNESCO World Heritage Site
          </p>
          <hr style="border:1px solid #333;margin:8px 0;"/>
          $descHtml
          <p style="color:#555;font-size:10px;text-align:right;
                    margin:8px 0 0 0;">LG 360° Explorer</p>
        </div>
      ]]></text>
    </BalloonStyle>
  </Style>
  <Placemark>
    <name>${site.name}</name>
    <styleUrl>#info_balloon</styleUrl>
    <gx:balloonVisibility>1</gx:balloonVisibility>
    <Point>
      <coordinates>$coordsStr</coordinates>
    </Point>
  </Placemark>
</Document>
</kml>''';
  }
}
