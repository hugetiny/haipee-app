import 'dart:async';

import 'package:dio/dio.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/modules/bangumi/episode_item.dart';
import 'package:haipee/modules/comments/comment_item.dart';
import 'package:haipee/modules/roads/road_module.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/plugins/plugins_controller.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/request/bangumi.dart';
import 'package:haipee/request/request.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/utils.dart';
import 'package:haipee/pages/webview/webview_controller.dart';
import 'package:haipee/pages/webview/providers.dart';
import 'package:logger/logger.dart';
import 'package:window_manager/window_manager.dart';
import 'package:haipee/modules/playback/media_selector.dart';
import 'package:haipee/utils/parse_failure_helper.dart';

import 'video_state.dart';

class VideoPageController extends Notifier<VideoPageState> {
  late final PluginsController pluginsController;
  late final WebviewItemController<dynamic> webviewController;

  @override
  VideoPageState build() {
    pluginsController = ref.read(pluginsProvider.notifier);
    webviewController = ref.read(webviewItemControllerProvider);
    ref.onDispose(cancelQueryRoads);
    // Keep the VideoPageController alive across route transitions to avoid
    // losing state (roadList/currentPlugin) between SourceSheet -> VideoPage.
    // This prevents AutoDispose from disposing the provider when temporarily
    // unlistened during navigation, which caused `Plugin is null!` and empty road lists.
    ref.keepAlive();
    return VideoPageState.initial();
  }

  CancelToken? _queryRoadsCancelToken;

  BangumiItem get bangumiItem {
    final item = state.bangumiItem;
    if (item != null) {
      return item;
    }
    return BangumiItem.dummy(
      title: state.title.isNotEmpty ? state.title : '未知视频',
    );
  }

  BangumiItem? get bangumiItemOrNull => state.bangumiItem;

  set bangumiItem(BangumiItem value) {
    state = state.copyWith(bangumiItem: value);
  }

  EpisodeInfo get episodeInfo => state.episodeInfo;
  set episodeInfo(EpisodeInfo value) {
    state = state.copyWith(episodeInfo: value);
  }

  List<EpisodeCommentItem> get episodeCommentsList => state.episodeComments;

  void resetEpisodeInfo() {
    state = state.copyWith(episodeInfo: EpisodeInfo.fromTemplate());
  }

  void clearEpisodeComments() {
    state = state.copyWith(episodeComments: []);
  }

  void addEpisodeComments(Iterable<EpisodeCommentItem> comments) {
    final updated = [...state.episodeComments, ...comments];
    state = state.copyWith(episodeComments: updated);
  }

  bool get loading => state.loading;
  set loading(bool value) {
    if (state.loading == value) return;
    state = state.copyWith(loading: value);
  }

  int get currentEpisode => state.currentEpisode;
  set currentEpisode(int value) {
    if (state.currentEpisode == value) return;
    state = state.copyWith(currentEpisode: value);
  }

  int get currentRoad => state.currentRoad;
  set currentRoad(int value) {
    if (state.currentRoad == value) return;
    state = state.copyWith(currentRoad: value);
  }

  bool get isFullscreen => state.isFullscreen;
  set isFullscreen(bool value) {
    if (state.isFullscreen == value) return;
    state = state.copyWith(isFullscreen: value);
  }

  bool get isPip => state.isPip;
  set isPip(bool value) {
    if (state.isPip == value) return;
    state = state.copyWith(isPip: value);
  }

  bool get showTabBody => state.showTabBody;
  set showTabBody(bool value) {
    if (state.showTabBody == value) return;
    state = state.copyWith(showTabBody: value);
  }

  int get historyOffset => state.historyOffset;
  set historyOffset(int value) {
    if (state.historyOffset == value) return;
    state = state.copyWith(historyOffset: value);
  }

  String get title => state.title;
  set title(String value) {
    if (state.title == value) return;
    state = state.copyWith(title: value);
  }

  String get src => state.src;
  set src(String value) {
    if (state.src == value) return;
    state = state.copyWith(src: value);
  }

  List<Road> get roadList => state.roadList;

  Plugin get currentPlugin {
    final plugin = state.currentPlugin;
    if (plugin != null) {
      return plugin;
    }
    return Plugin.fromTemplate();
  }

  Plugin? get currentPluginOrNull => state.currentPlugin;

  set currentPlugin(Plugin plugin) {
    state = state.copyWith(currentPlugin: plugin);
  }

  Future<void> changeEpisode(int episode,
      {int currentRoad = 0, int offset = 0}) async {
    if (state.roadList.isEmpty) {
      HaipeeLogger().log(Level.warning, '尝试切换剧集时播放列表为空 episode: $episode');
      return;
    }
    if (currentRoad >= state.roadList.length) {
      HaipeeLogger()
          .log(Level.warning, '尝试切换剧集时播放列表索引越界 currentRoad: $currentRoad');
      return;
    }
    if (episode <= 0 || episode > state.roadList[currentRoad].data.length) {
      HaipeeLogger().log(Level.warning,
          '尝试切换剧集时集数越界 episode: $episode currentRoad: $currentRoad');
      return;
    }
    currentEpisode = episode;
    this.currentRoad = currentRoad;
    historyOffset = offset;
    final chapterName = state.roadList[currentRoad].identifier[episode - 1];
    HaipeeLogger().log(Level.info, '跳转到$chapterName');

    if (state.bangumiItem != null && !state.bangumiItem!.isDummyItem) {
      final resolution = MediaSelector.resolve(
        rawIndex: episode,
        identifier: chapterName,
        roadName: state.roadList[currentRoad].name,
        bangumiTotalEpisodes: state.bangumiItem?.totalEpisodes,
      );
      unawaited(queryBangumiEpisodeCommentsByID(
        state.bangumiItem!.id,
        resolution.bangumiEpisode,
      ));
    }

    var urlItem = state.roadList[currentRoad].data[episode - 1];
    final plugin = currentPlugin;

    if (plugin.isBilibili || urlItem.startsWith('bili://')) {
      String bvid = '';
      int? cid;
      if (urlItem.startsWith('bili://')) {
        final parts = urlItem.substring('bili://'.length).split('/');
        if (parts.isNotEmpty) bvid = parts[0];
        if (parts.length >= 2) cid = int.tryParse(parts[1]);
      } else {
        cid = int.tryParse(urlItem);
        final bvMatch = RegExp(r'BV[a-zA-Z0-9]{10}').firstMatch(state.src);
        bvid = bvMatch?.group(0) ?? state.src;
      }
      final normalizedBiliUrl = 'bili://$bvid/${cid ?? 0}';
      HaipeeLogger().log(Level.info, 'B站原生WBI/DASH流直通播放器: $normalizedBiliUrl');
      loading = false;
      webviewController.videoParserEventController.add((normalizedBiliUrl, offset));
      return;
    }

    // 检查是否为直链视频（如 HLS .m3u8、.mp4 等媒体格式或流媒体协议）
    final isDirectStream = isDirectMediaUrl(urlItem);

    if (isDirectStream) {
      HaipeeLogger().log(Level.info, '免嗅探直接视频流，直通播放器: $urlItem');
      loading = false;
      webviewController.videoParserEventController.add((urlItem, offset));
      return;
    }

    // 若非直接媒体流格式（如影视采集 CMS/解析站返回的播放页面），先尝试快速轻量提取页面内嵌入的 .m3u8 / .mp4 直链
    if (urlItem.startsWith('http://') || urlItem.startsWith('https://')) {
      try {
        HaipeeLogger().log(Level.info, '检测到非直链网页播放地址，尝试快速提取内嵌直链: $urlItem');
        final resp = await Request().get(
          urlItem,
          options: Options(
            responseType: ResponseType.plain,
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
            headers: {
              'User-Agent': plugin.userAgent.isNotEmpty
                  ? plugin.userAgent
                  : Utils.getRandomUA(),
              'Referer': plugin.referer.isNotEmpty
                  ? plugin.referer
                  : (plugin.baseUrl.isNotEmpty ? '${plugin.baseUrl}/' : ''),
            },
          ),
        );
        if (resp.data != null) {
          final content = resp.data.toString();
          final matches = embeddedStreamRegex.allMatches(content);
          for (final m in matches) {
            final matchedUrl = m.group(0);
            if (matchedUrl != null &&
                !matchedUrl.contains('.js') &&
                !matchedUrl.contains('dplayer') &&
                !matchedUrl.contains('hls.min')) {
              HaipeeLogger().log(Level.info, '从播放页面成功提取内嵌直链: $matchedUrl');
              loading = false;
              webviewController.videoParserEventController
                  .add((matchedUrl, offset));
              return;
            }
          }
        }
      } catch (e) {
        HaipeeLogger().log(Level.warning, '快速提取网页内嵌视频流异常: $e');
      }
    }

    if (!urlItem.contains(plugin.baseUrl) &&
        !urlItem.contains(plugin.baseUrl.replaceAll('https', 'http'))) {
      if (plugin.baseUrl.endsWith('/') && urlItem.startsWith('/')) {
        urlItem = plugin.baseUrl + urlItem.substring(1);
      } else if (!plugin.baseUrl.endsWith('/') && !urlItem.startsWith('/')) {
        urlItem = '${plugin.baseUrl}/$urlItem';
      } else {
        urlItem = plugin.baseUrl + urlItem;
      }
    }
    // 规范化 URL 路径，清理意外的双斜杠（保留协议头 ://）
    urlItem = urlItem.replaceAllMapped(
      RegExp(r'^((?:https?:)?//[^/]+)(/.*)$'),
      (match) {
        final host = match.group(1)!;
        final path = match.group(2)!.replaceAll(RegExp(r'/+'), '/');
        return '$host$path';
      },
    );
    await webviewController.loadUrl(
      urlItem,
      plugin.useNativePlayer,
      plugin.useLegacyParser,
      offset: offset,
    );
  }

  static final RegExp embeddedStreamRegex = RegExp(
    r'''https?://[^\s"'<>\\]+?\.(?:m3u8|mp4)[^\s"'<>\\]*''',
    caseSensitive: false,
  );

  static bool isDirectMediaUrl(String url) {
    if (url.startsWith('bili://') ||
        url.startsWith('rtmp://') ||
        url.startsWith('rtsp://')) {
      return true;
    }
    final cleanUrl = url.split('#').first;
    final uri = Uri.tryParse(cleanUrl);
    final path = (uri != null && uri.path.isNotEmpty) ? uri.path : cleanUrl;
    final lowerPath = path.toLowerCase();

    const mediaExts = [
      '.m3u8',
      '.mp4',
      '.flv',
      '.mkv',
      '.ts',
      '.mpd',
      '.webm',
      '.m4s',
      '.f4v',
      '.mov',
      '.avi',
    ];
    for (final ext in mediaExts) {
      if (lowerPath.endsWith(ext) || lowerPath.contains('$ext?')) {
        return true;
      }
    }

    if (uri != null && uri.hasQuery) {
      final query = uri.query.toLowerCase();
      for (final ext in mediaExts) {
        if (query.contains(ext)) {
          return true;
        }
      }
    }

    return false;
  }

  Future<void> queryBangumiEpisodeCommentsByID(int id, int episode) async {
    clearEpisodeComments();
    if (state.bangumiItem?.isDummyItem == true || id <= 0) {
      return;
    }
    episodeInfo = await BangumiHTTP.getBangumiEpisodeByID(id, episode);
    if (episodeInfo.id <= 0) {
      return;
    }
    final result =
        await BangumiHTTP.getBangumiCommentsByEpisodeID(episodeInfo.id);
    addEpisodeComments(result.commentList);
    HaipeeLogger().log(Level.info, '已加载评论列表长度 ${state.episodeComments.length}');
  }

  Future<void> queryRoads(String url, String pluginName,
      {CancelToken? cancelToken}) async {
    cancelToken ??= CancelToken();
    _queryRoadsCancelToken?.cancel();
    _queryRoadsCancelToken = cancelToken;

    Plugin? matched;
    for (final plugin in pluginsController.pluginList) {
      if (plugin.name == pluginName) {
        matched = plugin;
        break;
      }
    }

    if (matched == null) {
      HaipeeLogger().log(Level.warning, '未找到源 $pluginName');
      state = state.copyWith(
        roadList: const [],
        currentPlugin: null,
      );
      return;
    }

    try {
      final roads =
          await matched.querychapterRoads(url, cancelToken: cancelToken);
      state = state.copyWith(
        roadList: List<Road>.from(roads),
        currentPlugin: matched,
      );
      HaipeeLogger().log(Level.info, '播放列表长度 ${state.roadList.length}');
      if (state.roadList.isNotEmpty) {
        HaipeeLogger()
            .log(Level.info, '第一播放列表选集数 ${state.roadList.first.data.length}');
      }
    } catch (e) {
      HaipeeLogger().log(Level.error, '查询播放列表失败: $e');

      // 记录查询失败(非解析失败,是获取播放列表失败)
      String reason = 'network_error';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout) {
          reason = 'connection_timeout';
        } else if (e.type == DioExceptionType.receiveTimeout) {
          reason = 'receive_timeout';
        } else if (e.type == DioExceptionType.badResponse) {
          reason = 'bad_response_${e.response?.statusCode ?? 0}';
        } else if (e.type == DioExceptionType.cancel) {
          reason = 'cancelled';
        }
      }

      // 记录失败
      ParseFailureHelper.recordFailure(
        bangumiId: bangumiItem.id,
        pluginName: pluginName,
        src: url,
        reason: reason,
      );

      state = state.copyWith(
        roadList: const [],
        currentPlugin: matched,
      );
      rethrow;
    }
  }

  void cancelQueryRoads() {
    if (_queryRoadsCancelToken != null &&
        !_queryRoadsCancelToken!.isCancelled) {
      _queryRoadsCancelToken!.cancel();
    }
    _queryRoadsCancelToken = null;
  }

  void enterFullScreen() {
    isFullscreen = true;
    showTabBody = false;
    Utils.enterFullScreen(lockOrientation: false);
  }

  void exitFullScreen() {
    isFullscreen = false;
    Utils.exitFullScreen();
  }

  Future<void> isDesktopFullscreen() async {
    if (Utils.isDesktop()) {
      isFullscreen = await windowManager.isFullScreen();
    }
  }

  void handleOnEnterFullScreen() {
    isFullscreen = true;
    showTabBody = false;
  }

  void handleOnExitFullScreen() {
    isFullscreen = false;
  }
}
