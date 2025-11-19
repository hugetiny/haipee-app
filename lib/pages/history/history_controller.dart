import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HistoryState {
  final List<History> histories;
  const HistoryState({this.histories = const []});

  HistoryState copyWith({List<History>? histories}) =>
      HistoryState(histories: histories ?? this.histories);
}

class HistoryController extends Notifier<HistoryState> {
  @override
  HistoryState build() {
    return HistoryState(histories: _sortedHistories());
  }

  get setting => GStorage.setting;
  MockBox<History> get storedHistories => GStorage.histories;

  List<History> _sortedHistories() {
    return List<History>.from(storedHistories.values)
      ..sort((a, b) =>
          b.lastWatchTime.millisecondsSinceEpoch -
          a.lastWatchTime.millisecondsSinceEpoch);
  }

  void refreshHistories() {
    state = state.copyWith(histories: _sortedHistories());
  }

  void updateHistory(
    int episode,
    int road,
    String adapterName,
    BangumiItem bangumiItem,
    Duration progress,
    String lastSrc,
    String lastWatchEpisodeName,
  ) {
  final privateMode =
    setting.get(SettingBoxKey.privateMode, defaultValue: false);
  if (privateMode) {
    return;
  }

    final key = History.getKey(adapterName, bangumiItem);
    final history = storedHistories.get(key) ??
        History(bangumiItem, episode, adapterName, DateTime.now(), lastSrc,
            lastWatchEpisodeName);

    history.lastWatchEpisode = episode;
    history.lastWatchTime = DateTime.now();
    if (lastSrc.isNotEmpty) {
      history.lastSrc = lastSrc;
    }
    if (lastWatchEpisodeName.isNotEmpty) {
      history.lastWatchEpisodeName = lastWatchEpisodeName;
    }

    final prog = history.progresses[episode];
    if (prog == null) {
      history.progresses[episode] =
          Progress(episode, road, progress.inMilliseconds);
    } else {
      prog.progress = progress;
    }

    storedHistories.put(history.key, history);
    refreshHistories();
  }

  Progress? lastWatching(BangumiItem bangumiItem, String adapterName) {
    final history =
        storedHistories.get(History.getKey(adapterName, bangumiItem));
    return history?.progresses[history.lastWatchEpisode];
  }

  Progress? findProgress(
      BangumiItem bangumiItem, String adapterName, int episode) {
    final history =
        storedHistories.get(History.getKey(adapterName, bangumiItem));
    return history?.progresses[episode];
  }

  void deleteHistory(History history) {
    storedHistories.delete(history.key);
    refreshHistories();
  }

  void clearProgress(BangumiItem bangumiItem, String adapterName, int episode) {
    final history =
        storedHistories.get(History.getKey(adapterName, bangumiItem));
    history?.progresses[episode]?.progress = Duration.zero;
    refreshHistories();
  }

  void clearAll() {
    GStorage.histories.clear();
    state = state.copyWith(histories: []);
  }
}
