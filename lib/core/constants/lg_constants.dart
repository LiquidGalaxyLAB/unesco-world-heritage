/// Core constants for Liquid Galaxy operations
class LGConstants {
  // Connection defaults
  static const int defaultPort = 22;
  static const int defaultScreenCount = 5;
  static const Duration connectionTimeout = Duration(seconds: 10);

  // KML paths
  static const String kmlPath = '/var/www/html';
  static const String queryPath = '/tmp/query.txt';

  // Screen configuration
  static const int masterScreen = 3; // Middle screen in a 5-screen setup

  // KML templates
  static const String kmlHeader = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
<Document>
''';

  static const String kmlFooter = '''
</Document>
</kml>''';

  // Common KML snippets
  static String lookAt({
    required double longitude,
    required double latitude,
    required double range,
    double tilt = 0,
    double heading = 0,
  }) {
    return '''
<LookAt>
  <longitude>$longitude</longitude>
  <latitude>$latitude</latitude>
  <range>$range</range>
  <tilt>$tilt</tilt>
  <heading>$heading</heading>
  <gx:altitudeMode>relativeToGround</gx:altitudeMode>
</LookAt>''';
  }

  static String placemark({
    required String name,
    required double longitude,
    required double latitude,
    String? description,
  }) {
    return '''
<Placemark>
  <name>$name</name>
  ${description != null ? '<description>$description</description>' : ''}
  <Point>
    <coordinates>$longitude,$latitude,0</coordinates>
  </Point>
</Placemark>''';
  }
}
