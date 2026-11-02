import 'dart:async';
import 'package:dio/dio.dart';
import 'package:haipee/modules/playback/aniskip_model.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/storage.dart';
import 'package:logger/logger.dart';

/// AniSkip 智能片头片尾 (OP/ED/Recap) 跳过服务
class AniSkipService {
  static final AniSkipService instance = AniSkipService._();
  AniSkipService._({Dio? dio}) : _dio = dio ?? Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
            sendTimeout: const Duration(seconds: 5),
          ),
        );

  factory AniSkipService.forTesting({Dio? dio}) => AniSkipService._(dio: dio);

  final Dio _dio;

  /// In-memory cache for Bangumi ID -> MyAnimeList ID mapping
  static final Map<int, int> _malIdCache = {};

  /// In-memory cache for skip intervals: `"$malId:$episodeNumber"` -> `List<AniSkipInterval>`
  static final Map<String, List<AniSkipInterval>> _intervalsCache = {};

  /// Resolves MyAnimeList (MAL) ID from Bangumi ID using MALSync API with local caching.
  Future<int?> getMalIdFromBangumiId(int bangumiId) async {
    if (bangumiId <= 0) return null;

    // 1. In-memory cache
    if (_malIdCache.containsKey(bangumiId)) {
      return _malIdCache[bangumiId];
    }

    // 2. Persistent storage cache
    final cacheKey = 'mal_sync_id_$bangumiId';
    try {
      final cachedVal = GStorage.setting.get(cacheKey);
      if (cachedVal is int && cachedVal > 0) {
        _malIdCache[bangumiId] = cachedVal;
        return cachedVal;
      }
    } catch (_) {}

    // 3. Query MALSync API
    try {
      final url = 'https://api.malsync.moe/bangumi/anime/$bangumiId';
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        options: Options(responseType: ResponseType.json),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        int? malId;

        // Try direct malId
        if (data['malId'] != null) {
          malId = int.tryParse(data['malId'].toString());
        }
        // Try id
        if (malId == null && data['id'] != null) {
          malId = int.tryParse(data['id'].toString());
        }
        // Try Sites -> MyAnimeList -> first key
        if (malId == null && data['Sites'] is Map) {
          final sites = data['Sites'] as Map;
          final malSites = sites['MyAnimeList'];
          if (malSites is Map && malSites.isNotEmpty) {
            final firstKey = malSites.keys.first.toString();
            malId = int.tryParse(firstKey);
          }
        }

        if (malId != null && malId > 0) {
          _malIdCache[bangumiId] = malId;
          try {
            await GStorage.setting.put(cacheKey, malId);
          } catch (_) {}
          HaipeeLogger().log(
            Level.info,
            '[AniSkipService] Resolved Bangumi $bangumiId -> MAL $malId',
          );
          return malId;
        }
      }
    } catch (e) {
      HaipeeLogger().log(
        Level.debug,
        '[AniSkipService] Failed to query MALSync for Bangumi $bangumiId: $e',
      );
    }

    return null;
  }

  /// Queries AniSkip API for OP/ED/Recap skip times using MAL ID or Bangumi ID.
  Future<List<AniSkipInterval>> getSkipTimes({
    int? malId,
    int? bangumiId,
    required int episode,
    double episodeLength = 0,
  }) async {
    if (episode <= 0) return const [];

    int? effectiveMalId = malId;
    if (effectiveMalId == null && bangumiId != null) {
      effectiveMalId = await getMalIdFromBangumiId(bangumiId);
    }

    if (effectiveMalId == null || effectiveMalId <= 0) {
      return const [];
    }

    final cacheKey = '$effectiveMalId:$episode';
    if (_intervalsCache.containsKey(cacheKey)) {
      return _intervalsCache[cacheKey]!;
    }

    try {
      final url =
          'https://api.aniskip.com/v1/skip-times/$effectiveMalId/$episode'
          '?types[]=op&types[]=ed&types[]=recap&episodeLength=${episodeLength.toInt()}';

      final response = await _dio.get<Map<String, dynamic>>(
        url,
        options: Options(responseType: ResponseType.json),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final found = data['found'] == true;
        if (found && data['results'] is List) {
          final rawResults = data['results'] as List;
          final intervals = <AniSkipInterval>[];
          for (final item in rawResults) {
            if (item is Map<String, dynamic>) {
              final interval = AniSkipInterval.fromJson(item);
              if (interval.endTime > interval.startTime) {
                intervals.add(interval);
              }
            }
          }

          // Sort by start time ascending
          intervals.sort((a, b) => a.startTime.compareTo(b.startTime));
          _intervalsCache[cacheKey] = intervals;

          HaipeeLogger().log(
            Level.info,
            '[AniSkipService] Loaded ${intervals.length} skip intervals for MAL $effectiveMalId Ep $episode: $intervals',
          );
          return intervals;
        }
      }
    } catch (e) {
      HaipeeLogger().log(
        Level.debug,
        '[AniSkipService] AniSkip query failed for MAL $effectiveMalId Ep $episode: $e',
      );
    }

    return const [];
  }

  /// Clear in-memory caches (for tests)
  static void clearCache() {
    _malIdCache.clear();
    _intervalsCache.clear();
  }

  /// Seed MAL ID for test/offline environments
  static void seedMalId(int bangumiId, int malId) {
    _malIdCache[bangumiId] = malId;
  }

  /// Seed intervals for test/offline environments
  static void seedIntervals(int malId, int episode, List<AniSkipInterval> intervals) {
    _intervalsCache['$malId:$episode'] = intervals;
  }
}
