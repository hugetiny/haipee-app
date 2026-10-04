import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/metadata_sync/metadata_cache_repository.dart';
import 'package:kazumi/modules/metadata_sync/metadata_sync_controller.dart';
import 'package:kazumi/modules/metadata_sync/models/metadata_record.dart';
import 'package:kazumi/request/metadata_client.dart';
import 'package:kazumi/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<dynamic> metadataBox;
  late Box<dynamic> settingsBox;
  late MetadataCacheRepository repository;
  late DateTime now;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('metadata_sync_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(EpisodeMetadataAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(MetadataSourceSnapshotAdapter());
    }
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(MetadataRecordAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    metadataBox = await Hive.openBox<dynamic>('metadataCacheSyncTest');
    settingsBox = await Hive.openBox<dynamic>('settingsSyncTest');
    await settingsBox.put(SettingBoxKey.metadataRetentionHours, 24);
    await settingsBox.put(SettingBoxKey.metadataBangumiEnabled, true);
    await settingsBox.put(SettingBoxKey.metadataTmdbEnabled, true);
    now = DateTime(2025, 1, 1, 12, 0, 0);
    repository = MetadataCacheRepository(
      metadataBox: metadataBox,
      settingBox: settingsBox,
      clock: () => now,
    );
  });

  tearDown(() async {
    await metadataBox.clear();
    await metadataBox.close();
    await settingsBox.clear();
    await settingsBox.close();
    await Hive.deleteBoxFromDisk('metadataCacheSyncTest');
    await Hive.deleteBoxFromDisk('settingsSyncTest');
  });

  group('Metadata sync integration', () {
    test('merges Bangumi and TMDb payloads respecting locale precedence',
        () async {
      final ui.Locale locale = const ui.Locale('zh', 'CN');
      final Map<_MetadataKey, MetadataFetchResult> responses =
          <_MetadataKey, MetadataFetchResult>{
        _MetadataKey(MetadataSourceKind.bangumi, '123'): MetadataFetchResult(
          source: MetadataSourceKind.bangumi,
          locale: locale,
          payload: <String, dynamic>{
            'name_cn': '孤独摇滚',
            'name': 'ぼっち・ざ・ろっく！',
            'summary': '乐队的少女日记',
            'images': <String, dynamic>{
              'common': 'https://bangumi.test/common.jpg',
            },
            'eps': <Map<String, dynamic>>[
              <String, dynamic>{
                'sort': 1,
                'name': '序章',
                'desc': '开场演出',
              },
            ],
          },
        ),
        _MetadataKey(MetadataSourceKind.tmdb, 'tmdb-456'): MetadataFetchResult(
          source: MetadataSourceKind.tmdb,
          locale: locale,
          payload: <String, dynamic>{
            'name': 'BOCCHI THE ROCK!',
            'original_name': 'ぼっち・ざ・ろっく！',
            'overview': 'After meeting a drummer, Bocchi forms a band.',
            'poster_path': '/poster.jpg',
            'backdrop_path': '/backdrop.jpg',
            'seasons': <Map<String, dynamic>>[
              <String, dynamic>{
                'episodes': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'episode_number': 1,
                    'name': 'Episode 1',
                    'overview': 'Live debut! ',
                    'still_path': '/still.jpg',
                  },
                ],
              },
            ],
          },
        ),
      };

      final _FakeMetadataClient client =
          _FakeMetadataClient(responses, settingsBox, locale);

      final MetadataSyncController controller = MetadataSyncController(
        client: client,
        repository: repository,
      );

      final MetadataRecord? record = await controller.ensureLatest(
        '123',
        identifiers: <String, String>{'tmdb': 'tmdb-456'},
        localeOverride: locale,
      );

      expect(record, isNotNull);
      expect(record!.slug, '123');
      expect(record.primaryTitle, 'BOCCHI THE ROCK!');
      expect(record.alternateTitles['ja'], 'ぼっち・ざ・ろっく！');
      expect(record.synopsis['zh-CN'],
          'After meeting a drummer, Bocchi forms a band.');
      expect(
          record.posterUrl, 'https://image.tmdb.org/t/p/original/poster.jpg');
      expect(record.backdropUrl,
          'https://image.tmdb.org/t/p/original/backdrop.jpg');
      expect(record.identifiers['bangumi'], '123');
      expect(record.identifiers['tmdb'], 'tmdb-456');
      expect(record.sourceSnapshots.length, 2);
      expect(record.sourceSnapshots.map((snapshot) => snapshot.sourceId),
          containsAll(<String>['bangumi', 'tmdb']));
      expect(record.episodes.length, 1);
      expect(record.episodes.first.number, 1);
      expect(record.episodes.first.title, 'Episode 1');
      expect(record.episodes.first.stillImageUrl,
          'https://image.tmdb.org/t/p/original/still.jpg');
      expect(record.activeSource, MetadataSourceKind.tmdb.name);
    });
  });
}

class _FakeMetadataClient extends MetadataClient {
  _FakeMetadataClient(this._responses, Box<dynamic> settingBox, this.locale)
      : super(settingBox: settingBox);

  final Map<_MetadataKey, MetadataFetchResult> _responses;
  final ui.Locale locale;

  @override
  Future<MetadataFetchResult?> fetchFromSource({
    required MetadataSourceKind source,
    required String identifier,
    ui.Locale? localeOverride,
    bool forceRefresh = false,
  }) async {
    final MetadataFetchResult? result =
        _responses[_MetadataKey(source, identifier)];
    if (result == null) {
      return null;
    }
    return MetadataFetchResult(
      source: result.source,
      payload: result.payload,
      locale: localeOverride ?? locale,
    );
  }
}

class _MetadataKey {
  const _MetadataKey(this.source, this.identifier);

  final MetadataSourceKind source;
  final String identifier;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _MetadataKey &&
        other.source == source &&
        other.identifier == identifier;
  }

  @override
  int get hashCode => Object.hash(source, identifier);
}
