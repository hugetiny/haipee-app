import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kazumi/utils/utils.dart';

/// 跨平台现代商业级高质感返回按钮组件
/// 
/// 核心特性：
/// 1. 桌面端平滑细腻的悬浮 (Hover) 背景与微边框过渡动效 (150ms Ease-out)
/// 2. 点击按下时的弹性微缩放反馈 (Press scale feedback 0.93)
/// 3. 平台原生契合的矢量图标 (macOS/iOS 使用 Apple HIG 风格平滑箭头，Windows/Android 使用 Material 3 圆角箭头)
/// 4. 国际化 Tooltip (遵循系统 MaterialLocalizations) 与快捷感知
/// 5. 支持任意深色/浅色/全屏白色自定义场景
/// 6. 全局统一的标准热区与对齐 (默认 48x48 触摸包络，视觉按钮 34x34 居中对齐)
class AppBackButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Color? color;
  final String? tooltip;
  final double size;
  final double? iconSize;
  final BorderRadius? borderRadius;
  final IconData? icon;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.tooltip,
    this.size = 34.0,
    this.iconSize,
    this.borderRadius,
    this.icon,
  });

  @override
  State<AppBackButton> createState() => _AppBackButtonState();
}

class _AppBackButtonState extends State<AppBackButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  void _handleTap() {
    if (widget.onPressed != null) {
      widget.onPressed!();
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isApplePlatform = Platform.isMacOS || Platform.isIOS;

    // 默认图标颜色：如果传入则优先使用，否则跟随主题语义色
    final effectiveColor = widget.color ?? colorScheme.onSurface;

    // 图标大小：Apple 平台平滑箭头稍小更显精致，Material 箭头稍大
    final effectiveIconSize = widget.iconSize ?? (isApplePlatform ? 16.0 : 20.0);

    // 圆角：默认 8.0 现代微圆角
    final effectiveBorderRadius =
        widget.borderRadius ?? BorderRadius.circular(8.0);

    // 多语言 Tooltip
    final effectiveTooltip = widget.tooltip ??
        MaterialLocalizations.of(context).backButtonTooltip;

    // 背景色计算
    Color backgroundColor;
    if (_isPressed) {
      backgroundColor = widget.color != null
          ? widget.color!.withValues(alpha: 0.20)
          : colorScheme.onSurface.withValues(alpha: 0.16);
    } else if (_isHovered) {
      backgroundColor = widget.color != null
          ? widget.color!.withValues(alpha: 0.12)
          : colorScheme.onSurface.withValues(alpha: 0.08);
    } else {
      backgroundColor = Colors.transparent;
    }

    // 微高亮边框
    Border border;
    if (_isPressed || _isHovered) {
      border = Border.all(
        color: widget.color != null
            ? widget.color!.withValues(alpha: 0.35)
            : colorScheme.outlineVariant.withValues(alpha: 0.35),
        width: 1.0,
      );
    } else {
      border = Border.all(color: Colors.transparent, width: 1.0);
    }

    // 缩放比例
    final double scale = _isPressed
        ? 0.93
        : (_isHovered && Utils.isDesktop() ? 1.04 : 1.0);

    final double slotWidth = math.max(48.0, widget.size);
    final double slotHeight = math.max(48.0, widget.size);

    final Widget buttonContent = SizedBox(
      width: slotWidth,
      height: slotHeight,
      child: Semantics(
        button: true,
        label: effectiveTooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            if (mounted) setState(() => _isHovered = true);
          },
          onExit: (_) {
            if (mounted) {
              setState(() {
                _isHovered = false;
                _isPressed = false;
              });
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              if (mounted) setState(() => _isPressed = true);
            },
            onTapUp: (_) {
              if (mounted) setState(() => _isPressed = false);
            },
            onTapCancel: () {
              if (mounted) setState(() => _isPressed = false);
            },
            onTap: _handleTap,
            child: Center(
              child: AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  width: widget.size,
                  height: widget.size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: effectiveBorderRadius,
                    border: border,
                  ),
                  child: Icon(
                    widget.icon ??
                        (isApplePlatform
                            ? Icons.arrow_back_ios_new_rounded
                            : Icons.arrow_back_rounded),
                    size: effectiveIconSize,
                    color: effectiveColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Tooltip(
      message: effectiveTooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: buttonContent,
    );
  }
}
