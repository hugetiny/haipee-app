import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';

/// Torznab standard category numbers and bidirectional mapping with Kazumi's TorrentCategory.
class TorznabCategories {
  // 1000 Audio
  static const int audio = 1000;
  static const int audioMp3 = 1010;
  static const int audioVideo = 1020;
  static const int audioAudiobook = 1030;
  static const int audioLossless = 1040;
  static const int audioOther = 1050;
  static const int audioForeign = 1060;

  // 2000 Movies
  static const int movies = 2000;
  static const int moviesForeign = 2010;
  static const int moviesOther = 2020;
  static const int moviesSd = 2030;
  static const int moviesHd = 2040;
  static const int moviesUhd = 2045;
  static const int moviesBluray = 2050;
  static const int movies3d = 2060;
  static const int moviesDvd = 2070;
  static const int moviesWebDl = 2080;

  // 3000 Books
  static const int books = 3000;
  static const int booksEbook = 3010;
  static const int booksComics = 3020;
  static const int booksMagazines = 3030;
  static const int booksTechnical = 3040;
  static const int booksOther = 3050;

  // 4000 PC
  static const int pc = 4000;
  static const int pc0day = 4010;
  static const int pcIso = 4020;
  static const int pcMac = 4030;
  static const int pcMobileOther = 4040;
  static const int pcGames = 4050;
  static const int pcMobileIos = 4060;
  static const int pcMobileAndroid = 4070;

  // 5000 TV
  static const int tv = 5000;
  static const int tvWebDl = 5010;
  static const int tvForeign = 5020;
  static const int tvSd = 5030;
  static const int tvHd = 5040;
  static const int tvUhd = 5045;
  static const int tvOther = 5050;
  static const int tvSport = 5060;
  static const int tvAnime = 5070;
  static const int tvDocumentary = 5080;

  // 6000 XXX
  static const int xxx = 6000;

  // 7000 Other
  static const int other = 7000;

  /// Maps a standard Torznab category integer to Kazumi's TorrentCategory.
  static TorrentCategory toTorrentCategory(int torznabCat) => switch (torznabCat) {
    pcGames || (>= 10000 && < 11000) => TorrentCategory.game,
    >= 1000 && < 2000 => TorrentCategory.audio,
    >= 2000 && < 3000 => TorrentCategory.video,
    >= 3000 && < 4000 => TorrentCategory.document,
    >= 4000 && < 5000 => TorrentCategory.software,
    >= 5000 && < 6000 => TorrentCategory.video,
    _ => TorrentCategory.all,
  };

  /// Maps Kazumi's TorrentCategory back to standard Torznab category integer list.
  static List<int> fromTorrentCategory(TorrentCategory category) => switch (category) {
    TorrentCategory.all => const [],
    TorrentCategory.video => const [movies, tv, tvAnime],
    TorrentCategory.audio => const [audio],
    TorrentCategory.software => const [pc],
    TorrentCategory.game => const [pcGames, 10000],
    TorrentCategory.document => const [books],
  };

  /// Parses an integer or text category (e.g. "Movies/HD", "TV", "Anime") to a canonical Torznab integer.
  static int parseCategory(dynamic raw) {
    if (raw == null) return 7000;
    if (raw is int) return raw;
    final str = raw.toString().trim();
    final parsed = int.tryParse(str);
    if (parsed != null) return parsed;

    final lower = str.toLowerCase();
    if (lower.startsWith('movies')) return movies;
    if (lower.startsWith('tv') || lower.startsWith('television')) {
      if (lower.contains('anime')) return tvAnime;
      return tv;
    }
    if (lower.startsWith('anime')) return tvAnime;
    if (lower.startsWith('audio') || lower.startsWith('music')) return audio;
    if (lower.startsWith('book') || lower.startsWith('ebook') || lower.startsWith('comic')) return books;
    if (lower.startsWith('pc') || lower.startsWith('software') || lower.startsWith('app')) {
      if (lower.contains('game')) return pcGames;
      return pc;
    }
    if (lower.startsWith('game') || lower.contains('console')) return pcGames;
    return 7000;
  }
}
