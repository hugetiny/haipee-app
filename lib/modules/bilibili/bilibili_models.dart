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
  final String ruleType;

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
    this.ruleType = '',
  });

  String get resolvedRuleType {
    if (ruleType.isNotEmpty) {
      final clean = ruleType.trim().toLowerCase();
      if (clean == 'tvbox' || clean == 'fongmi' || clean == 'box') return 'tvbox';
      if (clean == 'maccms' || clean == '2' || clean == 'vod' || clean == 'applecms') return 'maccms';
      if (clean == 'iptv' || clean == 'live' || clean == 'm3u' || clean == 'm3u8') return 'iptv';
      if (clean == 'piped' || clean == 'youtube' || clean == 'bilibili' || clean == 'douyin') return 'piped';
      if (clean == 'alist' || clean == 'drive' || clean == 'pan' || clean == 'webdav') return 'alist';
      if (clean == 'cardigann' || clean == 'bt' || clean == 'torrent' || clean == 'magnet') return 'cardigann';
      return 'haipee';
    }
    if (bvid.startsWith('douyin_') || tag.contains('抖音')) return 'piped';
    if (bvid.startsWith('BV') || tag.contains('B站') || tag.contains('哔哩')) return 'piped';
    if (tag.contains('直播') || tag.contains('IPTV')) return 'iptv';
    if (tag.contains('TVBox') || tag.contains('tvbox') || tag.contains('盒子')) return 'tvbox';
    if (tag.contains('苹果CMS') || tag.contains('采集') || tag.contains('MacCMS') || tag.contains('maccms')) return 'maccms';
    if (tag.contains('网盘') || tag.contains('alist') || tag.contains('AList')) return 'alist';
    if (tag.contains('BT') || tag.contains('磁力') || tag.contains('Cardigann')) return 'cardigann';
    return 'haipee';
  }

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
  final List<BiliStreamQuality> availableQualities;

  const BiliPlayUrl({
    required this.videoUrl,
    this.audioUrl,
    required this.quality,
    this.format = 'dash',
    required this.headers,
    this.availableQualities = const [],
  });

  String get qualityLabel => BiliQualityHelper.getLabel(quality);
}

/// 可用画质选项
class BiliStreamQuality {
  final int id;
  final String label;
  final String format;

  const BiliStreamQuality({
    required this.id,
    required this.label,
    required this.format,
  });
}

/// B站扫码登录二维码数据
class BiliQrCodeData {
  final String url;
  final String qrcodeKey;

  const BiliQrCodeData({
    required this.url,
    required this.qrcodeKey,
  });
}

/// 二维码轮询状态枚举
enum BiliQrCodeStatus {
  notScanned(86101, '未扫码，等待扫描'),
  scannedWaitingConfirmation(86090, '已扫码，请在手机端确认'),
  expired(86038, '二维码已过期，请刷新'),
  success(0, '登录成功'),
  error(-1, '登录异常');

  final int code;
  final String description;
  const BiliQrCodeStatus(this.code, this.description);
}

/// 二维码轮询结果
class BiliQrCodePollResult {
  final BiliQrCodeStatus status;
  final String message;
  final String? sessData;
  final String? biliJct;
  final String? dedeUserId;

  const BiliQrCodePollResult({
    required this.status,
    required this.message,
    this.sessData,
    this.biliJct,
    this.dedeUserId,
  });
}

/// B站已登录用户画像
class BiliUserProfile {
  final bool isLogin;
  final int mid;
  final String uname;
  final String face;
  final int vipType; // 0: 无, 1: 月度大会员, 2: 年度/十年大会员
  final String vipLabel;
  final int vipDueDate;

  const BiliUserProfile({
    required this.isLogin,
    required this.mid,
    required this.uname,
    required this.face,
    required this.vipType,
    required this.vipLabel,
    required this.vipDueDate,
  });

  bool get isVip => vipType > 0;

  factory BiliUserProfile.fromJson(Map<String, dynamic> json) {
    return BiliUserProfile(
      isLogin: json['isLogin'] == true,
      mid: json['mid'] is int ? json['mid'] : int.tryParse(json['mid']?.toString() ?? '0') ?? 0,
      uname: json['uname']?.toString() ?? '',
      face: json['face']?.toString() ?? '',
      vipType: json['vipType'] is int ? json['vipType'] : 0,
      vipLabel: json['vipLabel']?.toString() ?? '',
      vipDueDate: json['vipDueDate'] is int ? json['vipDueDate'] : 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'isLogin': isLogin,
        'mid': mid,
        'uname': uname,
        'face': face,
        'vipType': vipType,
        'vipLabel': vipLabel,
        'vipDueDate': vipDueDate,
      };
}

/// B站清晰度对照字典
class BiliQualityHelper {
  static const Map<int, String> qualityMap = {
    127: '8K 超高清',
    126: '杜比视界',
    125: 'HDR 真彩',
    120: '4K 超清',
    116: '1080P 60帧',
    112: '1080P 高码率',
    80: '1080P 高清',
    74: '720P 60帧',
    64: '720P 高清',
    32: '480P 清晰',
    16: '360P 流畅',
  };

  static String getLabel(int quality) => qualityMap[quality] ?? '${quality}P';
}
