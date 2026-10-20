import 'package:flutter/material.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/widget/bottom_sheet/bottom_selector.dart';

/// 底部选择器示例页面
///
/// 展示 BottomSelector 的各种用法
class BottomSelectorExample extends StatefulWidget {
  const BottomSelectorExample({super.key});

  @override
  State<BottomSelectorExample> createState() => _BottomSelectorExampleState();
}

class _BottomSelectorExampleState extends State<BottomSelectorExample> {
  final ValueNotifier<String?> _selectedFruitNotifier = ValueNotifier(null);
  final ValueNotifier<List<String>> _selectedColorsNotifier = ValueNotifier([]);
  final ValueNotifier<String?> _lastActionNotifier = ValueNotifier(null);

  String? get _selectedFruit => _selectedFruitNotifier.value;
  List<String> get _selectedColors => _selectedColorsNotifier.value;

  final List<String> _fruits = [
    '苹果',
    '香蕉',
    '橙子',
    '西瓜',
    '葡萄',
    '草莓',
    '芒果',
    '猕猴桃',
    '樱桃',
    '蓝莓',
  ];

  final List<String> _colors = [
    '红色',
    '橙色',
    '黄色',
    '绿色',
    '青色',
    '蓝色',
    '紫色',
    '粉色',
    '棕色',
    '黑色',
    '白色',
    '灰色',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(
        title: Text('底部选择器示例'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 单选示例
          _buildSection(
            title: '单选选择器',
            description: '从列表中选择一个选项',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: _showSingleSelector,
                  icon: const Icon(Icons.list),
                  label: const Text('选择水果'),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String?>(
                  valueListenable: _selectedFruitNotifier,
                  builder: (context, selectedFruit, child) =>
                    selectedFruit != null ? Chip(
                      label: Text('已选择: $selectedFruit'),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        _selectedFruitNotifier.value = null;
                      },
                    ) : const SizedBox(),
                )
              ],
            ),
          ),

          const Divider(height: 32),

          // 带搜索的单选示例
          _buildSection(
            title: '带搜索的单选',
            description: '适用于大量选项的场景',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: _showSingleSelectorWithSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('搜索并选择水果'),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String?>(
                  valueListenable: _selectedFruitNotifier,
                  builder: (context, selectedFruit, child) =>
                    selectedFruit != null ? Text(
                      '当前选择: $selectedFruit',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ) : const SizedBox(),
                )
              ],
            ),
          ),

          const Divider(height: 32),

          // 多选示例
          _buildSection(
            title: '多选选择器',
            description: '从列表中选择多个选项',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: _showMultiSelector,
                  icon: const Icon(Icons.check_box),
                  label: const Text('选择颜色'),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<List<String>>(
                  valueListenable: _selectedColorsNotifier,
                  builder: (context, selectedColors, child) =>
                    selectedColors.isNotEmpty ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedColors.map((color) {
                        return Chip(
                          label: Text(color),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            final newColors = List<String>.from(selectedColors)..remove(color);
                            _selectedColorsNotifier.value = newColors;
                          },
                        );
                      }).toList(),
                    ) : Text(
                      '未选择任何颜色',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                )
              ],
            ),
          ),

          const Divider(height: 32),

          // 操作菜单示例
          _buildSection(
            title: '操作菜单',
            description: '显示操作选项列表',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: _showActionSheet,
                  icon: const Icon(Icons.more_vert),
                  label: const Text('显示操作菜单'),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String?>(
                  valueListenable: _lastActionNotifier,
                  builder: (context, lastAction, child) =>
                    lastAction != null ? Text(
                      '最后操作: $lastAction',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ) : const SizedBox(),
                )
              ],
            ),
          ),

          const Divider(height: 32),

          // 自定义图标示例
          _buildSection(
            title: '自定义图标',
            description: '为每个选项添加自定义图标',
            child: ElevatedButton.icon(
              onPressed: _showSelectorWithCustomIcons,
              icon: const Icon(Icons.palette),
              label: const Text('选择带图标的选项'),
            ),
          ),

          const Divider(height: 32),

          // 危险操作示例
          _buildSection(
            title: '危险操作',
            description: '显示带有警告的操作',
            child: ElevatedButton.icon(
              onPressed: _showDestructiveActions,
              icon: const Icon(Icons.warning),
              label: const Text('危险操作'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Future<void> _showSingleSelector() async {
    final result = await BottomSelector.showSingleSelector<String>(
      context: context,
      title: '选择水果',
      items: _fruits,
      currentValue: _selectedFruit,
      itemBuilder: (item) => item,
      leadingBuilder: (item) => const Icon(Icons.apple),
    );

    if (result != null) {
      _selectedFruitNotifier.value = result;
    }
  }

  Future<void> _showSingleSelectorWithSearch() async {
    final result = await BottomSelector.showSingleSelector<String>(
      context: context,
      title: '搜索水果',
      items: _fruits,
      currentValue: _selectedFruit,
      itemBuilder: (item) => item,
      showSearch: true,
      searchHint: '输入水果名称...',
      leadingBuilder: (item) => const Icon(Icons.search),
    );

    if (result != null) {
      _selectedFruitNotifier.value = result;
    }
  }

  Future<void> _showMultiSelector() async {
    final results = await BottomSelector.showMultiSelector<String>(
      context: context,
      title: '选择颜色（可多选）',
      items: _colors,
      selectedValues: _selectedColors,
      itemBuilder: (item) => item,
      showSearch: true,
      searchHint: '搜索颜色...',
      leadingBuilder: (item) => Icon(
        Icons.circle,
        color: _getColorByName(item),
      ),
    );

    if (results != null) {
      _selectedColorsNotifier.value = results;
    }
  }

  Future<void> _showActionSheet() async {
    final action = await BottomSelector.showActionSheet(
      context: context,
      title: '选择操作',
      actions: [
        const ActionSheetItem(
          key: 'share',
          label: '分享',
          icon: Icons.share,
        ),
        const ActionSheetItem(
          key: 'edit',
          label: '编辑',
          icon: Icons.edit,
        ),
        const ActionSheetItem(
          key: 'download',
          label: '下载',
          icon: Icons.download,
        ),
        const ActionSheetItem(
          key: 'delete',
          label: '删除',
          icon: Icons.delete,
          color: Colors.red,
          isDestructive: true,
        ),
      ],
      showCancel: true,
      cancelText: '取消',
    );

    if (action != null) {
      _lastActionNotifier.value = _getActionLabel(action);

      // 显示 SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('执行操作: ${_getActionLabel(action)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _showSelectorWithCustomIcons() async {
    final items = [
      {'name': '首页', 'icon': Icons.home},
      {'name': '搜索', 'icon': Icons.search},
      {'name': '收藏', 'icon': Icons.favorite},
      {'name': '设置', 'icon': Icons.settings},
      {'name': '帮助', 'icon': Icons.help},
    ];

    final result =
        await BottomSelector.showSingleSelector<Map<String, dynamic>>(
      context: context,
      title: '选择页面',
      items: items,
      itemBuilder: (item) => item['name'] as String,
      leadingBuilder: (item) => Icon(item['icon'] as IconData),
      trailingBuilder: (item) => const Icon(Icons.arrow_forward_ios, size: 16),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('选择了: ${result['name']}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _selectedFruitNotifier.dispose();
    _selectedColorsNotifier.dispose();
    _lastActionNotifier.dispose();
    super.dispose();
  }

  Future<void> _showDestructiveActions() async {
    final action = await BottomSelector.showActionSheet(
      context: context,
      title: '危险操作',
      actions: [
        const ActionSheetItem(
          key: 'clear_cache',
          label: '清除缓存',
          icon: Icons.clear_all,
        ),
        const ActionSheetItem(
          key: 'reset_settings',
          label: '重置设置',
          icon: Icons.settings_backup_restore,
          color: Colors.orange,
        ),
        const ActionSheetItem(
          key: 'delete_all',
          label: '删除所有数据',
          icon: Icons.delete_forever,
          color: Colors.red,
          isDestructive: true,
        ),
      ],
      showCancel: true,
    );

    if (action != null && mounted) {
      // 显示确认对话框
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认操作'),
          content: Text('确定要执行"${_getDestructiveActionLabel(action)}"吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('确认'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已执行: ${_getDestructiveActionLabel(action)}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _getActionLabel(String key) {
    switch (key) {
      case 'share':
        return '分享';
      case 'edit':
        return '编辑';
      case 'download':
        return '下载';
      case 'delete':
        return '删除';
      default:
        return key;
    }
  }

  String _getDestructiveActionLabel(String key) {
    switch (key) {
      case 'clear_cache':
        return '清除缓存';
      case 'reset_settings':
        return '重置设置';
      case 'delete_all':
        return '删除所有数据';
      default:
        return key;
    }
  }

  Color _getColorByName(String name) {
    switch (name) {
      case '红色':
        return Colors.red;
      case '橙色':
        return Colors.orange;
      case '黄色':
        return Colors.yellow;
      case '绿色':
        return Colors.green;
      case '青色':
        return Colors.cyan;
      case '蓝色':
        return Colors.blue;
      case '紫色':
        return Colors.purple;
      case '粉色':
        return Colors.pink;
      case '棕色':
        return Colors.brown;
      case '黑色':
        return Colors.black;
      case '白色':
        return Colors.white;
      case '灰色':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
