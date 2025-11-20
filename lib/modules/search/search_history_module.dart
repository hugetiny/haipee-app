class SearchHistory {
  String keyword;

  int timestamp;

  SearchHistory(this.keyword, this.timestamp);

  String get key => timestamp.toString();

  Map<String, dynamic> toJson() => {
        'keyword': keyword,
        'timestamp': timestamp,
      };

  @override
  String toString() {
    return 'Search keyword: $keyword, search time: ${DateTime.fromMillisecondsSinceEpoch(timestamp)}';
  }
}
