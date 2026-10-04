import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/metadata_sync/metadata_cache_repository.dart';
import 'package:kazumi/modules/metadata_sync/models/metadata_record.dart';
import 'package:kazumi/modules/metadata_sync/metadata_sync_controller.dart';
import 'package:kazumi/request/metadata_client.dart';
import 'package:kazumi/utils/aria2_client.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/utils/platform_guard.dart';

final metadataClientProvider = Provider<MetadataClient>((ref) {
  return MetadataClient();
});

final metadataCacheRepositoryProvider =
    Provider<MetadataCacheRepository>((ref) {
  return MetadataCacheRepository();
});

final metadataCacheBoxProvider = Provider<Box<MetadataRecord>>((ref) {
  return GStorage.metadataCache;
});

final downloadQueueBoxProvider = Provider<Box<dynamic>>((ref) {
  return GStorage.downloadTasks;
});

final playbackProfileBoxProvider = Provider<Box<dynamic>>((ref) {
  return GStorage.playbackProfiles;
});

final aria2ClientProvider = Provider<Aria2Client>((ref) {
  return Aria2Client.fromSettings();
});

final platformGuardProvider = Provider<PlatformGuard>((ref) {
  return PlatformGuard();
});

final metadataSyncControllerProvider = Provider<MetadataSyncController>((ref) {
  return MetadataSyncController(
    client: ref.read(metadataClientProvider),
    repository: ref.read(metadataCacheRepositoryProvider),
  );
});

final metadataRetentionDurationProvider = Provider<Duration>((ref) {
  return GStorage.metadataRetentionDuration();
});

final downloadRetentionDurationProvider = Provider<Duration>((ref) {
  return GStorage.downloadRetentionDuration();
});

final playbackRetentionDurationProvider = Provider<Duration>((ref) {
  return GStorage.playbackProfileRetentionDuration();
});

class TorrentConsentState {
  const TorrentConsentState({required this.granted, this.timestamp});

  final bool granted;
  final DateTime? timestamp;

  TorrentConsentState copyWith({bool? granted, DateTime? timestamp}) {
    return TorrentConsentState(
      granted: granted ?? this.granted,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class TorrentConsentNotifier extends Notifier<TorrentConsentState> {
  @override
  TorrentConsentState build() {
    final bool granted = (GStorage.setting
                .get(SettingBoxKey.torrentConsentAccepted, defaultValue: false)
            as bool?) ??
        false;
    final dynamic storedTimestamp =
        GStorage.setting.get(SettingBoxKey.torrentConsentTimestamp);
    DateTime? timestamp;
    if (storedTimestamp is int && storedTimestamp > 0) {
      timestamp =
          DateTime.fromMillisecondsSinceEpoch(storedTimestamp, isUtc: true)
              .toLocal();
    } else if (storedTimestamp is String && storedTimestamp.isNotEmpty) {
      timestamp = DateTime.tryParse(storedTimestamp)?.toLocal();
    }

    return TorrentConsentState(granted: granted, timestamp: timestamp);
  }

  Future<void> accept({DateTime? at}) async {
    final DateTime acceptedAt = (at ?? DateTime.now()).toUtc();
    await GStorage.setting.put(SettingBoxKey.torrentConsentAccepted, true);
    await GStorage.setting.put(SettingBoxKey.torrentConsentTimestamp,
        acceptedAt.millisecondsSinceEpoch);
    state = TorrentConsentState(
      granted: true,
      timestamp: acceptedAt.toLocal(),
    );
  }

  Future<void> revoke() async {
    await GStorage.setting.put(SettingBoxKey.torrentConsentAccepted, false);
    await GStorage.setting.put(SettingBoxKey.torrentConsentTimestamp, 0);
    state = const TorrentConsentState(granted: false, timestamp: null);
  }
}

final torrentConsentProvider =
    NotifierProvider<TorrentConsentNotifier, TorrentConsentState>(
  TorrentConsentNotifier.new,
);
