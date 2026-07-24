import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/utils/kml_builder.dart';
import '../../domain/models/lg_connection_settings.dart';

class LGRigService {
  static const String _lgBaseUrl = 'http://lg1:81';
  static const String _webRoot = '/var/www/html';
  static const String _slaveKmlDirectory = '$_webRoot/kml';
  static const String _logoUrl =
      'https://raw.githubusercontent.com/Saumya-28/lg_360_explorer/refs/heads/main/logos.png';

  // Splash screen assets
  static const String _splashTopAsset = 'assets/images/UNESCO_AboutPageTop.png';
  static const String _splashTopFileName = 'UNESCO_AboutPageTop.png';
  static const String _splashBottomAsset =
      'assets/images/AboutPage_Bottom_2.png';
  static const String _splashBottomFileName = 'AboutPage_Bottom_2.png';

  SSHClient? _client;
  SftpClient? _sftp;
  LGConnectionSettings? _connectionSettings;

  bool get isConnected => _client != null;

  LGConnectionSettings? get connectionSettings => _connectionSettings;

  Future<void> connect(LGConnectionSettings settings) async {
    await disconnect();

    SSHClient? client;
    try {
      final socket = await SSHSocket.connect(
        settings.host,
        settings.port,
        timeout: const Duration(seconds: 10),
      );
      client = SSHClient(
        socket,
        username: settings.username,
        onPasswordRequest: () => settings.password,
      );

      _client = client;
      _connectionSettings = settings;
    } catch (_) {
      client?.close();
      _client = null;
      _sftp = null;
      _connectionSettings = null;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    final client = _client;
    _client = null;
    _sftp = null;
    _connectionSettings = null;

    client?.close();
    await client?.done;
  }

  Future<void> setRefresh() async {
    final settings = _requireConnection();
    final password = settings.password;

    for (var screen = 2; screen <= settings.screens; screen++) {
      final search = '<href>##LG_PHPIFACE##kml/slave_$screen.kml</href>';
      final replace =
          '<href>##LG_PHPIFACE##kml/slave_$screen.kml</href>'
          '<refreshMode>onInterval</refreshMode>'
          '<refreshInterval>2</refreshInterval>';

      await _client!.run(
        'sshpass -p $password ssh -t lg$screen \'echo $password | sudo -S sed -i "s/$replace/$search/" ~/earth/kml/slave/myplaces.kml\'',
      );
      await _client!.run(
        'sshpass -p $password ssh -t lg$screen \'echo $password | sudo -S sed -i "s/$search/$replace/" ~/earth/kml/slave/myplaces.kml\'',
      );
    }
  }

  Future<void> resetRefresh() async {
    final settings = _requireConnection();
    final password = settings.password;

    for (var screen = 2; screen <= settings.screens; screen++) {
      final search =
          '<href>##LG_PHPIFACE##kml/slave_$screen.kml</href>'
          '<refreshMode>onInterval</refreshMode>'
          '<refreshInterval>2</refreshInterval>';
      final replace = '<href>##LG_PHPIFACE##kml/slave_$screen.kml</href>';

      await _client?.run(
        'sshpass -p $password ssh -t lg$screen \'echo $password | sudo -S sed -i "s/$search/$replace/" ~/earth/kml/slave/myplaces.kml\'',
      );
    }
  }

  Future<void> relaunch() async {
    final settings = _requireConnection();
    final password = settings.password;

    await _client!.execute(
      '"/home/${settings.username}/bin/lg-relaunch" > /home/${settings.username}/log.txt',
    );

    for (var screen = 1; screen <= settings.screens; screen++) {
      final command =
          """RELAUNCH_CMD="\\
          if [ -f /etc/init/lxdm.conf ]; then
            export SERVICE=lxdm
          elif [ -f /etc/init/lightdm.conf ]; then
            export SERVICE=lightdm
          else
            exit 1
          fi
          if  [[\\\$(service \\\$SERVICE status) =~ 'stop' ]]; then
            echo $password | sudo -S service \\\${SERVICE} start
          else
            echo $password | sudo -S service \\\${SERVICE} restart
          fi
          " && sshpass -p $password ssh -x -t lg@lg$screen "\$RELAUNCH_CMD\"""";

      await _client!.execute(command);
    }
  }

  Future<void> reboot() async {
    final settings = _requireConnection();
    final password = settings.password;

    for (var screen = settings.screens; screen >= 1; screen--) {
      await _client!.execute(
        'sshpass -p $password ssh -t lg$screen "echo $password | sudo -S reboot"',
      );
    }
  }

  Future<void> powerOff() async {
    final settings = _requireConnection();
    final password = settings.password;

    for (var screen = settings.screens; screen >= 1; screen--) {
      await _client!.execute(
        'sshpass -p $password ssh -t lg$screen "echo $password | sudo -S poweroff"',
      );
    }
  }

  Future<void> clearKml() async {
    final settings = _requireConnection();
    String query =
        'echo "exittour=true" > /tmp/query.txt && > $_webRoot/kmls.txt';

    for (var screen = 2; screen <= settings.screens; screen++) {
      final blankKml = KMLBuilder.generateBlankKml('slave_$screen');
      query += " && echo '$blankKml' > $_slaveKmlDirectory/slave_$screen.kml";
    }

    await _client?.execute(query);
  }

  Future<void> clearMaster() async {
    await _run('echo "exittour=true" > /tmp/query.txt && > $_webRoot/kmls.txt');
  }

  Future<void> clearLogoOverlay() async {
    final settings = _requireConnection();
    if (settings.screens < 2) {
      return;
    }

    await sendKmlToSlave(
      _leftmostScreen(settings.screens),
      KMLBuilder.generateBlankKml('slave_${_leftmostScreen(settings.screens)}'),
    );
  }

  Future<void> clearBalloon() async {
    final settings = _requireConnection();
    if (settings.screens < 2) {
      return;
    }

    await sendKmlToSlave(
      _rightmostScreen(settings.screens),
      KMLBuilder.generateBlankKml(
        'slave_${_rightmostScreen(settings.screens)}',
      ),
    );
  }

  /// Writes a KML file to the LG web root and registers it in kmls.txt so
  /// Google Earth auto-loads it.  Uses SSH echo (Open Buildings pattern) —
  /// no SFTP session required for text KML content.
  Future<void> sendKml(String fileName, String content) async {
    final safeFileName = _validateFileName(fileName);
    final escaped = content.replaceAll("'", "'\\'')");
    await _client!.run(
      "echo '$escaped' > $_webRoot/$safeFileName",
    );
    await _client!.run(
      'echo "$_lgBaseUrl/$safeFileName" > $_webRoot/kmls.txt',
    );
  }

  /// Writes a KML file to the LG web root without touching kmls.txt.
  /// Used for orbit / tour KML that is appended separately.
  Future<void> uploadKml(String fileName, String content) async {
    final safeFileName = _validateFileName(fileName);
    final escaped = content.replaceAll("'", "'\\'')");
    await _client!.run(
      "echo '$escaped' > $_webRoot/$safeFileName",
    );
  }

  /// Appends a KML file URL to kmls.txt (called after uploadKml for orbit).
  Future<void> appendKml(String fileName) async {
    final safeFileName = _validateFileName(fileName);
    await _client!.run(
      'echo "$_lgBaseUrl/$safeFileName" >> $_webRoot/kmls.txt',
    );
  }

  /// Writes KML directly to a slave screen file via SSH echo (Open Buildings
  /// pattern).  No SFTP session is needed; the echo command is sufficient
  /// and the file is world-readable by default under /var/www/html/kml/.
  Future<void> sendKmlToSlave(int screen, String content) async {
    final settings = _requireConnection();
    if (screen < 2 || screen > settings.screens) {
      throw ArgumentError.value(
        screen,
        'screen',
        'Must be between 2 and ${settings.screens}',
      );
    }

    final escaped = content.trim().replaceAll("'", "'\\'')");
    await _client!.run(
      "echo '$escaped' > $_slaveKmlDirectory/slave_$screen.kml",
    );
  }

  Future<void> sendKmlToLeftmostScreen(String content) async {
    final settings = _requireConnection();
    if (settings.screens < 2) {
      throw const LGLocalConnectionError(
        'At least 2 screens are required for leftmost screen rendering.',
      );
    }

    await sendKmlToSlave(_leftmostScreen(settings.screens), content);
  }

  Future<void> sendKmlToRightmostScreen(String content) async {
    final settings = _requireConnection();
    if (settings.screens < 2) {
      throw const LGLocalConnectionError(
        'At least 2 screens are required for rightmost screen rendering.',
      );
    }

    await sendKmlToSlave(_rightmostScreen(settings.screens), content);
  }

  /// Sends a splash screen to the LG leftmost slave screen.
  /// Layout mirrors the About screen:
  ///   - Top half : UNESCO_AboutPageTop.png (hero illustration)
  ///   - Bottom half : AboutPage_Bottom_2.png (all partner logos)
  Future<void> showSplashScreen() async {
    final settings = _requireConnection();
    if (settings.screens < 2) return;

    // Upload both images via SFTP
    final topAsset = await rootBundle.load(_splashTopAsset);
    await _writeRemoteFile(
      '$_webRoot/$_splashTopFileName',
      topAsset.buffer.asUint8List(
        topAsset.offsetInBytes,
        topAsset.lengthInBytes,
      ),
    );

    final bottomAsset = await rootBundle.load(_splashBottomAsset);
    await _writeRemoteFile(
      '$_webRoot/$_splashBottomFileName',
      bottomAsset.buffer.asUint8List(
        bottomAsset.offsetInBytes,
        bottomAsset.lengthInBytes,
      ),
    );

    // Build KML with two stacked ScreenOverlays
    final splashKml =
        '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2"
     xmlns:kml="http://www.opengis.net/kml/2.2"
     xmlns:atom="http://www.w3.org/2005/Atom">
<Document>
  <name>UNESCO Splash</name>
  <open>1</open>

  <!-- Top: UNESCO hero illustration (upper ~48% of screen) -->
  <ScreenOverlay id="splash_top">
    <name>Splash Top</name>
    <Icon><href>$_lgBaseUrl/$_splashTopFileName</href></Icon>
    <overlayXY x="0" y="1" xunits="fraction" yunits="fraction"/>
    <screenXY x="0" y="1" xunits="fraction" yunits="fraction"/>
    <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
    <size x="1" y="0.45" xunits="fraction" yunits="fraction"/>
  </ScreenOverlay>

  <!-- Bottom: All partner logos (lower ~48% of screen) -->
  <ScreenOverlay id="splash_bottom">
    <name>Splash Bottom</name>
    <Icon><href>$_lgBaseUrl/$_splashBottomFileName</href></Icon>
    <overlayXY x="0" y="1" xunits="fraction" yunits="fraction"/>
    <screenXY x="0" y="0.52" xunits="fraction" yunits="fraction"/>
    <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
    <size x="1" y="0.48" xunits="fraction" yunits="fraction"/>
  </ScreenOverlay>

</Document>
</kml>''';

    await sendKmlToSlave(_leftmostScreen(settings.screens), splashKml);
  }

  Future<void> showLogoOverlay() async {
    final settings = _requireConnection();
    if (settings.screens < 2) {
      return;
    }

    final double logoSizeX = settings.screens > 3 ? 998 : 554;
    final double logoSizeY = settings.screens > 3 ? 900 : 500;

    final overlay = KMLBuilder.screenOverlayImage(
      id: 'logo',
      name: 'Logo',
      imageUrl: _logoUrl,
      factor: logoSizeY / logoSizeX,
      sizeX: logoSizeX,
      sizeY: logoSizeY,
    );
    await sendKmlToSlave(_leftmostScreen(settings.screens), overlay);
  }

  Future<void> startOrbit() async {
    await _run('echo "playtour=Orbit" > /tmp/query.txt');
  }

  Future<void> stopOrbit() async {
    await _run('echo "exittour=true" > /tmp/query.txt');
  }

  Future<void> flyTo({
    required double latitude,
    required double longitude,
    required double altitude,
    required double zoom,
    required double tilt,
    required double bearing,
  }) async {
    final lookAt = KMLBuilder.buildLinearLookAt(
      lat: latitude,
      lng: longitude,
      altitude: altitude.toString(),
      range: zoom.toString(),
      tilt: tilt.toString(),
      heading: bearing.toString(),
      altitudeMode: 'relativeToGround',
    );
    await _client!.run('echo "flytoview=$lookAt" > /tmp/query.txt');
  }

  Future<void> _writeRemoteFile(String path, List<int> bytes) async {
    final sftp = await _requireSftp();
    final file = await sftp.open(
      path,
      mode:
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate |
          SftpFileOpenMode.write,
    );

    try {
      await file.write(Stream.value(Uint8List.fromList(bytes)));
    } finally {
      await file.close();
    }
  }

  Future<void> _run(String command) async {
    await _requireClient().run(command);
  }

  Future<SftpClient> _requireSftp() async {
    final existing = _sftp;
    if (existing != null) {
      return existing;
    }

    final sftp = await _requireClient().sftp();
    _sftp = sftp;
    return sftp;
  }

  SSHClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const LGLocalConnectionError('Not connected to Liquid Galaxy');
    }
    return client;
  }

  LGConnectionSettings _requireConnection() {
    final settings = _connectionSettings;
    if (settings == null) {
      throw const LGLocalConnectionError('Not connected to Liquid Galaxy');
    }
    return settings;
  }

  int _leftmostScreen(int screens) {
    final calculatedScreen = (screens / 2).floor() + 2;
    return calculatedScreen > screens ? screens : calculatedScreen;
  }

  int _rightmostScreen(int screens) {
    if (screens == 1) {
      return 1;
    }

    // Calculate right-most screen: floor(screens/2) + 1
    // Ensures balloon visibility while preserving main visualization space
    return (screens / 2).floor() + 1;
  }

  String _validateFileName(String fileName) {
    final normalized = fileName.trim();
    final isValid = RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(normalized);
    if (!isValid || normalized == '.' || normalized == '..') {
      throw ArgumentError.value(fileName, 'fileName', 'Invalid file name');
    }
    return normalized;
  }
}

class LGLocalConnectionError implements Exception {
  const LGLocalConnectionError(this.message);

  final String message;

  @override
  String toString() => message;
}
