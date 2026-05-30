class LGConnectionSettings {
  const LGConnectionSettings({
    required this.host,
    required this.username,
    required this.password,
    required this.port,
    required this.screens,
  });

  final String host;
  final String username;
  final String password;
  final int port;
  final int screens;

  LGConnectionSettings copyWith({
    String? host,
    String? username,
    String? password,
    int? port,
    int? screens,
  }) {
    return LGConnectionSettings(
      host: host ?? this.host,
      username: username ?? this.username,
      password: password ?? this.password,
      port: port ?? this.port,
      screens: screens ?? this.screens,
    );
  }
}
