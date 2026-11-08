// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Haipee 全链路自动发现 Bug 与修复诊断闭环引擎 (`tool/auto_bug_hunter.dart`)
///
/// 5 层确定性质量门禁：
/// 1. [Static]       `flutter analyze` 静态类型、空安全与代码规范零告警门禁
/// 2. [Architecture] `test/architecture/` 架构防崩门禁 (禁裸 AppBar、禁无守卫 extra 强转、禁 PopScope 死循环、禁播放器裸调 currentPlugin)
/// 3. [Unit]         `test/unit/` 核心协议契约门禁 (B站 UPOS 节点优选防 503、HTTP 请求头大小写去重与 mpv 防重、全局迷你条状态机)
/// 4. [Crawler]      `test/widget/` + `test/integration/` 多视口无头状态机巡检机器人 (覆盖 1280x800 桌面、480x270 小窗 PIP、360x640 手机窄屏及全部常规交互)
/// 5. [Live / Cloud] 自动探测本地运行实例 VM Service (`tool/inspect_app.dart --check-overflow`)，并支持按需联动云端 Firebase Test Lab 双模真机验证
///
/// 用法:
///   dart run tool/auto_bug_hunter.dart                # 默认快速全链路巡检 (约 15~25 秒，适合每次改完代码立即运行)
///   dart run tool/auto_bug_hunter.dart --full         # 执行仓库全量测试集 + 架构 + 实时 VM 自省
///   dart run tool/auto_bug_hunter.dart --live         # 强制附加本地运行态 VM Service 溢出与错误日志自省
///   dart run tool/auto_bug_hunter.dart --firebase-inst # 附加云端真机 Firebase Test Lab Instrumentation 套件
///   dart run tool/auto_bug_hunter.dart --firebase-robo # 附加云端真机 Firebase Test Lab Robo 探索套件

class DiagnosedBugItem {
  final String stage;
  final String category;
  final String summary;
  final String location;
  final String rootCause;
  final String suggestedFix;
  final String rawExcerpt;

  const DiagnosedBugItem({
    required this.stage,
    required this.category,
    required this.summary,
    required this.location,
    required this.rootCause,
    required this.suggestedFix,
    required this.rawExcerpt,
  });

  Map<String, dynamic> toJson() => {
        'stage': stage,
        'category': category,
        'summary': summary,
        'location': location,
        'rootCause': rootCause,
        'suggestedFix': suggestedFix,
        'rawExcerpt': rawExcerpt,
      };
}

class StageExecutionResult {
  final String id;
  final String title;
  final bool passed;
  final bool skipped;
  final Duration duration;
  final int exitCode;
  final List<DiagnosedBugItem> bugs;

  const StageExecutionResult({
    required this.id,
    required this.title,
    required this.passed,
    this.skipped = false,
    required this.duration,
    required this.exitCode,
    this.bugs = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status': skipped ? 'SKIPPED' : (passed ? 'PASSED' : 'FAILED'),
        'durationMs': duration.inMilliseconds,
        'exitCode': exitCode,
        'bugCount': bugs.length,
        'bugs': bugs.map((b) => b.toJson()).toList(),
      };
}

Future<void> main(List<String> args) async {
  final fullSuite = args.contains('--full');
  final forceLive = args.contains('--live');
  final runFirebaseInst = args.contains('--firebase-inst');
  final runFirebaseRobo = args.contains('--firebase-robo');

  final startedAt = DateTime.now();
  print('======================================================================');
  print('🛡️  Haipee 自动发现 Bug 与自愈诊断闭环引擎 (Auto Bug Hunter)');
  print('   模式: ${fullSuite ? "全量仓库回归 (--full)" : "核心高危链路极速巡检 (Default)"}');
  print('======================================================================\n');

  final results = <StageExecutionResult>[];

  // Stage 1: Static Code Analysis
  results.add(await _runCommandStage(
    id: 'static_analyze',
    title: '第 1 层: 静态类型与 Lint 零警告门禁 (flutter analyze)',
    executable: 'flutter',
    arguments: ['analyze'],
  ));

  // Stage 2: Architecture Safety Guards
  results.add(await _runCommandStage(
    id: 'architecture_guards',
    title: '第 2 层: 架构级防崩溃规则门禁 (Router 强转 / PopScope 死循环 / Player 解耦)',
    executable: 'flutter',
    arguments: ['test', 'test/architecture/'],
  ));

  // Stage 3: Core Unit & Protocol Contracts
  results.add(await _runCommandStage(
    id: 'unit_contracts',
    title: '第 3 层: 核心协议与状态契约单测 (B站 UPOS 防503 / 请求头去重 / 迷你播放条)',
    executable: 'flutter',
    arguments: fullSuite
        ? ['test', 'test/unit/']
        : [
            'test',
            'test/unit/bili_cdn_and_player_headers_test.dart',
            'test/unit/global_mini_player_bar_test.dart',
          ],
  ));

  // Stage 4: Multi-Viewport State-Machine & Routine Operations Crawler
  results.add(await _runCommandStage(
    id: 'headless_crawler',
    title: '第 4 层: 多视口状态机巡检机器人 (1280x800 桌面 <-> 480x270 小窗 PIP <-> 360x640 窄屏)',
    executable: 'flutter',
    arguments: fullSuite
        ? ['test', 'test/widget/', 'test/integration/automated_bug_discovery_test.dart']
        : [
            'test',
            'test/widget/player_pip_and_stats_test.dart',
            'test/integration/automated_bug_discovery_test.dart',
          ],
  ));

  // Stage 5: Live Runtime VM Service Introspection (if running or forced)
  results.add(await _runLiveVmStage(forceLive: forceLive));

  // Stage 6: Optional Cloud Firebase Test Lab Execution
  if (runFirebaseInst) {
    results.add(await _runCommandStage(
      id: 'firebase_instrumentation',
      title: '第 6A 层: 云端真机 Firebase Test Lab (Instrumentation 确定性巡检)',
      executable: 'bash',
      arguments: ['tool/run_firebase_testlab.sh', '--mode', 'instrumentation'],
    ));
  }
  if (runFirebaseRobo) {
    results.add(await _runCommandStage(
      id: 'firebase_robo',
      title: '第 6B 层: 云端真机 Firebase Test Lab (Robo 探索巡检 + 日志深度解析)',
      executable: 'bash',
      arguments: ['tool/run_firebase_testlab.sh', '--mode', 'robo'],
    ));
  }

  final totalDuration = DateTime.now().difference(startedAt);
  await _writeStructuredReports(results, totalDuration);

  final failedStages = results.where((r) => !r.skipped && !r.passed).toList();
  final totalBugs =
      results.fold<int>(0, (sum, stage) => sum + stage.bugs.length);

  print('\n======================================================================');
  if (failedStages.isEmpty) {
    print(
      '✅ 全链路验证通过！共耗时 ${(totalDuration.inMilliseconds / 1000).toStringAsFixed(1)}s，发现 0 处缺陷。',
    );
    print('📄 诊断报告已生成: test_reports/auto_bug_hunter_report.md');
    print('======================================================================');
    exit(0);
  } else {
    print(
      '🚨 拦截到 ${failedStages.length} 个未通过阶段 (共提取 $totalBugs 条根因诊断项)！',
    );
    for (final stage in failedStages) {
      print('  ✗ ${stage.title}');
      for (final bug in stage.bugs) {
        print('    - [${bug.category}] @ ${bug.location}: ${bug.summary}');
        print('      💡 修复方案: ${bug.suggestedFix}');
      }
    }
    print('\n📄 完整可操作修复清单已输出至:');
    print('   - test_reports/auto_bug_hunter_report.md');
    print('   - test_reports/auto_bug_hunter_report.json');
    print('======================================================================');
    exit(1);
  }
}

Future<StageExecutionResult> _runCommandStage({
  required String id,
  required String title,
  required String executable,
  required List<String> arguments,
}) async {
  print('▶️  正在执行 $title ...');
  final sw = Stopwatch()..start();
  final proc = await Process.run(executable, arguments);
  sw.stop();

  final combinedOutput = '${proc.stdout}\n${proc.stderr}'.trim();
  final passed = proc.exitCode == 0;

  if (passed) {
    print(
      '   ✓ 通过 (${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s)\n',
    );
    return StageExecutionResult(
      id: id,
      title: title,
      passed: true,
      duration: sw.elapsed,
      exitCode: 0,
    );
  }

  final bugs = _diagnoseOutput(stage: id, output: combinedOutput);
  print(
    '   ✗ 失败 (Exit ${proc.exitCode}, 耗时 ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s, 提取 ${bugs.length} 条诊断)\n',
  );
  return StageExecutionResult(
    id: id,
    title: title,
    passed: false,
    duration: sw.elapsed,
    exitCode: proc.exitCode,
    bugs: bugs,
  );
}

Future<StageExecutionResult> _runLiveVmStage({required bool forceLive}) async {
  const id = 'live_vm_inspect';
  const title = '第 5 层: 本地运行态 Dart VM Service 零溢出与异常自省';
  print('▶️  正在探测 $title ...');
  final sw = Stopwatch()..start();
  final proc = await Process.run(
    'dart',
    ['tool/inspect_app.dart', '--check-overflow'],
  );
  sw.stop();

  final combined = '${proc.stdout}\n${proc.stderr}'.trim();
  final cannotConnect = combined.contains('无法获取 VM Service URI') ||
      combined.contains('连接 VM Service 失败') ||
      combined.contains('未找到活跃的主 Isolate');

  if (cannotConnect && !forceLive) {
    print('   ⏭️ 当前未检测到活跃本地调试实例，自动跳过实时 VM 自省 (加 --live 可强制校验)\n');
    return StageExecutionResult(
      id: id,
      title: title,
      passed: true,
      skipped: true,
      duration: sw.elapsed,
      exitCode: 0,
    );
  }

  final hasOverflow = combined.contains('发现') && combined.contains('处布局溢出');
  final passed = proc.exitCode == 0 && !hasOverflow;
  if (passed) {
    print('   ✓ 实时运行态 0 像素溢出 (${sw.elapsedMilliseconds}ms)\n');
    return StageExecutionResult(
      id: id,
      title: title,
      passed: true,
      duration: sw.elapsed,
      exitCode: 0,
    );
  }

  final bugs = _diagnoseOutput(stage: id, output: combined);
  print('   ✗ 实时运行态检测到异常或布局溢出！\n');
  return StageExecutionResult(
    id: id,
    title: title,
    passed: false,
    duration: sw.elapsed,
    exitCode: proc.exitCode == 0 ? 1 : proc.exitCode,
    bugs: bugs,
  );
}

List<DiagnosedBugItem> _diagnoseOutput({
  required String stage,
  required String output,
}) {
  final items = <DiagnosedBugItem>[];
  final locationMatch =
      RegExp(r'((?:lib|test|integration_test)/[A-Za-z0-9_./]+\.dart:\d+(?::\d+)?)')
          .firstMatch(output);
  final defaultLocation = locationMatch?.group(1) ?? '详见日志输出';

  if (output.contains('RenderFlex overflowed by') ||
      output.contains('处布局溢出')) {
    items.add(DiagnosedBugItem(
      stage: stage,
      category: 'RenderFlexOverflow',
      summary: '检测到 Flex 布局像素溢出 (小窗口/窄视口适配缺陷)',
      location: defaultLocation,
      rootCause: 'Row / Column 子组件在受限宽高 (如 480x270 PIP 或 360x640 窄屏) 下缺少 Expanded / Flexible / ConstrainedBox 或 MenuStyle(maximumSize)。',
      suggestedFix: '使用 LayoutBuilder 按阈值收缩文案/间距，给可变长文本包裹 Expanded(overflow: ellipsis)，弹窗与菜单使用 clamp 限制最大宽高。',
      rawExcerpt: _trimExcerpt(output),
    ));
  }

  if (output.contains("is not a subtype of type") ||
      output.contains('_TypeError')) {
    items.add(DiagnosedBugItem(
      stage: stage,
      category: 'NullOrTypeCastCrash',
      summary: '检测到空值或类型不匹配的强制类型转换崩溃 (_TypeError)',
      location: defaultLocation,
      rootCause: '路由跳转未传 extra 或异步返回结构字段为空时直接执行了 `as T` 或 `!` 非空断言。',
      suggestedFix: '改为 `value is T ? value : fallback`，并在对应页面 initState 中提供状态回退兜底。',
      rawExcerpt: _trimExcerpt(output),
    ));
  }

  if (output.contains('LateInitializationError')) {
    items.add(DiagnosedBugItem(
      stage: stage,
      category: 'LateInitializationCrash',
      summary: '检测到未初始化的 late 字段被提前读取 (LateInitializationError)',
      location: defaultLocation,
      rootCause: '用户在异步流初始化完成前打开了设置面板、统计抽屉或点击了快捷按钮，触发读取尚未赋值的 late 字段。',
      suggestedFix: '消除非必要的 `late` 修饰符，改为赋予安全的编译期默认值或改为可空类型 `T?`。',
      rawExcerpt: _trimExcerpt(output),
    ));
  }

  if (output.contains('would not hit test on the specified widget') ||
      output.contains('outside the bounds of the root')) {
    items.add(DiagnosedBugItem(
      stage: stage,
      category: 'OffscreenControlInSmallViewport',
      summary: '控件在小窗口或窄视口下超出屏幕可视边界，无法点击交互',
      location: defaultLocation,
      rootCause: 'MenuAnchor / BottomSheet / Dialog 未限制在当前 MediaQuery 视口高度内或缺少滚动容器。',
      suggestedFix: '为 MenuAnchor 配置 `MenuStyle(maximumSize: ...)`，为弹窗添加 `SingleChildScrollView` 或紧凑行高。',
      rawExcerpt: _trimExcerpt(output),
    ));
  }

  if (stage == 'static_analyze') {
    final issueRegex =
        RegExp(r'(error|warning|info)\s+•\s+(.+?)\s+•\s+(.+?:\d+:\d+)');
    for (final m in issueRegex.allMatches(output).take(10)) {
      items.add(DiagnosedBugItem(
        stage: stage,
        category: 'StaticAnalyzer_${m.group(1)!.toUpperCase()}',
        summary: m.group(2)!.trim(),
        location: m.group(3)!.trim(),
        rootCause: '静态分析器检测到类型错误、未使用变量或 Lint 违规。',
        suggestedFix: '打开定位文件精确修复对应行编译/规范问题，确保 flutter analyze 0 issues。',
        rawExcerpt: m.group(0)!,
      ));
    }
  }

  if (items.isEmpty) {
    items.add(DiagnosedBugItem(
      stage: stage,
      category: 'TestAssertionOrRuntimeFailure',
      summary: '自动化断言或架构守卫未通过',
      location: defaultLocation,
      rootCause: '业务逻辑回归或违反架构安全守卫契约。',
      suggestedFix: '根据下方原始报错栈定位违规代码并修复后重新运行 `dart run tool/auto_bug_hunter.dart`。',
      rawExcerpt: _trimExcerpt(output),
    ));
  }

  return items;
}

String _trimExcerpt(String raw) {
  final lines = raw.split('\n');
  if (lines.length <= 25) return raw;
  return lines.sublist(lines.length - 25).join('\n');
}

Future<void> _writeStructuredReports(
  List<StageExecutionResult> results,
  Duration totalDuration,
) async {
  final dir = Directory('test_reports');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final jsonPayload = {
    'generatedAt': DateTime.now().toIso8601String(),
    'totalDurationMs': totalDuration.inMilliseconds,
    'overallPassed': results.every((r) => r.skipped || r.passed),
    'stages': results.map((r) => r.toJson()).toList(),
  };

  await File('test_reports/auto_bug_hunter_report.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(jsonPayload),
  );

  final md = StringBuffer();
  md.writeln('# Haipee 自动化 Bug 发现与自愈诊断报告');
  md.writeln();
  md.writeln('- **生成时间**: `${DateTime.now().toIso8601String()}`');
  md.writeln(
      '- **总耗时**: `${(totalDuration.inMilliseconds / 1000).toStringAsFixed(1)}s`');
  md.writeln(
      '- **总体结论**: ${jsonPayload['overallPassed'] == true ? '✅ PASS (零缺陷)' : '🚨 FAIL (发现待修复缺陷)'}');
  md.writeln();
  md.writeln('## 各层门禁执行明细');
  md.writeln();
  md.writeln('| 阶段 | 状态 | 耗时 | 发现问题数 |');
  md.writeln('| :--- | :--- | :--- | :---: |');
  for (final r in results) {
    final badge = r.skipped ? '⏭️ SKIPPED' : (r.passed ? '✅ PASS' : '❌ FAIL');
    md.writeln(
        '| ${r.title} | $badge | ${(r.duration.inMilliseconds / 1000).toStringAsFixed(1)}s | ${r.bugs.length} |');
  }

  final allBugs = results.expand((r) => r.bugs).toList();
  if (allBugs.isNotEmpty) {
    md.writeln('\n## 根因定位与修复处方');
    for (var i = 0; i < allBugs.length; i++) {
      final b = allBugs[i];
      md.writeln('\n### ${i + 1}. [${b.category}] ${b.summary}');
      md.writeln('- **代码位置**: `${b.location}`');
      md.writeln('- **根本原因**: ${b.rootCause}');
      md.writeln('- **修复方案**: ${b.suggestedFix}');
      md.writeln('\n```text\n${b.rawExcerpt}\n```');
    }
  }

  await File('test_reports/auto_bug_hunter_report.md')
      .writeAsString(md.toString());
}
