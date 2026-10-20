// ignore_for_file: avoid_print
import 'dart:convert';
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

  files.sort((a, b) => a.path.compareTo(b.path));
  print('Generating catalog from ${files.length} Prowlarr indexers...');

  final catalog = <Map<String, dynamic>>[];

  for (final file in files) {
    try {
      final content = file.readAsStringSync();
      final def = CardigannParser.parseYaml(content);
      final fileName = file.uri.pathSegments.last;

      final categories = def.caps.categorymappings
          .map((m) => m.cat)
          .toSet()
          .toList()..sort();

      catalog.add({
        'id': def.id,
        'name': def.name,
        'description': def.description,
        'language': def.language,
        'type': def.type,
        'encoding': def.encoding,
        'links': def.links,
        'categories': categories,
        'fileName': fileName,
      });
    } catch (e) {
      print('Skipping ${file.path}: $e');
    }
  }

  final outFile = File('assets/indexers/prowlarr_catalog.json');
  outFile.writeAsStringSync(jsonEncode(catalog));
  print('Saved catalog with ${catalog.length} indexers to ${outFile.path} (${(outFile.lengthSync() / 1024).toStringAsFixed(1)} KB)');
}
