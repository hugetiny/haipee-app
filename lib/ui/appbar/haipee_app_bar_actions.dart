import 'package:flutter/material.dart';
import 'haipee_action_item.dart';

/// 统一构建右上角 actions 的小组件，控制尺寸、间距、禁用态与 Tooltip 策略
class HaipeeAppBarActions extends StatelessWidget {
  final List<HaipeeActionItem> items;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final double gap;

  const HaipeeAppBarActions({
    super.key,
    required this.items,
    this.iconSize = 22,
    this.padding = const EdgeInsets.symmetric(horizontal: 4),
    this.gap = 2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _buildAction(context, items[i], theme),
          if (i != items.length - 1) SizedBox(width: gap),
        ],
      ],
    );
  }

  Widget _buildAction(BuildContext context, HaipeeActionItem item, ThemeData theme) {
    final iconColor = item.color ?? theme.colorScheme.onSurface;
    final button = Padding(
      padding: padding,
      child: IconButton(
        iconSize: iconSize,
        splashRadius: iconSize + 6,
        onPressed: item.enabled ? item.onPressed : null,
        icon: Icon(item.icon, color: item.enabled ? iconColor : theme.disabledColor),
      ),
    );
    if ((item.tooltip ?? '').isEmpty) return button;
    return Tooltip(message: item.tooltip!, child: button);
  }
}
