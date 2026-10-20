import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/bean/card/bangumi_timeline_card.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/storage.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('timeline_test');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('setting');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  final sampleItemWithLongText = BangumiItem(
    id: 12345,
    type: 2,
    name: 'Sousou no Frieren Season 2 Part 2 Extra Edition',
    nameCn: '葬送的芙莉莲 第二季 勇者欣梅尔的回忆与北方诸国旅途篇 剧场先行版',
    summary:
        '这是魔王被打倒之后的世界。千年精灵芙莉莲与新伙伴们继续踏上前往灵魂长眠之地的漫长旅途。旅途中他们遇到了许多新的人和事，重新回忆起当年的冒险。经历各种艰难险阻，探索未知的魔法奥秘。',
    airDate: '2024-01-05',
    airWeekday: 5,
    rank: 1,
    images: {'large': ''},
    tags: [],
    alias: [],
    ratingScore: 9.3,
    votes: 45210,
    votesCount: [],
    info: '全28话 / 2024年1月 / Madhouse',
  );

  final sampleItemWithoutSummary = BangumiItem(
    id: 12346,
    type: 2,
    name: 'Short Title Anime',
    nameCn: '短标题动画',
    summary: '',
    airDate: '2024-01-05',
    airWeekday: 5,
    rank: 10,
    images: {'large': ''},
    tags: [],
    alias: [],
    ratingScore: 8.0,
    votes: 120,
    votesCount: [],
    info: '',
  );

  const testViewports = [
    Size(360, 640),
    Size(600, 800),
    Size(800, 600),
    Size(1280, 860),
    Size(1920, 1080),
  ];

  for (final vp in testViewports) {
    testWidgets(
      'BangumiTimelineCard 在视口 ${vp.width.toInt()}x${vp.height.toInt()} 下多种卡片高度与超大字体均不溢出',
      (tester) async {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        for (final height in [120.0, 135.0, 150.0]) {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: vp,
                  textScaler: const TextScaler.linear(1.2),
                ),
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: vp.width > 600 ? 400 : vp.width - 24,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BangumiTimelineCard(
                            bangumiItem: sampleItemWithLongText,
                            cardHeight: height,
                          ),
                          BangumiTimelineCard(
                            bangumiItem: sampleItemWithoutSummary,
                            cardHeight: height,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
