import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/notification/notification_service.dart';

class MockNotificationService extends NotificationService {
  final List<Map<String, dynamic>> recordedCalls = [];

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? subtitle,
    String? payload,
  }) async {
    recordedCalls.add({
      'id': id,
      'title': title,
      'body': body,
      'subtitle': subtitle,
      'payload': payload,
    });
  }

  @override
  Future<bool> requestPermission() async {
    return true;
  }
}

void main() {
  group('NotificationService Tests', () {
    late MockNotificationService mockService;

    setUp(() {
      mockService = MockNotificationService();
      NotificationService.setMockInstance(mockService);
    });

    tearDown(() {
      NotificationService.setMockInstance(null);
    });

    test('verifies default channels configuration', () {
      expect(NotificationService.downloadChannelId, 'kazumi_downloads');
      expect(NotificationService.downloadChannelName, '下载通知');
      expect(NotificationService.streamChannelId, 'kazumi_stream');
      expect(NotificationService.streamChannelName, '媒体流通知');
    });

    test('showDownloadCompleted formats body with savePath and dispatches', () async {
      await NotificationService.instance.showDownloadCompleted(
        taskName: 'Cyberpunk 2077 OST.flac',
        savePath: '/Volumes/HD/downloads/Cyberpunk 2077 OST.flac',
      );

      expect(mockService.recordedCalls.length, 1);
      final call = mockService.recordedCalls.first;
      expect(call['title'], '下载完成');
      expect(call['subtitle'], 'Cyberpunk 2077 OST.flac');
      expect(call['body'], contains('/Volumes/HD/downloads/Cyberpunk 2077 OST.flac'));
      expect(call['payload'], '/Volumes/HD/downloads/Cyberpunk 2077 OST.flac');
    });

    test('showDownloadCompleted handles empty or null savePath gracefully', () async {
      await NotificationService.instance.showDownloadCompleted(
        taskName: 'Ubuntu 24.04 ISO',
      );

      expect(mockService.recordedCalls.length, 1);
      final call = mockService.recordedCalls.first;
      expect(call['title'], '下载完成');
      expect(call['subtitle'], 'Ubuntu 24.04 ISO');
      expect(call['body'], contains('全部文件已下载完成并已就绪'));
    });

    test('showStreamReady formats title and body correctly', () async {
      await NotificationService.instance.showStreamReady(
        title: 'Sousou no Frieren Episode 01.mkv',
        id: 42,
      );

      expect(mockService.recordedCalls.length, 1);
      final call = mockService.recordedCalls.first;
      expect(call['id'], 42);
      expect(call['title'], '媒体流就绪');
      expect(call['subtitle'], 'Sousou no Frieren Episode 01.mkv');
      expect(call['body'], contains('已缓冲足够数据'));
    });

    test('requestPermission returns true for mock service', () async {
      final granted = await NotificationService.instance.requestPermission();
      expect(granted, isTrue);
    });
  });
}
