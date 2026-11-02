import 'dart:async';
import 'package:haipee/modules/debrid/debrid_provider.dart';
import 'package:haipee/modules/debrid/providers/pikpak_provider.dart';
import 'package:haipee/modules/debrid/providers/real_debrid_provider.dart';
import 'package:haipee/modules/debrid/providers/torbox_provider.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/storage.dart';
import 'package:logger/logger.dart';

/// Debrid 云端高速离线加速中枢调度器
class DebridService {
  static final DebridService instance = DebridService._();
  DebridService._();

  DebridProvider? _testProvider;

  /// 可用的全部 Debrid 提供者列表
  List<DebridProvider> get availableProviders => [
        RealDebridProvider(),
        TorBoxProvider(),
        PikPakProvider(),
      ];

  /// 当前激活的 Debrid 提供商
  DebridProvider? get activeProvider {
    if (_testProvider != null) return _testProvider;

    try {
      final providerId = (GStorage.setting.get(
        SettingBoxKey.debridProvider,
        defaultValue: 'none',
      ) as String)
          .trim()
          .toLowerCase();

      if (providerId == 'none' || providerId.isEmpty) return null;

      final normalizedProviderId = providerId.replaceAll('_', '').replaceAll('-', '');

      for (final p in availableProviders) {
        final normalizedId = p.identifier.replaceAll('_', '').replaceAll('-', '').toLowerCase();
        if (p.identifier == providerId || normalizedId == normalizedProviderId) {
          return p;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// 检查当前是否已启用并配置了 Debrid 云加速
  bool get isDebridEnabled {
    try {
      return activeProvider?.isConfigured ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 前置秒级探测云端缓存：若云端已有缓存，可直接连接高速 CDN，免去 P2P 寻轨与磁盘写入
  Future<bool> checkInstantAvailability(String magnetOrInfoHash) async {
    final provider = activeProvider;
    if (provider == null || !provider.isConfigured) return false;

    try {
      return await provider.checkInstantAvailability(magnetOrInfoHash);
    } catch (e) {
      HaipeeLogger().log(
        Level.debug,
        '[DebridService] checkInstantAvailability error: $e',
      );
      return false;
    }
  }

  /// 尝试通过云端离线高速 CDN 解析播放直链
  Future<String?> tryResolveDebridStream(
    String magnetOrInfoHash, {
    int targetEpisode = 1,
  }) async {
    final provider = activeProvider;
    if (provider == null || !provider.isConfigured) return null;

    HaipeeLogger().log(
      Level.info,
      '[DebridService] Checking ${provider.name} cloud cache for instant streaming...',
    );

    try {
      final isCached = await provider.checkInstantAvailability(magnetOrInfoHash);
      if (!isCached) {
        HaipeeLogger().log(
          Level.info,
          '[DebridService] Cloud cache miss on ${provider.name}. Falling back to local P2P engine.',
        );
        return null;
      }

      HaipeeLogger().log(
        Level.info,
        '[DebridService] Cloud cache HIT! Resolving ultra-fast CDN stream link...',
      );

      final streamUrl = await provider.resolveStreamUrl(
        magnetOrInfoHash,
        targetEpisode: targetEpisode,
      );

      if (streamUrl != null && streamUrl.isNotEmpty) {
        HaipeeLogger().log(
          Level.info,
          '[DebridService] Successfully offloaded to ${provider.name}: $streamUrl',
        );
        return streamUrl;
      }
    } catch (e) {
      HaipeeLogger().log(
        Level.warning,
        '[DebridService] Failed to resolve via ${provider.name}: $e',
      );
    }

    return null;
  }

  /// 设置测试 Mock 提供者
  void setProviderForTesting(DebridProvider? provider) {
    _testProvider = provider;
  }
}
