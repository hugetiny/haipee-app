class PlayerErrorMapper {
  const PlayerErrorMapper._();

  static String? toActionableMessage(
    Object error, {
    required bool isBuffering,
  }) {
    final message = error.toString();
    if (message.contains('Failed to recognize file format') ||
        (isBuffering && message.contains('Failed to open'))) {
      return '加载失败, 请尝试更换其他视频来源';
    }
    return null;
  }

  /// Whether the error is a benign or transient network IO / chunk-read drop
  /// (e.g. ad segment disconnects or HTTP keep-alive timeouts in HLS) that
  /// libmpv/ffmpeg handles or retries internally.
  static bool isTransientNetworkError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('ffurl_read') ||
        message.contains('ffurl_connect') ||
        message.contains('0xdfb9b0bb') ||
        message.contains('connection reset') ||
        message.contains('broken pipe') ||
        message.contains('connection refused') ||
        message.contains('end of file') ||
        message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('network is unreachable') ||
        message.contains('no route to host') ||
        message.contains('server returned 404') ||
        message.contains('server returned 403') ||
        message.contains('server returned 5') ||
        message.contains('input/output error') ||
        message.contains('io error') ||
        message.contains('resource temporarily unavailable');
  }
}
