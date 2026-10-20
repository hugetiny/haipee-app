import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/aria2_process_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Aria2ProcessManager', () {
    test('generateSecureSecret returns 32-character hex string', () {
      final secret1 = Aria2ProcessManager.generateSecureSecret();
      final secret2 = Aria2ProcessManager.generateSecureSecret();

      expect(secret1.length, 32);
      expect(secret2.length, 32);
      expect(secret1, isNot(equals(secret2)));
    });

    test('findAvailablePort returns a valid positive port', () async {
      final port = await Aria2ProcessManager.findAvailablePort();
      expect(port, greaterThan(0));
      expect(port, lessThan(65536));
    });
  });
}
