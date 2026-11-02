import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/settings/settings_detail_scaffold.dart';
import 'package:haipee/bean/widget/settings/card_settings_ui.dart';

/// 响应式主菜单/子菜单项定义
class ResponsiveMenuItem {
  const ResponsiveMenuItem({
    required this.id,
    required this.title,
    this.description,
    required this.icon,
    this.key,
    this.badge,
    this.route,
    this.detailBuilder,
    this.onTap,
    this.trailing,
  });

  final String id;
  final String title;
  final String? description;
  final IconData icon;
  final Key? key;
  final String? badge;
  final String? route;
  final WidgetBuilder? detailBuilder;
  final VoidCallback? onTap;
  final Widget? trailing;
}

/// 响应式主菜单分组
class ResponsiveMenuGroup {
  const ResponsiveMenuGroup({
    required this.title,
    required this.items,
    this.key,
  });

  final String title;
  final Key? key;
  final List<ResponsiveMenuItem> items;
}

/// 统一响应式主菜单/子菜单脚手架组件
///
/// 遵循 Haipee 统一自适应设计系统：
/// - 宽屏 (宽度 > [breakpoint], 默认 640px): 呈现 280px 侧边栏轨道 (NavigationRail/RailDestination) + 垂直分割线 + 嵌入式详情面板 (SettingsPaneScope/SettingsDetailScaffold)
/// - 窄屏 (宽度 <= [breakpoint]): 呈现优雅的 Material 3 现代化卡片分组列表 (SettingsSection + SettingsCategoryTile)，点击平滑推入对应路由或子页面
class ResponsiveMenuScaffold extends StatefulWidget {
  const ResponsiveMenuScaffold({
    super.key,
    required this.groups,
    this.selectedId,
    this.onSelected,
    this.detailBuilder,
    this.breakpoint = 640,
    this.railWidth = 280,
    this.onBackPressed,
    this.onWideChanged,
    this.narrowAppBarTitle,
    this.narrowAppBarActions,
    this.leading,
    this.appBarBuilder,
    this.scopeEmbedded = true,
  });

  final List<ResponsiveMenuGroup> groups;
  final String? selectedId;
  final ValueChanged<String>? onSelected;
  final Widget Function(BuildContext context, String selectedId)? detailBuilder;
  final double breakpoint;
  final double railWidth;
  final VoidCallback? onBackPressed;
  final ValueChanged<bool>? onWideChanged;
  final Widget? narrowAppBarTitle;
  final List<Widget>? narrowAppBarActions;
  final Widget? leading;
  final PreferredSizeWidget Function(BuildContext context, bool wide)? appBarBuilder;
  final bool scopeEmbedded;

  @override
  State<ResponsiveMenuScaffold> createState() => _ResponsiveMenuScaffoldState();
}

class _ResponsiveMenuScaffoldState extends State<ResponsiveMenuScaffold> {
  late String _activeId;

  String _findFirstId() {
    for (final group in widget.groups) {
      if (group.items.isNotEmpty) {
        return group.items.first.id;
      }
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _activeId = widget.selectedId ?? _findFirstId();
  }

  @override
  void didUpdateWidget(covariant ResponsiveMenuScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId != null && widget.selectedId != oldWidget.selectedId) {
      setState(() {
        _activeId = widget.selectedId!;
      });
    }
  }

  void _handleBack() {
    if (widget.onBackPressed != null) {
      widget.onBackPressed!();
      return;
    }
    if (HaipeeDialog.observer.hasHaipeeDialog) {
      HaipeeDialog.dismiss();
      return;
    }
    if (context.canPop()) {
      context.pop();
    }
  }

  ResponsiveMenuItem? _findItemById(String id) {
    for (final group in widget.groups) {
      for (final item in group.items) {
        if (item.id == id) return item;
      }
    }
    return null;
  }

  Widget _buildDetail(BuildContext context, String id) {
    if (widget.detailBuilder != null) {
      return widget.detailBuilder!(context, id);
    }
    final item = _findItemById(id);
    if (item?.detailBuilder != null) {
      return item!.detailBuilder!(context);
    }
    return const Center(child: Text('请选择子项目'));
  }

  void _onItemSelectWide(ResponsiveMenuItem item) {
    setState(() {
      _activeId = item.id;
    });
    widget.onSelected?.call(item.id);
    item.onTap?.call();
  }

  void _onItemSelectNarrow(ResponsiveMenuItem item) {
    if (item.onTap != null) {
      item.onTap!();
      return;
    }
    if (item.route != null && item.route!.isNotEmpty) {
      context.push(item.route!);
      return;
    }
    if (item.detailBuilder != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (c) => SettingsPaneScope(
            embedded: false,
            showBackButton: true,
            onBack: () => Navigator.of(c).pop(),
            child: item.detailBuilder!(c),
          ),
        ),
      );
      return;
    }
    widget.onSelected?.call(item.id);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > widget.breakpoint;

        if (widget.onWideChanged != null) {
          Future.microtask(() {
            if (mounted) {
              widget.onWideChanged!(wide);
            }
          });
        }

        if (wide) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (bool didPop, Object? result) {
              if (didPop) return;
              _handleBack();
            },
            child: Scaffold(
              appBar: widget.appBarBuilder?.call(context, true),
              body: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: widget.railWidth,
                      child: _ResponsiveMenuRailList(
                        groups: widget.groups,
                        selectedId: _activeId,
                        onSelect: _onItemSelectWide,
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.25),
                    ),
                    Expanded(
                      child: SettingsPaneScope(
                        embedded: widget.scopeEmbedded,
                        showBackButton: false,
                        onBack: _handleBack,
                        child: _buildDetail(context, _activeId),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        PreferredSizeWidget? narrowAppBar;
        if (widget.appBarBuilder != null) {
          narrowAppBar = widget.appBarBuilder!(context, false);
        } else if (widget.narrowAppBarTitle != null) {
          narrowAppBar = SysAppBar(
            title: widget.narrowAppBarTitle,
            actions: widget.narrowAppBarActions,
            leading: widget.leading,
          );
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (didPop) return;
            _handleBack();
          },
          child: Scaffold(
            appBar: narrowAppBar,
            body: _ResponsiveMenuCardList(
              groups: widget.groups,
              onSelect: _onItemSelectNarrow,
            ),
          ),
        );
      },
    );
  }
}

class _ResponsiveMenuRailList extends StatelessWidget {
  const _ResponsiveMenuRailList({
    required this.groups,
    required this.selectedId,
    required this.onSelect,
  });

  final List<ResponsiveMenuGroup> groups;
  final String selectedId;
  final ValueChanged<ResponsiveMenuItem> onSelect;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 24),
        children: [
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: SectionHeader(title: Text(group.title)),
            ),
            for (final item in group.items)
              _ResponsiveMenuRailDestination(
                item: item,
                selected: selectedId == item.id,
                onTap: () => onSelect(item),
              ),
          ],
        ],
      ),
    );
  }
}

class _ResponsiveMenuRailDestination extends StatelessWidget {
  const _ResponsiveMenuRailDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ResponsiveMenuItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        key: item.key,
        color: selected ? colorScheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(item.icon, size: 22, color: foreground),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.title,
                    style: textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.badge != null) ...[
                  SettingsBadge(
                    label: item.badge!,
                    color: selected
                        ? colorScheme.primary.withValues(alpha: 0.15)
                        : colorScheme.surfaceContainerHighest,
                    textColor:
                        selected ? colorScheme.primary : colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                ],
                if (item.trailing != null) ...[
                  item.trailing!,
                  const SizedBox(width: 8),
                ],
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResponsiveMenuCardList extends StatelessWidget {
  const _ResponsiveMenuCardList({
    required this.groups,
    required this.onSelect,
  });

  final List<ResponsiveMenuGroup> groups;
  final ValueChanged<ResponsiveMenuItem> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (final group in groups)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SettingsSection(
              title: Text(group.title),
              tiles: [
                for (final item in group.items)
                  SettingsCategoryTile(
                    key: item.key,
                    icon: item.icon,
                    title: item.title,
                    description: item.description ?? '',
                    onTap: () => onSelect(item),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
