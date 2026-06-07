class KMLBuilder {
  static const String _namespaces =
      'xmlns="http://www.opengis.net/kml/2.2" '
      'xmlns:gx="http://www.google.com/kml/ext/2.2" '
      'xmlns:kml="http://www.opengis.net/kml/2.2" '
      'xmlns:atom="http://www.w3.org/2005/Atom"';

  static String buildKmlSkeleton({
    required String name,
    required String content,
  }) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml $_namespaces>
  <Document>
    <name>${_escapeXml(name)}</name>
    $content
  </Document>
</kml>''';
  }

  static String buildBlank(String id) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml $_namespaces>
  <Document id="${_escapeXml(id)}">
  </Document>
</kml>''';
  }

  static String buildScreenOverlay({
    required String id,
    required String name,
    required String imageUrl,
    double overlayX = 0,
    double overlayY = 1,
    double screenX = 0.025,
    double screenY = 0.95,
    double sizeX = 554,
    double sizeY = 500,
  }) {
    final safeName = _escapeXml(name);
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
      <size x="$sizeX" y="$sizeY" xunits="pixels" yunits="pixels"/>
    </ScreenOverlay>''';

    return buildKmlSkeleton(name: name, content: content);
  }

  static String buildLookAt({
    required double latitude,
    required double longitude,
    required double altitude,
    required double zoom,
    required double tilt,
    required double bearing,
  }) {
    return '''<LookAt>
  <longitude>$longitude</longitude>
  <latitude>$latitude</latitude>
  <range>$zoom</range>
  <tilt>$tilt</tilt>
  <heading>$bearing</heading>
  <gx:altitudeMode>absolute</gx:altitudeMode>
</LookAt>''';
  }

  static String buildLinearLookAt({
    required double latitude,
    required double longitude,
    required double altitude,
    required double zoom,
    required double tilt,
    required double bearing,
  }) {
    return '<LookAt>'
        '<longitude>$longitude</longitude>'
        '<latitude>$latitude</latitude>'
        '<altitude>$altitude</altitude>'
        '<range>$zoom</range>'
        '<tilt>$tilt</tilt>'
        '<heading>$bearing</heading>'
        '<gx:altitudeMode>relativeToGround</gx:altitudeMode>'
        '</LookAt>';
  }

  static String buildPlacemark({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    String? description,
    String? iconUrl,
  }) {
    final safeId = _escapeXml(id);
    final style = iconUrl == null
        ? ''
        : '''<Style id="icon-$safeId">
      <IconStyle>
        <scale>1.5</scale>
        <Icon><href>${_escapeXml(iconUrl)}</href></Icon>
      </IconStyle>
    </Style>''';
    final descriptionElement = description == null
        ? ''
        : '<description><![CDATA[${_escapeCdata(description)}]]></description>';
    final styleUrl = iconUrl == null
        ? ''
        : '<styleUrl>#icon-$safeId</styleUrl>';

    return '''$style
    <Placemark id="$safeId">
      <name>${_escapeXml(name)}</name>
      $descriptionElement
      $styleUrl
      <Point>
        <coordinates>$longitude,$latitude,0</coordinates>
      </Point>
    </Placemark>''';
  }

  static String buildOrbit({
    required double latitude,
    required double longitude,
    double range = 40000,
    double tilt = 60,
  }) {
    final lookAts = StringBuffer();
    for (var heading = 0; heading <= 360; heading += 10) {
      lookAts.write('''
      <gx:FlyTo>
        <gx:duration>1.2</gx:duration>
        <gx:flyToMode>smooth</gx:flyToMode>
        <LookAt>
          <longitude>$longitude</longitude>
          <latitude>$latitude</latitude>
          <heading>${heading.toDouble()}</heading>
          <tilt>$tilt</tilt>
          <range>$range</range>
          <gx:fovy>60</gx:fovy>
          <altitude>3341.7995674</altitude>
          <gx:altitudeMode>absolute</gx:altitudeMode>
        </LookAt>
      </gx:FlyTo>''');
    }

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml $_namespaces>
  <gx:Tour>
    <name>Orbit</name>
    <gx:Playlist>
${lookAts.toString()}
    </gx:Playlist>
  </gx:Tour>
</kml>''';
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _escapeCdata(String value) {
    return value.replaceAll(']]>', ']]]]><![CDATA[>');
  }
}
