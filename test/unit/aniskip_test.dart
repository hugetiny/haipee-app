import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:haipee/modules/playback/aniskip_model.dart';
import 'package:haipee/modules/playback/aniskip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AniSkipInterval Model Tests', () {
    test('fromJson and toJson roundtrip accurately', () {
      final json = {
        'interval': {
          'startTime': 90.5,
          'endTime': 180.0,
        },
        'skipType': 'op',
        'skipId': 'skip-123',
        'episodeLength': 1420.0,
      };

      final interval = AniSkipInterval.fromJson(json);

      expect(interval.startTime, equals(90.5));
      expect(interval.endTime, equals(180.0));
      expect(interval.skipType, equals('op'));
      expect(interval.isOp, isTrue);
      expect(interval.isEd, isFalse);
      expect(interval.typeLabel, equals('片头 (OP)'));
      expect(interval.skipId, equals('skip-123'));
      expect(interval.episodeLength, equals(1420.0));

      final serialized = interval.toJson();
      expect(serialized['interval']['startTime'], equals(90.5));
      expect(serialized['interval']['endTime'], equals(180.0));
      expect(serialized['skipType'], equals('op'));
    });

    test('contains and containsSeconds boundary checks', () {
      const interval = AniSkipInterval(
        startTime: 60.0,
        endTime: 150.0,
        skipType: 'ed',
      );

      expect(interval.containsSeconds(59.9), isFalse);
      expect(interval.containsSeconds(60.0), isTrue);
      expect(interval.containsSeconds(100.0), isTrue);
      expect(interval.containsSeconds(150.0), isTrue);
      expect(interval.containsSeconds(150.1), isFalse);

      expect(interval.contains(const Duration(seconds: 100)), isTrue);
      expect(interval.contains(const Duration(seconds: 50)), isFalse);
    });

    test('typeLabel resolves correctly for ed and recap', () {
      const edInterval = AniSkipInterval(startTime: 1200, endTime: 1290, skipType: 'ed');
      expect(edInterval.isEd, isTrue);
      expect(edInterval.typeLabel, equals('片尾 (ED)'));

      const recapInterval = AniSkipInterval(startTime: 0, endTime: 60, skipType: 'recap');
      expect(recapInterval.isRecap, isTrue);
      expect(recapInterval.typeLabel, equals('前情回顾 (Recap)'));
    });
  });

  group('AniSkipService Tests', () {
    late AniSkipService service;

    setUp(() {
      AniSkipService.clearCache();
      service = AniSkipService.instance;
    });

    tearDown(() {
      AniSkipService.clearCache();
    });

    test('seedMalId and getMalIdFromBangumiId retrieves from memory cache', () async {
      AniSkipService.seedMalId(253, 5114);

      final malId = await service.getMalIdFromBangumiId(253);
      expect(malId, equals(5114));
    });

    test('seedIntervals and getSkipTimes retrieves from memory cache', () async {
      const sampleIntervals = [
        AniSkipInterval(startTime: 85.0, endTime: 175.0, skipType: 'op'),
        AniSkipInterval(startTime: 1300.0, endTime: 1390.0, skipType: 'ed'),
      ];

      AniSkipService.seedIntervals(5114, 1, sampleIntervals);

      final times = await service.getSkipTimes(malId: 5114, episode: 1);
      expect(times.length, equals(2));
      expect(times[0].startTime, equals(85.0));
      expect(times[0].isOp, isTrue);
      expect(times[1].startTime, equals(1300.0));
      expect(times[1].isEd, isTrue);
    });

    test('mocked Dio client resolves MALSync and AniSkip endpoints', () async {
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.path.contains('/bangumi/anime/99999')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'id': 12345,
                    'malId': 54321,
                  },
                ),
              );
            }
            if (options.uri.path.contains('/skip-times/54321/1')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'found': true,
                    'results': [
                      {
                        'interval': {'startTime': 90.0, 'endTime': 180.0},
                        'skipType': 'op',
                      },
                    ],
                  },
                ),
              );
            }
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'Not Found',
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

      final testService = AniSkipService.forTesting(dio: mockDio);

      final resolvedMalId = await testService.getMalIdFromBangumiId(99999);
      expect(resolvedMalId, equals(54321));

      final intervals = await testService.getSkipTimes(
        malId: 54321,
        episode: 1,
      );
      expect(intervals.length, equals(1));
      expect(intervals.first.startTime, equals(90.0));
      expect(intervals.first.endTime, equals(180.0));
      expect(intervals.first.isOp, isTrue);
    });
  });
}
