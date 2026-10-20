import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/app_back_button.dart';
import 'package:kazumi/bean/widget/desktop_window_controls_safe_area.dart';
import 'kazumi_app_bar_actions.dart';

/// 播放页覆盖在视频之上的顶栏，视觉与普通页 AppBar 一致，但以 overlay 形式显隐
class KazumiTopOverlayBar extends StatelessWidget {
  final Widget? title;
  final KazumiAppBarActions? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final bool fullscreenAware; // 全屏时可切换透明/留边策略
  final bool requireOffset; // 与现有 EmbeddedNativeControlArea 的行为契合
  final double height;

  const KazumiTopOverlayBar({
    super.key,
    this.title,
    this.actions,
    this.showBack = true,
    this.onBack,
    this.fullscreenAware = true,
    this.requireOffset = true,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = fullscreenAware
        ? Colors.black.withValues(alpha: 0.0)
        : Colors.black.withValues(alpha: 0.2);

    return DesktopWindowControlsSafeArea(
      requireOffset: requireOffset,
      child: Container(
        height: height,
        padding: EdgeInsets.only(
            top: requireOffset ? MediaQuery.paddingOf(context).top : 0),
        color: bg,
        child: Row(
        children: [
          if (showBack)
            AppBackButton(
              color: Colors.white,
              onPressed: onBack,
            ),
          Expanded(child: Align(
            alignment: Alignment.centerLeft,
            child: DefaultTextStyle(
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white) ?? const TextStyle(color: Colors.white),
              child: title ?? const SizedBox(),
            ),
          )),
          if (actions != null) actions!,
        ],
      ),
    ),
  );
}
}
