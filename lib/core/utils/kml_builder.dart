import 'dart:math' as math;

import '../constants/lg_constants.dart';
import '../../domain/models/heritage_site.dart';

class KMLBuilder {
  static const int _denseComponentThreshold = 200;
  static const int _denseComponentRenderLimit = 120;
  static const int _denseCirclePointCount = 72;
  static const int _trajectoryComponentThreshold = 4;

  final StringBuffer _buffer = StringBuffer();
  bool _hasHeader = false;

  KMLBuilder addHeader() {
    if (!_hasHeader) {
      _buffer.write(LGConstants.kmlHeader);
      _hasHeader = true;
    }
    return this;
  }

  KMLBuilder addLookAt({
    required double longitude,
    required double latitude,
    required double range,
    double tilt = 0,
    double heading = 0,
  }) {
    _buffer.write(
      LGConstants.lookAt(
        longitude: longitude,
        latitude: latitude,
        range: range,
        tilt: tilt,
        heading: heading,
      ),
    );
    return this;
  }

  KMLBuilder addPlacemark({
    required String name,
    required double longitude,
    required double latitude,
    String? description,
  }) {
    _buffer.write(
      LGConstants.placemark(
        name: name,
        longitude: longitude,
        latitude: latitude,
        description: description,
      ),
    );
    return this;
  }

  KMLBuilder addCustom(String kml) {
    _buffer.write(kml);
    return this;
  }

  String build() {
    if (!_hasHeader) addHeader();
    _buffer.write(LGConstants.kmlFooter);
    return _buffer.toString();
  }

  static String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static String _escapeHtml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  static String getKmlSkeleton(String content, String name) =>
      '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
<Document>
  <name>$name</name>
    $content
</Document>
</kml>
  ''';

  static String screenOverlayImage({
    required String id,
    required String name,
    required String imageUrl,
    required double factor,
    double overlayX = 0,
    double overlayY = 1,
    double screenX = 0.02,
    double screenY = 0.95,
    double? sizeX,
    double? sizeY,
  }) {
    final safeName = _escapeXml(name);
    final effectiveSizeX = sizeX ?? 580;
    final effectiveSizeY = sizeY ?? (580 * factor);
    final content =
        '''
    <name>tags</name>
    <Style>
      <ListStyle>
        <listItemType>checkHideChildren</listItemType>
        <bgColor>00ffffff</bgColor>
        <maxSnippetLines>2</maxSnippetLines>
      </ListStyle>
    </Style>
    <ScreenOverlay id="${_escapeXml(id)}">
      <name>$safeName</name>
      <Icon>
        <href>${_escapeXml(imageUrl)}</href>
      </Icon>
      <overlayXY x="$overlayX" y="$overlayY" xunits="fraction" yunits="fraction"/>
      <screenXY x="$screenX" y="$screenY" xunits="fraction" yunits="fraction"/>
      <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
      <size x="$effectiveSizeX" y="$effectiveSizeY" xunits="pixels" yunits="pixels"/>
    </ScreenOverlay>''';
    return getKmlSkeleton(content, safeName);
  }

  static String buildBoundaryKml({
    required String name,
    required List<List<List<double>>> rings,
    HeritageCategory? category,
  }) {
    const double extrusionHeight = 150;
    final safeName = _escapeXml(name);
    final normalizedRings = rings
        .map(_normalizeRing)
        .where((ring) => ring.length >= 4)
        .toList(growable: false);

    if (normalizedRings.isEmpty) {
      return generateBlankKml(safeName);
    }

    final components = _buildPolygonComponents(normalizedRings);
    if (components.isEmpty) {
      return generateBlankKml(safeName);
    }

    // Category-based colors in KML AABBGGRR format:
    // CULTURAL: #FFCC33 → ff33ccff (line), 8833ccff (poly)
    // MIXED:    #00E5FF → ffffe500 (line), 88ffe500 (poly)
    // NATURAL:  #39FF14 → ff14ff39 (line), 8814ff39 (poly)
    String lineColor;
    String polyColor;
    switch (category) {
      case HeritageCategory.cultural:
        lineColor = 'ff33ccff';
        polyColor = '8833ccff';
        break;
      case HeritageCategory.mixed:
        lineColor = 'ffffe500';
        polyColor = '88ffe500';
        break;
      case HeritageCategory.natural:
        lineColor = 'ff14ff39';
        polyColor = '8814ff39';
        break;
      default:
        lineColor = 'ffebce87';
        polyColor = '88ebce87';
        break;
    }

    final isDenseSite = components.length > _denseComponentThreshold;
    final renderedComponents = isDenseSite
        ? _sampleComponentsForDenseSite(
            components,
            limit: _denseComponentRenderLimit,
          )
        : components;
    final placemarks = <String>[];
    for (var index = 0; index < renderedComponents.length; index++) {
      final component = renderedComponents[index];
      final outerBoundary = _buildLinearRing(
        component.outerRing,
        altitude: extrusionHeight,
      );
      final innerBoundaries = component.innerRings
          .map(
            (ring) =>
                '<innerBoundaryIs><LinearRing><coordinates>${_buildLinearRing(ring, altitude: extrusionHeight)}</coordinates></LinearRing></innerBoundaryIs>',
          )
          .join();

      placemarks.add('''
    <Placemark>
      <name>${index == 0 ? safeName : '$safeName ${index + 1}'}</name>
      <styleUrl>#site_boundary</styleUrl>
      <Polygon>
        <extrude>1</extrude>
        <altitudeMode>relativeToGround</altitudeMode>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>$outerBoundary</coordinates>
          </LinearRing>
        </outerBoundaryIs>
        $innerBoundaries
      </Polygon>
    </Placemark>''');
    }

    final trajectory = _buildTrajectoryPlacemark(
      name: safeName,
      components: components,
    );
    final denseSiteCircle = isDenseSite
        ? _buildDenseSiteCirclePlacemark(name: safeName, components: components)
        : '';

    final content =
        '''
    <Style id="site_boundary">
      <LineStyle>
        <color>$lineColor</color>
        <width>4</width>
      </LineStyle>
      <PolyStyle>
        <color>$polyColor</color>
      </PolyStyle>
    </Style>
    <Style id="site_trajectory">
      <LineStyle>
        <color>$lineColor</color>
        <width>3</width>
      </LineStyle>
      <PolyStyle>
        <color>00ffffff</color>
      </PolyStyle>
    </Style>
    <Style id="site_boundary_circle">
      <LineStyle>
        <color>ff66f2ff</color>
        <width>5</width>
      </LineStyle>
      <PolyStyle>
        <color>1a66f2ff</color>
      </PolyStyle>
    </Style>
    $denseSiteCircle
    ${placemarks.join()}
    $trajectory''';

    return getKmlSkeleton(content, safeName);
  }

  static String generateBlankKml(String name) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
    <Document id="$name">
    </Document>
</kml>''';
  }

  static String buildOrbit(double lat, double lon) {
    String lookAts = '';

    for (int i = 0; i <= 360; i += 10) {
      lookAts +=
          '''
      <gx:FlyTo>
              <gx:duration>1.2</gx:duration>
              <gx:flyToMode>smooth</gx:flyToMode>
              <LookAt>
                  <longitude>$lon</longitude>
                  <latitude>$lat</latitude>
                  <heading>${i.toDouble()}</heading>
                  <tilt>60</tilt>
                  <range>40000</range>
                  <gx:fovy>60</gx:fovy>
                  <altitude>3341.7995674</altitude>
                  <gx:altitudeMode>absolute</gx:altitudeMode>
              </LookAt>
            </gx:FlyTo>
''';
    }

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
   <gx:Tour>
   <name>Orbit</name>
      <gx:Playlist>
         $lookAts
      </gx:Playlist>
   </gx:Tour>
</kml>''';
  }

  static String buildTour(double lat, double lon, String name) {
    String lookAts = '';

    // Initial bounce brings the camera to the site before orbiting.
    lookAts +=
        '''
      <gx:FlyTo>
              <gx:duration>1.2</gx:duration>
              <gx:flyToMode>bounce</gx:flyToMode>
              <LookAt>
                  <longitude>$lon</longitude>
                  <latitude>$lat</latitude>
                  <heading>0</heading>
                  <tilt>60</tilt>
                  <range>40000</range>
                  <gx:fovy>60</gx:fovy>
                  <altitude>3341.7995674</altitude>
                  <gx:altitudeMode>absolute</gx:altitudeMode>
              </LookAt>
            </gx:FlyTo>
      ''';

    for (int i = 0; i <= 360; i += 18) {
      lookAts +=
          '''
      <gx:FlyTo>
              <gx:duration>1.2</gx:duration>
              <gx:flyToMode>smooth</gx:flyToMode>
              <LookAt>
                  <longitude>$lon</longitude>
                  <latitude>$lat</latitude>
                  <heading>${i.toDouble()}</heading>
                  <tilt>60</tilt>
                  <range>40000</range>
                  <gx:fovy>60</gx:fovy>
                  <altitude>3341.7995674</altitude>
                  <gx:altitudeMode>absolute</gx:altitudeMode>
              </LookAt>
            </gx:FlyTo>
      ''';
    }

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
   <gx:Tour>
   <name>$name</name>
      <gx:Playlist>
         $lookAts
      </gx:Playlist>
   </gx:Tour>
</kml>''';
  }

  static String createCityTour({
    required String tourName,
    required double latitude,
    required double longitude,
    double range = 5000,
    double tilt = 60,
    double orbitDuration = 5.0,
  }) {
    StringBuffer playlist = StringBuffer();

    playlist.write('''
      <gx:FlyTo>
        <gx:duration>1.0</gx:duration>
        <gx:flyToMode>smooth</gx:flyToMode>
        <LookAt>
          <longitude>$longitude</longitude>
          <latitude>$latitude</latitude>
          <range>$range</range>
          <tilt>$tilt</tilt>
          <heading>0</heading>
          <altitudeMode>relativeToGround</altitudeMode>
        </LookAt>
      </gx:FlyTo>
    ''');

    const int steps = 18;
    double stepDuration = orbitDuration / steps;

    for (int i = 1; i <= steps; i++) {
      double heading = (i * 20.0) % 360;
      playlist.write('''
      <gx:FlyTo>
        <gx:duration>$stepDuration</gx:duration>
        <gx:flyToMode>smooth</gx:flyToMode>
        <LookAt>
          <longitude>$longitude</longitude>
          <latitude>$latitude</latitude>
          <range>$range</range>
          <tilt>$tilt</tilt>
          <heading>$heading</heading>
          <altitudeMode>relativeToGround</altitudeMode>
        </LookAt>
      </gx:FlyTo>
      ''');
    }

    playlist.write('''
      <gx:Wait>
        <gx:duration>2.0</gx:duration>
      </gx:Wait>
    ''');

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>$tourName</name>
    <gx:Tour>
      <name>$tourName</name>
      <gx:Playlist>
        $playlist
      </gx:Playlist>
    </gx:Tour>
  </Document>
</kml>''';
  }

  static String createAllToursKML(List<dynamic> sites) {
    StringBuffer allTours = StringBuffer();

    for (var site in sites) {
      final sanitizedName = (site.name as String).replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '',
      );
      final tourName = 'Tour_$sanitizedName';
      StringBuffer playlist = StringBuffer();

      playlist.write('''
        <gx:FlyTo>
          <gx:duration>1.0</gx:duration>
          <gx:flyToMode>smooth</gx:flyToMode>
          <LookAt>
            <longitude>${site.longitude}</longitude>
            <latitude>${site.latitude}</latitude>
            <range>5000</range>
            <tilt>60</tilt>
            <heading>0</heading>
            <altitudeMode>relativeToGround</altitudeMode>
          </LookAt>
        </gx:FlyTo>
      ''');

      for (int i = 1; i <= 8; i++) {
        double heading = (i * 45.0);
        playlist.write('''
        <gx:FlyTo>
          <gx:duration>1.5</gx:duration>
          <gx:flyToMode>smooth</gx:flyToMode>
          <LookAt>
            <longitude>${site.longitude}</longitude>
            <latitude>${site.latitude}</latitude>
            <range>5000</range>
            <tilt>60</tilt>
            <heading>$heading</heading>
            <altitudeMode>relativeToGround</altitudeMode>
          </LookAt>
        </gx:FlyTo>
        ''');
      }

      playlist.write('''
        <gx:Wait>
          <gx:duration>5.0</gx:duration>
        </gx:Wait>
      ''');

      allTours.write('''
      <gx:Tour>
        <name>$tourName</name>
        <gx:Playlist>
          $playlist
        </gx:Playlist>
      </gx:Tour>
      ''');
    }

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>All Heritage Site Tours</name>
    $allTours
  </Document>
</kml>''';
  }

  static String createBalloon({
    required String title,
    required String content,
    required double longitude,
    required double latitude,
  }) {
    final balloonKml =
        '''
<Placemark>
  <name>$title</name>
  <description><![CDATA[$content]]></description>
  <gx:balloonVisibility>1</gx:balloonVisibility>
  <Point>
    <coordinates>$longitude,$latitude,0</coordinates>
  </Point>
</Placemark>''';

    return KMLBuilder().addHeader().addCustom(balloonKml).build();
  }

  static String createSiteInfoBalloon({
    required String title,
    required String description,
    required double longitude,
    required double latitude,
    String? imageUrl,
  }) {
    final safeTitle = _escapeHtml(title);
    final safeTitleXml = _escapeXml(title);
    final safeDescription = _escapeHtml(description);
    final normalizedImageUrl = imageUrl?.trim() ?? '';
    final imageSection = normalizedImageUrl.isNotEmpty
        ? '''
        <div style="padding:0 18px;">
          <img src="${_escapeHtml(normalizedImageUrl)}" alt="$safeTitle"
               style="width:100%;height:380px;display:block;object-fit:cover;border-radius:0;"/>
        </div>
        '''
        : '';

    return '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
  <Document>
   <name>Site Info</name>
   <Style id="site_info_balloon">
     <BalloonStyle>
        <bgColor>ff1b1b1b</bgColor>
        <textColor>ffffffff</textColor>
        <text><![CDATA[
          <div style="width:500px;background:#1f1d1d;border-radius:24px;overflow:hidden;
                      font-family:Arial,sans-serif;color:#ffffff;border:1px solid #3a3636;
                      box-shadow:0 16px 36px rgba(0,0,0,0.42);">
            <div style="display:flex;align-items:center;gap:14px;padding:22px 22px 18px 22px;"><!--
              <h2 style="margin: 0; font-size: 25px; font-weight: 700;">ðŸ“ $title</h2>
            --></div>
            <div style="display:flex;align-items:center;gap:14px;padding:0 22px 18px 22px;">
              <div style="font-size:24px;line-height:1;color:#ffffff;">&#128205;</div>
              <div style="font-size:26px;font-weight:700;line-height:1.3;color:#ffffff;">$safeTitle</div>
            </div>
            $imageSection
            <div style="padding:22px 22px 26px 22px;">
              <p style="margin:0;font-size:20px;line-height:1.6;color:#f0f0f0;">$safeDescription</p>
            </div>
          </div>
        ]]></text>
     </BalloonStyle>
   </Style>
    <Placemark id="site_info_balloon_marker">
      <name>$safeTitleXml</name>
      <description></description>
     <LookAt>
       <longitude>$longitude</longitude>
       <latitude>$latitude</latitude>
       <heading>0</heading>
       <tilt>0</tilt>
       <range>12</range>
     </LookAt>
      <styleUrl>#site_info_balloon</styleUrl>
     <gx:balloonVisibility>1</gx:balloonVisibility>
     <Point>
       <coordinates>$longitude,$latitude,0</coordinates>
     </Point>
   </Placemark>
  </Document>
  </kml>''';
  }

  static String createScreenOverlay({
    required String imageUrl,
    required String title,
    double overlayX = 0,
    double overlayY = 1,
    double screenX = 0.02,
    double screenY = 0.95,
    double sizeX = 0,
    double sizeY = 0,
  }) {
    final overlayKml =
        '''
<ScreenOverlay>
  <name>$title</name>
  <Icon>
    <href>$imageUrl</href>
  </Icon>
  <overlayXY x="$overlayX" y="$overlayY" xunits="fraction" yunits="fraction"/>
  <screenXY x="$screenX" y="$screenY" xunits="fraction" yunits="fraction"/>
  <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
  <size x="$sizeX" y="$sizeY" xunits="pixels" yunits="pixels"/>
</ScreenOverlay>
''';

    return KMLBuilder().addHeader().addCustom(overlayKml).build();
  }

  static String buildLinearLookAt({
    required double lng,
    required double lat,
    required String range,
    required String tilt,
    required String heading,
    String? altitude,
    String? altitudeMode,
  }) {
    return '<LookAt>'
        '<longitude>$lng</longitude>'
        '<latitude>$lat</latitude>'
        '${altitude != null ? '<altitude>$altitude</altitude>' : ''}'
        '<heading>$heading</heading>'
        '<tilt>$tilt</tilt>'
        '<range>$range</range>'
        '${altitudeMode != null ? '<altitudeMode>$altitudeMode</altitudeMode>' : ''}'
        '</LookAt>';
  }

  static List<List<double>> _normalizeRing(List<List<double>> ring) {
    if (ring.isEmpty) {
      return const <List<double>>[];
    }

    final normalizedRing = ring
        .where((point) => point.length >= 2)
        .map((point) => <double>[point[0], point[1]])
        .toList(growable: true);

    if (normalizedRing.isEmpty) {
      return const <List<double>>[];
    }

    final first = normalizedRing.first;
    final last = normalizedRing.last;
    if (first[0] != last[0] || first[1] != last[1]) {
      normalizedRing.add(<double>[first[0], first[1]]);
    }

    return normalizedRing;
  }

  static String _buildLinearRing(
    List<List<double>> ring, {
    double altitude = 0,
  }) {
    return ring
        .map(
          (point) => '${point[1]},${point[0]},${altitude.toStringAsFixed(1)}',
        )
        .join(' ');
  }

  static List<_PolygonComponent> _buildPolygonComponents(
    List<List<List<double>>> rings,
  ) {
    final descriptors = rings
        .map(_RingDescriptor.fromRing)
        .where((descriptor) => descriptor.ring.length >= 4)
        .toList(growable: false);
    if (descriptors.isEmpty) {
      return const <_PolygonComponent>[];
    }

    final sortedDescriptors = descriptors.toList(growable: true)
      ..sort((a, b) => b.absoluteArea.compareTo(a.absoluteArea));

    final components = <_PolygonComponentBuilder>[];
    for (final descriptor in sortedDescriptors) {
      _PolygonComponentBuilder? parent;
      for (final candidate in components) {
        if (_isRingInsideOuterRing(descriptor, candidate.outer) &&
            descriptor.orientation != candidate.outer.orientation) {
          parent = candidate;
          break;
        }
      }

      if (parent == null) {
        components.add(_PolygonComponentBuilder(outer: descriptor));
      } else {
        parent.innerRings.add(descriptor.ring);
      }
    }

    return components
        .map(
          (component) => _PolygonComponent(
            outerRing: component.outer.ring,
            innerRings: List<List<List<double>>>.unmodifiable(
              component.innerRings,
            ),
            centroid: component.outer.centroid,
          ),
        )
        .toList(growable: false);
  }

  static bool _isRingInsideOuterRing(
    _RingDescriptor ring,
    _RingDescriptor outerRing,
  ) {
    if (ring.minLatitude < outerRing.minLatitude ||
        ring.maxLatitude > outerRing.maxLatitude ||
        ring.minLongitude < outerRing.minLongitude ||
        ring.maxLongitude > outerRing.maxLongitude) {
      return false;
    }

    return _pointInPolygon(point: ring.ring.first, ring: outerRing.ring);
  }

  static bool _pointInPolygon({
    required List<double> point,
    required List<List<double>> ring,
  }) {
    if (ring.length < 4) {
      return false;
    }

    final latitude = point[0];
    final longitude = point[1];
    var isInside = false;

    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final currentLatitude = ring[i][0];
      final currentLongitude = ring[i][1];
      final previousLatitude = ring[j][0];
      final previousLongitude = ring[j][1];
      final crossesLatitude =
          (currentLatitude > latitude) != (previousLatitude > latitude);
      if (!crossesLatitude) {
        continue;
      }

      final intersectionLongitude =
          ((previousLongitude - currentLongitude) *
              (latitude - currentLatitude) /
              (previousLatitude - currentLatitude)) +
          currentLongitude;
      if (longitude < intersectionLongitude) {
        isInside = !isInside;
      }
    }

    return isInside;
  }

  static String _buildTrajectoryPlacemark({
    required String name,
    required List<_PolygonComponent> components,
  }) {
    if (components.length <= _trajectoryComponentThreshold) {
      return '';
    }

    final orderedComponents = _orderComponentsForTrajectory(components);
    final coordinates = orderedComponents
        .map(
          (component) =>
              '${component.centroid[1]},${component.centroid[0]},220.0',
        )
        .join(' ');

    return '''
    <Placemark>
      <name>$name trajectory</name>
      <styleUrl>#site_trajectory</styleUrl>
      <LineString>
        <extrude>1</extrude>
        <tessellate>1</tessellate>
        <altitudeMode>relativeToGround</altitudeMode>
        <coordinates>$coordinates</coordinates>
      </LineString>
    </Placemark>''';
  }

  static List<_PolygonComponent> _orderComponentsForTrajectory(
    List<_PolygonComponent> components,
  ) {
    var minLatitude = double.infinity;
    var maxLatitude = double.negativeInfinity;
    var minLongitude = double.infinity;
    var maxLongitude = double.negativeInfinity;
    for (final component in components) {
      minLatitude = minLatitude < component.centroid[0]
          ? minLatitude
          : component.centroid[0];
      maxLatitude = maxLatitude > component.centroid[0]
          ? maxLatitude
          : component.centroid[0];
      minLongitude = minLongitude < component.centroid[1]
          ? minLongitude
          : component.centroid[1];
      maxLongitude = maxLongitude > component.centroid[1]
          ? maxLongitude
          : component.centroid[1];
    }

    final orderByLongitude =
        (maxLongitude - minLongitude).abs() >=
        (maxLatitude - minLatitude).abs();
    final orderedComponents = components.toList(growable: true)
      ..sort((a, b) {
        if (orderByLongitude) {
          final longitudeCompare = a.centroid[1].compareTo(b.centroid[1]);
          if (longitudeCompare != 0) {
            return longitudeCompare;
          }
          return a.centroid[0].compareTo(b.centroid[0]);
        }

        final latitudeCompare = a.centroid[0].compareTo(b.centroid[0]);
        if (latitudeCompare != 0) {
          return latitudeCompare;
        }
        return a.centroid[1].compareTo(b.centroid[1]);
      });

    return List<_PolygonComponent>.unmodifiable(orderedComponents);
  }

  static List<_PolygonComponent> _sampleComponentsForDenseSite(
    List<_PolygonComponent> components, {
    required int limit,
  }) {
    if (components.length <= limit) {
      return components;
    }

    final orderedComponents = _orderComponentsForTrajectory(components);
    final step = math.max(1, (orderedComponents.length / limit).ceil());
    final sampled = <_PolygonComponent>[];
    for (
      var index = 0;
      index < orderedComponents.length && sampled.length < limit - 1;
      index += step
    ) {
      sampled.add(orderedComponents[index]);
    }

    final lastComponent = orderedComponents.last;
    if (sampled.isEmpty || !identical(sampled.last, lastComponent)) {
      sampled.add(lastComponent);
    }

    return List<_PolygonComponent>.unmodifiable(sampled);
  }

  static String _buildDenseSiteCirclePlacemark({
    required String name,
    required List<_PolygonComponent> components,
  }) {
    final extent = _computeComponentCentroidExtent(components);
    if (!extent.isValid) {
      return '';
    }

    final latitudeRadius = math.max(
      (extent.maxLatitude - extent.minLatitude) / 2,
      0.005,
    );
    final longitudeRadius = math.max(
      (extent.maxLongitude - extent.minLongitude) / 2,
      0.005,
    );
    final expandedLatitudeRadius = latitudeRadius * 1.02;
    final expandedLongitudeRadius = longitudeRadius * 1.02;

    final ring = <List<double>>[];
    for (var index = 0; index < _denseCirclePointCount; index++) {
      final angle = (2 * math.pi * index) / _denseCirclePointCount;
      ring.add(<double>[
        extent.centerLatitude + (expandedLatitudeRadius * math.sin(angle)),
        extent.centerLongitude + (expandedLongitudeRadius * math.cos(angle)),
      ]);
    }
    if (ring.isNotEmpty) {
      ring.add(ring.first);
    }

    final coordinates = _buildLinearRing(ring, altitude: 120);
    return '''
    <Placemark>
      <name>$name overview</name>
      <styleUrl>#site_boundary_circle</styleUrl>
      <Polygon>
        <extrude>1</extrude>
        <tessellate>1</tessellate>
        <altitudeMode>relativeToGround</altitudeMode>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>$coordinates</coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>''';
  }

  static _SiteExtent _computeComponentCentroidExtent(
    List<_PolygonComponent> components,
  ) {
    var minLatitude = double.infinity;
    var maxLatitude = double.negativeInfinity;
    var minLongitude = double.infinity;
    var maxLongitude = double.negativeInfinity;

    for (final component in components) {
      minLatitude = math.min(minLatitude, component.centroid[0]);
      maxLatitude = math.max(maxLatitude, component.centroid[0]);
      minLongitude = math.min(minLongitude, component.centroid[1]);
      maxLongitude = math.max(maxLongitude, component.centroid[1]);
    }

    if (!minLatitude.isFinite ||
        !maxLatitude.isFinite ||
        !minLongitude.isFinite ||
        !maxLongitude.isFinite) {
      return const _SiteExtent.empty();
    }

    return _SiteExtent(
      minLatitude: minLatitude,
      maxLatitude: maxLatitude,
      minLongitude: minLongitude,
      maxLongitude: maxLongitude,
    );
  }
}

enum _RingOrientation { clockwise, counterClockwise }

class _RingDescriptor {
  const _RingDescriptor({
    required this.ring,
    required this.absoluteArea,
    required this.orientation,
    required this.centroid,
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  factory _RingDescriptor.fromRing(List<List<double>> ring) {
    var signedArea = 0.0;
    var minLatitude = double.infinity;
    var maxLatitude = double.negativeInfinity;
    var minLongitude = double.infinity;
    var maxLongitude = double.negativeInfinity;

    for (var index = 0; index < ring.length - 1; index++) {
      final current = ring[index];
      final next = ring[index + 1];
      signedArea += (current[1] * next[0]) - (next[1] * current[0]);
    }

    for (final point in ring) {
      minLatitude = point[0] < minLatitude ? point[0] : minLatitude;
      maxLatitude = point[0] > maxLatitude ? point[0] : maxLatitude;
      minLongitude = point[1] < minLongitude ? point[1] : minLongitude;
      maxLongitude = point[1] > maxLongitude ? point[1] : maxLongitude;
    }

    return _RingDescriptor(
      ring: ring,
      absoluteArea: signedArea.abs() / 2,
      orientation: signedArea < 0
          ? _RingOrientation.clockwise
          : _RingOrientation.counterClockwise,
      centroid: <double>[
        (minLatitude + maxLatitude) / 2,
        (minLongitude + maxLongitude) / 2,
      ],
      minLatitude: minLatitude,
      maxLatitude: maxLatitude,
      minLongitude: minLongitude,
      maxLongitude: maxLongitude,
    );
  }

  final List<List<double>> ring;
  final double absoluteArea;
  final _RingOrientation orientation;
  final List<double> centroid;
  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;
}

class _PolygonComponentBuilder {
  _PolygonComponentBuilder({required this.outer});

  final _RingDescriptor outer;
  final List<List<List<double>>> innerRings = <List<List<double>>>[];
}

class _PolygonComponent {
  const _PolygonComponent({
    required this.outerRing,
    required this.innerRings,
    required this.centroid,
  });

  final List<List<double>> outerRing;
  final List<List<List<double>>> innerRings;
  final List<double> centroid;
}

class _SiteExtent {
  const _SiteExtent({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  const _SiteExtent.empty()
    : minLatitude = double.nan,
      maxLatitude = double.nan,
      minLongitude = double.nan,
      maxLongitude = double.nan;

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;

  bool get isValid =>
      minLatitude.isFinite &&
      maxLatitude.isFinite &&
      minLongitude.isFinite &&
      maxLongitude.isFinite;

  double get centerLatitude => (minLatitude + maxLatitude) / 2;
  double get centerLongitude => (minLongitude + maxLongitude) / 2;
}
