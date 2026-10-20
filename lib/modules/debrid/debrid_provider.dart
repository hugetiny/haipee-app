/// Common interface for Cloud Debrid offload & streaming providers (Real-Debrid, TorBox, PikPak).
abstract class DebridProvider {
  /// User-friendly display name (e.g. "Real-Debrid", "TorBox", "PikPak")
  String get name;

  /// Unique identifier key for settings persistence
  String get identifier;

  /// Whether the user has configured valid API keys/tokens for this provider
  bool get isConfigured;

  /// Fast instant cache check: determines if the torrent/magnet is already cached on cloud CDN
  Future<bool> checkInstantAvailability(String infoHash);

  /// Resolves the direct HTTPS streaming link from the cached cloud torrent
  Future<String?> resolveStreamUrl(String magnetOrInfoHash, {int targetEpisode = 1});
}
