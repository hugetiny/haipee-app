import 'package:flutter/material.dart';
import 'package:haipee/bean/widget/responsive/adaptive_dialog_frame.dart';
import 'package:haipee/bean/widget/responsive/constrained_content.dart';

/// 纯原生 Material 3 设置列表容器
class SettingsList extends StatelessWidget {
  final List<Widget> sections;
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
  final dynamic leading;
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
    final Widget? effectiveLeading = leading is IconData
        ? Icon(leading as IconData)
        : (leading is Widget ? leading as Widget : null);

    if (switchValue != null) {
      return SwitchListTile(
        secondary: effectiveLeading,
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
        secondary: effectiveLeading,
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
      leading: effectiveLeading,
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

/// 纯原生 Material 3 设置滑块项
class SettingsSliderTile extends StatelessWidget {
  final dynamic leading;
  final Widget title;
  final Widget? description;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? valueLabel;
  final ValueChanged<double> onChanged;

  const SettingsSliderTile({
    super.key,
    this.leading,
    required this.title,
    this.description,
    required this.value,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Widget? effectiveLeading = leading is IconData
        ? Icon(leading as IconData)
        : (leading is Widget ? leading as Widget : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: effectiveLeading,
          title: title,
          subtitle: description,
          trailing: valueLabel != null
              ? Text(
                  valueLabel!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// 纯原生 Material 3 设置下拉选择项
class SettingsDropdownTile<T> extends StatelessWidget {
  final dynamic leading;
  final Widget title;
  final Widget? description;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final String? fallbackLabel;
  final bool enabled;

  const SettingsDropdownTile({
    super.key,
    this.leading,
    required this.title,
    this.description,
    required this.value,
    required this.options,
    required this.onChanged,
    this.fallbackLabel,
    this.enabled = true,
  });

  void _showMobilePicker(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AdaptiveDialogFrame(
          showDragHandle: true,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: DefaultTextStyle(
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    child: title,
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: options.entries.map((e) {
                        final isSelected = e.key == value;
                        return ListTile(
                          title: Text(
                            e.value,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? theme.colorScheme.primary : null,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                              : null,
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            onChanged(e.key);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget? effectiveLeading = leading is IconData
        ? Icon(leading as IconData)
        : (leading is Widget ? leading as Widget : null);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < 640;

    if (isMobile) {
      final selectedLabel = options[value] ?? fallbackLabel ?? '';
      return ListTile(
        leading: effectiveLeading,
        title: title,
        subtitle: description,
        enabled: enabled,
        onTap: enabled ? () => _showMobilePicker(context) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedLabel.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.45,
                ),
                child: Text(
                  selectedLabel,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.outline,
              size: 20,
            ),
          ],
        ),
      );
    }

    return ListTile(
      leading: effectiveLeading,
      title: title,
      subtitle: description,
      enabled: enabled,
      trailing: DropdownButton<T>(
        value: options.containsKey(value) ? value : null,
        hint: fallbackLabel != null ? Text(fallbackLabel!) : null,
        underline: const SizedBox.shrink(),
        onChanged: enabled
            ? (v) {
                if (v != null) onChanged(v);
              }
            : null,
        items: options.entries
            .map(
              (e) => DropdownMenuItem<T>(
                value: e.key,
                child: Text(e.value),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// 纯原生 Material 3 单选分区容器
class SettingsRadioSection<T> extends StatelessWidget {
  final Widget? title;
  final T groupValue;
  final ValueChanged<T?> onChanged;
  final List<Widget> tiles;

  const SettingsRadioSection({
    super.key,
    this.title,
    required this.groupValue,
    required this.onChanged,
    required this.tiles,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: title,
      tiles: tiles,
    );
  }
}

/// 原生 Haipee 风格分类 Header
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.description});

  final Widget title;
  final Widget? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: DefaultTextStyle.merge(
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            child: title,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            child: description!,
          ),
        ],
      ],
    );
  }
}

/// 原生 Haipee 分类导航瓦片（用于移动端与自适应折叠布局）
class SettingsCategoryTile extends StatelessWidget {
  const SettingsCategoryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Widget? value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              DefaultTextStyle(
                style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ) ??
                    const TextStyle(),
                child: value!,
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

