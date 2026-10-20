import 'dart:async';
import 'package:dio/dio.dart';
import 'package:kazumi/request/core/git_proxy_interceptor.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:logger/logger.dart';

/// 管理高可用公共 BitTorrent Tracker 列表，支持多 CDN 镜像异步自动更新与 BEP 15 UDP Tracker DoH 防污染寻轨。
class TorrentTrackerService {
  static final TorrentTrackerService instance = TorrentTrackerService._internal();

  TorrentTrackerService._internal() {
    _loadCachedTrackers();
  }

  /// 预置高可用活跃公共 Tracker 列表（覆盖 HTTP, HTTPS, UDP 及动漫专享 Tracker）
  static const List<String> defaultTrackers = [
    // 动漫专享与亚洲高连通率 Tracker (HTTP / HTTPS 穿透性强，不惧 UDP 封锁)
    'http://tracker.renfei.net:8080/announce',
    'https://tracker.tamersunion.org:443/announce',
    'https://tracker.lilithraws.org:443/announce',
    'http://open.acgnxtracker.com:80/announce',
    'http://share.camoe.cn:8080/announce',
    'http://t.overflow.biz:6969/announce',
    'http://tracker.openbittorrent.com:80/announce',
    'https://tr.burnabyhighstar.com:443/announce',
    'http://tracker.opentrackr.org:1337/announce',

    // 全球顶级通用高活跃 UDP Trackers
    'udp://tracker.opentrackr.org:1337/announce',
    'udp://open.demonii.com:1337/announce',
    'udp://open.stealth.si:80/announce',
    'udp://tracker.torrent.eu.org:451/announce',
    'udp://explodie.org:6969/announce',
    'udp://tracker.moeking.me:6969/announce',
    'udp://tracker.dler.org:6969/announce',
    'udp://opentracker.i2p.rocks:6969/announce',
    'udp://tracker.therarbg.com:6969/announce',
    'udp://bt1.archive.org:6969/announce',
    'udp://bt2.archive.org:6969/announce',
    'udp://p4p.arenabg.com:1337/announce',
    'udp://movies.zsw.ca:6969/announce',
    'udp://newton.rainstream.top:6969/announce',
    'udp://tracker.altrosky.nl:6969/announce',
    'udp://tracker.auctor.tv:6969/announce',
    'udp://tracker.loadbt.com:6969/announce',
    'udp://tracker.dump.cl:6969/announce',
    'udp://valakas.rollo.cc:6969/announce',
    'udp://tracker.srv00.com:6969/announce',
    'udp://tracker.swateam.org.uk:2710/announce',
    'udp://tracker.zerobytes.xyz:1337/announce',
    'udp://retracker.lanta.me:2710/announce',
  ];

  /// 多个高可用 Tracker 镜像源
  static const List<String> trackerMirrorUrls = [
    'https://cf.trackerslist.com/best.txt',
    'https://cdn.jsdelivr.net/gh/XIU2/TrackersListCollection/best.txt',
    'https://gitea.com/XIU2/TrackersListCollection/raw/branch/master/best.txt',
    'https://trackerslist.com/best.txt',
    'https://raw.githubusercontent.com/XIU2/TrackersListCollection/master/best.txt',
  ];

  /// 高可靠公共 DoH 解析端点列表
  static const List<String> dohEndpoints = [
    'https://223.5.5.5/resolve', // 阿里公共 DNS (国内极速)
    'https://1.12.12.12/resolve', // 腾讯 DNSPod (国内高可用)
    'https://1.1.1.1/dns-query', // Cloudflare DoH (全球低延迟)
  ];

  static const String _cachedTrackersKey = 'cached_bt_trackers';

  final Set<String> _trackers = Set<String>.from(defaultTrackers);
  bool _isFetching = false;
  DateTime? _lastFetchTime;

  /// DoH 解析内存缓存 (hostname -> IP)
  static final Map<String, String> _dohCache = {};

  /// 获取当前所有可用 Tracker
  List<String> get activeTrackers => List.unmodifiable(_trackers);

  /// 从本地缓存中恢复上次保存的高速 Tracker
  void _loadCachedTrackers() {
    try {
      final setting = GStorage.setting;
      final cached = setting.get(_cachedTrackersKey);
      if (cached is List) {
        for (final item in cached) {
          if (item is String && item.trim().isNotEmpty) {
            _trackers.add(item.trim());
          }
        }
      }
    } catch (_) {}
  }

  /// 异步从多 CDN 镜像拉取最新活跃 Tracker 列表
  Future<void> fetchLatestTrackers({bool force = false}) async {
    if (_isFetching) return;
    if (!force &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < const Duration(hours: 12)) {
      return;
    }

    _isFetching = true;
    KazumiLogger().log(
      Level.info,
      '[TorrentTrackerService] Fetching latest trackers from mirrors...',
    );

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        sendTimeout: const Duration(seconds: 4),
        responseType: ResponseType.plain,
      ),
    );
    dio.interceptors.add(GitProxyInterceptor());

    bool success = false;
    for (final mirror in trackerMirrorUrls) {
      try {
        final response = await dio.get<String>(mirror);
        if (response.statusCode == 200 && response.data != null) {
          final content = response.data!;
          final lines = content.split('\n');
          final newTrackers = <String>[];
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty &&
                !trimmed.startsWith('#') &&
                (trimmed.startsWith('http://') ||
                    trimmed.startsWith('https://') ||
                    trimmed.startsWith('udp://') ||
                    trimmed.startsWith('wss://') ||
                    trimmed.startsWith('ws://'))) {
              newTrackers.add(trimmed);
            }
          }

          if (newTrackers.isNotEmpty) {
            _trackers.addAll(newTrackers);
            _lastFetchTime = DateTime.now();
            success = true;
            KazumiLogger().log(
              Level.info,
              '[TorrentTrackerService] Successfully fetched ${newTrackers.length} trackers from $mirror (total: ${_trackers.length})',
            );

            try {
              final setting = GStorage.setting;
              await setting.put(_cachedTrackersKey, _trackers.toList());
            } catch (_) {}

            break;
          }
        }
      } catch (e) {
        KazumiLogger().log(
          Level.debug,
          '[TorrentTrackerService] Mirror failed $mirror: $e',
        );
      }
    }

    if (!success) {
      KazumiLogger().log(
        Level.info,
        '[TorrentTrackerService] Using built-in default trackers (${_trackers.length} available)',
      );
    }
    _isFetching = false;
  }

  /// 通过 DNS-over-HTTPS (DoH) 解析域名对应的 IPv4 地址，彻底绕过运营商 DNS 投毒
  Future<String?> resolveHostWithDoh(String host) async {
    final cleanHost = host.trim().toLowerCase();
    if (cleanHost.isEmpty) return null;

    // 若本身即为纯 IP 地址，直接返回
    final isIpv4 = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(cleanHost);
    if (isIpv4) return cleanHost;

    // 查询缓存
    if (_dohCache.containsKey(cleanHost)) {
      return _dohCache[cleanHost];
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 1),
        receiveTimeout: const Duration(seconds: 1),
      ),
    );

    for (final endpoint in dohEndpoints) {
      try {
        final Response<Map<String, dynamic>> response = await dio.get<Map<String, dynamic>>(
          endpoint,
          queryParameters: {
            'name': cleanHost,
            'type': endpoint.contains('dns-query') ? 'A' : '1',
          },
          options: Options(
            headers: {
              if (endpoint.contains('dns-query')) 'Accept': 'application/dns-json',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final answers = response.data!['Answer'] as List<dynamic>?;
          if (answers != null && answers.isNotEmpty) {
            for (final answer in answers) {
              if (answer is Map) {
                final type = answer['type'];
                final data = answer['data']?.toString().trim();
                // Type 1 is DNS A record (IPv4)
                if ((type == 1 || type == '1' || type == 'A') &&
                    data != null &&
                    RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(data)) {
                  _dohCache[cleanHost] = data;
                  KazumiLogger().log(
                    Level.info,
                    '[TorrentTrackerService] DoH resolved $cleanHost -> $data via $endpoint',
                  );
                  return data;
                }
              }
            }
          }
        }
      } catch (e) {
        KazumiLogger().log(
          Level.debug,
          '[TorrentTrackerService] DoH endpoint $endpoint failed for $cleanHost: $e',
        );
      }
    }

    return null;
  }

  /// BEP 15 UDP Tracker 寻轨重写：将 `udp://tracker.host:port/announce` 重写为 `udp://[resolved-ip]:port/announce`
  Future<String> rewriteTrackerUrlWithDoh(String trackerUrl) async {
    if (!trackerUrl.startsWith('udp://')) {
      return trackerUrl;
    }

    final match = RegExp(r'^udp://([^:/]+)(?::(\d+))?(.*)$').firstMatch(trackerUrl);
    if (match == null) return trackerUrl;

    final host = match.group(1);
    final portSuffix = match.group(2) != null ? ':${match.group(2)}' : '';
    final path = match.group(3) ?? '/announce';

    if (host == null || host.isEmpty) return trackerUrl;

    final resolvedIp = await resolveHostWithDoh(host);
    if (resolvedIp != null && resolvedIp.isNotEmpty) {
      return 'udp://$resolvedIp$portSuffix$path';
    }

    return trackerUrl;
  }

  /// 批量对 Tracker 列表进行 BEP 15 DoH 防污染寻轨重写
  Future<List<String>> rewriteTrackersWithDoh(List<String> trackers) async {
    final uniqueHosts = <String>{};
    for (final tracker in trackers) {
      if (tracker.startsWith('udp://')) {
        final match = RegExp(r'^udp://([^:/]+)').firstMatch(tracker);
        if (match != null && match.group(1) != null) {
          uniqueHosts.add(match.group(1)!);
        }
      }
    }
    // 控制并发度至多 4 个域名并发查询，防止触发公共 DNS 频控
    final hostList = uniqueHosts.toList();
    for (int i = 0; i < hostList.length; i += 4) {
      final chunk = hostList.sublist(i, (i + 4 < hostList.length) ? i + 4 : hostList.length);
      await Future.wait(chunk.map((h) => resolveHostWithDoh(h)));
    }

    return Future.wait(trackers.map((t) => rewriteTrackerUrlWithDoh(t)));
  }

  /// 为磁力链接注入全部活跃 Tracker
  String injectTrackers(String magnetUri) {
    if (magnetUri.isEmpty) return magnetUri;

    String baseUri = magnetUri;
    final existingTrackers = <String>{};

    try {
      final uri = Uri.tryParse(magnetUri);
      if (uri != null) {
        final trList = uri.queryParametersAll['tr'] ?? [];
        existingTrackers.addAll(trList);
      }
    } catch (_) {}

    final buffer = StringBuffer(baseUri);
    bool hasQuery = baseUri.contains('?');

    for (final tracker in _trackers) {
      if (existingTrackers.contains(tracker)) continue;

      final encoded = Uri.encodeComponent(tracker);
      if (baseUri.contains(encoded) || baseUri.contains(tracker)) continue;

      if (!hasQuery) {
        buffer.write('?tr=');
        hasQuery = true;
      } else {
        buffer.write('&tr=');
      }
      buffer.write(encoded);
    }

    return buffer.toString();
  }

  /// 为磁力链接注入 Tracker 并对 UDP Tracker 进行 DoH 重写
  Future<String> rewriteMagnetWithDoh(String magnetUri) async {
    if (magnetUri.isEmpty) return magnetUri;

    final injected = injectTrackers(magnetUri);
    final uri = Uri.tryParse(injected);
    if (uri == null) return injected;

    final trList = uri.queryParametersAll['tr'] ?? [];
    if (trList.isEmpty) return injected;

    final rewrittenList = await rewriteTrackersWithDoh(trList);

    // 重构磁力链接 query
    final newParams = Map<String, List<String>>.from(uri.queryParametersAll);
    newParams['tr'] = rewrittenList;

    return Uri(
      scheme: uri.scheme,
      path: uri.path,
      queryParameters: newParams,
    ).toString();
  }

  /// 设置测试环境 Tracker
  void setTrackersForTesting(List<String> trackers) {
    _trackers.clear();
    _trackers.addAll(trackers);
  }

  /// 重置测试 Tracker 为默认值
  void resetTrackersForTesting() {
    _trackers.clear();
    _trackers.addAll(defaultTrackers);
  }

  /// 设置 DoH 解析缓存 (用于单元测试)
  static void seedDohCache(String host, String ip) {
    _dohCache[host.trim().toLowerCase()] = ip.trim();
  }

  /// 清除 DoH 解析缓存 (用于单元测试)
  static void clearDohCache() {
    _dohCache.clear();
  }
}
