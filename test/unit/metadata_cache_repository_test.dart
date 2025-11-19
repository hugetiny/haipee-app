import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:kazumi/db/database.dart';
import 'package:kazumi/modules/metadata_sync/metadata_cache_repository.dart';
import 'package:kazumi/modules/metadata_sync/models/metadata_record.dart';
import 'package:kazumi/request/metadata_client.dart';
import 'package:kazumi/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockBox<MetadataRecord> metadataBox;
  late MockBox<dynamic> settingsBox;
  late DateTime now;

  setUpAll(() async {
    final db = AppDatabase(NativeDatabase.memory());
    GStorage.db = db;
  });

  tearDownAll(() async {
    await GStorage.db.close();
  });

  setUp(() async {
    metadataBox = MockBox('metadataCacheRepoTest', GStorage.db);
    settingsBox = MockBox('settingsRepoTest', GStorage.db);
    now = DateTime(2025, 1, 1, 8, 0, 0);
  });

  tearDown(() async {
    await metadataBox.clear();
    await settingsBox.clear();
  });

  MetadataCacheRepository buildRepository() {
    return MetadataCacheRepository(
      metadataBox: metadataBox,
      settingBox: settingsBox,
      clock: () => now,
    );
  }

  group('MetadataCacheRepository', () {
    test('purges expired entries when accessing records', () async {
      await settingsBox.put(SettingBoxKey.metadataRetentionHours, 1);
      final MetadataCacheRepository repository = buildRepository();

      final MetadataRecord staleRecord = MetadataRecord(
        slug: 'stale',
        primaryTitle: 'Old Title',
        localeTag: 'zh-CN',
        updatedAt: now.subtract(const Duration(hours: 2)),
      );
      await metadataBox.put('stale', staleRecord);

      expect(repository.getRecord('stale'), isNull);
      expect(metadataBox.containsKey('stale'), isFalse);
    });

    test('upsert merges identifiers, titles, episodes and snapshots', () async {
      await settingsBox.put(SettingBoxKey.metadataRetentionHours, 24);
      final MetadataCacheRepository repository = buildRepository();

      final MetadataFetchResult tmdbResult = MetadataFetchResult(
        source: MetadataSourceKind.tmdb,
        locale: const ui.Locale('en', 'US'),
        payload: <String, dynamic>{
          'name': 'BOCCHI THE ROCK!',
          'original_name': 'ぼっち・ざ・ろっく！',
          'overview': 'Band practice begins.',
          'poster_path': '/poster.jpg',
          'backdrop_path': '/backdrop.jpg',
          'seasons': <Map<String, dynamic>>[
            <String, dynamic>{
              'episodes': <Map<String, dynamic>>[
                <String, dynamic>{
                  'episode_number': 1,
                  'name': 'Episode 1',
                  'overview': 'Debut showcase',
                  'still_path': '/still1.jpg',
                },
                <String, dynamic>{
                  'episode_number': 2,
                  'name': 'Episode 2',
                  'overview': 'Second act',
                  'still_path': '/still2.jpg',
                },
              ],
            },
          ],
        },
      );

      await repository.upsert(
        slug: 'kessoku-band',
        result: tmdbResult,
        identifiers: <String, String>{'tmdb': '42'},
      );

      now = now.add(const Duration(hours: 1));

      final MetadataFetchResult bangumiResult = MetadataFetchResult(
        source: MetadataSourceKind.bangumi,
        locale: const ui.Locale('zh', 'CN'),
        payload: <String, dynamic>{
          'name_cn': '孤独摇滚',
          'name': 'ぼっち・ざ・ろっく！',
          'summary': '文化祭舞台演出',
          'images': <String, dynamic>{
            'common': 'https://bangumi.test/common.jpg',
          },
          'eps': <Map<String, dynamic>>[
            <String, dynamic>{
              'sort': 2,
              'name': '文化祭',
              'desc': '文化祭演出',
              'airdate': '2024-10-10',
            },
          ],
        },
      );

      final MetadataRecord merged = await repository.upsert(
        slug: 'kessoku-band',
        result: bangumiResult,
        identifiers: <String, String>{'bangumi': '123'},
      );

      expect(merged.primaryTitle, '孤独摇滚');
      expect(merged.alternateTitles['ja'], 'ぼっち・ざ・ろっく！');
      expect(merged.synopsis['zh-CN'], '文化祭舞台演出');
      expect(merged.posterUrl, 'https://bangumi.test/common.jpg');
      expect(merged.identifiers, containsPair('tmdb', '42'));
      expect(merged.identifiers, containsPair('bangumi', '123'));
      expect(merged.episodes.length, 2);
      expect(merged.episodes.last.number, 2);
      expect(merged.episodes.last.title, '文化祭');
      expect(merged.sourceSnapshots.length, 2);
      expect(
        merged.sourceSnapshots.map((snapshot) => snapshot.sourceId).toSet(),
        containsAll(<String>['tmdb', 'bangumi']),
      );
      expect(merged.activeSource, MetadataSourceKind.bangumi.name);
    });

    test('purgeExpired removes entries older than retention window', () async {
      await settingsBox.put(SettingBoxKey.metadataRetentionHours, 2);
      final MetadataCacheRepository repository = buildRepository();

      final MetadataRecord fresh = MetadataRecord(
        slug: 'fresh',
        primaryTitle: 'Fresh Title',
        localeTag: 'en-US',
        updatedAt: now.subtract(const Duration(hours: 1)),
      );
      final MetadataRecord expired = MetadataRecord(
        slug: 'expired',
        primaryTitle: 'Expired Title',
        localeTag: 'en-US',
        updatedAt: now.subtract(const Duration(hours: 3)),
      );

      await metadataBox.put('fresh', fresh);
      await metadataBox.put('expired', expired);

      await repository.purgeExpired();

      expect(metadataBox.containsKey('fresh'), isTrue);
      expect(metadataBox.containsKey('expired'), isFalse);
    });
  });
}
