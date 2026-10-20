import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/services/logging/app_log.dart';
import 'package:kazumi/services/logging/log_module.dart';
import 'package:window_manager/window_manager.dart';

/// 桌面平台系统级全局快捷键服务 (Global System HotKey Manager)
///
/// 专为 macOS / Windows / Linux 商业桌面级体验打造：
/// - 支持老板键/全局窗口显隐切换 (Boss Key / Toggle Window Visibility)
/// - 支持全局媒体控制 / 自定义系统快捷键挂载
/// - 自动处理平台生命周期、异常防御与安全注销，防止快捷键泄漏或按键冲突崩溃
class GlobalHotKeyManager {
  GlobalHotKeyManager._();
  static final GlobalHotKeyManager instance = GlobalHotKeyManager._();

  bool _initialized = false;
  final Set<HotKey> _registeredHotKeys = {};

  /// 默认老板键 / 窗口显隐热键 (macOS: Cmd+Shift+H, Windows/Linux: Ctrl+Shift+H)
  late final HotKey toggleWindowHotKey = HotKey(
    key: PhysicalKeyboardKey.keyH,
    modifiers: [
      if (!kIsWeb && Platform.isMacOS)
        HotKeyModifier.meta
      else
        HotKeyModifier.control,
      HotKeyModifier.shift,
    ],
    scope: HotKeyScope.system,
  );

  /// 默认全局播放/暂停热键 (macOS: Cmd+Shift+Space, Windows/Linux: Ctrl+Shift+Space)
  late final HotKey playPauseHotKey = HotKey(
    key: PhysicalKeyboardKey.space,
    modifiers: [
      if (!kIsWeb && Platform.isMacOS)
        HotKeyModifier.meta
      else
        HotKeyModifier.control,
      HotKeyModifier.shift,
    ],
    scope: HotKeyScope.system,
  );

  /// 全局播放/暂停回调钩子
  VoidCallback? onPlayPause;

  /// 初始化系统全局热键
  Future<void> init() async {
    if (kIsWeb || !Utils.isDesktop()) return;
    if (_initialized) return;

    try {
      // 保证重新注册前清理既有残留
      await hotKeyManager.unregisterAll();
      _registeredHotKeys.clear();

      // 注册默认老板键
      await register(
        hotKey: toggleWindowHotKey,
        onKeyDown: (hotKey) => toggleWindowVisibility(),
      );

      // 注册全局播放/暂停热键
      await register(
        hotKey: playPauseHotKey,
        onKeyDown: (hotKey) => _handlePlayPause(),
      );

      _initialized = true;
      AppLog.i(LogModule.system,
          '[GlobalHotKeyManager] Initialized system hotkeys successfully (Boss key & Play/Pause registered)');
    } catch (e, stack) {
      AppLog.w(
          LogModule.system, '[GlobalHotKeyManager] System hotkeys unavailable (native plugin not linked or unsupported): $e');
      if (kDebugMode && e is! MissingPluginException) {
        AppLog.handle(e, stack, '[GlobalHotKeyManager.init]');
      }
    }
  }

  void _handlePlayPause() {
    AppLog.d(LogModule.system,
        '[GlobalHotKeyManager] Global play/pause shortcut triggered');
    onPlayPause?.call();
  }

  /// 注册全局热键
  Future<bool> register({
    required HotKey hotKey,
    required HotKeyHandler onKeyDown,
    HotKeyHandler? onKeyUp,
  }) async {
    if (kIsWeb || !Utils.isDesktop()) return false;

    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: onKeyDown,
        keyUpHandler: onKeyUp,
      );
      _registeredHotKeys.add(hotKey);
      AppLog.d(LogModule.system,
          '[GlobalHotKeyManager] Registered hotkey: ${hotKey.key} with modifiers: ${hotKey.modifiers}');
      return true;
    } catch (e) {
      AppLog.w(LogModule.system,
          '[GlobalHotKeyManager] Failed to register hotkey ${hotKey.key}: $e');
      return false;
    }
  }

  /// 注销指定全局热键
  Future<void> unregister(HotKey hotKey) async {
    if (kIsWeb || !Utils.isDesktop()) return;

    try {
      await hotKeyManager.unregister(hotKey);
      _registeredHotKeys.remove(hotKey);
    } catch (e) {
      AppLog.w(LogModule.system,
          '[GlobalHotKeyManager] Failed to unregister hotkey: $e');
    }
  }

  /// 切换主窗口显隐与焦点（老板键核心实现）
  Future<void> toggleWindowVisibility() async {
    if (kIsWeb || !Utils.isDesktop()) return;

    try {
      final isVisible = await windowManager.isVisible();
      if (isVisible) {
        await windowManager.hide();
        AppLog.d(LogModule.system,
            '[GlobalHotKeyManager] Window hidden by boss hotkey');
      } else {
        await windowManager.show();
        await windowManager.focus();
        AppLog.d(LogModule.system,
            '[GlobalHotKeyManager] Window shown and focused by boss hotkey');
      }
    } catch (e) {
      AppLog.w(LogModule.system,
          '[GlobalHotKeyManager] toggleWindowVisibility failed: $e');
    }
  }

  /// 清理并注销全部全局热键（程序退出时调用）
  Future<void> dispose() async {
    if (kIsWeb || !Utils.isDesktop()) return;

    try {
      await hotKeyManager.unregisterAll();
      AppLog.i(LogModule.system,
          '[GlobalHotKeyManager] All system hotkeys unregistered cleanly');
    } catch (e) {
      AppLog.w(LogModule.system,
          '[GlobalHotKeyManager] Error unregistering hotkeys during dispose: $e');
    } finally {
      _registeredHotKeys.clear();
      onPlayPause = null;
      _initialized = false;
    }
  }
}
