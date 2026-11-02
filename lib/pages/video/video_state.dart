import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/modules/bangumi/episode_item.dart';
import 'package:haipee/modules/comments/comment_item.dart';
import 'package:haipee/modules/roads/road_module.dart';
import 'package:haipee/plugins/plugins.dart';

part 'video_state.freezed.dart';

@freezed
class VideoPageState with _$VideoPageState {
  const factory VideoPageState({
    BangumiItem? bangumiItem,
    required EpisodeInfo episodeInfo,
    @Default([]) List<EpisodeCommentItem> episodeComments,
    required bool loading,
    required int currentEpisode,
    required int currentRoad,
    required bool isFullscreen,
    required bool isPip,
    required bool showTabBody,
    required int historyOffset,
    required String title,
    required String src,
    @Default([]) List<Road> roadList,
    Plugin? currentPlugin,
  }) = _VideoPageState;

  factory VideoPageState.initial() => VideoPageState(
        bangumiItem: null,
        episodeInfo: EpisodeInfo.fromTemplate(),
        episodeComments: const [],
        loading: true,
        currentEpisode: 1,
        currentRoad: 0,
        isFullscreen: false,
        isPip: false,
        showTabBody: true,
        historyOffset: 0,
        title: '',
        src: '',
        roadList: const [],
        currentPlugin: null,
      );
}
