import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const Set<String> _allowedExactLiterals = {
  '-',
  '—',
  '…',
  '·',
  '•',
  '• • •',
};

final RegExp _meaningfulCharacterPattern =
    RegExp(r'[A-Za-z\u00C0-\u024F\u4E00-\u9FFF\u3040-\u30FF\uAC00-\uD7AF]');

final List<String> _hardcodedScanRoots = <String>[
  p.join('lib', 'pages', 'settings', 'danmaku'),
];

const Set<String> _parityLocales = {
  'app_en-US.i18n.json',
};

class _PatternCheck {
  const _PatternCheck(this.regex, this.reason);

  final RegExp regex;
  final String reason;
}

final List<_PatternCheck> _checks = <_PatternCheck>[
  _PatternCheck(
    RegExp(r'''Text\(\s*(?:const\s+)?[rR]?(['"])([^'"]+?)\1'''),
    'Text widget uses a hardcoded string',
  ),
  _PatternCheck(
    RegExp(
        r'''HaipeeDialog\.showToast\([^)]*message:\s*[rR]?(['"])([^'"]+?)\1'''),
    'HaipeeDialog.showToast uses a hardcoded string',
  ),
];

Future<void> main(List<String> args) async {
  final List<String> issues = await runLocalizationAudit();
  if (issues.isNotEmpty) {
    for (final String issue in issues) {
      stderr.writeln(issue);
    }
    stderr
        .writeln('\nLocalization audit failed with ${issues.length} issue(s).');
    exitCode = 1;
    return;
  }
  stdout.writeln('Localization audit passed.');
}

Future<List<String>> runLocalizationAudit() async {
  final List<String> issues = <String>[];
  issues.addAll(await _checkTranslationParity());
  issues.addAll(await _scanForHardcodedStrings());
  return issues;
}

Future<List<String>> _scanForHardcodedStrings() async {
  final List<String> issues = <String>[];

  for (final String root in _hardcodedScanRoots) {
    final Directory directory = Directory(root);
    if (!await directory.exists()) {
      continue;
    }

    await for (final FileSystemEntity entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final String normalizedPath = p.normalize(entity.path);
      final List<String> lines = await entity.readAsLines();
      for (int index = 0; index < lines.length; index++) {
        final String line = lines[index];
        for (final _PatternCheck check in _checks) {
          for (final RegExpMatch match in check.regex.allMatches(line)) {
            final String literal = match.group(2) ?? '';
            if (_shouldFlagLiteral(literal)) {
              final String location =
                  '${p.relative(normalizedPath)}:${index + 1}';
              issues.add('$location -> ${check.reason}: "$literal"');
            }
          }
        }
      }
    }
  }

  return issues;
}

bool _shouldFlagLiteral(String literal) {
  final String trimmed = literal.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  if (_allowedExactLiterals.contains(trimmed)) {
    return false;
  }
  if (trimmed.contains('://')) {
    return false;
  }
  if (!_meaningfulCharacterPattern.hasMatch(trimmed)) {
    return false;
  }
  return true;
}

Future<List<String>> _checkTranslationParity() async {
  const String localeDirPath = 'lib/l10n';
  final Directory localeDir = Directory(localeDirPath);
  if (!await localeDir.exists()) {
    return <String>['Unable to locate $localeDirPath for parity audit.'];
  }

  final File baseFile = File(p.join(localeDirPath, 'app_zh-CN.i18n.json'));
  if (!await baseFile.exists()) {
    return <String>['Base locale app_zh-CN.i18n.json not found.'];
  }

  final Set<String> baseKeys = _loadLocaleKeys(baseFile);
  final List<String> issues = <String>[];

  await for (final FileSystemEntity entity in localeDir.list()) {
    if (entity is! File || !entity.path.endsWith('.i18n.json')) {
      continue;
    }

    final String fileName = p.basename(entity.path);
    if (!_parityLocales.contains(fileName)) {
      continue;
    }

    final Set<String> localeKeys = _loadLocaleKeys(entity);
    final Set<String> missingKeys = baseKeys.difference(localeKeys);
    final Set<String> extraKeys = localeKeys.difference(baseKeys);
    if (missingKeys.isNotEmpty) {
      issues.add(
          '${p.relative(entity.path)} is missing keys: ${missingKeys.join(', ')}');
    }
    if (extraKeys.isNotEmpty) {
      issues.add(
          '${p.relative(entity.path)} has extra keys: ${extraKeys.join(', ')}');
    }
  }

  return issues;
}

Set<String> _loadLocaleKeys(File file) {
  final String content = file.readAsStringSync();
  final Map<String, dynamic> jsonMap =
      jsonDecode(content) as Map<String, dynamic>;
  final Set<String> keys = <String>{};
  void collect(Map<String, dynamic> node, String prefix) {
    node.forEach((String key, dynamic value) {
      final String next = prefix.isEmpty ? key : '$prefix.$key';
      if (value is Map<String, dynamic>) {
        collect(value, next);
      } else {
        keys.add(next);
      }
    });
  }

  collect(jsonMap, '');
  return keys;
}
