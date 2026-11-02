import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:haipee/modules/bilibili/bilibili_models.dart';
import 'package:haipee/modules/bilibili/bilibili_wbi.dart';
import 'package:haipee/modules/danmaku/danmaku_module.dart';
import 'package:haipee/utils/danmaku.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/storage.dart';
import 'package:logger/logger.dart';

/// Bilibili 原生数据抓取与流媒体抽取服务
///
/// 完全脱离原站架构：
/// 1. 搜索与推荐：支持 WBI 签名逆向、关键词模糊检索、UP主与分P解析
/// 2. 分P提取与选集：解析多P CID
/// 3. DASH 双流抽取：提取 1080P/720P DASH 视频流及 192K/132K 独立音频流
/// 4. 实时弹幕：获取原生 XML/protobuf 弹幕并实时灌入 Haipee 弹幕层
class BilibiliService {
  static final Dio _dio = Dio(
    BaseOptions(
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://www.bilibili.com',
      },
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// 搜索视频
  static Future<List<BiliVideoItem>> searchVideos(
    String keyword, {
    int page = 1,
    Dio? client,
  }) async {
    final effectiveClient = client ?? _dio;
    final cleanKeyword = keyword.trim();
    if (cleanKeyword.isEmpty) return const [];

    try {
      final (imgKey, subKey) = await BiliWbiSigner.getWbiKeys(dio: effectiveClient);
      final rawParams = {
        'search_type': 'video',
        'keyword': cleanKeyword,
        'page': page,
      };

      final signedParams = BiliWbiSigner.signParams(
        rawParams,
        imgKey: imgKey,
        subKey: subKey,
      );

      final response = await effectiveClient.get<Map<String, dynamic>>(
        'https://api.bilibili.com/x/web-interface/wbi/search/type',
        queryParameters: signedParams,
      );

      final data = response.data?['data'];
      final result = data?['result'];
      if (result is List) {
        return result
            .map((item) => BiliVideoItem.fromJson(item as Map<String, dynamic>))
            .where((item) => item.bvid.isNotEmpty)
            .toList();
      }
    } catch (e) {
      HaipeeLogger().log(Level.warning, 'B站 WBI 搜索异常，尝试回退标准搜索: $e');
      // 容错回退接口
      try {
        final fallbackRes = await effectiveClient.get<Map<String, dynamic>>(
          'https://api.bilibili.com/x/web-interface/search/type',
          queryParameters: {
            'search_type': 'video',
            'keyword': cleanKeyword,
            'page': page,
          },
        );
        final data = fallbackRes.data?['data'];
        final result = data?['result'];
        if (result is List) {
          return result
              .map((item) => BiliVideoItem.fromJson(item as Map<String, dynamic>))
              .where((item) => item.bvid.isNotEmpty)
              .toList();
        }
      } catch (err) {
        HaipeeLogger().log(Level.error, 'B站回退搜索亦失败: $err');
      }
    }

    return const [];
  }

  /// 获取视频详情及分P剧集列表
  static Future<BiliVideoDetail?> getVideoDetails(
    String bvid, {
    Dio? client,
  }) async {
    final effectiveClient = client ?? _dio;
    if (bvid.isEmpty) return null;

    try {
      final response = await effectiveClient.get<Map<String, dynamic>>(
        'https://api.bilibili.com/x/web-interface/view',
        queryParameters: {'bvid': bvid},
      );

      final data = response.data?['data'];
      if (data != null && data is Map<String, dynamic>) {
        return BiliVideoDetail.fromJson(data);
      }
    } catch (e) {
      HaipeeLogger().log(Level.error, '获取 B站 视频详情失败 bvid=$bvid: $e');
    }

    return null;
  }

  /// 获取 DASH 播放直链 (返回视频流 URL + 独立音频流 URL + HTTP 请求头)
  static Future<BiliPlayUrl?> getPlayUrl(
    String bvid,
    int cid, {
    Dio? client,
    String? sessData,
    int? targetQuality,
  }) async {
    final effectiveClient = client ?? _dio;
    if (bvid.isEmpty || cid <= 0) return null;

    String? sessDataValue = sessData;
    if (sessDataValue == null || sessDataValue.trim().isEmpty) {
      try {
        final saved = GStorage.setting.get('bilibiliSessData');
        if (saved is String && saved.trim().isNotEmpty) {
          sessDataValue = saved.trim();
        }
      } catch (_) {}
    }

    final headers = {
      'Referer': 'https://www.bilibili.com',
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      if (sessDataValue != null && sessDataValue.isNotEmpty)
        'Cookie': 'SESSDATA=$sessDataValue;',
    };

    try {
      final (imgKey, subKey) = await BiliWbiSigner.getWbiKeys(dio: effectiveClient);
      final rawParams = {
        'bvid': bvid,
        'cid': cid,
        'qn': targetQuality ?? 120, // 优先请求最高 4K / 1080P60 / 1080P
        'fnval': 4048, // 请求 DASH 格式
        'fnver': 0,
        'fourk': 1,
      };

      final signedParams = BiliWbiSigner.signParams(
        rawParams,
        imgKey: imgKey,
        subKey: subKey,
      );

      final response = await effectiveClient.get<Map<String, dynamic>>(
        'https://api.bilibili.com/x/player/wbi/playurl',
        queryParameters: signedParams,
        options: Options(headers: headers),
      );

      final data = response.data?['data'];
      if (data != null) {
        final dash = data['dash'];
        if (dash != null) {
          final List<dynamic>? videoList = dash['video'];
          final List<dynamic>? audioList = dash['audio'];

          final List<BiliStreamQuality> availableQualities = [];
          if (videoList != null) {
            for (final v in videoList) {
              final id = v['id'] is int ? v['id'] as int : int.tryParse(v['id']?.toString() ?? '0') ?? 0;
              if (id > 0 && !availableQualities.any((q) => q.id == id)) {
                availableQualities.add(BiliStreamQuality(
                  id: id,
                  label: BiliQualityHelper.getLabel(id),
                  format: 'dash',
                ));
              }
            }
            availableQualities.sort((a, b) => b.id.compareTo(a.id));
          }

          String? videoUrl;
          int quality = 80;
          if (videoList != null && videoList.isNotEmpty) {
            Map<String, dynamic>? selectedVideo;
            if (targetQuality != null) {
              selectedVideo = videoList.firstWhere(
                (v) => (v['id'] is int ? v['id'] : int.tryParse(v['id']?.toString() ?? '0')) == targetQuality,
                orElse: () => videoList.first as Map<String, dynamic>,
              ) as Map<String, dynamic>?;
            }
            selectedVideo ??= videoList.first as Map<String, dynamic>;

            videoUrl = selectedVideo['baseUrl'] ?? selectedVideo['base_url'];
            quality = selectedVideo['id'] is int
                ? selectedVideo['id'] as int
                : int.tryParse(selectedVideo['id']?.toString() ?? '80') ?? 80;
          }

          String? audioUrl;
          if (audioList != null && audioList.isNotEmpty) {
            // 选取最高码率音频
            final bestAudio = audioList.first as Map<String, dynamic>;
            audioUrl = bestAudio['baseUrl'] ?? bestAudio['base_url'];
          }

          if (videoUrl != null && videoUrl.isNotEmpty) {
            return BiliPlayUrl(
              videoUrl: videoUrl,
              audioUrl: audioUrl,
              quality: quality,
              format: 'dash',
              headers: headers,
              availableQualities: availableQualities,
            );
          }
        }

        // 降级使用 durl 单流
        final List<dynamic>? durls = data['durl'];
        if (durls != null && durls.isNotEmpty) {
          final first = durls.first as Map<String, dynamic>;
          final url = first['url']?.toString();
          if (url != null && url.isNotEmpty) {
            return BiliPlayUrl(
              videoUrl: url,
              quality: data['quality'] is int ? data['quality'] : 64,
              format: 'durl',
              headers: headers,
              availableQualities: [
                BiliStreamQuality(
                  id: data['quality'] is int ? data['quality'] : 64,
                  label: BiliQualityHelper.getLabel(data['quality'] is int ? data['quality'] : 64),
                  format: 'durl',
                )
              ],
            );
          }
        }
      }
    } catch (e) {
      HaipeeLogger().log(Level.error, '获取 B站 播放直链失败 bvid=$bvid cid=$cid: $e');
    }

    return null;
  }

  /// 获取并解析 B站 原生弹幕流 (支持 RFC 1951 raw deflate 解压与 XML 实体还原)
  static Future<List<DanmakuEntry>> getDanmaku(
    int cid, {
    Dio? client,
  }) async {
    final effectiveClient = client ?? _dio;
    if (cid <= 0) return const [];

    try {
      final response = await effectiveClient.get<dynamic>(
        'https://comment.bilibili.com/$cid.xml',
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept-Encoding': 'deflate, gzip',
          },
        ),
      );

      final dynamic data = response.data;
      if (data == null) return const [];

      String xmlContent = '';
      if (data is List<int>) {
        List<int> decompressed;
        try {
          // B站 comment.bilibili.com/{cid}.xml 标准返回 RFC 1951 raw deflate 压缩流
          decompressed = ZLibDecoder(raw: true).convert(data);
        } catch (_) {
          try {
            decompressed = zlib.decode(data);
          } catch (_) {
            try {
              decompressed = gzip.decode(data);
            } catch (_) {
              decompressed = data;
            }
          }
        }
        xmlContent = utf8.decode(decompressed, allowMalformed: true);
      } else if (data is String) {
        xmlContent = data;
      }

      if (xmlContent.isNotEmpty) {
        return parseDanmakuXml(xmlContent);
      }
    } catch (e) {
      HaipeeLogger().log(Level.warning, '获取 B站 弹幕 XML 失败 cid=$cid: $e');
    }

    return const [];
  }

  /// 正则解析 B站 弹幕 XML (支持标准 8 字段协议与 XML 实体反转义)
  static List<DanmakuEntry> parseDanmakuXml(String xmlContent) {
    final danmakus = <DanmakuEntry>[];
    final regExp = RegExp(r'<d\s+p="([^"]+)"[^>]*>([^<]*)</d>', caseSensitive: false);

    for (final match in regExp.allMatches(xmlContent)) {
      final p = match.group(1);
      final rawText = match.group(2);
      if (p == null || rawText == null || rawText.trim().isEmpty) continue;

      final parts = p.split(',');
      if (parts.length < 3) continue;

      try {
        final time = double.tryParse(parts[0]) ?? 0.0;
        final type = int.tryParse(parts[1]) ?? 1;

        // B站 p 属性规范: time, type, font_size, color, timestamp, pool, user_hash, dmid
        // 若 parts[3] 为有效数字则为真实颜色 (如 16777215 白色)；兼容部分精简 4 字段情况
        int colorInt = 16777215;
        if (parts.length > 3 && int.tryParse(parts[3]) != null) {
          colorInt = int.parse(parts[3]);
        } else if (parts.length > 2 && int.tryParse(parts[2]) != null) {
          colorInt = int.parse(parts[2]);
        }

        // XML 实体转义还原 (包括命名实体与十进制/十六进制数字实体)
        var text = rawText
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll('&apos;', "'")
            .replaceAll('&#39;', "'");
        text = text
            .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
              final code = int.tryParse(match.group(1)!);
              return code != null ? String.fromCharCode(code) : match.group(0)!;
            })
            .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
              final code = int.tryParse(match.group(1)!, radix: 16);
              return code != null ? String.fromCharCode(code) : match.group(0)!;
            });

        danmakus.add(
          DanmakuEntry(
            message: text,
            time: time,
            type: type,
            color: generateDanmakuColor(colorInt),
            source: '[BiliBili]',
          ),
        );
      } catch (_) {}
    }

    return danmakus;
  }

  /// 获取 B站 热门视频推荐流
  static Future<List<BiliVideoItem>> getPopularVideos({
    int page = 1,
    int pageSize = 20,
    Dio? client,
    CancelToken? cancelToken,
  }) async {
    final effectiveClient = client ?? _dio;
    try {
      final response = await effectiveClient.get<Map<String, dynamic>>(
        'https://api.bilibili.com/x/web-interface/popular',
        queryParameters: {
          'pn': page,
          'ps': pageSize,
        },
        cancelToken: cancelToken,
      );

      final data = response.data?['data'];
      final list = data?['list'];
      if (list is List) {
        return list
            .map((item) => BiliVideoItem.fromJson(item as Map<String, dynamic>))
            .where((item) => item.bvid.isNotEmpty)
            .toList();
      }
    } catch (e) {
      HaipeeLogger().log(Level.warning, '获取 B站 热门流失败: $e');
    }

    return const [];
  }
}
