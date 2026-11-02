import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('架构规范检测：所有页面严禁直接使用原生 AppBar，必须统一使用 SysAppBar', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue);

    final rawAppBarViolations = <String>[];
    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    // 允许使用原生 AppBar 的白名单（基础建设实现组件）
    const allowedFiles = <String>{
      'lib/bean/appbar/sys_app_bar.dart',
      'lib/ui/appbar/haipee_app_bar.dart',
    };

    // 匹配如 appBar: AppBar( 或 return AppBar( 或 child: AppBar(
    final rawAppBarRegex = RegExp(r'(?<!Sys)(?<!Kazumi)(?<!Haipee)\bAppBar\s*\(');

    for (final file in dartFiles) {
      final normalizedPath = file.path.replaceAll(r'\', '/');
      if (allowedFiles.any((allowed) => normalizedPath.endsWith(allowed))) {
        continue;
      }

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        // 忽略单行或行内注释
        if (line.startsWith('//') || line.startsWith('/*') || line.startsWith('*')) {
          continue;
        }

        if (rawAppBarRegex.hasMatch(line)) {
          rawAppBarViolations.add('${file.path}:${i + 1} -> $line');
        }
      }
    }

    expect(
      rawAppBarViolations,
      isEmpty,
      reason: '发现页面直接使用了原生 AppBar()，在 macOS 隐藏标题栏模式下会导致返回键与系统红黄绿按钮重叠碰撞！'
          '\n请改为使用 SysAppBar()。违规列表：\n${rawAppBarViolations.join('\n')}',
    );
  });
}
