import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/kml_builder.dart';
import '../../domain/models/lg_connection_settings.dart';

class LGRigService {
  static const String _lgBaseUrl = 'http://lg1:81';
  static const String _webRoot = '/var/www/html';
  static const String _slaveKmlDirectory = '$_webRoot/kml';
  static const String _logoAssetPath = 'assets/images/logos.png';
  static const String _logoFileName = 'logos.png';

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

      await setRefresh();
      await _clearSlaveScreens();
      await _showLogoOverlay();
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
    final password = _shellQuote(settings.password);

    for (var screen = 2; screen <= settings.screens; screen++) {
      final href = '<href>##LG_PHPIFACE##kml\\/slave_$screen.kml<\\/href>';
      final refreshedHref =
          '$href<refreshMode>onInterval<\\/refreshMode>'
          '<refreshInterval>2<\\/refreshInterval>';
      final remoteCommand =
          'echo $password | sudo -S sed -i '
          '"s/$refreshedHref/$href/; s/$href/$refreshedHref/" '
          '~/earth/kml/slave/myplaces.kml';

      await _run(
        'sshpass -p $password ssh -t lg$screen '
        '${_shellQuote(remoteCommand)}',
      );
    }
  }

  Future<void> resetRefresh() async {
    final settings = _requireConnection();
    final password = _shellQuote(settings.password);

    for (var screen = 2; screen <= settings.screens; screen++) {
      final href = '<href>##LG_PHPIFACE##kml\\/slave_$screen.kml<\\/href>';
      final refreshedHref =
          '$href<refreshMode>onInterval<\\/refreshMode>'
          '<refreshInterval>2<\\/refreshInterval>';
      final remoteCommand =
          'echo $password | sudo -S sed -i '
          '"s/$refreshedHref/$href/" '
          '~/earth/kml/slave/myplaces.kml';

      await _run(
        'sshpass -p $password ssh -t lg$screen '
        '${_shellQuote(remoteCommand)}',
      );
    }
  }

  Future<void> relaunch() async {
    final settings = _requireConnection();
    final password = _shellQuote(settings.password);

    await _run(
      '${_shellQuote('/home/${settings.username}/bin/lg-relaunch')} '
      '> ${_shellQuote('/home/${settings.username}/log.txt')} 2>&1',
    );

    for (var screen = 1; screen <= settings.screens; screen++) {
      final remoteCommand =
          '''
if [ -f /etc/init/lxdm.conf ]; then
  SERVICE=lxdm
elif [ -f /etc/init/lightdm.conf ]; then
  SERVICE=lightdm
else
  exit 1
fi
if service "\$SERVICE" status 2>&1 | grep -q stop; then
  echo $password | sudo -S service "\$SERVICE" start
else
  echo $password | sudo -S service "\$SERVICE" restart
fi''';

      await _run(
        'sshpass -p $password ssh -x -t lg@lg$screen '
        '${_shellQuote(remoteCommand)}',
      );
    }
  }

  Future<void> reboot() async {
    final settings = _requireConnection();
    final password = _shellQuote(settings.password);

    for (var screen = settings.screens; screen >= 1; screen--) {
      final remoteCommand = 'echo $password | sudo -S reboot';
      await _run(
        'sshpass -p $password ssh -t lg$screen '
        '${_shellQuote(remoteCommand)}',
      );
    }
  }

  Future<void> powerOff() async {
    final settings = _requireConnection();
    final password = _shellQuote(settings.password);

    for (var screen = settings.screens; screen >= 1; screen--) {
      final remoteCommand = 'echo $password | sudo -S poweroff';
      await _run(
        'sshpass -p $password ssh -t lg$screen '
        '${_shellQuote(remoteCommand)}',
      );
    }
  }

  Future<void> clearKml() async {
    await _run(
      'echo "exittour=true" > /tmp/query.txt && '
      ': > $_webRoot/kmls.txt',
    );
  }

  Future<void> clearKmlAndLogos() async {
    await clearKml();
    await _clearSlaveScreens();
  }

  Future<void> sendKml(String fileName, String content) async {
    final safeFileName = _validateFileName(fileName);
    await _writeRemoteFile('$_webRoot/$safeFileName', utf8.encode(content));
    await _run(
      'printf "%s\\n" ${_shellQuote('$_lgBaseUrl/$safeFileName')} '
      '> $_webRoot/kmls.txt',
    );
  }

  Future<void> appendKml(String fileName) async {
    final safeFileName = _validateFileName(fileName);
    await _run(
      'printf "%s\\n" ${_shellQuote('$_lgBaseUrl/$safeFileName')} '
      '>> $_webRoot/kmls.txt',
    );
  }

  Future<void> sendKmlToSlave(int screen, String content) async {
    final settings = _requireConnection();
    if (screen < 2 || screen > settings.screens) {
      throw ArgumentError.value(
        screen,
        'screen',
        'Must be between 2 and ${settings.screens}',
      );
    }

    await _ensureSlaveKmlDirectory();
    await _writeRemoteFile(
      '$_slaveKmlDirectory/slave_$screen.kml',
      utf8.encode(content.trim()),
    );
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
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      zoom: zoom,
      tilt: tilt,
      bearing: bearing,
    );
    await _run(
      'printf "%s\\n" ${_shellQuote('flytoview=$lookAt')} '
      '> /tmp/query.txt',
    );
  }

  Future<void> _showLogoOverlay() async {
    final settings = _requireConnection();
    if (settings.screens < 2) {
      return;
    }

    final asset = await rootBundle.load(_logoAssetPath);
    final bytes = asset.buffer.asUint8List(
      asset.offsetInBytes,
      asset.lengthInBytes,
    );
    await _writeRemoteFile('$_webRoot/$_logoFileName', bytes);

    final overlay = KMLBuilder.buildScreenOverlay(
      id: 'unesco_logo',
      name: 'UNESCO World Heritage',
      imageUrl: '$_lgBaseUrl/$_logoFileName',
    );
    await sendKmlToSlave(_leftmostScreen(settings.screens), overlay);
  }

  Future<void> _clearSlaveScreens() async {
    final settings = _requireConnection();
    if (settings.screens < 2) {
      return;
    }

    await _ensureSlaveKmlDirectory();
    for (var screen = 2; screen <= settings.screens; screen++) {
      await _writeRemoteFile(
        '$_slaveKmlDirectory/slave_$screen.kml',
        utf8.encode(KMLBuilder.buildBlank('slave_$screen')),
      );
    }
  }

  Future<void> _ensureSlaveKmlDirectory() async {
    await _run('mkdir -p $_slaveKmlDirectory');
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

  String _validateFileName(String fileName) {
    final normalized = fileName.trim();
    final isValid = RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(normalized);
    if (!isValid || normalized == '.' || normalized == '..') {
      throw ArgumentError.value(fileName, 'fileName', 'Invalid file name');
    }
    return normalized;
  }

  String _shellQuote(String value) {
    return "'${value.replaceAll("'", r"'\''")}'";
  }
}

class LGLocalConnectionError implements Exception {
  const LGLocalConnectionError(this.message);

  final String message;

  @override
  String toString() => message;
}
