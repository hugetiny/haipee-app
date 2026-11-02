import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/utils/platform_guard.dart';

void main() {
  group('PlatformGuard', () {
    test('desktop platforms support downloads and torrents', () {
      final guard = PlatformGuard(
        descriptor: PlatformDescriptor.forValues(
          isWeb: false,
          platform: TargetPlatform.windows,
        ),
      );

      expect(guard.downloadQueueSupport.isSupported, isTrue);
      expect(guard.torrentSupport.isSupported, isTrue);
      expect(guard.anime4kSupport.isSupported, isTrue);
    });

    test('android supports downloads but requires fallback for Anime4K', () {
      final guard = PlatformGuard(
        descriptor: PlatformDescriptor.forValues(
          isWeb: false,
          platform: TargetPlatform.android,
        ),
      );

      expect(guard.downloadQueueSupport.isSupported, isTrue);
      expect(guard.torrentSupport.isSupported, isTrue);
      expect(guard.anime4kSupport.isSupported, isFalse);
      expect(
        guard.anime4kSupport.reason,
        contains('Windows or Linux'),
      );
    });

    test('web build disables downloads and torrents', () {
      final guard = PlatformGuard(
        descriptor: PlatformDescriptor.forValues(
          isWeb: true,
          platform: TargetPlatform.android,
        ),
      );

      expect(guard.downloadQueueSupport.isSupported, isFalse);
      expect(
        guard.downloadQueueSupport.reason,
        contains('web builds'),
      );
      expect(guard.torrentSupport.isSupported, isFalse);
      expect(
        guard.torrentSupport.reason,
        contains('web builds'),
      );
    });

    test('iOS disables torrent/download queue integration', () {
      final guard = PlatformGuard(
        descriptor: PlatformDescriptor.forValues(
          isWeb: false,
          platform: TargetPlatform.iOS,
        ),
      );

      expect(guard.downloadQueueSupport.isSupported, isFalse);
      expect(guard.torrentSupport.isSupported, isFalse);
      expect(
        guard.torrentSupport.reason,
        contains('disabled on this platform'),
      );
    });
  });
}
