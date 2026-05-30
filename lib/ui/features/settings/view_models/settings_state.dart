import '../../../../domain/models/lg_connection_settings.dart';

class SettingsState {
  const SettingsState({
    this.settings,
    this.isLoading = false,
    this.isConnected = false,
    this.errorMessage,
  });

  final LGConnectionSettings? settings;
  final bool isLoading;
  final bool isConnected;
  final String? errorMessage;

  SettingsState copyWith({
    LGConnectionSettings? settings,
    bool? isLoading,
    bool? isConnected,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
