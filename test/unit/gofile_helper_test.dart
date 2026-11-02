import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/download/gofile_helper.dart';

void main() {
  group('GofileHelper', () {
    final helper = GofileHelper();

    test('should correctly identify gofile URLs', () {
      expect(helper.isGofileUrl('https://gofile.io/d/2e3f4aac-b07d-4a79-9ff7-f3128c5580b5'), isTrue);
      expect(helper.isGofileUrl('https://store8.gofile.io/download/web/2e3f4aac-b07d-4a79-9ff7-f3128c5580b5/test.rar'), isTrue);
      expect(helper.isGofileUrl('https://example.com/file.mp4'), isFalse);
    });

    test('should extract content ID from various gofile URL formats', () {
      expect(
        helper.extractContentId('https://gofile.io/d/2e3f4aac-b07d-4a79-9ff7-f3128c5580b5'),
        equals('2e3f4aac-b07d-4a79-9ff7-f3128c5580b5'),
      );
      expect(
        helper.extractContentId('https://store8.gofile.io/download/web/2e3f4aac-b07d-4a79-9ff7-f3128c5580b5/Romance.part7.rar'),
        equals('2e3f4aac-b07d-4a79-9ff7-f3128c5580b5'),
      );
    });
  });
}
