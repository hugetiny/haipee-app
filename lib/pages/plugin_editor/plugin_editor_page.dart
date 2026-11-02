import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/widget/settings/card_settings_ui.dart';
import 'package:haipee/plugins/plugins.dart';
import 'package:haipee/plugins/plugins_controller.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/pages/plugin_editor/widgets/plugin_dry_run_dialog.dart';
import 'package:haipee/plugins/plugins_providers.dart';
import 'package:haipee/l10n/generated/translations.g.dart';

class PluginEditorPage extends ConsumerStatefulWidget {
  const PluginEditorPage({
    super.key,
    required this.plugin,
  });

  final Plugin plugin;

  @override
  ConsumerState<PluginEditorPage> createState() => _PluginEditorPageState();
}

class _PluginEditorPageState extends ConsumerState<PluginEditorPage> {
  late final PluginsController pluginsController;
  final TextEditingController apiController = TextEditingController();
  final TextEditingController typeController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController versionController = TextEditingController();
  final TextEditingController userAgentController = TextEditingController();
  final TextEditingController baseURLController = TextEditingController();
  final TextEditingController searchURLController = TextEditingController();
  final TextEditingController searchListController = TextEditingController();
  final TextEditingController searchNameController = TextEditingController();
  final TextEditingController searchResultController = TextEditingController();
  final TextEditingController chapterRoadsController = TextEditingController();
  final TextEditingController chapterResultController = TextEditingController();
  final TextEditingController refererController = TextEditingController();
  bool muliSources = true;
  bool useWebview = true;

  @override
  void initState() {
    super.initState();
    pluginsController = ref.read(pluginsProvider.notifier);
    final Plugin plugin = widget.plugin;
    apiController.text = plugin.api;
    typeController.text = plugin.type;
    nameController.text = plugin.name;
    versionController.text = plugin.version;
    userAgentController.text = plugin.userAgent;
    baseURLController.text = plugin.baseUrl;
    searchURLController.text = plugin.searchURL;
    searchListController.text = plugin.searchList;
    searchNameController.text = plugin.searchName;
    searchResultController.text = plugin.searchResult;
    chapterRoadsController.text = plugin.chapterRoads;
    chapterResultController.text = plugin.chapterResult;
    refererController.text = plugin.referer;
    muliSources = plugin.muliSources;
    useWebview = plugin.useWebview;

    // ✅ Initialize providers with plugin values after the build phase
    Future.microtask(() {
      if (mounted) {
        ref
            .read(pluginEditorUIProvider.notifier)
            .setUseNativePlayer(plugin.useNativePlayer);
        ref.read(pluginEditorUIProvider.notifier).setUsePost(plugin.usePost);
        ref
            .read(pluginEditorUIProvider.notifier)
            .setUseLegacyParser(plugin.useLegacyParser);
      }
    });
  }

  @override
  void dispose() {
    apiController.dispose();
    typeController.dispose();
    nameController.dispose();
    versionController.dispose();
    userAgentController.dispose();
    baseURLController.dispose();
    searchURLController.dispose();
    searchListController.dispose();
    searchNameController.dispose();
    searchResultController.dispose();
    chapterRoadsController.dispose();
    chapterResultController.dispose();
    refererController.dispose();
    super.dispose();
  }

  void _savePlugin() {
    final cleanName = nameController.text.trim().isEmpty
        ? widget.plugin.name.trim()
        : nameController.text.trim();
    if (cleanName.isEmpty) {
      HaipeeDialog.showToast(message: '请填写规则名称');
      return;
    }
    final Plugin plugin = widget.plugin;
    plugin.api = apiController.text.trim().isEmpty
        ? (widget.plugin.api.isEmpty ? '4' : widget.plugin.api)
        : apiController.text.trim();
    plugin.type = typeController.text.trim().isEmpty
        ? (widget.plugin.type.isEmpty ? 'xpath' : widget.plugin.type)
        : typeController.text.trim();
    plugin.name = cleanName;
    plugin.version = versionController.text.trim().isEmpty
        ? '1.0'
        : versionController.text.trim();
    plugin.userAgent = userAgentController.text;
    plugin.baseUrl = baseURLController.text.trim();
    plugin.searchURL = searchURLController.text.trim();
    plugin.searchList = searchListController.text.trim();
    plugin.searchName = searchNameController.text.trim();
    plugin.searchResult = searchResultController.text.trim();
    plugin.chapterRoads = chapterRoadsController.text.trim();
    plugin.chapterResult = chapterResultController.text.trim();
    plugin.muliSources = muliSources;
    plugin.useWebview = useWebview;
    // ✅ Read values from providers
    plugin.useNativePlayer =
        ref.read(pluginEditorUIProvider).useNativePlayer;
    plugin.usePost = ref.read(pluginEditorUIProvider).usePost;
    plugin.useLegacyParser =
        ref.read(pluginEditorUIProvider).useLegacyParser;
    plugin.referer = refererController.text;
    pluginsController.updatePlugin(plugin);
    pluginsController.togglePluginEnabled(plugin.name, true);
    HaipeeDialog.showToast(message: '已保存并启用规则: ${plugin.name}');
    Navigator.of(context).pop();
  }

  Widget _buildRuleTypeSelector(ThemeData theme, ColorScheme colorScheme) {
    final currentType = typeController.text.trim().toLowerCase();
    const protocols = [
      ('xpath', 'Haipee 规则'),
      ('maccms', 'MacCMS 规则'),
      ('tvbox', 'TVBox 规则'),
      ('iptv', 'IPTV 规则'),
      ('piped', 'Piped 规则'),
      ('alist', 'AList 规则'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '快捷选择规则协议类型',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: protocols.map((entry) {
              final code = entry.$1;
              final label = entry.$2;
              final isSelected = currentType == code ||
                  (code == 'xpath' && (currentType == 'anime' || currentType == 'kazumi' || currentType == 'haipee'));
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                visualDensity: VisualDensity.compact,
                onSelected: (_) {
                  setState(() {
                    typeController.text = code;
                    if (code == 'iptv') {
                      widget.plugin.category = 'live';
                    } else if (code == 'alist') {
                      widget.plugin.category = 'drive';
                    } else {
                      widget.plugin.category = 'video';
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldTile({
    required TextEditingController controller,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editorTexts = context.t.settings.plugins.editor;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isNewRule = widget.plugin.name.trim().isEmpty;

    return Scaffold(
      appBar: SysAppBar(
        title: Text(isNewRule ? '手动添加规则' : editorTexts.title),
        actions: [
          IconButton(
            tooltip: '测试抓取 (Dry-Run)',
            icon: const Icon(Icons.play_arrow_outlined),
            onPressed: () {
              final testPlugin = Plugin(
                api: apiController.text.trim().isEmpty
                    ? (widget.plugin.api.isEmpty ? '4' : widget.plugin.api)
                    : apiController.text.trim(),
                type: typeController.text.trim().isEmpty
                    ? (widget.plugin.type.isEmpty ? 'xpath' : widget.plugin.type)
                    : typeController.text.trim(),
                name: nameController.text.trim().isEmpty
                    ? widget.plugin.name
                    : nameController.text.trim(),
                version: versionController.text.trim(),
                muliSources: muliSources,
                useWebview: useWebview,
                useNativePlayer:
                    ref.read(pluginEditorUIProvider).useNativePlayer,
                usePost: ref.read(pluginEditorUIProvider).usePost,
                useLegacyParser:
                    ref.read(pluginEditorUIProvider).useLegacyParser,
                userAgent: userAgentController.text,
                baseUrl: baseURLController.text.trim(),
                searchURL: searchURLController.text.trim(),
                searchList: searchListController.text.trim(),
                searchName: searchNameController.text.trim(),
                searchResult: searchResultController.text.trim(),
                chapterRoads: chapterRoadsController.text.trim(),
                chapterResult: chapterResultController.text.trim(),
                referer: refererController.text,
                searchMode: widget.plugin.searchMode,
                searchApiConfig: widget.plugin.searchApiConfig,
                chapterMode: widget.plugin.chapterMode,
                chapterApiConfig: widget.plugin.chapterApiConfig,
                adBlocker: widget.plugin.adBlocker,
              );
              PluginDryRunDialog.show(context, testPlugin);
            },
          ),
          IconButton(
            tooltip: '保存规则',
            icon: const Icon(Icons.save_outlined),
            onPressed: _savePlugin,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SettingsList(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        sections: [
          SettingsSection(
            title: const Text('基本信息'),
            tiles: [
              _buildRuleTypeSelector(theme, colorScheme),
              _buildFieldTile(
                controller: nameController,
                label: editorTexts.fields.name,
              ),
              _buildFieldTile(
                controller: versionController,
                label: editorTexts.fields.version,
              ),
              _buildFieldTile(
                controller: typeController,
                label: '规则类型 (如 xpath, maccms, tvbox, iptv, piped, alist)',
              ),
              _buildFieldTile(
                controller: apiController,
                label: 'API 级别 (如 4)',
              ),
              _buildFieldTile(
                controller: baseURLController,
                label: editorTexts.fields.baseUrl,
              ),
            ],
          ),
          SettingsSection(
            title: const Text('搜索与列表规则 (XPath)'),
            tiles: [
              _buildFieldTile(
                controller: searchURLController,
                label: editorTexts.fields.searchUrl,
              ),
              _buildFieldTile(
                controller: searchListController,
                label: editorTexts.fields.searchList,
              ),
              _buildFieldTile(
                controller: searchNameController,
                label: editorTexts.fields.searchName,
              ),
              _buildFieldTile(
                controller: searchResultController,
                label: editorTexts.fields.searchResult,
              ),
            ],
          ),
          SettingsSection(
            title: const Text('剧集与线路规则 (XPath)'),
            tiles: [
              _buildFieldTile(
                controller: chapterRoadsController,
                label: editorTexts.fields.chapterRoads,
              ),
              _buildFieldTile(
                controller: chapterResultController,
                label: editorTexts.fields.chapterResult,
              ),
            ],
          ),
          SettingsSection(
            title: Text(editorTexts.advanced.title),
            tiles: [
              SettingsTile.switchTile(
                title: const Text('多线路支持'),
                description: const Text('该规则提供多个解析线路'),
                initialValue: muliSources,
                onToggle: (bool? value) {
                  setState(() {
                    muliSources = value ?? true;
                  });
                },
              ),
              SettingsTile.switchTile(
                title: const Text('WebView 解析'),
                description: const Text('通过无头 WebView 渲染嗅探解析页面'),
                initialValue: useWebview,
                onToggle: (bool? value) {
                  setState(() {
                    useWebview = value ?? false;
                  });
                },
              ),
              Consumer(
                builder: (context, ref, child) {
                  final useNativePlayer = ref.watch(pluginEditorUIProvider
                      .select((s) => s.useNativePlayer));
                  return SettingsTile.switchTile(
                    title: Text(editorTexts.advanced.nativePlayer.title),
                    description:
                        Text(editorTexts.advanced.nativePlayer.subtitle),
                    initialValue: useNativePlayer,
                    onToggle: (bool? value) {
                      ref
                          .read(pluginEditorUIProvider.notifier)
                          .setUseNativePlayer(value ?? false);
                    },
                  );
                },
              ),
              Consumer(
                builder: (context, ref, child) {
                  final usePost = ref.watch(
                      pluginEditorUIProvider.select((s) => s.usePost));
                  return SettingsTile.switchTile(
                    title: Text(editorTexts.advanced.httpPost.title),
                    description: Text(editorTexts.advanced.httpPost.subtitle),
                    initialValue: usePost,
                    onToggle: (bool? value) {
                      ref
                          .read(pluginEditorUIProvider.notifier)
                          .setUsePost(value ?? false);
                    },
                  );
                },
              ),
              Consumer(
                builder: (context, ref, child) {
                  final useLegacyParser = ref.watch(pluginEditorUIProvider
                      .select((s) => s.useLegacyParser));
                  return SettingsTile.switchTile(
                    title: Text(editorTexts.advanced.legacyParser.title),
                    description:
                        Text(editorTexts.advanced.legacyParser.subtitle),
                    initialValue: useLegacyParser,
                    onToggle: (bool? value) {
                      ref
                          .read(pluginEditorUIProvider.notifier)
                          .setUseLegacyParser(value ?? false);
                    },
                  );
                },
              ),
              _buildFieldTile(
                controller: userAgentController,
                label: editorTexts.fields.userAgent,
              ),
              _buildFieldTile(
                controller: refererController,
                label: editorTexts.fields.referer,
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '保存规则',
        onPressed: _savePlugin,
        child: const Icon(Icons.save),
      ),
    );
  }
}
