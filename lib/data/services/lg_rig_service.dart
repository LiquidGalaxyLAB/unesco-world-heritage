import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../../domain/models/lg_connection_settings.dart';

class LGRigService {
  SSHClient? _client;
  SftpClient? _sftp;
  LGConnectionSettings? _connectionSettings;

  bool get isConnected => _client != null;

  LGConnectionSettings? get connectionSettings => _connectionSettings;

  Future<void> connect(LGConnectionSettings settings) async {
    await disconnect();

    final socket = await SSHSocket.connect(
      settings.host,
      settings.port,
      timeout: const Duration(seconds: 10),
    );

    _client = SSHClient(
      socket,
      username: settings.username,
      onPasswordRequest: () => settings.password,
    );
    _sftp = await _client!.sftp();
    _connectionSettings = settings;
  }

  Future<void> disconnect() async {
    _sftp = null;
    _connectionSettings = null;
    _client?.close();
    await _client?.done;
    _client = null;
  }

  Future<void> relaunch() async {
    await _runFireAndForget('lg-relaunch');
  }

  Future<void> reboot() async {
    final settings = _requireConnection();
    for (var screen = settings.screens; screen >= 1; screen--) {
      await _runFireAndForget(
        'sshpass -p ${_shellQuote(settings.password)} '
        'ssh -t lg$screen '
        '"echo ${_shellQuote(settings.password)} | sudo -S reboot"',
      );
    }
  }

  Future<void> powerOff() async {
    final settings = _requireConnection();
    for (var screen = settings.screens; screen >= 1; screen--) {
      await _runFireAndForget(
        'sshpass -p ${_shellQuote(settings.password)} '
        'ssh -t lg$screen '
        '"echo ${_shellQuote(settings.password)} | sudo -S poweroff"',
      );
    }
  }

  Future<void> clearKml() async {
    await _uploadKml(fileName: 'clear_kml.kml', content: _emptyKml);
    await _runFireAndForget('echo "" > /tmp/query.txt');
    await _runFireAndForget('rm -f /var/www/html/kmls.txt');
  }

  Future<void> clearKmlAndLogos() async {
    await clearKml();
    await _clearSlaveScreens();
    await _runFireAndForget('rm -f /var/www/html/*.kml');
    await _runFireAndForget('rm -f /var/www/html/kml/*.kml');
  }

  Future<void> _clearSlaveScreens() async {
    final settings = _requireConnection();
    for (var screen = 1; screen <= settings.screens; screen++) {
      await _sendKmlToSlave(screen, _emptyKml);
    }
  }

  Future<void> _uploadKml({
    required String fileName,
    required String content,
  }) async {
    final sftp = _requireSftp();
    final remoteFile = await sftp.open(
      '/var/www/html/$fileName',
      mode:
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate |
          SftpFileOpenMode.write,
    );

    final bytes = Uint8List.fromList(utf8.encode(content));
    await remoteFile.write(Stream.value(bytes));
    await remoteFile.close();

    await _runFireAndForget(
      'echo "http://lg1:81/$fileName" > /var/www/html/kmls.txt',
    );
  }

  Future<void> _sendKmlToSlave(int screen, String content) async {
    final sftp = _requireSftp();

    try {
      await sftp.mkdir('/var/www/html/kml');
    } catch (_) {
      // Directory may already exist.
    }

    final remoteFile = await sftp.open(
      '/var/www/html/kml/slave_$screen.kml',
      mode:
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate |
          SftpFileOpenMode.write,
    );

    final bytes = Uint8List.fromList(utf8.encode(content));
    await remoteFile.write(Stream.value(bytes));
    await remoteFile.close();
  }

  Future<void> _runFireAndForget(String command) async {
    final client = _requireClient();
    final session = await client.execute(command);
    await session.done;
  }

  LGLocalConnectionError _notConnected() {
    return const LGLocalConnectionError('Not connected to Liquid Galaxy');
  }

  SSHClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw _notConnected();
    }
    return client;
  }

  SftpClient _requireSftp() {
    final sftp = _sftp;
    if (sftp == null) {
      throw _notConnected();
    }
    return sftp;
  }

  LGConnectionSettings _requireConnection() {
    final settings = _connectionSettings;
    if (settings == null) {
      throw _notConnected();
    }
    return settings;
  }

  String _shellQuote(String value) {
    return "'${value.replaceAll("'", r"'\''")}'";
  }

  static const String _emptyKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
  </Document>
</kml>''';
}

class LGLocalConnectionError implements Exception {
  const LGLocalConnectionError(this.message);

  final String message;

  @override
  String toString() => message;
}
