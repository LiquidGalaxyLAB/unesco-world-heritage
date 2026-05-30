import 'package:shared_preferences/shared_preferences.dart';

class SettingsStorageService {
  static const String hostKey = 'lg_host';
  static const String portKey = 'lg_port';
  static const String usernameKey = 'lg_username';
  static const String passwordKey = 'lg_password';
  static const String screensKey = 'lg_screens';

  Future<void> save({
    required String host,
    required String username,
    required String password,
    required int port,
    required int screens,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(hostKey, host);
    await prefs.setString(usernameKey, username);
    await prefs.setString(passwordKey, password);
    await prefs.setInt(portKey, port);
    await prefs.setInt(screensKey, screens);
  }

  Future<Map<String, Object>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(hostKey);
    final username = prefs.getString(usernameKey);
    final password = prefs.getString(passwordKey);
    final port = prefs.getInt(portKey);
    final screens = prefs.getInt(screensKey);

    if (host == null ||
        username == null ||
        password == null ||
        port == null ||
        screens == null) {
      return null;
    }

    return <String, Object>{
      hostKey: host,
      usernameKey: username,
      passwordKey: password,
      portKey: port,
      screensKey: screens,
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(hostKey);
    await prefs.remove(usernameKey);
    await prefs.remove(passwordKey);
    await prefs.remove(portKey);
    await prefs.remove(screensKey);
  }
}
