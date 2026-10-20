/// B站 (Bilibili) 核心数据模型
class BiliVideoItem {
  final String bvid;
  final String title;
  final String author;
  final String pic;
  final int play;
  final int danmaku;
  final String duration;
  final int pubdate;
  final String description;
  final String tag;

  const BiliVideoItem({
    required this.bvid,
    required this.title,
    required this.author,
    required this.pic,
    this.play = 0,
    this.danmaku = 0,
    this.duration = '',
    this.pubdate = 0,
    this.description = '',
    this.tag = '',
  });

  factory BiliVideoItem.fromJson(Map<String, dynamic> json) {
    // 过滤标题中的 HTML 标签 (如 <em class="keyword">...</em>)
    String rawTitle = json['title'] ?? '';
    rawTitle = rawTitle.replaceAll(RegExp(r'<[^>]*>'), '');

    String picUrl = json['pic'] ?? '';
    if (picUrl.startsWith('//')) {
      picUrl = 'https:$picUrl';
    }

    int parseStat(dynamic val) {
      if (val is int) return val;
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return BiliVideoItem(
      bvid: json['bvid'] ?? '',
      title: rawTitle,
      author: json['author'] ?? json['owner']?['name'] ?? '',
      pic: picUrl,
      play: parseStat(json['play'] ?? json['stat']?['view']),
      danmaku: parseStat(json['video_review'] ?? json['stat']?['danmaku']),
      duration: json['duration']?.toString() ?? '',
      pubdate: json['pubdate'] is int ? json['pubdate'] : 0,
      description: json['description'] ?? '',
      tag: json['tag'] ?? '',
    );
  }
}

/// B站视频详情（包含分P列表）
class BiliVideoDetail {
  final String bvid;
  final int aid;
  final String title;
  final String pic;
  final String desc;
  final String ownerName;
  final String ownerFace;
  final int view;
  final int danmaku;
  final List<BiliVideoPart> parts;

  const BiliVideoDetail({
    required this.bvid,
    required this.aid,
    required this.title,
    required this.pic,
    required this.desc,
    required this.ownerName,
    required this.ownerFace,
    required this.view,
    required this.danmaku,
    required this.parts,
  });

  factory BiliVideoDetail.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    String picUrl = data['pic'] ?? '';
    if (picUrl.startsWith('//')) picUrl = 'https:$picUrl';

    final pages = (data['pages'] as List<dynamic>?) ?? [];
    final parts = pages
        .map((p) => BiliVideoPart.fromJson(p as Map<String, dynamic>))
        .toList();

    return BiliVideoDetail(
      bvid: data['bvid'] ?? '',
      aid: data['aid'] is int ? data['aid'] : 0,
      title: data['title'] ?? '',
      pic: picUrl,
      desc: data['desc'] ?? '',
      ownerName: data['owner']?['name'] ?? '',
      ownerFace: data['owner']?['face'] ?? '',
      view: data['stat']?['view'] is int ? data['stat']['view'] : 0,
      danmaku: data['stat']?['danmaku'] is int ? data['stat']['danmaku'] : 0,
      parts: parts,
    );
  }
}

/// B站分P/集数条目
class BiliVideoPart {
  final int cid;
  final int page;
  final String part;
  final int duration;

  const BiliVideoPart({
    required this.cid,
    required this.page,
    required this.part,
    required this.duration,
  });

  factory BiliVideoPart.fromJson(Map<String, dynamic> json) {
    return BiliVideoPart(
      cid: json['cid'] is int ? json['cid'] : int.tryParse(json['cid'].toString()) ?? 0,
      page: json['page'] is int ? json['page'] : 1,
      part: json['part'] ?? '第${json['page'] ?? 1}集',
      duration: json['duration'] is int ? json['duration'] : 0,
    );
  }
}

/// B站解析后的播放流信息 (DASH 音视频分离流)
class BiliPlayUrl {
  final String videoUrl;
  final String? audioUrl;
  final int quality;
  final String format; // 'dash' 或 'durl'
  final Map<String, String> headers;

  const BiliPlayUrl({
    required this.videoUrl,
    this.audioUrl,
    required this.quality,
    this.format = 'dash',
    required this.headers,
  });
}
