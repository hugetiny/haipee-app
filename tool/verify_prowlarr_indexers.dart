// ignore_for_file: avoid_print
import 'dart:io';
import 'package:kazumi/modules/cardigann/models/cardigann_definition.dart';

void main() {
  final dir = Directory('prowlarr_indexers/definitions/v11');
  if (!dir.existsSync()) {
    print('Directory does not exist: ${dir.path}');
    return;
  }

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.yml'))
      .toList();

  print('Testing CardigannParser on ${files.length} Prowlarr YAML definitions...');
  int success = 0;
  int failed = 0;
  final errors = <String, String>{};

  for (final file in files) {
    try {
      final content = file.readAsStringSync();
      final def = CardigannParser.parseYaml(content);
      if (def.id.isNotEmpty && def.name.isNotEmpty) {
        success++;
      } else {
        failed++;
        errors[file.path] = 'Empty id or name';
      }
    } catch (e) {
      failed++;
      errors[file.path] = e.toString();
    }
  }

  print('========================================');
  print('Result: $success passed, $failed failed.');
  print('Pass rate: ${(success / files.length * 100).toStringAsFixed(1)}%');
  print('========================================');

  if (errors.isNotEmpty) {
    print('Sample errors (first 10):');
    errors.entries.take(10).forEach((e) => print('${e.key}: ${e.value}'));
  }
}
