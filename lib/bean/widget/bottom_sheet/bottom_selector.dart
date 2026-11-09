import 'package:flutter/material.dart';

/// 全局统一的底部选择器
///
/// 用于替代下拉菜单，提供更好的用户体验
/// 支持单选、多选、搜索等功能
class BottomSelector {
  /// 显示底部单选选择器
  ///
  /// [context] - BuildContext
  /// [title] - 标题
  /// [items] - 选项列表
  /// [currentValue] - 当前选中值
  /// [itemBuilder] - 自定义显示文本
  /// [onSelected] - 选中回调
  /// [showSearch] - 是否显示搜索框
  /// [searchHint] - 搜索提示文本
  static Future<T?> showSingleSelector<T>({
    required BuildContext context,
    String? title,
    required List<T> items,
    T? currentValue,
    String Function(T item)? itemBuilder,
    bool showSearch = false,
    String? searchHint,
    Widget Function(T item)? leadingBuilder,
    Widget Function(T item)? trailingBuilder,
  }) async {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SingleSelectorBottomSheet<T>(
        title: title,
        items: items,
        currentValue: currentValue,
        itemBuilder: itemBuilder,
        showSearch: showSearch,
        searchHint: searchHint,
        leadingBuilder: leadingBuilder,
        trailingBuilder: trailingBuilder,
      ),
    );
  }

  /// 显示底部多选选择器
  ///
  /// [context] - BuildContext
  /// [title] - 标题
  /// [items] - 选项列表
  /// [selectedValues] - 当前选中值列表
  /// [itemBuilder] - 自定义显示文本
  /// [onConfirm] - 确认回调
  /// [showSearch] - 是否显示搜索框
  /// [searchHint] - 搜索提示文本
  static Future<List<T>?> showMultiSelector<T>({
    required BuildContext context,
    String? title,
    required List<T> items,
    List<T>? selectedValues,
    String Function(T item)? itemBuilder,
    bool showSearch = false,
    String? searchHint,
    Widget Function(T item)? leadingBuilder,
  }) async {
    return showModalBottomSheet<List<T>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MultiSelectorBottomSheet<T>(
        title: title,
        items: items,
        selectedValues: selectedValues ?? [],
        itemBuilder: itemBuilder,
        showSearch: showSearch,
        searchHint: searchHint,
        leadingBuilder: leadingBuilder,
      ),
    );
  }

  /// 显示底部操作菜单
  ///
  /// [context] - BuildContext
  /// [title] - 标题
  /// [actions] - 操作列表
  static Future<String?> showActionSheet({
    required BuildContext context,
    String? title,
    required List<ActionSheetItem> actions,
    bool showCancel = true,
    String? cancelText,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ActionSheetBottomSheet(
        title: title,
        actions: actions,
        showCancel: showCancel,
        cancelText: cancelText,
      ),
    );
  }
}

/// 操作菜单项
class ActionSheetItem {
  final String key;
  final String label;
  final IconData? icon;
  final Color? color;
  final bool isDestructive;

  const ActionSheetItem({
    required this.key,
    required this.label,
    this.icon,
    this.color,
    this.isDestructive = false,
  });
}

/// 单选选择器底部弹窗
class _SingleSelectorBottomSheet<T> extends StatefulWidget {
  final String? title;
  final List<T> items;
  final T? currentValue;
  final String Function(T item)? itemBuilder;
  final bool showSearch;
  final String? searchHint;
  final Widget Function(T item)? leadingBuilder;
  final Widget Function(T item)? trailingBuilder;

  const _SingleSelectorBottomSheet({
    this.title,
    required this.items,
    this.currentValue,
    this.itemBuilder,
    this.showSearch = false,
    this.searchHint,
    this.leadingBuilder,
    this.trailingBuilder,
  });

  @override
  State<_SingleSelectorBottomSheet<T>> createState() =>
      _SingleSelectorBottomSheetState<T>();
}

class _SingleSelectorBottomSheetState<T>
    extends State<_SingleSelectorBottomSheet<T>> {
  final ValueNotifier<List<T>> _filteredItemsNotifier = ValueNotifier([]);
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItemsNotifier.value = widget.items;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filteredItemsNotifier.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      _filteredItemsNotifier.value = widget.items;
    } else {
      _filteredItemsNotifier.value = widget.items.where((item) {
        final text = widget.itemBuilder?.call(item) ?? item.toString();
        return text.toLowerCase().contains(query);
      }).toList();
    }
  }

  String _getItemText(T item) {
    return widget.itemBuilder?.call(item) ?? item.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动条
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),          // 标题
          if (widget.title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Text(
                widget.title!,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // 搜索框
          if (widget.showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.searchHint ?? '搜索...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

          // 选项列表
          Flexible(
            child: ValueListenableBuilder<List<T>>(
              valueListenable: _filteredItemsNotifier,
              builder: (context, filteredItems, child) => ListView.builder(
                shrinkWrap: true,
                itemCount: filteredItems.length,
                padding: const EdgeInsets.only(bottom: 16),
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  final isSelected = item == widget.currentValue;
                  final text = _getItemText(item);

                  return ListTile(
                    leading: widget.leadingBuilder?.call(item),
                    title: Text(
                      text,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    trailing: widget.trailingBuilder?.call(item) ??
                        (isSelected
                            ? Icon(
                                Icons.check,
                                color: theme.colorScheme.primary,
                              )
                            : null),
                    selected: isSelected,
                    onTap: () {
                      Navigator.of(context).pop(item);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}

/// 多选选择器底部弹窗
class _MultiSelectorBottomSheet<T> extends StatefulWidget {
  final String? title;
  final List<T> items;
  final List<T> selectedValues;
  final String Function(T item)? itemBuilder;
  final bool showSearch;
  final String? searchHint;
  final Widget Function(T item)? leadingBuilder;

  const _MultiSelectorBottomSheet({
    this.title,
    required this.items,
    required this.selectedValues,
    this.itemBuilder,
    this.showSearch = false,
    this.searchHint,
    this.leadingBuilder,
  });

  @override
  State<_MultiSelectorBottomSheet<T>> createState() =>
      _MultiSelectorBottomSheetState<T>();
}

class _MultiSelectorBottomSheetState<T>
    extends State<_MultiSelectorBottomSheet<T>> {
  final ValueNotifier<List<T>> _filteredItemsNotifier = ValueNotifier([]);
  final ValueNotifier<Set<T>> _selectedSetNotifier = ValueNotifier({});
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItemsNotifier.value = widget.items;
    _selectedSetNotifier.value = Set<T>.from(widget.selectedValues);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filteredItemsNotifier.dispose();
    _selectedSetNotifier.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      _filteredItemsNotifier.value = widget.items;
    } else {
      _filteredItemsNotifier.value = widget.items.where((item) {
        final text = widget.itemBuilder?.call(item) ?? item.toString();
        return text.toLowerCase().contains(query);
      }).toList();
    }
  }

  String _getItemText(T item) {
    return widget.itemBuilder?.call(item) ?? item.toString();
  }

  void _toggleItem(T item) {
    final newSelectedSet = Set<T>.from(_selectedSetNotifier.value);
    if (newSelectedSet.contains(item)) {
      newSelectedSet.remove(item);
    } else {
      newSelectedSet.add(item);
    }
    _selectedSetNotifier.value = newSelectedSet;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动条
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 标题和按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.title != null)
                  Text(
                    widget.title!,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(null);
                      },
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<Set<T>>(
                    valueListenable: _selectedSetNotifier,
                    builder: (context, selectedSet, child) => FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop(selectedSet.toList());
                      },
                      child: Text('确定 (${selectedSet.length})'),
                    ),
                  )
                  ],
                ),
              ],
            ),
          ),

          // 搜索框
          if (widget.showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.searchHint ?? '搜索...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

          // 选项列表
          Flexible(
            child: ValueListenableBuilder<List<T>>(
              valueListenable: _filteredItemsNotifier,
              builder: (context, filteredItems, child) => ListView.builder(
                shrinkWrap: true,
                itemCount: filteredItems.length,
                padding: const EdgeInsets.only(bottom: 16),
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return ValueListenableBuilder<Set<T>>(
                    valueListenable: _selectedSetNotifier,
                    builder: (context, selectedSet, child) {
                      final isSelected = selectedSet.contains(item);
                      final text = _getItemText(item);

                      return CheckboxListTile(
                        secondary: widget.leadingBuilder?.call(item),
                        title: Text(text),
                        value: isSelected,
                        onChanged: (_) => _toggleItem(item),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}

/// 操作菜单底部弹窗
class _ActionSheetBottomSheet extends StatelessWidget {
  final String? title;
  final List<ActionSheetItem> actions;
  final bool showCancel;
  final String? cancelText;

  const _ActionSheetBottomSheet({
    this.title,
    required this.actions,
    this.showCancel = true,
    this.cancelText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动条
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 标题
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text(
                  title!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            // 操作列表
            ...actions.map((action) {
              final color = action.isDestructive
                  ? theme.colorScheme.error
                  : (action.color ?? theme.colorScheme.onSurface);

              return ListTile(
                leading: action.icon != null
                    ? Icon(action.icon, color: color)
                    : null,
                title: Text(
                  action.label,
                  style: TextStyle(
                    color: color,
                    fontWeight: action.isDestructive
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop(action.key);
                },
              );
            }),

            // 取消按钮
            if (showCancel) ...[
              const Divider(height: 1),
              ListTile(
                title: Text(
                  cancelText ?? '取消',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
