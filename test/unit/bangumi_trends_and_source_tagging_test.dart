import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/card/bangumi_card.dart';
import 'package:haipee/bean/card/bangumi_info_card.dart';
import 'package:haipee/bean/card/bangumi_timeline_card.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/request/config/api_endpoints.dart';
import 'package:haipee/request/core/bangumi_transport.dart';
import 'package:haipee/services/network/bangumi_acceleration.dart';
import 'package:haipee/modules/collect/collect_module.dart';
import 'package:haipee/services/storage/storage.dart';
import 'package:haipee/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('trends_and_source_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(BangumiItemAdapter().typeId)) {
      Hive.registerAdapter(BangumiItemAdapter());
    }
    if (!Hive.isAdapterRegistered(CollectedBangumiAdapter().typeId)) {
      Hive.registerAdapter(CollectedBangumiAdapter());
    }
    GStorage.setting = await Hive.openBox('setting');
    GStorage.collectibles =
        await Hive.openBox<CollectedBangumi>('collectibles');
  });

  tearDownAll(() async {
    try {
      await GStorage.collectibles.close();
      await GStorage.setting.close();
      await Hive.close();
    } catch (_) {}
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('BangumiAccelerationInterceptor tests', () {
    test('routes trending request to mirror popular subjects when mirror is active', () async {
      await GStorage.putSetting(SettingsKeys.bangumiAcceleration, 'mirror');
      expect(BangumiAcceleration.current, BangumiAcceleration.mirror);

      final interceptor = BangumiAccelerationInterceptor();
      final options = RequestOptions(
        path: 'https://next.bgm.tv${ApiEndpoints.bangumiTrendsNext}',
      );

      final handler = _TestRequestInterceptorHandler();
      interceptor.onRequest(options, handler);

      expect(handler.handledOptions, isNotNull);
      expect(handler.handledOptions!.path,
          '${ApiEndpoints.bangumiMirrorDomain}${ApiEndpoints.bangumiMirrorPopularSubjects}');
    });

    test('preserves direct path when direct acceleration is active', () async {
      await GStorage.putSetting(SettingsKeys.bangumiAcceleration, 'direct');
      expect(BangumiAcceleration.current, BangumiAcceleration.direct);

      final interceptor = BangumiAccelerationInterceptor();
      final options = RequestOptions(
        path: 'https://next.bgm.tv${ApiEndpoints.bangumiTrendsNext}',
      );

      final handler = _TestRequestInterceptorHandler();
      interceptor.onRequest(options, handler);

      expect(handler.handledOptions, isNotNull);
      expect(handler.handledOptions!.path,
          'https://next.bgm.tv${ApiEndpoints.bangumiTrendsNext}');
    });
  });

  group('BangumiItem source & parser compatibility tests', () {
    test('BangumiItem default source is Bangumi', () {
      final item = BangumiItem(
        id: 101,
        type: 2,
        name: 'Test Anime',
        nameCn: '测试动画',
        summary: '',
        airDate: '2026-01-01',
        airWeekday: 1,
        rank: 1,
        images: {},
        tags: [],
        alias: [],
        ratingScore: 8.5,
        votes: 100,
        votesCount: [],
        info: '',
      );
      expect(item.source, 'Bangumi');
    });

    test('Parses flat subject dictionary from mirror popular response', () {
      final mirrorItemJson = {
        'id': 622288,
        'name': 'FX戦士くるみちゃん',
        'nameCN': 'FX战士久留美',
        'type': 2,
        'info': '12话 / 2026年10月1日',
        'summary': '炒汇少女的残酷青春',
        'date': '2026-10-01',
        'images': {
          'large': 'https://lain.bgm.tv/pic/cover/l/d3/99/622288_nmbC3.jpg',
        },
        'rating': {
          'rank': 5,
          'score': 8.2,
          'total': 1200,
          'count': [10, 20, 30, 40, 50, 60, 70, 80, 90, 100],
        },
      };

      final item = BangumiItem.fromJson(mirrorItemJson);
      expect(item.id, 622288);
      expect(item.name, 'FX戦士くるみちゃん');
      expect(item.nameCn, 'FX战士久留美');
      expect(item.ratingScore, 8.2);
      expect(item.source, 'Bangumi');
      expect(item.rank, 5);
    });

    test('Parses nested subject dictionary from Next API response', () {
      final nextApiJson = {
        'id': 622288,
        'name': 'Nested Anime',
        'type': 2,
        'info': '',
        'summary': '',
        'date': '2026-10-01',
        'images': {},
        'rating': {'rank': 12, 'score': 7.9, 'total': 500},
      };

      final item = BangumiItem.fromJson(nextApiJson);
      expect(item.id, 622288);
      expect(item.name, 'Nested Anime');
      expect(item.ratingScore, 7.9);
      expect(item.source, 'Bangumi');
    });
  });

  group('Card source badge UI rendering tests', () {
    final sampleItem = BangumiItem(
      id: 999,
      type: 2,
      name: 'Sample Source Anime',
      nameCn: '示例番剧',
      summary: '测试卡片源站徽章显式渲染',
      airDate: '2026-04-01',
      airWeekday: 3,
      rank: 42,
      images: {'large': ''},
      tags: [],
      alias: [],
      ratingScore: 8.7,
      votes: 888,
      votesCount: [],
      info: '全12话',
    );

    testWidgets('BangumiCardV renders Bangumi source badge by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 320,
              child: BangumiCardV(
                enableHero: false,
                bangumiItem: sampleItem,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Bangumi'), findsOneWidget);
      expect(find.text('8.7'), findsOneWidget);
    });

    testWidgets('BangumiCardV renders custom source badge when specified', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 320,
              child: BangumiCardV(
                enableHero: false,
                bangumiItem: sampleItem,
                source: '在线解析源',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('在线解析源'), findsOneWidget);
    });

    testWidgets('BangumiTimelineCard renders Bangumi source badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 140,
              child: BangumiTimelineCard(
                bangumiItem: sampleItem,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Bangumi'), findsOneWidget);
    });

    testWidgets('BangumiInfoCardV renders Bangumi source badge on poster', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 350,
                child: BangumiInfoCardV(
                  bangumiItem: sampleItem,
                  isLoading: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Bangumi'), findsWidgets);
    });
  });
}

class _TestRequestInterceptorHandler extends RequestInterceptorHandler {
  RequestOptions? handledOptions;

  @override
  void next(RequestOptions requestOptions) {
    handledOptions = requestOptions;
  }
}
