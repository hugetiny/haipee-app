import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/cardigann/engine/cardigann_filter_pipeline.dart';
import 'package:haipee/modules/cardigann/models/cardigann_definition.dart';

void main() {
  group('CardigannFilterPipeline Tests', () {
    test('trim and trimstrings filter', () {
      expect(
        CardigannFilterPipeline.apply(
          '   hello world   ',
          [const CardigannFilter(name: 'trim')],
        ),
        equals('hello world'),
      );

      expect(
        CardigannFilterPipeline.apply(
          '###important###',
          [const CardigannFilter(name: 'trimstrings', args: '#')],
        ),
        equals('important'),
      );
    });

    test('replace and re_replace filter', () {
      expect(
        CardigannFilterPipeline.apply(
          'foo bar baz',
          [const CardigannFilter(name: 'replace', args: ['bar', 'qux'])],
        ),
        equals('foo qux baz'),
      );

      expect(
        CardigannFilterPipeline.apply(
          'Episode 05 [1080p]',
          [
            const CardigannFilter(
              name: 're_replace',
              args: [r'\[1080p\]', 'FULL-HD'],
            )
          ],
        ),
        equals('Episode 05 FULL-HD'),
      );
    });

    test('regexp filter with extraction and group index', () {
      expect(
        CardigannFilterPipeline.apply(
          'https://example.com/details.php?id=12345',
          [const CardigannFilter(name: 'regexp', args: [r'id=(\d+)', 1])],
        ),
        equals('12345'),
      );

      expect(
        CardigannFilterPipeline.apply(
          'Size: 1.45 GB, Seeders: 20',
          [const CardigannFilter(name: 'regexp', args: [r'([\d\.]+\s+[A-Z]+)', 1])],
        ),
        equals('1.45 GB'),
      );
    });

    test('append and prepend filter', () {
      expect(
        CardigannFilterPipeline.apply(
          'base',
          [
            const CardigannFilter(name: 'prepend', args: 'pre-'),
            const CardigannFilter(name: 'append', args: '-post'),
          ],
        ),
        equals('pre-base-post'),
      );
    });

    test('split filter', () {
      expect(
        CardigannFilterPipeline.apply(
          'apple,banana,orange',
          [const CardigannFilter(name: 'split', args: [',', 1])],
        ),
        equals('banana'),
      );

      expect(
        CardigannFilterPipeline.apply(
          'part1/part2/part3',
          [const CardigannFilter(name: 'split', args: ['/', -1])],
        ),
        equals('part3'),
      );
    });

    test('querystring filter', () {
      expect(
        CardigannFilterPipeline.apply(
          '/download.php?id=999&passkey=abc',
          [const CardigannFilter(name: 'querystring', args: 'id')],
        ),
        equals('999'),
      );

      expect(
        CardigannFilterPipeline.apply(
          'id=888&type=magnet',
          [const CardigannFilter(name: 'querystring', args: 'type')],
        ),
        equals('magnet'),
      );
    });

    test('urldecode and urlencode filter', () {
      expect(
        CardigannFilterPipeline.apply(
          'hello%20world',
          [const CardigannFilter(name: 'urldecode')],
        ),
        equals('hello world'),
      );

      expect(
        CardigannFilterPipeline.apply(
          'hello world',
          [const CardigannFilter(name: 'urlencode')],
        ),
        equals('hello%20world'),
      );
    });

    test('tolower and toupper filter', () {
      expect(
        CardigannFilterPipeline.apply(
          'HeLLo',
          [const CardigannFilter(name: 'tolower')],
        ),
        equals('hello'),
      );

      expect(
        CardigannFilterPipeline.apply(
          'HeLLo',
          [const CardigannFilter(name: 'toupper')],
        ),
        equals('HELLO'),
      );
    });

    test('sub filter (numeric subtraction)', () {
      expect(
        CardigannFilterPipeline.apply(
          '10',
          [const CardigannFilter(name: 'sub', args: 3)],
        ),
        equals('7'),
      );
    });

    test('parseHumanSizeToBytes and validsize filter', () {
      expect(CardigannFilterPipeline.parseHumanSizeToBytes('1.5 GB'), equals(1610612736));
      expect(CardigannFilterPipeline.parseHumanSizeToBytes('500 MB'), equals(524288000));
      expect(CardigannFilterPipeline.parseHumanSizeToBytes('1024 KB'), equals(1048576));
      expect(CardigannFilterPipeline.parseHumanSizeToBytes('2.5 GiB'), equals(2684354560));
      expect(CardigannFilterPipeline.parseHumanSizeToBytes('5000000'), equals(5000000));

      expect(
        CardigannFilterPipeline.apply(
          '1.5 GB',
          [const CardigannFilter(name: 'parse_bytes')],
        ),
        equals('1610612736'),
      );
    });

    test('dateparse and timeago filter', () {
      final iso = CardigannFilterPipeline.parseDateString('2024-05-10 14:30:00');
      expect(iso.startsWith('2024-05-10'), isTrue);

      final rel2Hours = CardigannFilterPipeline.parseRelativeTime('2 hours ago');
      final dt = DateTime.parse(rel2Hours);
      expect(DateTime.now().difference(dt).inMinutes, greaterThanOrEqualTo(110));
      expect(DateTime.now().difference(dt).inMinutes, lessThanOrEqualTo(130));

      final chineseRel = CardigannFilterPipeline.parseRelativeTime('3天前');
      final dtCh = DateTime.parse(chineseRel);
      expect(DateTime.now().difference(dtCh).inDays, equals(3));
    });
  });
}
