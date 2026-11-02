import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_context_menu/super_context_menu.dart';

import 'package:haipee/utils/utils.dart';

/// 统一的上下文菜单条目抽象
sealed class AppMenuItem {
  const AppMenuItem();
}

/// 动作菜单项
class AppMenuAction extends AppMenuItem {
  final String title;
  final VoidCallback onSelected;
  final IconData? icon;
  final bool destructive;
  final bool disabled;
  final String? shortcutHint;

  const AppMenuAction({
    required this.title,
    required this.onSelected,
    this.icon,
    this.destructive = false,
    this.disabled = false,
    this.shortcutHint,
  });
}

/// 分割线
class AppMenuSeparator extends AppMenuItem {
  const AppMenuSeparator();
}

/// 子菜单
class AppMenuSubmenu extends AppMenuItem {
  final String title;
  final List<AppMenuItem> children;
  final IconData? icon;

  const AppMenuSubmenu({
    required this.title,
    required this.children,
    this.icon,
  });
}

/// 跨平台商业级原生右键/长按菜单组件
///
/// 在 macOS 上调用真实 NSMenu，在 Windows/Linux 上调用系统原生菜单，
/// 在移动端提供长按触发原生/自适应上下文菜单，保证沉浸式体验。
class AppContextMenu extends StatelessWidget {
  final Widget child;
  final List<AppMenuItem> Function(BuildContext context) itemsBuilder;
  final bool enabled;
  final HitTestBehavior hitTestBehavior;
  final bool enableLongPress;

  const AppContextMenu({
    super.key,
    required this.child,
    required this.itemsBuilder,
    this.enabled = true,
    this.hitTestBehavior = HitTestBehavior.opaque,
    this.enableLongPress = true,
  });

  /// 单元测试或特殊无原生 Runner 环境下切换为自适应纯 Flutter 菜单，避免 MissingPluginException
  @visibleForTesting
  static bool forceNative = false;

  static bool get _isTestEnvironment {
    if (forceNative) return false;
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    if (_isTestEnvironment) {
      return GestureDetector(
        behavior: hitTestBehavior,
        onSecondaryTapUp: (details) {
          show(context, details.globalPosition, itemsBuilder(context));
        },
        onLongPressStart: enableLongPress
            ? (details) {
                show(context, details.globalPosition, itemsBuilder(context));
              }
            : null,
        child: child,
      );
    }

    return ContextMenuWidget(
      hitTestBehavior: hitTestBehavior,
      contextMenuIsAllowed: (location) {
        if (!enableLongPress && !Utils.isDesktop()) {
          return false;
        }
        return true;
      },
      menuProvider: (MenuRequest request) {
        final items = itemsBuilder(context);
        if (items.isEmpty) return null;

        return Menu(
          children: _buildMenuElements(items),
        );
      },
      child: child,
    );
  }

  static List<MenuElement> _buildMenuElements(List<AppMenuItem> items) {
    final elements = <MenuElement>[];
    for (final item in items) {
      if (item is AppMenuAction) {
        elements.add(
          MenuAction(
            title: item.title,
            callback: item.disabled ? () {} : item.onSelected,
            image: item.icon != null ? MenuImage.icon(item.icon!) : null,
            attributes: MenuActionAttributes(
              destructive: item.destructive,
              disabled: item.disabled,
            ),
          ),
        );
      } else if (item is AppMenuSeparator) {
        elements.add(MenuSeparator());
      } else if (item is AppMenuSubmenu) {
        elements.add(
          Menu(
            title: item.title,
            image: item.icon != null ? MenuImage.icon(item.icon!) : null,
            children: _buildMenuElements(item.children),
          ),
        );
      }
    }
    return elements;
  }

  /// 编程式触发通用菜单（兼容传统点击/悬浮按钮）
  static Future<void> show(
    BuildContext context,
    Offset position,
    List<AppMenuItem> items,
  ) async {
    final popupItems = <PopupMenuEntry<VoidCallback>>[];
    for (final item in items) {
      if (item is AppMenuAction) {
        popupItems.add(
          PopupMenuItem<VoidCallback>(
            enabled: !item.disabled,
            value: item.onSelected,
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(
                    item.icon,
                    size: 18,
                    color: item.destructive
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    item.title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: item.destructive
                        ? TextStyle(color: Theme.of(context).colorScheme.error)
                        : null,
                  ),
                ),
                if (item.shortcutHint != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    item.shortcutHint!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      } else if (item is AppMenuSeparator) {
        popupItems.add(const PopupMenuDivider());
      } else if (item is AppMenuSubmenu) {
        popupItems.add(
          PopupMenuItem<VoidCallback>(
            value: () {
              if (context.mounted) {
                show(context, position, item.children);
              }
            },
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    item.title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_right, size: 18),
              ],
            ),
          ),
        );
      }
    }

    if (popupItems.isEmpty) return;

    final selected = await showMenu<VoidCallback>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: popupItems,
    );

    selected?.call();
  }
}

/// 桌面级原生上下文菜单别名，满足不同模块语义化调用
typedef DesktopContextMenu = AppContextMenu;

/// 自适应跨平台上下文菜单别名
typedef AdaptiveContextMenu = AppContextMenu;

