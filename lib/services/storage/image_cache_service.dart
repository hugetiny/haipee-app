import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageCacheService {
  Stream<File> _files() async* {
    final temporary = await getTemporaryDirectory();
    final directory =
        Directory(p.join(temporary.path, DefaultCacheManager.key));
    if (!await directory.exists()) return;
    yield* directory
        .list(recursive: true, followLinks: false)
        .where((entry) => entry is File)
        .cast<File>();
  }

  Future<int> sizeInBytes() async {
    var bytes = 0;
    await for (final file in _files()) {
      final stat = await file.stat();
      if (stat.type == FileSystemEntityType.file) bytes += stat.size;
    }
    return bytes;
  }

  Future<void> clear() async {
    final files = await _files().toList();
    await DefaultCacheManager().emptyCache();
    for (final file in files) {
      try {
        await file.delete();
      } on PathNotFoundException {
        // Already removed by cache manager.
      }
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}
