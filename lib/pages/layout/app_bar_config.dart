import 'package:flutter/material.dart';
import 'package:haipee/providers/riverpod_compat.dart';

/// AppBar 配置模型
class AppBarConfig {
  /// 标题文本或 Widget
  final dynamic title;

  /// 右侧操作按钮
  final List<Widget>? actions;

  /// 左侧按钮（返回按钮等）
  final Widget? leading;

  /// 底部 Widget（如 TabBar）
  final PreferredSizeWidget? bottom;

  /// 自定义工具栏高度
  final double? toolbarHeight;

  /// 是否需要顶部偏移
  final bool needTopOffset;

  /// 前导按钮宽度
  final double? leadingWidth;

  /// 是否显示 AppBar（某些页面可能不需要）
  final bool visible;

  const AppBarConfig({
    this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.toolbarHeight,
    this.needTopOffset = false,
    this.leadingWidth,
    this.visible = true,
  });

  /// 创建一个空的配置（隐藏 AppBar）
  const AppBarConfig.hidden() : this(visible: false);

  /// 拷贝并修改部分属性
  AppBarConfig copyWith({
    dynamic title,
    List<Widget>? actions,
    Widget? leading,
    PreferredSizeWidget? bottom,
    double? toolbarHeight,
    bool? needTopOffset,
    double? leadingWidth,
    bool? visible,
  }) {
    return AppBarConfig(
      title: title ?? this.title,
      actions: actions ?? this.actions,
      leading: leading ?? this.leading,
      bottom: bottom ?? this.bottom,
      toolbarHeight: toolbarHeight ?? this.toolbarHeight,
      needTopOffset: needTopOffset ?? this.needTopOffset,
      leadingWidth: leadingWidth ?? this.leadingWidth,
      visible: visible ?? this.visible,
    );
  }
}

/// 全局 AppBar 配置 Provider
final appBarConfigProvider = StateProvider<AppBarConfig?>((ref) => null);
