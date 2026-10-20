import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('架构规范检测：所有页面严禁使用散落的原生 BackButton 或自定义 arrow_back，必须统一使用 AppBackButton', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue);

    final violations = <String>[];
    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    // 允许使用原生 BackButton 或 arrow_back 的白名单（仅限 AppBackButton 自身底层实现）
    const allowedFiles = <String>{
      'lib/bean/widget/app_back_button.dart',
    };

    // 匹配如 BackButton( 或 Icons.arrow_back 或 Icons.arrow_back_rounded 或 Icons.arrow_back_ios
    final forbiddenRegex = RegExp(r'\bBackButton\s*\(|Icons\.arrow_back\b|Icons\.arrow_back_rounded\b|Icons\.arrow_back_ios\b');

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

        if (forbiddenRegex.hasMatch(line)) {
          violations.add('${file.path}:${i + 1} -> $line');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: '发现页面使用了非统一的返回图标或按钮，导致全屏/各页面回退按钮尺寸、样式、动效或避让距离不一致！'
          '\n请改为统一使用 AppBackButton。违规列表：\n${violations.join('\n')}',
    );
  });

  test('架构规范检测：AppBar 与 AppBarConfig 的 leading 槽位严禁使用 raw IconButton(icon: Icon(Icons.close))，必须统一使用 AppBackButton', () {
    final libDir = Directory('lib');
    final violations = <String>[];
    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      // 检查 leading: IconButton( ... Icons.close ... )
      final leadingCloseMatch = RegExp(r'leading:\s*(?:[a-zA-Z0-9_.]+\s*\?\s*)?IconButton\s*\(\s*(?:[^\n;]*\n)*?\s*(?:icon:\s*)?(?:const\s+)?Icon\s*\(\s*Icons\.close');
      if (leadingCloseMatch.hasMatch(content)) {
        violations.add('${file.path}: 发现 leading 槽位使用 raw IconButton(Icons.close)，请统一替换为 AppBackButton(icon: Icons.close_rounded)');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: '发现 AppBar leading 槽位使用了非统一的关闭图标按钮，破坏了顶栏操作按钮尺寸与 Hover 交互一致性！',
    );
  });
}
