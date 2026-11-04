import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Haipee Flutter VM Service Introspection CLI
/// 
/// 允许 AI 代理和开发者无需截图即可：
/// 1. 动态自省运行中 Flutter 应用的完整 Widget 树 (`--tree`)
/// 2. 检测是否存在任何像素溢出 (`--check-overflow`)
/// 3. 定位指定组件、文本、Key 的屏幕坐标、尺寸与属性 (`--find <query>`)
/// 4. 触发毫秒级热重载 (`--reload`) 或热重启 (`--restart`)
/// 5. 打印当前路由栈与当前展示页面
void main(List<String> args) async {
  String? uriStr;
  String command = 'summary';
  String? findQuery;

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--uri' && i + 1 < args.length) {
      uriStr = args[++i];
    } else if (args[i] == '--tree') {
      command = 'tree';
    } else if (args[i] == '--check-overflow') {
      command = 'check-overflow';
    } else if (args[i] == '--reload') {
      command = 'reload';
    } else if (args[i] == '--restart') {
      command = 'restart';
    } else if (args[i] == '--find' && i + 1 < args.length) {
      command = 'find';
      findQuery = args[++i];
    } else if (args[i] == '--failures') {
      await _dumpParseFailures();
      return;
    } else if (args[i] == '--errors') {
      int limit = 50;
      if (i + 1 < args.length && int.tryParse(args[i + 1]) != null) {
        limit = int.parse(args[++i]);
      }
      await _dumpErrors(limit, asJson: false);
      return;
    } else if (args[i] == '--errors-json') {
      int limit = 50;
      if (i + 1 < args.length && int.tryParse(args[i + 1]) != null) {
        limit = int.parse(args[++i]);
      }
      await _dumpErrors(limit, asJson: true);
      return;
    } else if (args[i] == '--clear-logs') {
      await _clearAllLogs();
      return;
    } else if (args[i] == '--logs') {
      int limit = 50;
      if (i + 1 < args.length && int.tryParse(args[i + 1]) != null) {
        limit = int.parse(args[++i]);
      }
      await _dumpRecentLogs(limit);
      return;
    }
  }

  // 尝试自动从日志文件解析最新的 VM Service URI
  uriStr ??= await _autoDiscoverVmServiceUri();

  if (uriStr == null) {
    stderr.writeln('❌ 无法获取 VM Service URI。请使用 --uri ws://127.0.0.1:<port>/<token>/ws 指定。');
    exit(1);
  }

  // 格式化为 ws://
  if (uriStr.startsWith('http://')) {
    uriStr = uriStr.replaceFirst('http://', 'ws://');
  }
  if (!uriStr.endsWith('/ws') && !uriStr.endsWith('ws')) {
    if (!uriStr.endsWith('/')) uriStr += '/';
    uriStr += 'ws';
  }

  stdout.writeln('🔌 正在连接 Dart VM Service: $uriStr ...');
  VmService client;
  try {
    client = await vmServiceConnectUri(uriStr).timeout(const Duration(seconds: 5));
  } catch (e) {
    stderr.writeln('❌ 连接 VM Service 失败: $e');
    exit(1);
  }

  final vm = await client.getVM();
  stdout.writeln('✅ 已连接 VM (${vm.name}, 架构: ${vm.architectureBits}位, Isolate 数量: ${vm.isolates?.length ?? 0})');

  final mainIsolateRef = vm.isolates?.firstWhere(
    (iso) => !(iso.isSystemIsolate ?? false),
    orElse: () => vm.isolates!.first,
  );

  if (mainIsolateRef == null || mainIsolateRef.id == null) {
    stderr.writeln('❌ 未找到活跃的主 Isolate');
    client.dispose();
    exit(1);
  }

  final isolateId = mainIsolateRef.id!;
  final isolate = await client.getIsolate(isolateId);
  stdout.writeln('📱 主 Isolate: ${isolate.name} ($isolateId)');

  switch (command) {
    case 'reload':
      try {
        final res = await client.callServiceExtension('ext.flutter.reassemble', isolateId: isolateId);
        stdout.writeln('⚡ 热重载成功: ${res.json}');
      } catch (e) {
        stderr.writeln('❌ 热重载失败: $e');
      }
      break;

    case 'restart':
      stdout.writeln('🔄 正在执行热重启...');
      bool restarted = false;
      try {
        final vm = await client.getVM();
        stdout.writeln('  Isolates: ${vm.isolates?.length}');
      } catch (_) {}

      // Try registered flutter hotRestart services
      for (var i = 0; i < 20; i++) {
        try {
          final res = await client
              .callMethod('s$i.hotRestart', args: {'pause': false})
              .timeout(const Duration(milliseconds: 600));
          stdout.writeln('⚡ 热重启成功: ${res.json}');
          restarted = true;
          break;
        } catch (_) {}
        try {
          final res = await client
              .callMethod('hotRestart', args: {'pause': false})
              .timeout(const Duration(milliseconds: 600));
          stdout.writeln('⚡ 热重启成功: ${res.json}');
          restarted = true;
          break;
        } catch (_) {}
      }
      if (!restarted) {
        try {
          await client
              .callServiceExtension('ext.flutter.reassemble', isolateId: isolateId)
              .timeout(const Duration(seconds: 3));
          stdout.writeln('⚡ 回退触发 Reassemble 成功');
        } catch (e) {
          stderr.writeln('❌ 重启操作失败: $e');
        }
      }
      break;

    case 'check-overflow':
      await _checkOverflow(client, isolateId);
      break;

    case 'tree':
      await _dumpWidgetTree(client, isolateId);
      break;

    case 'find':
      await _findWidget(client, isolateId, findQuery ?? '');
      break;

    case 'summary':
    default:
      await _dumpSummary(client, isolateId);
      break;
  }

  client.dispose();
  exit(0);
}

Future<void> _checkOverflow(VmService client, String isolateId) async {
  stdout.writeln('🔍 正在检测全界面 RenderFlex 像素溢出...');
  try {
    final res = await client.callServiceExtension(
      'ext.flutter.inspector.getRootWidgetSummaryTree',
      isolateId: isolateId,
      args: {'objectGroup': 'haipee_inspector'},
    );
    final treeJson = res.json?['result'];
    if (treeJson == null) {
      stdout.writeln('⚠️ 无法获取 Inspector Widget 摘要树');
      return;
    }

    final overflows = <String>[];
    _scanNodeForOverflow(treeJson, overflows);

    if (overflows.isEmpty) {
      stdout.writeln('🎉 [无截图验证通过] 全界面 0 像素溢出 (Zero RenderFlex Overflows)!');
    } else {
      stderr.writeln('🚨 发现 ${overflows.length} 处布局溢出:');
      for (final err in overflows) {
        stderr.writeln('  - $err');
      }
    }
  } catch (e) {
    stderr.writeln('❌ 检测溢出时发生异常: $e');
  }
}

void _scanNodeForOverflow(dynamic node, List<String> overflows) {
  if (node is! Map) return;
  final desc = node['description']?.toString() ?? '';
  final error = node['hasOverflow'] == true || desc.contains('OVERFLOWING') || desc.contains('overflowed');
  if (error) {
    overflows.add('Widget: ${node['widgetType'] ?? 'Unknown'} | Description: $desc');
  }
  final children = node['children'];
  if (children is List) {
    for (final child in children) {
      _scanNodeForOverflow(child, overflows);
    }
  }
}

Future<void> _dumpSummary(VmService client, String isolateId) async {
  stdout.writeln('\n📊 --- 当前 UI 结构与关键组件摘要 ---');
  try {
    final res = await client.callServiceExtension(
      'ext.flutter.inspector.getRootWidgetSummaryTree',
      isolateId: isolateId,
      args: {'objectGroup': 'haipee_inspector', 'groupName': 'haipee_inspector'},
    );
    stdout.writeln('Keys in res.json: ${res.json?.keys.toList()}');
    final tree = res.json?['result'];
    if (tree is Map) {
      stdout.writeln('Keys in result: ${tree.keys.toList()}');
      stdout.writeln('widgetType: ${tree['widgetType']}, description: ${tree['description']}');
      final children = tree['children'];
      stdout.writeln('children count: ${children is List ? children.length : 0}');
      _printCompactTree(tree, indent: 0, maxDepth: 40);
    } else {
      stdout.writeln('Result is not a Map: $tree');
    }
  } catch (e) {
    stderr.writeln('获取摘要失败: $e');
  }
}

Future<void> _dumpWidgetTree(VmService client, String isolateId) async {
  stdout.writeln('\n🌲 --- 完整 Widget 树结构 ---');
  try {
    final res = await client.callServiceExtension(
      'ext.flutter.inspector.getRootWidgetTree',
      isolateId: isolateId,
      args: {'objectGroup': 'haipee_inspector', 'groupName': 'haipee_inspector'},
    );
    final tree = res.json?['result'];
    if (tree != null) {
      _printCompactTree(tree, indent: 0, maxDepth: 40);
    }
  } catch (e) {
    stderr.writeln('获取 Widget 树失败: $e');
  }
}

Future<void> _findWidget(VmService client, String isolateId, String query) async {
  stdout.writeln('🔍 正在检索包含 "$query" 的组件与文本...');
  try {
    final res = await client.callServiceExtension(
      'ext.flutter.inspector.getRootWidgetTree',
      isolateId: isolateId,
      args: {'objectGroup': 'haipee_inspector', 'groupName': 'haipee_inspector'},
    );
    final tree = res.json?['result'];
    final matches = <Map<String, dynamic>>[];
    _searchTree(tree, query.toLowerCase(), matches);

    if (matches.isEmpty) {
      stdout.writeln('❌ 未检索到匹配 "$query" 的组件');
    } else {
      stdout.writeln('✅ 检索到 ${matches.length} 个匹配项:');
      for (final m in matches) {
        stdout.writeln('  • [${m['widgetType']}] desc: ${m['description']}');
      }
    }
  } catch (e) {
    stderr.writeln('检索失败: $e');
  }
}

void _searchTree(dynamic node, String query, List<Map<String, dynamic>> matches) {
  if (node is! Map) return;
  final desc = node['description']?.toString() ?? '';
  final type = node['widgetRuntimeType']?.toString() ?? node['type']?.toString() ?? '';
  final keyStr = node['key']?.toString() ?? '';
  
  bool matched = desc.toLowerCase().contains(query) || 
                 type.toLowerCase().contains(query) || 
                 keyStr.toLowerCase().contains(query);
  if (!matched && node['properties'] is List) {
    for (final prop in node['properties']) {
      if (prop is Map && prop['description']?.toString().toLowerCase().contains(query) == true) {
        matched = true;
        break;
      }
    }
  }

  if (matched) {
    matches.add({
      'widgetType': type,
      'description': desc,
      'key': keyStr,
      'node': node,
    });
  }
  final children = node['children'];
  if (children is List) {
    for (final child in children) {
      _searchTree(child, query, matches);
    }
  }
}

void _printCompactTree(dynamic node, {int indent = 0, int maxDepth = 40}) {
  if (node is! Map || indent > maxDepth) return;
  final type = node['widgetRuntimeType']?.toString() ?? node['type']?.toString();
  final desc = node['description']?.toString() ?? '';
  if (type != null && !_isBoilerplateWidget(type)) {
    final prefix = '  ' * indent;
    stdout.writeln('$prefix• $type: $desc');
  }
  final children = node['children'];
  if (children is List) {
    for (final child in children) {
      _printCompactTree(child, indent: indent + 1, maxDepth: maxDepth);
    }
  }
}

bool _isBoilerplateWidget(String type) {
  const boilerplate = {
    'InheritedWidget',
    'InheritedElement',
    'ComponentElement',
    '_FocusMarker',
    'FocusScope',
    'Actions',
    'Shortcuts',
    'UncontrolledProviderScope',
    '_InheritedTheme',
  };
  return boilerplate.contains(type);
}

Future<String?> _autoDiscoverVmServiceUri() async {
  final regExp = RegExp(r'ws://127\.0\.0\.1:(\d+)/([a-zA-Z0-9_\-=]+)/ws');
  final vmNoticeRegExp = RegExp(r'Dart VM Service.*?http://127\.0\.0\.1:(\d+)/([a-zA-Z0-9_\-=]+)/');

  final brainDir = Directory('/Users/a12/.gemini/antigravity-cli/brain');
  if (await brainDir.exists()) {
    final taskFiles = <File>[];
    for (final conv in brainDir.listSync().whereType<Directory>()) {
      final tasksDir = Directory('${conv.path}/.system_generated/tasks');
      if (tasksDir.existsSync()) {
        taskFiles.addAll(tasksDir.listSync().whereType<File>().where((f) => f.path.endsWith('.log')));
      }
    }
    taskFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    for (final file in taskFiles) {
      try {
        final lines = await file.readAsLines();
        for (final line in lines.reversed) {
          final vmMatch = vmNoticeRegExp.firstMatch(line);
          if (vmMatch != null) {
            return 'ws://127.0.0.1:${vmMatch.group(1)}/${vmMatch.group(2)}/ws';
          }
          final match = regExp.firstMatch(line);
          if (match != null && !line.contains('/stream/')) {
            return match.group(0);
          }
        }
      } catch (_) {}
    }
  }
  return null;
}

File? _findHaipeeLogFile() {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
  final candidateDirs = [
    '$home/Library/Application Support/com.example.haipee/logs',
    '$home/Library/Application Support/haipee/logs',
    '$home/.local/share/haipee/logs',
    '${Platform.environment['APPDATA']}/haipee/logs',
  ];
  for (final dirStr in candidateDirs) {
    final file = File('$dirStr/haipee.log');
    if (file.existsSync()) {
      return file;
    }
  }
  return null;
}

Future<void> _dumpParseFailures() async {
  final file = _findHaipeeLogFile();
  if (file == null) {
    stderr.writeln('❌ 未找到本地 haipee.log 日志文件');
    exit(1);
  }
  stdout.writeln('📋 从 ${file.path} 检索解析失败相关日志:\n');
  final lines = await file.readAsLines();
  final failures = lines.where((l) => 
    l.contains('解析失败') || 
    l.contains('嗅探超时') || 
    l.contains('解析视频资源超时') ||
    l.contains('[STREAM] 视频资源解析失败')
  ).toList();

  if (failures.isEmpty) {
    stdout.writeln('✨ 暂无任何解析失败记录。');
  } else {
    for (final f in failures.reversed.take(30).toList().reversed) {
      stdout.writeln(f);
    }
    stdout.writeln('\n总计检索到 ${failures.length} 条解析失败事件。');
  }
}

Future<void> _dumpRecentLogs(int limit) async {
  final file = _findHaipeeLogFile();
  if (file == null) {
    stdout.writeln('✨ 暂无本地日志文件或日志已清空重置。');
    return;
  }
  stdout.writeln('📋 最近 $limit 条日志 (${file.path}):\n');
  final lines = await file.readAsLines();
  if (lines.isEmpty) {
    stdout.writeln('✨ 日志文件为空。');
    return;
  }
  final recent = lines.length > limit ? lines.sublist(lines.length - limit) : lines;
  for (final line in recent) {
    stdout.writeln(line);
  }
}

Future<void> _dumpErrors(int limit, {required bool asJson}) async {
  final file = _findHaipeeLogFile();
  if (file == null) {
    if (asJson) {
      stdout.writeln('[]');
    } else {
      stdout.writeln('✨ 日志文件为空或已重置，暂无任何异常或错误记录。');
    }
    return;
  }

  final lines = await file.readAsLines();
  final headerRegExp = RegExp(
    r'^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})\] \[(ERROR|EXCEPTION|WARNING|CRITICAL)\] \[([^\]]+)\] (.*)$',
  );

  final List<Map<String, dynamic>> errorEntries = [];
  Map<String, dynamic>? currentEntry;

  for (final line in lines) {
    final match = headerRegExp.firstMatch(line);
    if (match != null) {
      if (currentEntry != null) {
        errorEntries.add(currentEntry);
      }
      final timestamp = match.group(1)!;
      final level = match.group(2)!;
      final module = match.group(3)!;
      final message = match.group(4)!;
      currentEntry = {
        'timestamp': timestamp,
        'level': level,
        'module': module,
        'message': message,
      };
    } else if (currentEntry != null) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Diagnostic:')) {
        final diagStr = trimmed.substring('Diagnostic:'.length).trim();
        final diagCodeMatch = RegExp(r'^\[([^\]]+)\]\s*(.*)$').firstMatch(diagStr);
        if (diagCodeMatch != null) {
          currentEntry['diagnosticCode'] = diagCodeMatch.group(1);
          currentEntry['diagnosticTitle'] = diagCodeMatch.group(2);
        } else {
          currentEntry['diagnostic'] = diagStr;
        }
      } else if (trimmed.startsWith('Explanation:')) {
        currentEntry['explanation'] = trimmed.substring('Explanation:'.length).trim();
      } else if (trimmed.startsWith('Action:')) {
        currentEntry['action'] = trimmed.substring('Action:'.length).trim();
      } else if (trimmed.startsWith('Error:')) {
        currentEntry['error'] = trimmed.substring('Error:'.length).trim();
      } else if (line.startsWith('    ') || line.startsWith('\t')) {
        currentEntry['details'] = (currentEntry['details'] != null ? '${currentEntry['details']}\n' : '') + trimmed;
      } else if (line.startsWith('[') && !headerRegExp.hasMatch(line)) {
        errorEntries.add(currentEntry);
        currentEntry = null;
      }
    }
  }
  if (currentEntry != null) {
    errorEntries.add(currentEntry);
  }

  final recent = errorEntries.length > limit
      ? errorEntries.sublist(errorEntries.length - limit)
      : errorEntries;

  if (asJson) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(recent));
    return;
  }

  if (recent.isEmpty) {
    stdout.writeln('📋 Haipee 异常与错误自省诊断报告 (共 0 条):\n');
    stdout.writeln('✨ 完美！未检测到任何近期异常或错误记录。');
    return;
  }

  final fatalList = recent.where((e) => e['level'] != 'WARNING').toList();
  final warningList = recent.where((e) => e['level'] == 'WARNING').toList();

  stdout.writeln('📋 Haipee 运行诊断报告 (共 ${recent.length} 项记录: ${fatalList.length} 项严重错误/溢出, ${warningList.length} 项外部网络告警):\n');

  if (fatalList.isNotEmpty) {
    stdout.writeln('=== 🚨 严重错误与 UI 溢出 (${fatalList.length} 项) ===');
    for (final err in fatalList) {
      final ts = err['timestamp'];
      final lvl = err['level'];
      final mod = err['module'];
      final msg = err['message'];
      stdout.writeln('🚨 [$ts] [$lvl] [$mod] $msg');
      if (err.containsKey('diagnosticCode')) {
        stdout.writeln('   ├─ 诊断代号: [${err['diagnosticCode']}] ${err['diagnosticTitle']}');
      }
      if (err.containsKey('explanation')) {
        stdout.writeln('   ├─ 根因剖析: ${err['explanation']}');
      }
      if (err.containsKey('action')) {
        stdout.writeln('   ├─ 建议操作: ${err['action']}');
      }
      if (err.containsKey('error')) {
        stdout.writeln('   ├─ 底层错误: ${err['error']}');
      }
      stdout.writeln('   └────────────────────────────────────────');
    }
    stdout.writeln('');
  }

  if (warningList.isNotEmpty) {
    stdout.writeln('=== ⚠️ 外部网络与索引器告警 (${warningList.length} 项) ===');
    for (final err in warningList) {
      final ts = err['timestamp'];
      final lvl = err['level'];
      final mod = err['module'];
      final msg = err['message'];
      stdout.writeln('⚠️  [$ts] [$lvl] [$mod] $msg');
      if (err.containsKey('error')) {
        stdout.writeln('   ├─ 底层错误: ${err['error']}');
      }
      stdout.writeln('   └────────────────────────────────────────');
    }
  }
}

Future<void> _clearAllLogs() async {
  // 1. Try VM Service extension to clear in-memory logs and reset error count
  try {
    final uriStr = await _autoDiscoverVmServiceUri();
    if (uriStr != null) {
      String wsUri = uriStr;
      if (wsUri.startsWith('http://')) wsUri = wsUri.replaceFirst('http://', 'ws://');
      if (!wsUri.endsWith('/ws') && !wsUri.endsWith('ws')) {
        if (!wsUri.endsWith('/')) wsUri += '/';
        wsUri += 'ws';
      }
      final client = await vmServiceConnectUri(wsUri).timeout(const Duration(seconds: 2));
      final vm = await client.getVM();
      final mainIso = vm.isolates?.firstWhere((iso) => !(iso.isSystemIsolate ?? false), orElse: () => vm.isolates!.first);
      if (mainIso?.id != null) {
        try {
          await client.callServiceExtension('ext.haipee.clearLogs', isolateId: mainIso!.id).timeout(const Duration(seconds: 2));
          stdout.writeln('⚡ 成功调用运行态 ext.haipee.clearLogs (内存日志已重置，错误计数已归零)');
        } catch (_) {}
      }
      client.dispose();
    }
  } catch (_) {}

  // 2. Clear disk log files
  final file = _findHaipeeLogFile();
  if (file == null) {
    stderr.writeln('❌ 未找到本地 haipee.log 日志文件');
    return;
  }
  final dir = file.parent;
  int count = 0;
  if (dir.existsSync()) {
    for (final f in dir.listSync().whereType<File>()) {
      if ((f.path.contains('haipee') || f.path.contains('kazumi')) && f.path.endsWith('.log')) {
        try {
          f.deleteSync();
          count++;
        } catch (_) {
          try {
            f.writeAsStringSync('');
            count++;
          } catch (_) {}
        }
      }
    }
  }
  stdout.writeln('✅ 已成功清理 $count 个本地日志文件 (${dir.path})。');
}
