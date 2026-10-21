import 'package:flutter_riverpod/flutter_riverpod.dart';

/// DownloadSettingsState stores the download settings page UI state
class DownloadSettingsState {
  final String engineStatus;
  final bool isTestingConnection;
  final String connectionStatus;

  DownloadSettingsState({
    this.engineStatus = 'Gopeed 2.0 (原生内核)',
    this.isTestingConnection = false,
    this.connectionStatus = '',
  });

  DownloadSettingsState copyWith({
    String? engineStatus,
    bool? isTestingConnection,
    String? connectionStatus,
  }) {
    return DownloadSettingsState(
      engineStatus: engineStatus ?? this.engineStatus,
      isTestingConnection: isTestingConnection ?? this.isTestingConnection,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }
}

/// DownloadSettingsNotifier manages the download settings page state
class DownloadSettingsNotifier extends Notifier<DownloadSettingsState> {
  @override
  DownloadSettingsState build() {
    return DownloadSettingsState();
  }

  void setEngineStatus(String status) {
    state = state.copyWith(engineStatus: status);
  }

  void setTestingConnection(bool value) {
    state = state.copyWith(isTestingConnection: value);
  }

  void setConnectionStatus(String status) {
    state = state.copyWith(connectionStatus: status);
  }
}

final downloadSettingsProvider =
    NotifierProvider<DownloadSettingsNotifier, DownloadSettingsState>(
  () => DownloadSettingsNotifier(),
);
