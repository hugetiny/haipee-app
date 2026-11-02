// Bangumi mirror API credentials for the search signature flow.
// Release/PR CI injects them via --dart-define=KAZUMI_APPID / KAZUMI_KEY.
const Map<String, String> bangumiMirrorCredentials = {
  'id': String.fromEnvironment('HAIPEE_APPID', defaultValue: String.fromEnvironment('KAZUMI_APPID')), // Release/CI
  'value': String.fromEnvironment('HAIPEE_KEY', defaultValue: String.fromEnvironment('KAZUMI_KEY')), // Release/CI
};
