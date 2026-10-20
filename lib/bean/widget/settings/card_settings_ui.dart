import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/responsive/constrained_content.dart';

/// 纯原生 Material 3 设置列表容器
class SettingsList extends StatelessWidget {
  final List<SettingsSection> sections;
  final double? maxWidth;
  final EdgeInsetsGeometry? contentPadding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const SettingsList({
    super.key,
    required this.sections,
    this.maxWidth,
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget list = ListView.builder(
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: contentPadding,
      itemCount: sections.length,
      itemBuilder: (context, index) => sections[index],
    );

    if (maxWidth != null) {
      list = ConstrainedContent(
        maxWidth: maxWidth!,
        child: list,
      );
    }
    return list;
  }
}

/// 纯原生 Material 3 设置分区块
class SettingsSection extends StatelessWidget {
  final Widget? title;
  final List<Widget> tiles;
  final Widget? bottomInfo;
  final EdgeInsetsGeometry? margin;

  const SettingsSection({
    super.key,
    this.title,
    required this.tiles,
    this.bottomInfo,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: margin ?? const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8, top: 4),
              child: DefaultTextStyle(
                style: theme.textTheme.titleSmall!.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                child: title!,
              ),
            ),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < tiles.length; i++) ...[
                  tiles[i],
                  if (i < tiles.length - 1)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color:
                          theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                ],
              ],
            ),
          ),
          if (bottomInfo != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 6),
              child: DefaultTextStyle(
                style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                child: bottomInfo!,
              ),
            ),
        ],
      ),
    );
  }
}

/// 纯原生 Material 3 设置项
class SettingsTile<T> extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? description;
  final Widget? value;
  final Widget? trailing;
  final Function(BuildContext)? onPressed;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool selected;
  final EdgeInsetsGeometry? contentPadding;

  // switchTile 专用属性
  final bool? switchValue;
  final Function(bool?)? onToggle;

  // radioTile 专用属性
  final T? radioValue;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;

  const SettingsTile({
    super.key,
    this.leading,
    required this.title,
    this.description,
    this.value,
    this.trailing,
    this.onPressed,
    this.onLongPress,
    this.enabled = true,
    this.selected = false,
    this.contentPadding,
  })  : switchValue = null,
        onToggle = null,
        radioValue = null,
        groupValue = null,
        onChanged = null;

  const SettingsTile.navigation({
    super.key,
    this.leading,
    required this.title,
    this.description,
    this.value,
    this.trailing,
    this.onPressed,
    this.onLongPress,
    this.enabled = true,
    this.selected = false,
    this.contentPadding,
  })  : switchValue = null,
        onToggle = null,
        radioValue = null,
        groupValue = null,
        onChanged = null;

  const SettingsTile.switchTile({
    super.key,
    this.leading,
    required this.title,
    this.description,
    required bool initialValue,
    required this.onToggle,
    this.enabled = true,
    this.contentPadding,
  })  : switchValue = initialValue,
        value = null,
        trailing = null,
        onPressed = null,
        onLongPress = null,
        selected = false,
        radioValue = null,
        groupValue = null,
        onChanged = null;

  const SettingsTile.radioTile({
    super.key,
    this.leading,
    required this.title,
    this.description,
    required this.radioValue,
    required this.groupValue,
    required this.onChanged,
    this.enabled = true,
    this.contentPadding,
  })  : switchValue = null,
        onToggle = null,
        value = null,
        trailing = null,
        onPressed = null,
        onLongPress = null,
        selected = false;

  @override
  Widget build(BuildContext context) {
    if (switchValue != null) {
      return SwitchListTile(
        secondary: leading,
        title: title,
        subtitle: description,
        value: switchValue!,
        contentPadding: contentPadding,
        onChanged: enabled && onToggle != null ? (v) => onToggle!(v) : null,
      );
    }

    if (radioValue != null) {
      // ignore: deprecated_member_use
      return RadioListTile<T>(
        secondary: leading,
        title: title,
        subtitle: description,
        value: radioValue as T,
        // ignore: deprecated_member_use
        groupValue: groupValue,
        contentPadding: contentPadding,
        // ignore: deprecated_member_use
        onChanged: enabled && onChanged != null ? (v) => onChanged!(v) : null,
      );
    }

    Widget? effectiveTrailing = trailing;
    if (effectiveTrailing == null && (value != null || onPressed != null)) {
      effectiveTrailing = Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (value != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: DefaultTextStyle(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                child: value!,
              ),
            ),
          if (onPressed != null)
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        ],
      );
    }

    return ListTile(
      leading: leading,
      title: title,
      subtitle: description,
      trailing: effectiveTrailing,
      enabled: enabled,
      selected: selected,
      selectedTileColor:
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      contentPadding: contentPadding,
      onTap: enabled && onPressed != null ? () => onPressed!(context) : null,
      onLongPress: enabled && onLongPress != null ? onLongPress : null,
    );
  }
}

/// 纯原生 Material 3 设置徽章/标签组件
class SettingsBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final VoidCallback? onTap;
  final String? tooltip;

  const SettingsBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.textColor,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBg = color ?? theme.colorScheme.surfaceContainerHighest;
    final effectiveFg = textColor ?? theme.colorScheme.onSurfaceVariant;

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: effectiveFg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: effectiveFg,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      badge = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: badge,
      );
    }

    if (tooltip != null) {
      badge = Tooltip(
        message: tooltip!,
        child: badge,
      );
    }

    return badge;
  }
}

