import 'package:haipee/modules/torrent_search/models/torrent_item.dart';

abstract class TorrentSource {
  String get name;
  TorrentSourceType get type;
  bool get enabled;

  Future<List<TorrentItem>> search(String keyword);
}
