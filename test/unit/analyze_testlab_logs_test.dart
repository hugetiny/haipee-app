import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/analyze_testlab_logs.dart';

void main() {
  group('TestLabAnalyzer 确定性日志分析器测试套件', () {
    late Directory tempDir;
    late Directory tempAndroidDir;
    late Directory tempIosDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('testlab_analyzer_test_');
      tempAndroidDir = Directory('${tempDir.path}/android');
      tempIosDir = Directory('${tempDir.path}/ios');
      await tempAndroidDir.create(recursive: true);
      await tempIosDir.create(recursive: true);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('空目录与缺失文件防御性处理：平稳输出 0 崩溃与完整统计', () async {
      final analyzer = TestLabAnalyzer(androidDir: tempAndroidDir, iosDir: tempIosDir);
      await analyzer.runAnalysis();

      expect(analyzer.issues, isEmpty);
      expect(analyzer.crawlStats['Android']?.totalActions, 0);
      expect(analyzer.crawlStats['iOS']?.totalActions, 0);

      final mdReport = analyzer.generateMarkdownReport();
      expect(mdReport, contains('未发现任何异常或缺陷'));
      expect(mdReport, contains('零未知准则 (Zero-Unknown Policy)'));
    });

    test('精准解析 iOS Info.plist 缺失 BackgroundTasks 报错并 100% 确定性分类', () async {
      final syslog = File('${tempIosDir.path}/syslog.txt');
      await syslog.writeAsString('''
Oct 27 04:39:05 iPhone Runner[740] <Notice>: Launching app
Oct 27 04:39:06 iPhone Runner(BackgroundTasks)[740] <Error>: Registration rejected; com.pravera.flutter_foreground_task.refresh is not advertised in the application's Info.plist
Oct 27 04:39:07 iPhone Runner[740] <Notice>: Finished launch
''');

      final analyzer = TestLabAnalyzer(androidDir: tempAndroidDir, iosDir: tempIosDir);
      await analyzer.runAnalysis();

      final bgIssues = analyzer.issues.where((e) => e.category == IssueCategory.iosBackgroundTaskConfigMissing).toList();
      expect(bgIssues.length, 1);
      final issue = bgIssues.first;
      expect(issue.id, 'ISSUE-IOS-BG-TASK');
      expect(issue.severity, IssueSeverity.error);
      expect(issue.platform, 'iOS');
      expect(issue.categoryDisplayName, contains('BackgroundTasks'));
      expect(issue.isFixed, isTrue);
      expect(issue.title, isNot(contains('Unknown')));
      expect(issue.title, isNot(contains('未知')));
    });

    test('精准解析 Android documentsui 爬虫超时陷阱并归类为 Crawler Stagnation', () async {
      final crawlScript = File('${tempAndroidDir.path}/crawlscript.json');
      await crawlScript.writeAsString(jsonEncode({
        'roboscript': {
          'actions': [
            {'contentDescription': '更改'},
            {'className': 'com.android.documentsui.picker.PickActivity'}
          ]
        }
      }));

      final analyzer = TestLabAnalyzer(androidDir: tempAndroidDir, iosDir: tempIosDir);
      await analyzer.runAnalysis();

      final trapIssues = analyzer.issues.where((e) => e.category == IssueCategory.androidCrawlerStagnation).toList();
      expect(trapIssues.length, 1);
      final issue = trapIssues.first;
      expect(issue.id, 'ISSUE-AND-DOCSUI-TRAP');
      expect(issue.severity, IssueSeverity.warning);
      expect(issue.platform, 'Android');
      expect(issue.sourceLocation, contains('selective_download_dialog.dart'));
    });

    test('精准解析 actions.json 统计数据与失败动作详情', () async {
      final actions = File('${tempIosDir.path}/actions.json');
      await actions.writeAsString(jsonEncode({
        'events': [
          {'sequence': 1, 'sourceScreenId': '1', 'destinationScreenId': '1', 'executionResult': 'SUCCESS'},
          {'sequence': 2, 'sourceScreenId': '1', 'destinationScreenId': '2', 'executionResult': 'SUCCESS'},
          {'sequence': 3, 'sourceScreenId': '2', 'destinationScreenId': '2', 'executionResult': 'FAILED', 'target': {'type': 'SWIPE', 'className': 'UIScrollView'}},
        ]
      }));

      final analyzer = TestLabAnalyzer(androidDir: tempAndroidDir, iosDir: tempIosDir);
      await analyzer.runAnalysis();

      final stats = analyzer.crawlStats['iOS'];
      expect(stats, isNotNull);
      expect(stats!.totalActions, 3);
      expect(stats.successfulActions, 2);
      expect(stats.failedActions, 1);
      expect(stats.uniqueScreensVisited, 2);

      final swipeFailures = analyzer.issues.where((e) => e.category == IssueCategory.iosAccessibilityGestureFailure).toList();
      expect(swipeFailures.length, 1);
    });

    test('精准解析 Android & iOS 中的 Flutter RenderFlex 像素溢出错误', () async {
      final androidLogcat = File('${tempAndroidDir.path}/logcat');
      await androidLogcat.writeAsString('''
10-27 04:37:58.711 25456 25488 E flutter : ══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞══
10-27 04:37:58.711 25456 25488 E flutter : A RenderFlex overflowed by 48 pixels on the bottom.
10-27 04:37:58.711 25456 25488 E Kazumi  : [KAZUMI_OVERFLOW] RenderFlex layout overflow: bottom 48px
''');

      final iosSyslog = File('${tempIosDir.path}/syslog.txt');
      await iosSyslog.writeAsString('''
Oct 27 04:39:10 iPhone Runner(Flutter)[740] <Error>: A RenderFlex overflowed by 22 pixels on the right.
''');

      final analyzer = TestLabAnalyzer(androidDir: tempAndroidDir, iosDir: tempIosDir);
      await analyzer.runAnalysis();

      final overflows = analyzer.issues.where((e) => e.category == IssueCategory.flutterRenderFlexOverflow).toList();
      expect(overflows.length, 2);
      expect(overflows.any((e) => e.platform == 'Android'), isTrue);
      expect(overflows.any((e) => e.platform == 'iOS'), isTrue);
      for (final overflow in overflows) {
        expect(overflow.severity, IssueSeverity.error);
        expect(overflow.isFixed, isFalse);
      }
    });

    test('精准解析 Flutter 未捕获 Dart 异常并提取异常类型', () async {
      final androidLogcat = File('${tempAndroidDir.path}/logcat');
      await androidLogcat.writeAsString('''
10-27 04:37:58.711 25456 25488 E Kazumi  : [2026-10-27 04:37:58.711] [ERROR] [system] [KAZUMI_ERROR] Flutter unhandled error: RangeError (index): Invalid value: Valid value range is empty: 0
10-27 04:37:58.712 25456 25488 E flutter : [ERROR:flutter/runtime/dart_vm_initializer.cc(41)] Unhandled Exception: FormatException: Unexpected character (at character 1)
''');

      final analyzer = TestLabAnalyzer(androidDir: tempAndroidDir, iosDir: tempIosDir);
      await analyzer.runAnalysis();

      final exceptions = analyzer.issues.where((e) => e.category == IssueCategory.flutterUnhandledException).toList();
      expect(exceptions.length, 2);
      expect(exceptions.any((e) => e.title.contains('RangeError')), isTrue);
      expect(exceptions.any((e) => e.title.contains('FormatException')), isTrue);
      for (final exc in exceptions) {
        expect(exc.severity, IssueSeverity.error);
        expect(exc.isFixed, isFalse);
      }
    });

    test('精准解析网络连接超时与 DNS 失败', () async {
      final androidLogcat = File('${tempAndroidDir.path}/logcat');
      await androidLogcat.writeAsString('''
10-27 04:37:58.711 25456 25488 E Kazumi  : [2026-10-27 04:37:58.711] [ERROR] [system] SocketException: Failed host lookup: 'api.example.com' (OS Error: No address associated with hostname, errno = 7)
''');

      final analyzer = TestLabAnalyzer(androidDir: tempAndroidDir, iosDir: tempIosDir);
      await analyzer.runAnalysis();

      final netIssues = analyzer.issues.where((e) => e.category == IssueCategory.networkFailureOrTimeout).toList();
      expect(netIssues.length, 1);
      final issue = netIssues.first;
      expect(issue.severity, IssueSeverity.warning);
      expect(issue.platform, 'Android');
      expect(issue.categoryDisplayName, contains('Network'));
    });

    test('支持多真机矩阵嵌套子目录递归制品发现 (panther-33 / oriole-32)', () async {
      final matrixDir = Directory('${tempAndroidDir.path}/panther-33-zh_CN-portrait');
      await matrixDir.create(recursive: true);

      final logcatFile = File('${matrixDir.path}/logcat');
      await logcatFile.writeAsString('''
10-27 04:37:58.657 25456 25456 W predidit.kazumi: type=1400 audit(0.0:666): avc: denied { read } for name="max_map_count"
''');

      final actionsFile = File('${matrixDir.path}/actions.json');
      await actionsFile.writeAsString(jsonEncode({
        'events': [
          {'sequence': 1, 'sourceScreenId': '0', 'destinationScreenId': '1', 'executionResult': 'SUCCESS'},
          {'sequence': 2, 'sourceScreenId': '1', 'destinationScreenId': '2', 'executionResult': 'SUCCESS'},
        ]
      }));

      final analyzer = TestLabAnalyzer(androidDir: tempAndroidDir, iosDir: tempIosDir);
      await analyzer.runAnalysis();

      expect(analyzer.crawlStats['Android']?.totalActions, 2);
      final selinuxIssues = analyzer.issues.where((e) => e.category == IssueCategory.androidSELinuxRestriction).toList();
      expect(selinuxIssues.length, 1);
    });

    test('真实测试数据回归验证：完整加载 test_reports 并确认所有错误均 100% 修复闭环', () async {
      final realAndroidDir = Directory('test_reports/firebase_android');
      final realIosDir = Directory('test_reports/firebase_ios');

      if (!realAndroidDir.existsSync() && !realIosDir.existsSync()) {
        // test_reports is an ignored local artifacts directory, skip on clean CI checkouts
        return;
      }

      final analyzer = TestLabAnalyzer(androidDir: realAndroidDir, iosDir: realIosDir);
      await analyzer.runAnalysis();

      expect(analyzer.issues, isNotEmpty);

      // 验证绝无任何模糊未知项
      for (final issue in analyzer.issues) {
        expect(issue.id, isNotEmpty);
        expect(issue.title, isNot(contains('Unknown')));
        expect(issue.title, isNot(contains('未知')));
        expect(issue.title, isNot(contains('不明')));
        expect(issue.rootCause, isNotEmpty);
        expect(issue.fixAction, isNotEmpty);
      }

      // 验证没有未捕获的致命崩溃 (Fatal == 0)
      final fatalCount = analyzer.issues.where((e) => e.severity == IssueSeverity.fatal).length;
      expect(fatalCount, 0);

      // 验证所有功能缺陷在代码库中均已标记为彻底修复闭环
      final unfixedErrors = analyzer.issues.where((e) => e.severity == IssueSeverity.error && !e.isFixed).toList();
      expect(unfixedErrors, isEmpty);
    });
  });
}
