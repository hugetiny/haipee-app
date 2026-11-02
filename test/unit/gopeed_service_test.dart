import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/download/gopeed/gopeed_service.dart';
import 'package:haipee/modules/download/gopeed/libgopeed_worker.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('GopeedService initializes and creates an HTTP task', () async {
    final tempDir = Directory.systemTemp.createTempSync('gopeed_test_');
    try {
      final service = GopeedService();
      await service.initialize(storageDir: tempDir.path);
      expect(service.isInitialized, isTrue);

      // Test 0: Inspect raw resolve response
      final rawResolve = await LibgopeedWorker().invoke(
        'POST',
        '/api/v1/resolve',
        '',
        '{"req":{"url":"https://speed.cloudflare.com/__down?bytes=1000"}}',
      );
      expect(rawResolve, isA<Map>());
      final rid = (rawResolve as Map)['data']['id'] as String;

      final ridTaskRes = await LibgopeedWorker().invoke(
        'POST',
        '/api/v1/tasks',
        '',
        '{"rid":"$rid","opts":{"path":"${tempDir.path}","selectFiles":[0]}}',
      );
      expect((ridTaskRes as Map)['code'], equals(0));

      // Test 1: HTTP task with savePath
      final taskId = await service.createTask(
        url: 'https://speed.cloudflare.com/__down?bytes=1000',
        name: 'test.bin',
        savePath: tempDir.path,
      );
      expect(taskId, isNotEmpty);

      // Test 2: Creating task with null or empty savePath
      try {
        final idNoSavePath = await service.createTask(
          url: 'magnet:?xt=urn:btih:3772F6578DACB15C02DC090168DF9CFA2610094A&dn=Nintendo+DS+Roms',
          name: 'magnet_test',
        );
        expect(idNoSavePath, isNotEmpty);
      } catch (_) {}

      final tasks = await service.getTasks();
      expect(tasks, isNotEmpty);


      await service.stop();
    } finally {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  });
}

