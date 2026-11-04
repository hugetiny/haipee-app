import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/bean/widget/app_back_button.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/request/api.dart';
import 'package:haipee/router_constants.dart';

/// 统一风格的开源许可证与授权协议页面
///
/// 完全采用标准 [SysAppBar] 与 [AppBackButton]，在 macOS 桌面端无缝避让红黄绿窗口控制按钮，
/// 杜绝原生 LicensePage 在 macOS 标题栏隐藏模式下与交通灯按钮重叠挤占的问题。
class HaipeeLicensePage extends StatefulWidget {
  const HaipeeLicensePage({super.key});

  @override
  State<HaipeeLicensePage> createState() => _HaipeeLicensePageState();
}

class _HaipeeLicensePageState extends State<HaipeeLicensePage> {
  bool _loading = true;
  final Map<String, List<LicenseEntry>> _packageLicenses = {};
  List<String> _packages = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLicenses();
  }

  Future<void> _loadLicenses() async {
    try {
      await for (final entry in LicenseRegistry.licenses.handleError((_, __) {})) {
        for (final package in entry.packages) {
          _packageLicenses.putIfAbsent(package, () => []).add(entry);
        }
      }
      if (_packageLicenses.isEmpty) {
        _packageLicenses['haipee'] = [
          const LicenseEntryWithLineBreaks(
            ['haipee'],
            'Haipee open source media application.\nLicensed under the GNU General Public License v3.0.',
          ),
        ];
        _packageLicenses['flutter'] = [
          const LicenseEntryWithLineBreaks(
            ['flutter'],
            'Flutter framework.\nCopyright 2014 The Flutter Authors. All rights reserved.\nLicensed under the BSD-style license.',
          ),
        ];
      }
      final sortedPackages = _packageLicenses.keys.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (mounted) {
        setState(() {
          _packages = sortedPackages;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _openPackageDetail(String package, List<LicenseEntry> entries) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PackageLicenseDetailPage(
          packageName: package,
          entries: entries,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final pageTitle = t.settings.about.sections.licenses.title;
    final legalese = t.dialogs.about.licenseLegalese;

    final filteredPackages = _searchQuery.trim().isEmpty
        ? _packages
        : _packages
            .where((pkg) =>
                pkg.toLowerCase().contains(_searchQuery.trim().toLowerCase()))
            .toList();

    return Scaffold(
      appBar: SysAppBar(
        title: Text(pageTitle),
        leading: AppBackButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go(Routes.settings);
            }
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Card(
                          elevation: 0,
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 24, horizontal: 20),
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/images/logo/logo_rounded.png',
                                  width: 64,
                                  height: 64,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.verified_user_outlined,
                                    size: 56,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'haipee',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Version ${Api.version}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                ),
                                if (legalese.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    legalese,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: '搜索开源库 (${_packages.length})',
                            filled: true,
                            fillColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                      ),
                    ),
                    if (filteredPackages.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text('未找到匹配的开源库'),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final package = filteredPackages[index];
                              final entries = _packageLicenses[package] ?? [];
                              final licenseCount = entries.length;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 0,
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.25),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: ListTile(
                                  title: Text(
                                    package,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$licenseCount 项授权协议段落',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                  ),
                                  onTap: () =>
                                      _openPackageDetail(package, entries),
                                ),
                              );
                            },
                            childCount: filteredPackages.length,
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

/// 开源库详细许可文本查看页
class PackageLicenseDetailPage extends StatelessWidget {
  const PackageLicenseDetailPage({
    super.key,
    required this.packageName,
    required this.entries,
  });

  final String packageName;
  final List<LicenseEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(
        title: Text(packageName),
        leading: AppBackButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go(Routes.settingsAboutLicense);
            }
          },
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final paragraphs = entry.paragraphs.toList();

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 0,
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final p in paragraphs)
                        Padding(
                          padding: EdgeInsets.only(
                            top: 4,
                            bottom: 4,
                            left: p.indent >= 0 ? 16.0 * p.indent : 0.0,
                          ),
                          child: Text(
                            p.text,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontFamily: !kIsWeb && (Platform.isMacOS || Platform.isIOS)
                                      ? 'Menlo'
                                      : 'monospace',
                                  height: 1.4,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}
