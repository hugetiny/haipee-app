import 'dart:async';
import 'dart:io';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Kazumi Flutter VM Service Introspection CLI
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
      args: {'objectGroup': 'kazumi_inspector'},
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
      args: {'objectGroup': 'kazumi_inspector', 'groupName': 'kazumi_inspector'},
    );
    stdout.writeln('Keys in res.json: ${res.json?.keys.toList()}');
    final tree = res.json?['result'];
    if (tree is Map) {
      stdout.writeln('Keys in result: ${tree.keys.toList()}');
      stdout.writeln('widgetType: ${tree['widgetType']}, description: ${tree['description']}');
      final children = tree['children'];
      stdout.writeln('children count: ${children is List ? children.length : 0}');
      _printCompactTree(tree, indent: 0, maxDepth: 6);
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
      args: {'objectGroup': 'kazumi_inspector', 'groupName': 'kazumi_inspector'},
    );
    final tree = res.json?['result'];
    if (tree != null) {
      _printCompactTree(tree, indent: 0, maxDepth: 12);
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
      args: {'objectGroup': 'kazumi_inspector', 'groupName': 'kazumi_inspector'},
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

void _printCompactTree(dynamic node, {int indent = 0, int maxDepth = 6}) {
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
  final httpRegExp = RegExp(r'http://127\.0\.0\.1:(\d+)/([a-zA-Z0-9_\-=]+)/');

  final tasksDir = Directory('/Users/a12/.gemini/antigravity-cli/brain/f8aa996f-3e7a-43fd-a39e-24ad2cba58f0/.system_generated/tasks');
  if (await tasksDir.exists()) {
    final files = tasksDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.log'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    for (final file in files) {
      try {
        final lines = await file.readAsLines();
        for (final line in lines.reversed) {
          final match = regExp.firstMatch(line);
          if (match != null) {
            return match.group(0);
          }
          final httpMatch = httpRegExp.firstMatch(line);
          if (httpMatch != null) {
            return 'ws://127.0.0.1:${httpMatch.group(1)}/${httpMatch.group(2)}/ws';
          }
        }
      } catch (_) {}
    }
  }
  return null;
}
