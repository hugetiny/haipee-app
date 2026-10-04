import 'dart:async';

import 'package:dio/dio.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/episode_item.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/plugins/plugins_providers.dart';
import 'package:kazumi/request/bangumi.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/webview/webview_controller.dart';
import 'package:kazumi/pages/webview/providers.dart';
import 'package:logger/logger.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/utils/parse_failure_helper.dart';

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
    if (item == null) {
      throw StateError('bangumiItem is not set');
    }
    return item;
  }

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
    if (plugin == null) {
      throw StateError('currentPlugin is not set');
    }
    return plugin;
  }

  set currentPlugin(Plugin plugin) {
    state = state.copyWith(currentPlugin: plugin);
  }

  Future<void> changeEpisode(int episode,
      {int currentRoad = 0, int offset = 0}) async {
    if (state.roadList.isEmpty) {
      KazumiLogger().log(Level.warning, '尝试切换剧集时播放列表为空 episode: $episode');
      return;
    }
    if (currentRoad >= state.roadList.length) {
      KazumiLogger()
          .log(Level.warning, '尝试切换剧集时播放列表索引越界 currentRoad: $currentRoad');
      return;
    }
    if (episode <= 0 || episode > state.roadList[currentRoad].data.length) {
      KazumiLogger().log(Level.warning,
          '尝试切换剧集时集数越界 episode: $episode currentRoad: $currentRoad');
      return;
    }
    currentEpisode = episode;
    this.currentRoad = currentRoad;
    historyOffset = offset;
    final chapterName = state.roadList[currentRoad].identifier[episode - 1];
    KazumiLogger().log(Level.info, '跳转到$chapterName');
    var urlItem = state.roadList[currentRoad].data[episode - 1];
    final plugin = currentPlugin;
    if (!urlItem.contains(plugin.baseUrl) &&
        !urlItem.contains(plugin.baseUrl.replaceAll('https', 'http'))) {
      urlItem = plugin.baseUrl + urlItem;
    }
    await webviewController.loadUrl(
      urlItem,
      plugin.useNativePlayer,
      plugin.useLegacyParser,
      offset: offset,
    );
  }

  Future<void> queryBangumiEpisodeCommentsByID(int id, int episode) async {
    clearEpisodeComments();
    episodeInfo = await BangumiHTTP.getBangumiEpisodeByID(id, episode);
    final result =
        await BangumiHTTP.getBangumiCommentsByEpisodeID(episodeInfo.id);
    addEpisodeComments(result.commentList);
    KazumiLogger().log(Level.info, '已加载评论列表长度 ${state.episodeComments.length}');
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
      KazumiLogger().log(Level.warning, '未找到源 $pluginName');
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
      KazumiLogger().log(Level.info, '播放列表长度 ${state.roadList.length}');
      if (state.roadList.isNotEmpty) {
        KazumiLogger()
            .log(Level.info, '第一播放列表选集数 ${state.roadList.first.data.length}');
      }
    } catch (e) {
      KazumiLogger().log(Level.error, '查询播放列表失败: $e');

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
