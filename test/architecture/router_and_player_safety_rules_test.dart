import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('架构级静态防崩溃门禁 (Router & Player Safety Guards)', () {
    test('1. 路由安全规范：lib/router.dart 严禁对 state.extra 进行无 is 守卫的强转 (as)', () {
      final routerFile = File('lib/router.dart');
      expect(routerFile.existsSync(), isTrue);

      final content = routerFile.readAsStringSync();
      final lines = content.split('\n');
      final unsafeCastViolations = <String>[];

      final directAsRegex = RegExp(r'state\.extra\s+as\s+[A-Za-z0-9_<>]+');

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//') || line.startsWith('/*') || line.startsWith('*')) {
          continue;
        }
        if (directAsRegex.hasMatch(line)) {
          // 检查当前行及前两行是否包含 `state.extra is ` 类型守卫
          final windowStart = (i - 2).clamp(0, lines.length - 1);
          final contextSnippet = lines.sublist(windowStart, i + 1).join(' ');
          final hasSafeIsCheck = contextSnippet.contains('state.extra is ');
          if (!hasSafeIsCheck) {
            unsafeCastViolations.add('lib/router.dart:${i + 1} -> $line');
          }
        }
      }

      expect(
        unsafeCastViolations,
        isEmpty,
        reason: '发现 lib/router.dart 存在未加 `state.extra is T` 判断的直接强转！'
            '当通过命名路由、深链、浏览器刷新或迷你播放条无参跳转时将直接抛出 _TypeError 崩溃。\n'
            '违规位置：\n${unsafeCastViolations.join('\n')}',
      );
    });

    test('2. 播放器模块安全规范：lib/pages/player/ 全目录严禁调用非空抛错的 currentPlugin，必须使用 currentPluginOrNull', () {
      final playerDir = Directory('lib/pages/player');
      expect(playerDir.existsSync(), isTrue);

      final violations = <String>[];
      // 匹配 `.currentPlugin` 但排除 `.currentPluginOrNull`
      final unsafePluginGetter = RegExp(r'\.currentPlugin(?!OrNull)\b');

      for (final file in playerDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('//')) continue;
          if (unsafePluginGetter.hasMatch(line)) {
            violations.add('${file.path}:${i + 1} -> $line');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: '播放器模块同时服务于 B站原生直链、本地文件、磁力边下边播与多源规则，'
            '严禁直接访问 `.currentPlugin`（无活跃插件时会抛 Null check operator 异常），必须统一使用 `.currentPluginOrNull`！\n'
            '违规位置：\n${violations.join('\n')}',
      );
    });

    test('3. 播放内核解耦规范：mpv 高频内部流日志不得污染全局 AppLog，且 Media 请求头必须剔除重复 UA/Referer', () {
      final controllerFile = File('lib/pages/player/player_controller.dart');
      expect(controllerFile.existsSync(), isTrue);
      final content = controllerFile.readAsStringSync();

      // 确保 stream.log 回调内部不会向 HaipeeLogger().simpleLog 或 AppLog 刷屏输出
      final streamLogMatch = RegExp(
        r'stream\.log\.listen\(\(event\)\s*\{([\s\S]*?)\}\);',
      ).firstMatch(content);
      expect(streamLogMatch, isNotNull, reason: '应保留 mpv stream.log 环形缓冲监听');
      final listenerBody = streamLogMatch!.group(1) ?? '';
      expect(
        listenerBody.contains('simpleLog') || listenerBody.contains('AppLog.'),
        isFalse,
        reason: 'mpv 底层内部日志必须与全局 AppLog 系统解耦，仅保留在播放器环形缓冲中按需排查！',
      );

      // 确保 Media(..., httpHeaders: ...) 使用的是剥离了 User-Agent / Referer 后的 extraMpvHeaders
      expect(
        content.contains('extractExtraMpvHeaders'),
        isTrue,
        reason: 'PlayerController 必须通过 extractExtraMpvHeaders 剥离已通过 mpv 属性设置的 User-Agent/Referer，防止发送重复请求头触发 CDN 503/403。',
      );
    });

    test('4. PopScope 防死循环规范：包含 PopScope(canPop: false) 的页面严禁在回调内调用 maybePop()', () {
      final libDir = Directory('lib');
      final violations = <String>[];

      for (final file in libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final content = file.readAsStringSync();
        if (content.contains('PopScope') &&
            RegExp(r'canPop\s*:\s*false').hasMatch(content)) {
          final lines = content.split('\n');
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.startsWith('//')) continue;
            if (line.contains('.maybePop(')) {
              violations.add('${file.path}:${i + 1} -> $line');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: '在 PopScope(canPop: false) 拦截器内调用 Navigator.maybePop() 会再次触发 onPopInvokedWithResult 导致无限递归卡死！'
            '请改用 Navigator.of(ctx).pop() (配合 canPop() 兜底)。\n'
            '违规位置：\n${violations.join('\n')}',
      );
    });

    test('5. 主流响应式顶栏规范：一级业务页面右上角严禁堆砌冗余的规则设置跳转、一级菜单重复链接或独立BT弹窗按钮', () {
      final primaryPages = <String>[
        'lib/pages/online/online_video_search_page.dart',
        'lib/pages/resource/resource_search_page.dart',
        'lib/pages/media_library/media_library_page.dart',
      ];

      for (final path in primaryPages) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '缺少核心文件: $path');
        final content = file.readAsStringSync();

        // 严禁在视频直播、全网资源、媒体库的 SysAppBar 中塞入 actions 按钮
        final sysAppBarMatch = RegExp(
          r'SysAppBar\s*\(([\s\S]*?)\)\s*,',
        ).firstMatch(content);
        expect(sysAppBarMatch, isNotNull, reason: '$path 应使用 SysAppBar');
        final appBarBody = sysAppBarMatch!.group(1) ?? '';
        expect(
          appBarBody.contains('actions:'),
          isFalse,
          reason: '$path 的 SysAppBar 严禁包含冗余右上角 actions 按钮（规则与下载设置统一由「设置」管理，下载管理/媒体库子项已有主导航或侧边栏）！',
        );
      }

      // 进一步确认 OnlineVideoSearchPage 与 SearchPage 不再引入独立的 TorrentSearchSheet 弹窗
      final onlineContent =
          File('lib/pages/online/online_video_search_page.dart').readAsStringSync();
      expect(
        onlineContent.contains('TorrentSearchSheet'),
        isFalse,
        reason: '视频直播页面严禁包含独立的 TorrentSearchSheet 弹窗入口！',
      );

      final downloadContent =
          File('lib/pages/download/download_page.dart').readAsStringSync();
      expect(
        downloadContent.contains("context.push('/settings/download')"),
        isFalse,
        reason: '下载管理页面右上角严禁包含重复的「下载设置」跳转按钮（全部设置统一在设置页管理）！',
      );
    });

    test('6. 统一搜索工作区组件复用规范：视频直播与全网资源必须共用 UnifiedSearchWorkspace 标准组件体系且同时具备 Grid View 与 Table View', () {
      final onlinePage =
          File('lib/pages/online/online_video_search_page.dart').readAsStringSync();
      final resourcePage =
          File('lib/pages/resource/resource_search_page.dart').readAsStringSync();
      final resourceContent =
          File('lib/pages/resource/resource_search_content.dart').readAsStringSync();

      // 两大板块一级入口必须同时复用 UnifiedSearchHeader
      expect(
        onlinePage.contains('UnifiedSearchHeader('),
        isTrue,
        reason: 'OnlineVideoSearchPage 必须复用全局 UnifiedSearchHeader 组件',
      );
      expect(
        resourcePage.contains('UnifiedSearchHeader('),
        isTrue,
        reason: 'ResourceSearchPage 必须复用全局 UnifiedSearchHeader 组件',
      );

      // 两大板块必须同时复用 UnifiedFilterPanelContainer / UnifiedFilterCategoryRow / UnifiedFilterChoiceChip / UnifiedSearchResultSummaryBar / UnifiedRuleReadinessCard
      for (final comp in const [
        'UnifiedFilterPanelContainer(',
        'UnifiedFilterCategoryRow(',
        'UnifiedFilterChoiceChip(',
        'UnifiedSearchResultSummaryBar(',
        'UnifiedRuleReadinessCard(',
      ]) {
        expect(
          onlinePage.contains(comp),
          isTrue,
          reason: 'OnlineVideoSearchPage 必须复用标准组件 $comp',
        );
        expect(
          resourceContent.contains(comp),
          isTrue,
          reason: 'ResourceSearchContent 必须复用标准组件 $comp',
        );
      }

      // 两大板块必须同时具备 Grid View 与 Table View 实现
      expect(
        onlinePage.contains('_buildVideoTableView(') &&
            onlinePage.contains('SliverGrid('),
        isTrue,
        reason: 'OnlineVideoSearchPage 必须同时支持 Grid View (SliverGrid) 与 Table View (_buildVideoTableView)',
      );
      expect(
        resourceContent.contains('_buildXunleiTableView(') &&
            resourceContent.contains('GridView.builder('),
        isTrue,
        reason: 'ResourceSearchContent 必须同时支持 Table View (_buildXunleiTableView) 与 Grid View (GridView.builder)',
      );
    });
  });
}
