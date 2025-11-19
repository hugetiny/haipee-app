class SearchHistory {
  String keyword;

  int timestamp;

  SearchHistory(this.keyword, this.timestamp);

  String get key => timestamp.toString();

  @override
  String toString() {
    return 'Search keyword: $keyword, search time: ${DateTime.fromMillisecondsSinceEpoch(timestamp)}';
  }
}
