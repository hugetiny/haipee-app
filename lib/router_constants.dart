/// 路由常量定义
///
/// 集中管理所有路由路径，避免魔法字符串
/// 提供类型安全的路由导航
class Routes {
  Routes._(); // 私有构造函数，防止实例化

  // ==================== Tab 路由 ====================
  /// 在线视频搜索引擎页（一级主导航 1）
  static const String onlineVideo = '/tab/online';

  /// 热门番剧页
  static const String popular = '/tab/popular';

  /// 追番时间表页
  static const String timeline = '/tab/timeline';

  /// 资源搜索页（一级菜单）
  static const String resource = '/tab/resource';

  /// 媒体分类页
  static const String media = '/tab/media';

  /// 我的收藏页
  static const String my = '/tab/my';

  /// 下载管理页
  static const String download = '/tab/download';

  /// 设置页
  static const String settings = '/tab/setting';

  // ==================== 功能路由 ====================
  /// 视频播放页
  static const String video = '/video';
  static const String localPlayer = '/player/local';

  /// 番剧详情页
  static const String info = '/info';

  /// 搜索页
  static const String search = '/search';

  /// 收藏页面
  static const String favorites = '/my/favorites';

  /// 观看历史页
  static const String history = '/my/history';

  // ==================== 设置路由 ====================
  /// 设置根路径（重定向到主题设置）
  static const String settingsRoot = '/settings';

  /// 主题设置
  static const String settingsTheme = '/settings/theme';

  /// 显示模式设置
  static const String settingsThemeDisplay = '/settings/theme/display';

  /// 语言设置
  static const String settingsLanguage = '/settings/language';

  /// 退出行为设置
  static const String settingsExitBehavior = '/settings/exit-behavior';

  /// 播放器设置
  static const String settingsPlayer = '/settings/player';

  /// 解码器设置
  static const String settingsPlayerDecoder = '/settings/player/decoder';

  /// 超分辨率设置
  static const String settingsPlayerSuper = '/settings/player/super';

  /// 弹幕设置
  static const String settingsDanmaku = '/settings/danmaku';

  /// 弹幕屏蔽设置
  static const String settingsDanmakuShield = '/settings/danmaku/shield';

  /// 统一规则管理中心
  static const String settingsRuleCenter = '/settings/rules';

  /// 插件设置
  static const String settingsPlugin = '/settings/plugin';

  /// 插件编辑器
  static const String settingsPluginEditor = '/settings/plugin/editor';

  /// 插件商店
  static const String settingsPluginShop = '/settings/plugin/shop';

  /// 索引器与在线源设置
  static const String settingsIndexers = '/settings/indexers';

  /// 视听与媒体设置
  static const String settingsMedia = '/settings/media';

  /// 媒体元数据与刮削设置
  static const String settingsMetadata = '/settings/metadata';

  /// 下载引擎设置
  static const String settingsDownload = '/settings/download';

  /// WebDAV 设置
  static const String settingsWebdav = '/settings/webdav';

  /// WebDAV 编辑器
  static const String settingsWebdavEditor = '/settings/webdav/editor';

  /// 关于页面
  static const String settingsAbout = '/settings/about';

  /// 日志页面
  static const String settingsAboutLogs = '/settings/about/logs';

  /// 开源许可页面
  static const String settingsAboutLicense = '/settings/about/license';

  // ==================== 路由构造方法 ====================

  /// 构造搜索路由（带标签参数）
  ///
  /// 示例: `Routes.searchWithTag('动作')`
  static String searchWithTag(String tag) {
    return '$search?tag=${Uri.encodeComponent(tag)}';
  }

  /// 获取查询参数中的标签
  ///
  /// 示例: `Routes.getSearchTag(state.uri.queryParameters)`
  static String getSearchTag(Map<String, String> params) {
    return params['tag'] ?? '';
  }
}
