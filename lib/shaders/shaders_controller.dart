import 'dart:io';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:kazumi/utils/logger.dart';

class ShadersController {
  Directory? _shadersDirectory;
  int superResolutionType = 1;

  static const List<String> requiredShaderFiles = [
    'Anime4K_Clamp_Highlights.glsl',
    'Anime4K_Restore_CNN_VL.glsl',
    'Anime4K_Upscale_CNN_x2_VL.glsl',
    'Anime4K_AutoDownscalePre_x2.glsl',
    'Anime4K_AutoDownscalePre_x4.glsl',
    'Anime4K_Upscale_CNN_x2_M.glsl',
    'Anime4K_Restore_CNN_M.glsl',
    'Anime4K_Restore_CNN_S.glsl',
    'Anime4K_Upscale_CNN_x2_S.glsl',
  ];

  Directory get shadersDirectory {
    if (_shadersDirectory != null) return _shadersDirectory!;
    // Fallback temporary location to prevent LateInitializationError if accessed synchronously
    return Directory(path.join(Directory.systemTemp.path, 'kazumi_shaders'));
  }

  set shadersDirectory(Directory dir) {
    _shadersDirectory = dir;
  }

  Future<Directory> ensureInitialized() async {
    final targetDir = _shadersDirectory ?? await _resolveShadersDirectory();
    bool allValid = true;
    for (final fileName in requiredShaderFiles) {
      final file = File(path.join(targetDir.path, fileName));
      if (!await file.exists() || await file.length() < 100) {
        allValid = false;
        break;
      }
    }

    if (!allValid) {
      await copyShadersToExternalDirectory();
    }
    return shadersDirectory;
  }

  Future<Directory> _resolveShadersDirectory() async {
    try {
      final directory = await getApplicationSupportDirectory();
      _shadersDirectory = Directory(path.join(directory.path, 'anime_shaders'));
    } catch (_) {
      _shadersDirectory =
          Directory(path.join(Directory.systemTemp.path, 'kazumi_shaders'));
    }
    return _shadersDirectory!;
  }

  Future<void> copyShadersToExternalDirectory() async {
    await _resolveShadersDirectory();

    if (!await _shadersDirectory!.exists()) {
      try {
        await _shadersDirectory!.create(recursive: true);
        KazumiLogger()
            .log(Level.info, 'Create GLSL Shader: ${_shadersDirectory!.path}');
      } catch (e) {
        KazumiLogger()
            .log(Level.warning, 'Could not create shaders directory: $e');
      }
    }

    List<String> shaderFiles = [];
    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = assetManifest.listAssets();
      shaderFiles = assets
          .where((String asset) =>
              asset.startsWith('assets/shaders/') && asset.endsWith('.glsl'))
          .toList();
    } catch (e) {
      KazumiLogger().log(Level.warning, 'AssetManifest load shaders failed: $e');
    }

    if (shaderFiles.isEmpty) {
      for (final s in requiredShaderFiles) {
        shaderFiles.add('assets/shaders/$s');
      }
    }

    int copiedFilesCount = 0;

    for (var filePath in shaderFiles) {
      final fileName = filePath.split('/').last;
      final targetFile = File(path.join(_shadersDirectory!.path, fileName));
      if (await targetFile.exists() && await targetFile.length() >= 100) {
        KazumiLogger()
            .log(Level.info, 'GLSL Shader exists, skip: ${targetFile.path}');
        continue;
      }

      try {
        final data = await rootBundle.load(filePath);
        final List<int> bytes = data.buffer.asUint8List();
        await targetFile.writeAsBytes(bytes);
        copiedFilesCount++;
        KazumiLogger().log(Level.info, 'Copy: ${targetFile.path}');
      } catch (e) {
        KazumiLogger().log(Level.warning, 'Copy: ($filePath): $e');
      }
    }

    KazumiLogger().log(Level.info,
        '$copiedFilesCount GLSL files copied to ${_shadersDirectory!.path}');
  }
}
