import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/pages/setting/providers.dart';
import 'package:kazumi/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<dynamic> box;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('metadata_settings_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>('setting');
    GStorage.setting = box;
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  setUp(() {
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDown(() async {
    await box.clear();
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  tearDownAll(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('setting');
    await tempDir.delete(recursive: true);
  });

  test('metadata settings default to enabled sources', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final MetadataSettingsState state =
        container.read(metadataSettingsProvider);

    expect(state.bangumiEnabled, isTrue);
    expect(state.tmdbEnabled, isTrue);
    expect(state.manualLocaleTag, isNull);
  });

  test('toggling metadata source persists to storage', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final MetadataSettingsNotifier notifier =
        container.read(metadataSettingsProvider.notifier);

    await notifier.setBangumiEnabled(false);
    await notifier.setTmdbEnabled(false);

    final MetadataSettingsState state =
        container.read(metadataSettingsProvider);

    expect(state.bangumiEnabled, isFalse);
    expect(state.tmdbEnabled, isFalse);
    expect(GStorage.setting.get(SettingBoxKey.metadataBangumiEnabled), isFalse);
    expect(GStorage.setting.get(SettingBoxKey.metadataTmdbEnabled), isFalse);
  });

  test('manual locale updates dashed tag and supports clearing', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final MetadataSettingsNotifier notifier =
        container.read(metadataSettingsProvider.notifier);

    await notifier.setManualLocale('ja-JP');
    expect(
        GStorage.setting.get(SettingBoxKey.metadataPreferredLocale), 'ja-JP');

    MetadataSettingsState state = container.read(metadataSettingsProvider);
    expect(state.manualLocaleTag, 'ja-JP');

    await notifier.setManualLocale(null);
    expect(GStorage.setting.get(SettingBoxKey.metadataPreferredLocale), '');

    state = container.read(metadataSettingsProvider);
    expect(state.manualLocaleTag, isNull);
  });

  test('app locale defaults to follow system when preference missing', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final LocaleSettingsState state = container.read(localeSettingsProvider);

    expect(state.followSystem, isTrue);
    expect(state.appLocale, AppLocaleUtils.findDeviceLocale());
  });

  test('setLocale persists manual selection', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final LocaleSettingsNotifier notifier =
        container.read(localeSettingsProvider.notifier);

    await notifier.setLocale(AppLocale.jaJp);

    final LocaleSettingsState state = container.read(localeSettingsProvider);

    expect(state.followSystem, isFalse);
    expect(state.appLocale, AppLocale.jaJp);
    expect(GStorage.setting.get(SettingBoxKey.appLocale), 'ja-JP');
  });

  test('useSystemLocale clears preference and resumes follow system', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final LocaleSettingsNotifier notifier =
        container.read(localeSettingsProvider.notifier);

    await notifier.setLocale(AppLocale.enUs);
    await notifier.useSystemLocale();

    final LocaleSettingsState state = container.read(localeSettingsProvider);

    expect(state.followSystem, isTrue);
    expect(GStorage.setting.get(SettingBoxKey.appLocale), '');
  });
}
