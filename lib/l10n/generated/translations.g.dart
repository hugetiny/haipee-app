/// Generated file. Do not edit.
///
/// Original: lib/l10n
/// To regenerate, run: `dart run slang`
///
/// Locales: 4
/// Strings: 2774 (693 per locale)
///
/// Built on 2026-11-10 at 23:11 UTC

// coverage:ignore-file
// ignore_for_file: type=lint

import 'package:flutter/widgets.dart';
import 'package:slang/builder/model/node.dart';
import 'package:slang_flutter/slang_flutter.dart';
export 'package:slang_flutter/slang_flutter.dart';

const AppLocale _baseLocale = AppLocale.enUs;

/// Supported locales, see extension methods below.
///
/// Usage:
/// - LocaleSettings.setLocale(AppLocale.enUs) // set locale
/// - Locale locale = AppLocale.enUs.flutterLocale // get flutter locale from enum
/// - if (LocaleSettings.currentLocale == AppLocale.enUs) // locale check
enum AppLocale with BaseAppLocale<AppLocale, AppTranslations> {
	enUs(languageCode: 'en', countryCode: 'US', build: AppTranslations.build),
	jaJp(languageCode: 'ja', countryCode: 'JP', build: _TranslationsJaJp.build),
	zhCn(languageCode: 'zh', countryCode: 'CN', build: _TranslationsZhCn.build),
	zhTw(languageCode: 'zh', countryCode: 'TW', build: _TranslationsZhTw.build);

	const AppLocale({required this.languageCode, this.scriptCode, this.countryCode, required this.build}); // ignore: unused_element

	@override final String languageCode;
	@override final String? scriptCode;
	@override final String? countryCode;
	@override final TranslationBuilder<AppLocale, AppTranslations> build;

	/// Gets current instance managed by [LocaleSettings].
	AppTranslations get translations => LocaleSettings.instance.translationMap[this]!;
}

/// Method A: Simple
///
/// No rebuild after locale change.
/// Translation happens during initialization of the widget (call of t).
/// Configurable via 'translate_var'.
///
/// Usage:
/// String a = t.someKey.anotherKey;
/// String b = t['someKey.anotherKey']; // Only for edge cases!
AppTranslations get t => LocaleSettings.instance.currentTranslations;

/// Method B: Advanced
///
/// All widgets using this method will trigger a rebuild when locale changes.
/// Use this if you have e.g. a settings page where the user can select the locale during runtime.
///
/// Step 1:
/// wrap your App with
/// TranslationProvider(
/// 	child: MyApp()
/// );
///
/// Step 2:
/// final t = AppTranslations.of(context); // Get t variable.
/// String a = t.someKey.anotherKey; // Use t variable.
/// String b = t['someKey.anotherKey']; // Only for edge cases!
class TranslationProvider extends BaseTranslationProvider<AppLocale, AppTranslations> {
	TranslationProvider({required super.child}) : super(settings: LocaleSettings.instance);

	static InheritedLocaleData<AppLocale, AppTranslations> of(BuildContext context) => InheritedLocaleData.of<AppLocale, AppTranslations>(context);
}

/// Method B shorthand via [BuildContext] extension method.
/// Configurable via 'translate_var'.
///
/// Usage (e.g. in a widget's build method):
/// context.t.someKey.anotherKey
extension BuildContextTranslationsExtension on BuildContext {
	AppTranslations get t => TranslationProvider.of(this).translations;
}

/// Manages all translation instances and the current locale
class LocaleSettings extends BaseFlutterLocaleSettings<AppLocale, AppTranslations> {
	LocaleSettings._() : super(utils: AppLocaleUtils.instance);

	static final instance = LocaleSettings._();

	// static aliases (checkout base methods for documentation)
	static AppLocale get currentLocale => instance.currentLocale;
	static Stream<AppLocale> getLocaleStream() => instance.getLocaleStream();
	static AppLocale setLocale(AppLocale locale, {bool? listenToDeviceLocale = false}) => instance.setLocale(locale, listenToDeviceLocale: listenToDeviceLocale);
	static AppLocale setLocaleRaw(String rawLocale, {bool? listenToDeviceLocale = false}) => instance.setLocaleRaw(rawLocale, listenToDeviceLocale: listenToDeviceLocale);
	static AppLocale useDeviceLocale() => instance.useDeviceLocale();
	@Deprecated('Use [AppLocaleUtils.supportedLocales]') static List<Locale> get supportedLocales => instance.supportedLocales;
	@Deprecated('Use [AppLocaleUtils.supportedLocalesRaw]') static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
	static void setPluralResolver({String? language, AppLocale? locale, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver}) => instance.setPluralResolver(
		language: language,
		locale: locale,
		cardinalResolver: cardinalResolver,
		ordinalResolver: ordinalResolver,
	);
}

/// Provides utility functions without any side effects.
class AppLocaleUtils extends BaseAppLocaleUtils<AppLocale, AppTranslations> {
	AppLocaleUtils._() : super(baseLocale: _baseLocale, locales: AppLocale.values);

	static final instance = AppLocaleUtils._();

	// static aliases (checkout base methods for documentation)
	static AppLocale parse(String rawLocale) => instance.parse(rawLocale);
	static AppLocale parseLocaleParts({required String languageCode, String? scriptCode, String? countryCode}) => instance.parseLocaleParts(languageCode: languageCode, scriptCode: scriptCode, countryCode: countryCode);
	static AppLocale findDeviceLocale() => instance.findDeviceLocale();
	static List<Locale> get supportedLocales => instance.supportedLocales;
	static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
}

// translations

// Path: <root>
class AppTranslations implements BaseTranslations<AppLocale, AppTranslations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = AppTranslations.of(context);
	static AppTranslations of(BuildContext context) => InheritedLocaleData.of<AppLocale, AppTranslations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	AppTranslations.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.enUs,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en-US>.
	@override final TranslationMetadata<AppLocale, AppTranslations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final AppTranslations _root = this; // ignore: unused_field

	// Translations
	late final _TranslationsAppEnUs app = _TranslationsAppEnUs._(_root);
	late final _TranslationsMetadataEnUs metadata = _TranslationsMetadataEnUs._(_root);
	late final _TranslationsDownloadsEnUs downloads = _TranslationsDownloadsEnUs._(_root);
	late final _TranslationsTorrentEnUs torrent = _TranslationsTorrentEnUs._(_root);
	late final _TranslationsSettingsEnUs settings = _TranslationsSettingsEnUs._(_root);
	late final _TranslationsExitDialogEnUs exitDialog = _TranslationsExitDialogEnUs._(_root);
	late final _TranslationsTrayEnUs tray = _TranslationsTrayEnUs._(_root);
	late final _TranslationsNavigationEnUs navigation = _TranslationsNavigationEnUs._(_root);
	late final _TranslationsDialogsEnUs dialogs = _TranslationsDialogsEnUs._(_root);
	late final _TranslationsLibraryEnUs library = _TranslationsLibraryEnUs._(_root);
	late final _TranslationsPlaybackEnUs playback = _TranslationsPlaybackEnUs._(_root);
	late final _TranslationsNetworkEnUs network = _TranslationsNetworkEnUs._(_root);
	late final _TranslationsSyncEnUs sync = _TranslationsSyncEnUs._(_root);
}

// Path: app
class _TranslationsAppEnUs {
	_TranslationsAppEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Haipee';
	String get loading => 'Loading…';
	String get retry => 'Retry';
	String get confirm => 'Confirm';
	String get cancel => 'Cancel';
	String get delete => 'Delete';
}

// Path: metadata
class _TranslationsMetadataEnUs {
	_TranslationsMetadataEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get sectionTitle => 'Media Information';
	String get refresh => 'Refresh Metadata';
	late final _TranslationsMetadataSourceEnUs source = _TranslationsMetadataSourceEnUs._(_root);
	String get lastSynced => 'Last synced: {timestamp}';
}

// Path: downloads
class _TranslationsDownloadsEnUs {
	_TranslationsDownloadsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get sectionTitle => 'Download Queue';
	String get downloadOffline => 'Download engine not connected';
	String get queued => 'Queued';
	String get running => 'Downloading';
	String get completed => 'Completed';
	late final _TranslationsDownloadsPageEnUs page = _TranslationsDownloadsPageEnUs._(_root);
	late final _TranslationsDownloadsAddDialogEnUs addDialog = _TranslationsDownloadsAddDialogEnUs._(_root);
	late final _TranslationsDownloadsDetailDialogEnUs detailDialog = _TranslationsDownloadsDetailDialogEnUs._(_root);
}

// Path: torrent
class _TranslationsTorrentEnUs {
	_TranslationsTorrentEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	late final _TranslationsTorrentConsentEnUs consent = _TranslationsTorrentConsentEnUs._(_root);
	late final _TranslationsTorrentErrorEnUs error = _TranslationsTorrentErrorEnUs._(_root);
}

// Path: settings
class _TranslationsSettingsEnUs {
	_TranslationsSettingsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Settings';
	String get downloads => 'Download Settings';
	String get playback => 'Playback Preferences';
	late final _TranslationsSettingsGeneralEnUs general = _TranslationsSettingsGeneralEnUs._(_root);
	late final _TranslationsSettingsAppearancePageEnUs appearancePage = _TranslationsSettingsAppearancePageEnUs._(_root);
	late final _TranslationsSettingsSourceEnUs source = _TranslationsSettingsSourceEnUs._(_root);
	late final _TranslationsSettingsPluginsEnUs plugins = _TranslationsSettingsPluginsEnUs._(_root);
	late final _TranslationsSettingsMetadataEnUs metadata = _TranslationsSettingsMetadataEnUs._(_root);
	late final _TranslationsSettingsPlayerEnUs player = _TranslationsSettingsPlayerEnUs._(_root);
	late final _TranslationsSettingsWebdavEnUs webdav = _TranslationsSettingsWebdavEnUs._(_root);
	late final _TranslationsSettingsUpdateEnUs update = _TranslationsSettingsUpdateEnUs._(_root);
	late final _TranslationsSettingsOtherEnUs other = _TranslationsSettingsOtherEnUs._(_root);
	late final _TranslationsSettingsAboutEnUs about = _TranslationsSettingsAboutEnUs._(_root);
}

// Path: exitDialog
class _TranslationsExitDialogEnUs {
	_TranslationsExitDialogEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Exit Confirmation';
	String get message => 'Do you want to exit Haipee?';
	String get dontAskAgain => 'Don\'t ask again';
	String get exit => 'Exit Haipee';
	String get minimize => 'Minimize to Tray';
	String get cancel => 'Cancel';
}

// Path: tray
class _TranslationsTrayEnUs {
	_TranslationsTrayEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get showWindow => 'Show Window';
	String get exit => 'Exit Haipee';
}

// Path: navigation
class _TranslationsNavigationEnUs {
	_TranslationsNavigationEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	late final _TranslationsNavigationTabsEnUs tabs = _TranslationsNavigationTabsEnUs._(_root);
	late final _TranslationsNavigationActionsEnUs actions = _TranslationsNavigationActionsEnUs._(_root);
}

// Path: dialogs
class _TranslationsDialogsEnUs {
	_TranslationsDialogsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	late final _TranslationsDialogsDisclaimerEnUs disclaimer = _TranslationsDialogsDisclaimerEnUs._(_root);
	late final _TranslationsDialogsUpdateMirrorEnUs updateMirror = _TranslationsDialogsUpdateMirrorEnUs._(_root);
	late final _TranslationsDialogsPluginUpdatesEnUs pluginUpdates = _TranslationsDialogsPluginUpdatesEnUs._(_root);
	late final _TranslationsDialogsWebdavEnUs webdav = _TranslationsDialogsWebdavEnUs._(_root);
	late final _TranslationsDialogsAboutEnUs about = _TranslationsDialogsAboutEnUs._(_root);
	late final _TranslationsDialogsCacheEnUs cache = _TranslationsDialogsCacheEnUs._(_root);
}

// Path: library
class _TranslationsLibraryEnUs {
	_TranslationsLibraryEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	late final _TranslationsLibraryCommonEnUs common = _TranslationsLibraryCommonEnUs._(_root);
	late final _TranslationsLibraryPopularEnUs popular = _TranslationsLibraryPopularEnUs._(_root);
	late final _TranslationsLibraryTimelineEnUs timeline = _TranslationsLibraryTimelineEnUs._(_root);
	late final _TranslationsLibrarySearchEnUs search = _TranslationsLibrarySearchEnUs._(_root);
	late final _TranslationsLibraryHistoryEnUs history = _TranslationsLibraryHistoryEnUs._(_root);
	late final _TranslationsLibraryInfoEnUs info = _TranslationsLibraryInfoEnUs._(_root);
	late final _TranslationsLibraryMyEnUs my = _TranslationsLibraryMyEnUs._(_root);
}

// Path: playback
class _TranslationsPlaybackEnUs {
	_TranslationsPlaybackEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	late final _TranslationsPlaybackToastEnUs toast = _TranslationsPlaybackToastEnUs._(_root);
	late final _TranslationsPlaybackDanmakuEnUs danmaku = _TranslationsPlaybackDanmakuEnUs._(_root);
	late final _TranslationsPlaybackExternalPlayerEnUs externalPlayer = _TranslationsPlaybackExternalPlayerEnUs._(_root);
	late final _TranslationsPlaybackControlsEnUs controls = _TranslationsPlaybackControlsEnUs._(_root);
	late final _TranslationsPlaybackLoadingEnUs loading = _TranslationsPlaybackLoadingEnUs._(_root);
	late final _TranslationsPlaybackDanmakuSearchEnUs danmakuSearch = _TranslationsPlaybackDanmakuSearchEnUs._(_root);
	late final _TranslationsPlaybackRemoteEnUs remote = _TranslationsPlaybackRemoteEnUs._(_root);
	late final _TranslationsPlaybackDebugEnUs debug = _TranslationsPlaybackDebugEnUs._(_root);
	late final _TranslationsPlaybackSyncplayEnUs syncplay = _TranslationsPlaybackSyncplayEnUs._(_root);
	late final _TranslationsPlaybackPlaylistEnUs playlist = _TranslationsPlaybackPlaylistEnUs._(_root);
	late final _TranslationsPlaybackTabsEnUs tabs = _TranslationsPlaybackTabsEnUs._(_root);
	late final _TranslationsPlaybackCommentsEnUs comments = _TranslationsPlaybackCommentsEnUs._(_root);
	late final _TranslationsPlaybackSuperResolutionEnUs superResolution = _TranslationsPlaybackSuperResolutionEnUs._(_root);
}

// Path: network
class _TranslationsNetworkEnUs {
	_TranslationsNetworkEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	late final _TranslationsNetworkErrorEnUs error = _TranslationsNetworkErrorEnUs._(_root);
	late final _TranslationsNetworkStatusEnUs status = _TranslationsNetworkStatusEnUs._(_root);
}

// Path: sync
class _TranslationsSyncEnUs {
	_TranslationsSyncEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
}

// Path: metadata.source
class _TranslationsMetadataSourceEnUs {
	_TranslationsMetadataSourceEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get bangumi => 'Bangumi';
	String get tmdb => 'TMDb';
}

// Path: downloads.page
class _TranslationsDownloadsPageEnUs {
	_TranslationsDownloadsPageEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Download Manager';
	String selectedItems({required Object count}) => '${count} items selected';
	String get newDownload => 'New Download';
	String get batchManage => 'Batch Manage';
	String get downloadSettings => 'Download Settings';
	String get refresh => 'Refresh';
	late final _TranslationsDownloadsPageTabsEnUs tabs = _TranslationsDownloadsPageTabsEnUs._(_root);
	late final _TranslationsDownloadsPageActionsEnUs actions = _TranslationsDownloadsPageActionsEnUs._(_root);
	late final _TranslationsDownloadsPageStatisticsEnUs statistics = _TranslationsDownloadsPageStatisticsEnUs._(_root);
	late final _TranslationsDownloadsPageSearchEnUs search = _TranslationsDownloadsPageSearchEnUs._(_root);
	late final _TranslationsDownloadsPageSortEnUs sort = _TranslationsDownloadsPageSortEnUs._(_root);
	late final _TranslationsDownloadsPageEmptyEnUs empty = _TranslationsDownloadsPageEmptyEnUs._(_root);
	late final _TranslationsDownloadsPageStatusEnUs status = _TranslationsDownloadsPageStatusEnUs._(_root);
	late final _TranslationsDownloadsPageDialogEnUs dialog = _TranslationsDownloadsPageDialogEnUs._(_root);
	late final _TranslationsDownloadsPageToastEnUs toast = _TranslationsDownloadsPageToastEnUs._(_root);
}

// Path: downloads.addDialog
class _TranslationsDownloadsAddDialogEnUs {
	_TranslationsDownloadsAddDialogEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'New Download Task';
	late final _TranslationsDownloadsAddDialogTabsEnUs tabs = _TranslationsDownloadsAddDialogTabsEnUs._(_root);
	late final _TranslationsDownloadsAddDialogUrlEnUs url = _TranslationsDownloadsAddDialogUrlEnUs._(_root);
	late final _TranslationsDownloadsAddDialogTorrentEnUs torrent = _TranslationsDownloadsAddDialogTorrentEnUs._(_root);
	late final _TranslationsDownloadsAddDialogAdvancedEnUs advanced = _TranslationsDownloadsAddDialogAdvancedEnUs._(_root);
	late final _TranslationsDownloadsAddDialogActionsEnUs actions = _TranslationsDownloadsAddDialogActionsEnUs._(_root);
	late final _TranslationsDownloadsAddDialogErrorsEnUs errors = _TranslationsDownloadsAddDialogErrorsEnUs._(_root);
	late final _TranslationsDownloadsAddDialogToastEnUs toast = _TranslationsDownloadsAddDialogToastEnUs._(_root);
}

// Path: downloads.detailDialog
class _TranslationsDownloadsDetailDialogEnUs {
	_TranslationsDownloadsDetailDialogEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Task Details';
	late final _TranslationsDownloadsDetailDialogSectionsEnUs sections = _TranslationsDownloadsDetailDialogSectionsEnUs._(_root);
	late final _TranslationsDownloadsDetailDialogActionsEnUs actions = _TranslationsDownloadsDetailDialogActionsEnUs._(_root);
	late final _TranslationsDownloadsDetailDialogToastEnUs toast = _TranslationsDownloadsDetailDialogToastEnUs._(_root);
}

// Path: torrent.consent
class _TranslationsTorrentConsentEnUs {
	_TranslationsTorrentConsentEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'BitTorrent Usage Notice';
	String get description => 'Before enabling BT downloads, please confirm compliance with local laws and understand the risks involved.';
	String get agree => 'I understand, continue';
	String get decline => 'Not now';
}

// Path: torrent.error
class _TranslationsTorrentErrorEnUs {
	_TranslationsTorrentErrorEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get submit => 'Unable to submit magnet link, please try again later';
}

// Path: settings.general
class _TranslationsSettingsGeneralEnUs {
	_TranslationsSettingsGeneralEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'General';
	String get appearance => 'Appearance';
	String get appearanceDesc => 'Configure app theme and refresh rate';
	String get language => 'App Language';
	String get languageDesc => 'Choose the display language for the app interface';
	String get followSystem => 'System';
	String get exitBehavior => 'On Close';
	String get exitApp => 'Exit Haipee';
	String get minimizeToTray => 'Minimize to Tray';
	String get askEveryTime => 'Ask Every Time';
}

// Path: settings.appearancePage
class _TranslationsSettingsAppearancePageEnUs {
	_TranslationsSettingsAppearancePageEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Appearance';
	late final _TranslationsSettingsAppearancePageModeEnUs mode = _TranslationsSettingsAppearancePageModeEnUs._(_root);
	late final _TranslationsSettingsAppearancePageColorSchemeEnUs colorScheme = _TranslationsSettingsAppearancePageColorSchemeEnUs._(_root);
	late final _TranslationsSettingsAppearancePageOledEnUs oled = _TranslationsSettingsAppearancePageOledEnUs._(_root);
	late final _TranslationsSettingsAppearancePageWindowEnUs window = _TranslationsSettingsAppearancePageWindowEnUs._(_root);
	late final _TranslationsSettingsAppearancePageRefreshRateEnUs refreshRate = _TranslationsSettingsAppearancePageRefreshRateEnUs._(_root);
}

// Path: settings.source
class _TranslationsSettingsSourceEnUs {
	_TranslationsSettingsSourceEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Source';
	String get ruleManagement => 'Rule Management';
	String get ruleManagementDesc => 'Manage anime resource rules';
	String get githubProxy => 'GitHub Proxy';
	String get githubProxyDesc => 'Use proxy to access rule repository';
}

// Path: settings.plugins
class _TranslationsSettingsPluginsEnUs {
	_TranslationsSettingsPluginsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Rule Management';
	String get empty => 'No rules available';
	late final _TranslationsSettingsPluginsTooltipEnUs tooltip = _TranslationsSettingsPluginsTooltipEnUs._(_root);
	late final _TranslationsSettingsPluginsSortEnUs sort = _TranslationsSettingsPluginsSortEnUs._(_root);
	late final _TranslationsSettingsPluginsMultiSelectEnUs multiSelect = _TranslationsSettingsPluginsMultiSelectEnUs._(_root);
	late final _TranslationsSettingsPluginsLoadingEnUs loading = _TranslationsSettingsPluginsLoadingEnUs._(_root);
	late final _TranslationsSettingsPluginsLabelsEnUs labels = _TranslationsSettingsPluginsLabelsEnUs._(_root);
	late final _TranslationsSettingsPluginsActionsEnUs actions = _TranslationsSettingsPluginsActionsEnUs._(_root);
	late final _TranslationsSettingsPluginsDialogsEnUs dialogs = _TranslationsSettingsPluginsDialogsEnUs._(_root);
	late final _TranslationsSettingsPluginsToastEnUs toast = _TranslationsSettingsPluginsToastEnUs._(_root);
	late final _TranslationsSettingsPluginsEditorEnUs editor = _TranslationsSettingsPluginsEditorEnUs._(_root);
	late final _TranslationsSettingsPluginsShopEnUs shop = _TranslationsSettingsPluginsShopEnUs._(_root);
}

// Path: settings.metadata
class _TranslationsSettingsMetadataEnUs {
	_TranslationsSettingsMetadataEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Information Sources';
	String get enableBangumi => 'Enable Bangumi Information Source';
	String get enableBangumiDesc => 'Fetch anime information from Bangumi';
	String get enableTmdb => 'Enable TMDb Information Source';
	String get enableTmdbDesc => 'Supplement multilingual data from TMDb';
	String get preferredLanguage => 'Preferred Language';
	String get preferredLanguageDesc => 'Set the language for metadata synchronization';
	String get followSystemLanguage => 'Follow System Language';
	String get simplifiedChinese => 'Simplified Chinese (zh-CN)';
	String get traditionalChinese => 'Traditional Chinese (zh-TW)';
	String get japanese => 'Japanese (ja-JP)';
	String get english => 'English (en-US)';
	String get custom => 'Custom';
}

// Path: settings.player
class _TranslationsSettingsPlayerEnUs {
	_TranslationsSettingsPlayerEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Player Settings';
	String get playerSettings => 'Player Settings';
	String get playerSettingsDesc => 'Configure player parameters';
	String get hardwareDecoding => 'Hardware Decoding';
	String get hardwareDecoder => 'Hardware Decoder';
	String get hardwareDecoderDesc => 'Only takes effect when hardware decoding is enabled';
	String get lowMemoryMode => 'Low Memory Mode';
	String get lowMemoryModeDesc => 'Disable advanced caching to reduce memory usage';
	String get lowLatencyAudio => 'Low Latency Audio';
	String get lowLatencyAudioDesc => 'Enable OpenSLES audio output to reduce latency';
	String get superResolution => 'Super Resolution';
	String get autoJump => 'Auto Jump';
	String get autoJumpDesc => 'Jump to last playback position';
	String get disableAnimations => 'Disable transition animations';
	String get disableAnimationsDesc => 'Disable transition animations in the player';
	String get errorPrompt => 'Error Prompt';
	String get errorPromptDesc => 'Show player internal error prompts';
	String get debugMode => 'Debug Mode';
	String get debugModeDesc => 'Log player internal logs';
	String get privateMode => 'Private Mode';
	String get privateModeDesc => 'Don\'t keep viewing history';
	String get defaultPlaySpeed => 'Default Playback Speed';
	String get defaultVideoAspectRatio => 'Default Video Aspect Ratio';
	late final _TranslationsSettingsPlayerAspectRatioEnUs aspectRatio = _TranslationsSettingsPlayerAspectRatioEnUs._(_root);
	String get danmakuSettings => 'Danmaku Settings';
	String get danmakuSettingsDesc => 'Configure danmaku parameters';
	String get danmaku => 'Danmaku';
	String get danmakuDefaultOn => 'Default On';
	String get danmakuDefaultOnDesc => 'Whether to play danmaku with video by default';
	String get danmakuSource => 'Danmaku Source';
	late final _TranslationsSettingsPlayerDanmakuSourcesEnUs danmakuSources = _TranslationsSettingsPlayerDanmakuSourcesEnUs._(_root);
	String get danmakuCredentials => 'Credentials';
	String get danmakuDanDanCredentials => 'DanDan API Credentials';
	String get danmakuDanDanCredentialsDesc => 'Customize DanDan credentials';
	String get danmakuCredentialModeBuiltIn => 'Built-in';
	String get danmakuCredentialModeCustom => 'Custom';
	String get danmakuCredentialHint => 'Leave blank to use built-in credentials';
	String get danmakuCredentialNotConfigured => 'Not configured';
	String get danmakuCredentialsSummary => 'App ID: {appId}\nAPI Key: {apiKey}';
	String get danmakuShield => 'Danmaku Shield';
	String get danmakuKeywordShield => 'Keyword Shield';
	String get danmakuShieldInputHint => 'Enter a keyword or regular expression';
	String get danmakuShieldDescription => 'Text starting and ending with "/" will be treated as regular expressions, e.g. "/\\d+/" blocks all numbers';
	String get danmakuShieldCount => 'Added {count} keywords';
	String get danmakuConvert => 'Conversion';
	String get danmakuConvertTitle => 'Danmaku Simplified/Traditional Conversion';
	String get danmakuConvertDesc => 'Takes effect upon next online load. Cached danmaku retains original text';
	String get danmakuConvertNone => 'No conversion';
	String get danmakuConvertSimplified => 'Convert to Simplified';
	String get danmakuConvertTraditional => 'Convert to Traditional';
	String get danmakuStyle => 'Danmaku Style';
	String get danmakuDisplay => 'Danmaku Display';
	String get danmakuArea => 'Danmaku Area';
	String get danmakuTopDisplay => 'Top Danmaku';
	String get danmakuBottomDisplay => 'Bottom Danmaku';
	String get danmakuScrollDisplay => 'Scrolling Danmaku';
	String get danmakuMassiveDisplay => 'Massive Danmaku';
	String get danmakuMassiveDescription => 'Overlay rendering when the screen is crowded';
	String get danmakuOutline => 'Danmaku Outline';
	String get danmakuColor => 'Danmaku Color';
	String get danmakuFontSize => 'Font Size';
	String get danmakuFontWeight => 'Font Weight';
	String get danmakuOpacity => 'Danmaku Opacity';
	String get add => 'Add';
	String get save => 'Save';
	String get restoreDefault => 'Restore Default';
	String get superResolutionTitle => 'Super Resolution';
	String get superResolutionHint => 'Choose the default upscaling profile';
	late final _TranslationsSettingsPlayerSuperResolutionOptionsEnUs superResolutionOptions = _TranslationsSettingsPlayerSuperResolutionOptionsEnUs._(_root);
	String get superResolutionDefaultBehavior => 'Default Behavior';
	String get superResolutionClosePrompt => 'Close Prompt';
	String get superResolutionClosePromptDesc => 'Close the prompt when enabling super resolution';
	late final _TranslationsSettingsPlayerToastEnUs toast = _TranslationsSettingsPlayerToastEnUs._(_root);
}

// Path: settings.webdav
class _TranslationsSettingsWebdavEnUs {
	_TranslationsSettingsWebdavEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'WebDAV';
	String get desc => 'Configure sync parameters';
	String get pageTitle => 'Sync Settings';
	late final _TranslationsSettingsWebdavEditorEnUs editor = _TranslationsSettingsWebdavEditorEnUs._(_root);
	late final _TranslationsSettingsWebdavSectionEnUs section = _TranslationsSettingsWebdavSectionEnUs._(_root);
	late final _TranslationsSettingsWebdavTileEnUs tile = _TranslationsSettingsWebdavTileEnUs._(_root);
	late final _TranslationsSettingsWebdavInfoEnUs info = _TranslationsSettingsWebdavInfoEnUs._(_root);
	late final _TranslationsSettingsWebdavToastEnUs toast = _TranslationsSettingsWebdavToastEnUs._(_root);
	late final _TranslationsSettingsWebdavResultEnUs result = _TranslationsSettingsWebdavResultEnUs._(_root);
}

// Path: settings.update
class _TranslationsSettingsUpdateEnUs {
	_TranslationsSettingsUpdateEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get fallbackDescription => 'No release notes provided.';
	late final _TranslationsSettingsUpdateErrorEnUs error = _TranslationsSettingsUpdateErrorEnUs._(_root);
	late final _TranslationsSettingsUpdateDialogEnUs dialog = _TranslationsSettingsUpdateDialogEnUs._(_root);
	late final _TranslationsSettingsUpdateInstallationTypeEnUs installationType = _TranslationsSettingsUpdateInstallationTypeEnUs._(_root);
	late final _TranslationsSettingsUpdateToastEnUs toast = _TranslationsSettingsUpdateToastEnUs._(_root);
	late final _TranslationsSettingsUpdateDownloadEnUs download = _TranslationsSettingsUpdateDownloadEnUs._(_root);
}

// Path: settings.other
class _TranslationsSettingsOtherEnUs {
	_TranslationsSettingsOtherEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Other';
	String get about => 'About';
}

// Path: settings.about
class _TranslationsSettingsAboutEnUs {
	_TranslationsSettingsAboutEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'About';
	late final _TranslationsSettingsAboutSectionsEnUs sections = _TranslationsSettingsAboutSectionsEnUs._(_root);
	late final _TranslationsSettingsAboutLogsEnUs logs = _TranslationsSettingsAboutLogsEnUs._(_root);
}

// Path: navigation.tabs
class _TranslationsNavigationTabsEnUs {
	_TranslationsNavigationTabsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get popular => 'Popular';
	String get catalog => 'Catalog';
	String get media => 'Online Video';
	String get resource => 'Resources';
	String get timeline => 'Timeline';
	String get my => 'Media Library';
	String get download => 'Downloads';
	String get settings => 'Settings';
}

// Path: navigation.actions
class _TranslationsNavigationActionsEnUs {
	_TranslationsNavigationActionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get search => 'Search';
	String get history => 'History';
	String get close => 'Quit';
}

// Path: dialogs.disclaimer
class _TranslationsDialogsDisclaimerEnUs {
	_TranslationsDialogsDisclaimerEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Disclaimer';
	String get agree => 'I have read and agree';
	String get exit => 'Exit';
}

// Path: dialogs.updateMirror
class _TranslationsDialogsUpdateMirrorEnUs {
	_TranslationsDialogsUpdateMirrorEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Update Mirror';
	String get question => 'Where would you like to fetch app updates?';
	String get description => 'GitHub mirror works best for most users. Choose F-Droid if you use the F-Droid store.';
	late final _TranslationsDialogsUpdateMirrorOptionsEnUs options = _TranslationsDialogsUpdateMirrorOptionsEnUs._(_root);
}

// Path: dialogs.pluginUpdates
class _TranslationsDialogsPluginUpdatesEnUs {
	_TranslationsDialogsPluginUpdatesEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get toast => 'Detected {count} rule updates';
}

// Path: dialogs.webdav
class _TranslationsDialogsWebdavEnUs {
	_TranslationsDialogsWebdavEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get syncFailed => 'Failed to sync watch history: {error}';
}

// Path: dialogs.about
class _TranslationsDialogsAboutEnUs {
	_TranslationsDialogsAboutEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get licenseLegalese => 'Open Source Licenses';
}

// Path: dialogs.cache
class _TranslationsDialogsCacheEnUs {
	_TranslationsDialogsCacheEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Cache Management';
	String get message => 'Cached data includes poster art. Clearing it will require re-downloading assets. Do you want to continue?';
}

// Path: library.common
class _TranslationsLibraryCommonEnUs {
	_TranslationsLibraryCommonEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get emptyState => 'No content found';
	String get retry => 'Tap to retry';
	String get backHint => 'Press again to exit Haipee';
	late final _TranslationsLibraryCommonToastEnUs toast = _TranslationsLibraryCommonToastEnUs._(_root);
}

// Path: library.popular
class _TranslationsLibraryPopularEnUs {
	_TranslationsLibraryPopularEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Home';
	String get allTag => 'Home';
	late final _TranslationsLibraryPopularToastEnUs toast = _TranslationsLibraryPopularToastEnUs._(_root);
}

// Path: library.timeline
class _TranslationsLibraryTimelineEnUs {
	_TranslationsLibraryTimelineEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	late final _TranslationsLibraryTimelineWeekdaysEnUs weekdays = _TranslationsLibraryTimelineWeekdaysEnUs._(_root);
	late final _TranslationsLibraryTimelineSeasonPickerEnUs seasonPicker = _TranslationsLibraryTimelineSeasonPickerEnUs._(_root);
	late final _TranslationsLibraryTimelineSeasonEnUs season = _TranslationsLibraryTimelineSeasonEnUs._(_root);
	late final _TranslationsLibraryTimelineSortEnUs sort = _TranslationsLibraryTimelineSortEnUs._(_root);
}

// Path: library.search
class _TranslationsLibrarySearchEnUs {
	_TranslationsLibrarySearchEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	late final _TranslationsLibrarySearchSortEnUs sort = _TranslationsLibrarySearchSortEnUs._(_root);
	String get noHistory => 'No search history yet.';
}

// Path: library.history
class _TranslationsLibraryHistoryEnUs {
	_TranslationsLibraryHistoryEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Watch History';
	String get empty => 'No watch history found';
	late final _TranslationsLibraryHistoryChipsEnUs chips = _TranslationsLibraryHistoryChipsEnUs._(_root);
	late final _TranslationsLibraryHistoryToastEnUs toast = _TranslationsLibraryHistoryToastEnUs._(_root);
	late final _TranslationsLibraryHistoryManageEnUs manage = _TranslationsLibraryHistoryManageEnUs._(_root);
}

// Path: library.info
class _TranslationsLibraryInfoEnUs {
	_TranslationsLibraryInfoEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	late final _TranslationsLibraryInfoSummaryEnUs summary = _TranslationsLibraryInfoSummaryEnUs._(_root);
	late final _TranslationsLibraryInfoTagsEnUs tags = _TranslationsLibraryInfoTagsEnUs._(_root);
	late final _TranslationsLibraryInfoMetadataEnUs metadata = _TranslationsLibraryInfoMetadataEnUs._(_root);
	late final _TranslationsLibraryInfoEpisodesEnUs episodes = _TranslationsLibraryInfoEpisodesEnUs._(_root);
	late final _TranslationsLibraryInfoErrorsEnUs errors = _TranslationsLibraryInfoErrorsEnUs._(_root);
	late final _TranslationsLibraryInfoTabsEnUs tabs = _TranslationsLibraryInfoTabsEnUs._(_root);
	late final _TranslationsLibraryInfoActionsEnUs actions = _TranslationsLibraryInfoActionsEnUs._(_root);
	late final _TranslationsLibraryInfoToastEnUs toast = _TranslationsLibraryInfoToastEnUs._(_root);
	late final _TranslationsLibraryInfoSourceSheetEnUs sourceSheet = _TranslationsLibraryInfoSourceSheetEnUs._(_root);
}

// Path: library.my
class _TranslationsLibraryMyEnUs {
	_TranslationsLibraryMyEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'My';
	late final _TranslationsLibraryMySectionsEnUs sections = _TranslationsLibraryMySectionsEnUs._(_root);
	late final _TranslationsLibraryMyFavoritesEnUs favorites = _TranslationsLibraryMyFavoritesEnUs._(_root);
	late final _TranslationsLibraryMyHistoryEnUs history = _TranslationsLibraryMyHistoryEnUs._(_root);
}

// Path: playback.toast
class _TranslationsPlaybackToastEnUs {
	_TranslationsPlaybackToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get screenshotProcessing => 'Capturing screenshot…';
	String get screenshotSaved => 'Screenshot saved to gallery';
	String get screenshotSaveFailed => 'Failed to save screenshot: {error}';
	String get screenshotError => 'Screenshot failed: {error}';
	String get playlistEmpty => 'Playlist is empty';
	String get episodeLatest => 'Already at the latest episode';
	String get loadingEpisode => 'Loading {identifier}';
	String get danmakuUnsupported => 'Danmaku sending is unavailable for this episode';
	String get danmakuEmpty => 'Danmaku content cannot be empty';
	String get danmakuTooLong => 'Danmaku content is too long';
	String get waitForVideo => 'Please wait until the video finishes loading';
	String get enableDanmakuFirst => 'Turn on danmaku first';
	String get danmakuSearchError => 'Danmaku search failed: {error}';
	String get danmakuSearchEmpty => 'No matching results found';
	String get danmakuSwitching => 'Switching danmaku';
	String get clipboardCopied => 'Copied to clipboard';
	String get internalError => 'Player internal error: {details}';
}

// Path: playback.danmaku
class _TranslationsPlaybackDanmakuEnUs {
	_TranslationsPlaybackDanmakuEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get inputHint => 'Share a friendly danmaku in the moment';
	String get inputDisabled => 'Danmaku is turned off';
	String get send => 'Send';
	String get mobileButton => 'Tap to send danmaku';
	String get mobileButtonDisabled => 'Danmaku disabled';
}

// Path: playback.externalPlayer
class _TranslationsPlaybackExternalPlayerEnUs {
	_TranslationsPlaybackExternalPlayerEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get launching => 'Trying to open external player';
	String get launchFailed => 'Unable to open external player';
	String get unavailable => 'External player is not available';
	String get unsupportedDevice => 'This device is not supported yet';
	String get unsupportedPlugin => 'This plugin is not supported yet';
}

// Path: playback.controls
class _TranslationsPlaybackControlsEnUs {
	_TranslationsPlaybackControlsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	late final _TranslationsPlaybackControlsSpeedEnUs speed = _TranslationsPlaybackControlsSpeedEnUs._(_root);
	late final _TranslationsPlaybackControlsSkipEnUs skip = _TranslationsPlaybackControlsSkipEnUs._(_root);
	late final _TranslationsPlaybackControlsStatusEnUs status = _TranslationsPlaybackControlsStatusEnUs._(_root);
	late final _TranslationsPlaybackControlsSuperResolutionEnUs superResolution = _TranslationsPlaybackControlsSuperResolutionEnUs._(_root);
	late final _TranslationsPlaybackControlsSpeedMenuEnUs speedMenu = _TranslationsPlaybackControlsSpeedMenuEnUs._(_root);
	late final _TranslationsPlaybackControlsAspectRatioEnUs aspectRatio = _TranslationsPlaybackControlsAspectRatioEnUs._(_root);
	late final _TranslationsPlaybackControlsTooltipsEnUs tooltips = _TranslationsPlaybackControlsTooltipsEnUs._(_root);
	late final _TranslationsPlaybackControlsMenuEnUs menu = _TranslationsPlaybackControlsMenuEnUs._(_root);
	late final _TranslationsPlaybackControlsSyncplayEnUs syncplay = _TranslationsPlaybackControlsSyncplayEnUs._(_root);
}

// Path: playback.loading
class _TranslationsPlaybackLoadingEnUs {
	_TranslationsPlaybackLoadingEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get parsing => 'Parsing video source…';
	String get parseFailed => 'Video source parsing failed';
	String get player => 'Video source parsed, loading player';
	String get danmakuSearch => 'Searching danmaku…';
}

// Path: playback.danmakuSearch
class _TranslationsPlaybackDanmakuSearchEnUs {
	_TranslationsPlaybackDanmakuSearchEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Danmaku search';
	String get hint => 'Series title';
	String get submit => 'Submit';
}

// Path: playback.remote
class _TranslationsPlaybackRemoteEnUs {
	_TranslationsPlaybackRemoteEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Remote cast';
	late final _TranslationsPlaybackRemoteToastEnUs toast = _TranslationsPlaybackRemoteToastEnUs._(_root);
}

// Path: playback.debug
class _TranslationsPlaybackDebugEnUs {
	_TranslationsPlaybackDebugEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Debug info';
	String get closeTooltip => 'Close debug info';
	late final _TranslationsPlaybackDebugTabsEnUs tabs = _TranslationsPlaybackDebugTabsEnUs._(_root);
	late final _TranslationsPlaybackDebugSectionsEnUs sections = _TranslationsPlaybackDebugSectionsEnUs._(_root);
	late final _TranslationsPlaybackDebugLabelsEnUs labels = _TranslationsPlaybackDebugLabelsEnUs._(_root);
	late final _TranslationsPlaybackDebugValuesEnUs values = _TranslationsPlaybackDebugValuesEnUs._(_root);
	late final _TranslationsPlaybackDebugLogsEnUs logs = _TranslationsPlaybackDebugLogsEnUs._(_root);
}

// Path: playback.syncplay
class _TranslationsPlaybackSyncplayEnUs {
	_TranslationsPlaybackSyncplayEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get invalidEndpoint => 'SyncPlay: Invalid server address {endpoint}';
	String get disconnected => 'SyncPlay: Connection interrupted {reason}';
	String get actionReconnect => 'Reconnect';
	String get alone => 'SyncPlay: You are the only user in this room';
	String get followUser => 'SyncPlay: Using {username}\'s progress';
	String get userLeft => 'SyncPlay: {username} left the room';
	String get userJoined => 'SyncPlay: {username} joined the room';
	String get switchEpisode => 'SyncPlay: {username} switched to episode {episode}';
	String get chat => 'SyncPlay: {username} said: {message}';
	String get paused => 'SyncPlay: {username} paused playback';
	String get resumed => 'SyncPlay: {username} resumed playback';
	String get unknownUser => 'unknown';
	String get switchServerBlocked => 'SyncPlay: Exit the current room before switching servers';
	String get defaultCustomEndpoint => 'Custom server';
	late final _TranslationsPlaybackSyncplaySelectServerEnUs selectServer = _TranslationsPlaybackSyncplaySelectServerEnUs._(_root);
	late final _TranslationsPlaybackSyncplayJoinEnUs join = _TranslationsPlaybackSyncplayJoinEnUs._(_root);
}

// Path: playback.playlist
class _TranslationsPlaybackPlaylistEnUs {
	_TranslationsPlaybackPlaylistEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get collection => 'Collection';
	String get list => 'Playlist {index}';
}

// Path: playback.tabs
class _TranslationsPlaybackTabsEnUs {
	_TranslationsPlaybackTabsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get episodes => 'Episodes';
	String get comments => 'Comments';
}

// Path: playback.comments
class _TranslationsPlaybackCommentsEnUs {
	_TranslationsPlaybackCommentsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get sectionTitle => 'Episode title';
	String get manualSwitch => 'Switch manually';
	String get dialogTitle => 'Enter episode number';
	String get dialogEmpty => 'Please enter an episode number';
	String get dialogConfirm => 'Refresh';
}

// Path: playback.superResolution
class _TranslationsPlaybackSuperResolutionEnUs {
	_TranslationsPlaybackSuperResolutionEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	late final _TranslationsPlaybackSuperResolutionWarningEnUs warning = _TranslationsPlaybackSuperResolutionWarningEnUs._(_root);
}

// Path: network.error
class _TranslationsNetworkErrorEnUs {
	_TranslationsNetworkErrorEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get badCertificate => 'Certificate error.';
	String get badResponse => 'Server error. Please try again later.';
	String get cancel => 'Request was cancelled. Please retry.';
	String get connection => 'Connection error. Check your network settings.';
	String get connectionTimeout => 'Connection timed out. Check your network settings.';
	String get receiveTimeout => 'Response timed out. Please try again.';
	String get sendTimeout => 'Request timed out. Check your network settings.';
	String get unknown => '{status} network issue.';
}

// Path: network.status
class _TranslationsNetworkStatusEnUs {
	_TranslationsNetworkStatusEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get mobile => 'Using mobile data';
	String get wifi => 'Using Wi-Fi';
	String get ethernet => 'Using Ethernet';
	String get vpn => 'Using VPN connection';
	String get other => 'Using another network';
	String get none => 'No network connection';
}

// Path: downloads.page.tabs
class _TranslationsDownloadsPageTabsEnUs {
	_TranslationsDownloadsPageTabsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String downloading({required Object count}) => 'Downloading (${count})';
	String paused({required Object count}) => 'Paused (${count})';
	String completed({required Object count}) => 'Completed (${count})';
	String failed({required Object count}) => 'Failed (${count})';
	String get all => 'All';
}

// Path: downloads.page.actions
class _TranslationsDownloadsPageActionsEnUs {
	_TranslationsDownloadsPageActionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get selectAll => 'Select All';
	String get resume => 'Resume';
	String get pause => 'Pause';
	String get pauseAll => 'Pause All';
	String get resumeAll => 'Resume All';
	String get clearCompleted => 'Clear Completed';
	String get deleteAll => 'Delete All';
	String get retry => 'Retry';
	String get delete => 'Delete';
	String get open => 'Open';
}

// Path: downloads.page.statistics
class _TranslationsDownloadsPageStatisticsEnUs {
	_TranslationsDownloadsPageStatisticsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String tasks({required Object count}) => '${count} tasks';
	String eta({required Object time}) => 'ETA ${time}';
}

// Path: downloads.page.search
class _TranslationsDownloadsPageSearchEnUs {
	_TranslationsDownloadsPageSearchEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get placeholder => 'Search downloads...';
	String get clear => 'Clear';
}

// Path: downloads.page.sort
class _TranslationsDownloadsPageSortEnUs {
	_TranslationsDownloadsPageSortEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get label => 'Sort';
	String get created => 'Created Time';
	String get name => 'File Name';
	String get size => 'File Size';
	String get speed => 'Download Speed';
	String get progress => 'Progress';
}

// Path: downloads.page.empty
class _TranslationsDownloadsPageEmptyEnUs {
	_TranslationsDownloadsPageEmptyEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get downloading => 'No active downloads';
	String get paused => 'No paused downloads';
	String get completed => 'No completed downloads yet';
	String get failed => 'No failed downloads';
	String get all => 'Download list is empty';
	String get hint => 'Click the new button above to add downloads';
}

// Path: downloads.page.status
class _TranslationsDownloadsPageStatusEnUs {
	_TranslationsDownloadsPageStatusEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get active => 'Downloading';
	String get waiting => 'Waiting';
	String get paused => 'Paused';
	String get error => 'Error';
	String get complete => 'Completed';
	String get removed => 'Removed';
}

// Path: downloads.page.dialog
class _TranslationsDownloadsPageDialogEnUs {
	_TranslationsDownloadsPageDialogEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get deleteConfirm => 'Are you sure you want to delete the selected downloads?';
	String get deleteAllConfirm => 'Are you sure you want to delete all downloads? This action cannot be undone.';
}

// Path: downloads.page.toast
class _TranslationsDownloadsPageToastEnUs {
	_TranslationsDownloadsPageToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get addedToQueue => 'Added to download queue';
	String get resumed => 'Download resumed';
	String get paused => 'Download paused';
	String get deleted => 'Deleted';
	String get retrying => 'Re-added to download queue';
	String fileLocation({required Object path}) => 'File location: ${path}';
}

// Path: downloads.addDialog.tabs
class _TranslationsDownloadsAddDialogTabsEnUs {
	_TranslationsDownloadsAddDialogTabsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get url => 'URL Download';
	String get torrent => 'Torrent Download';
}

// Path: downloads.addDialog.url
class _TranslationsDownloadsAddDialogUrlEnUs {
	_TranslationsDownloadsAddDialogUrlEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get hint => 'Enter download links, one per line\nSupported:\n- HTTP/HTTPS links\n- FTP links\n- Magnet links (magnet:?xt=...)';
}

// Path: downloads.addDialog.torrent
class _TranslationsDownloadsAddDialogTorrentEnUs {
	_TranslationsDownloadsAddDialogTorrentEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get dropZone => 'Drop torrent file here';
	String get dropZoneWindows => 'Click the button below to select torrent file';
	String get supported => 'Supports .torrent files';
	String get selectFile => 'Select Torrent File';
}

// Path: downloads.addDialog.advanced
class _TranslationsDownloadsAddDialogAdvancedEnUs {
	_TranslationsDownloadsAddDialogAdvancedEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Advanced Options';
	String get savePath => 'Save Path (Optional)';
	String get savePathHint => 'Leave empty to use default download path';
	String connections({required Object count}) => 'Connections per file: ${count}';
	String split({required Object count}) => 'Split per task: ${count}';
}

// Path: downloads.addDialog.actions
class _TranslationsDownloadsAddDialogActionsEnUs {
	_TranslationsDownloadsAddDialogActionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get cancel => 'Cancel';
	String get start => 'Start Download';
}

// Path: downloads.addDialog.errors
class _TranslationsDownloadsAddDialogErrorsEnUs {
	_TranslationsDownloadsAddDialogErrorsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get noUrl => 'Please enter at least one download link';
	String get noTorrent => 'Please select or drop a torrent file';
	String selectFileFailed({required Object error}) => 'Failed to select file: ${error}';
	String selectPathFailed({required Object error}) => 'Failed to select path: ${error}';
	String submitFailed({required Object error}) => 'Failed to add download: ${error}';
}

// Path: downloads.addDialog.toast
class _TranslationsDownloadsAddDialogToastEnUs {
	_TranslationsDownloadsAddDialogToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String added({required Object count}) => 'Added ${count} download tasks';
	String get addedTorrent => 'Added torrent download task';
}

// Path: downloads.detailDialog.sections
class _TranslationsDownloadsDetailDialogSectionsEnUs {
	_TranslationsDownloadsDetailDialogSectionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get taskName => 'Task Name';
	String get fileName => 'File Name';
	String get fileSize => 'File Size';
	String get progress => 'Download Progress';
	String get speed => 'Download Speed';
	String get uploadSpeed => 'Upload Speed';
	String get connections => 'Connections';
	String get eta => 'Estimated Time';
	String get filePath => 'File Path';
	String get gid => 'Task ID';
	String get createdAt => 'Created At';
}

// Path: downloads.detailDialog.actions
class _TranslationsDownloadsDetailDialogActionsEnUs {
	_TranslationsDownloadsDetailDialogActionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get copyPath => 'Copy Path';
	String get openFile => 'Open File';
	String get openFolder => 'Open Folder';
	String get retry => 'Retry Download';
	String get close => 'Close';
}

// Path: downloads.detailDialog.toast
class _TranslationsDownloadsDetailDialogToastEnUs {
	_TranslationsDownloadsDetailDialogToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get pathCopied => 'Path copied';
}

// Path: settings.appearancePage.mode
class _TranslationsSettingsAppearancePageModeEnUs {
	_TranslationsSettingsAppearancePageModeEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Theme mode';
	String get system => 'system';
	String get light => 'Light';
	String get dark => 'Dark';
}

// Path: settings.appearancePage.colorScheme
class _TranslationsSettingsAppearancePageColorSchemeEnUs {
	_TranslationsSettingsAppearancePageColorSchemeEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Accent color';
	String get dialogTitle => 'Choose an accent color';
	String get dynamicColor => 'Use dynamic color';
	String get dynamicColorInfo => 'Generate a palette from your wallpaper when supported (Android 12+ / Windows 11).';
	late final _TranslationsSettingsAppearancePageColorSchemeLabelsEnUs labels = _TranslationsSettingsAppearancePageColorSchemeLabelsEnUs._(_root);
}

// Path: settings.appearancePage.oled
class _TranslationsSettingsAppearancePageOledEnUs {
	_TranslationsSettingsAppearancePageOledEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'OLED contrast';
	String get description => 'Use deeper blacks optimized for OLED displays.';
}

// Path: settings.appearancePage.window
class _TranslationsSettingsAppearancePageWindowEnUs {
	_TranslationsSettingsAppearancePageWindowEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Window buttons';
	String get description => 'Show window control buttons in the title bar.';
}

// Path: settings.appearancePage.refreshRate
class _TranslationsSettingsAppearancePageRefreshRateEnUs {
	_TranslationsSettingsAppearancePageRefreshRateEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Refresh rate';
}

// Path: settings.plugins.tooltip
class _TranslationsSettingsPluginsTooltipEnUs {
	_TranslationsSettingsPluginsTooltipEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get updateAll => 'Update all';
	String get addRule => 'Add rule';
}

// Path: settings.plugins.sort
class _TranslationsSettingsPluginsSortEnUs {
	_TranslationsSettingsPluginsSortEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Sort order';
	String get tooltip => 'Sort';
	late final _TranslationsSettingsPluginsSortOptionsEnUs options = _TranslationsSettingsPluginsSortOptionsEnUs._(_root);
}

// Path: settings.plugins.multiSelect
class _TranslationsSettingsPluginsMultiSelectEnUs {
	_TranslationsSettingsPluginsMultiSelectEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get selectedCount => '{count} selected';
}

// Path: settings.plugins.loading
class _TranslationsSettingsPluginsLoadingEnUs {
	_TranslationsSettingsPluginsLoadingEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get updating => 'Updating rules…';
	String get updatingSingle => 'Updating…';
	String get importing => 'Importing…';
}

// Path: settings.plugins.labels
class _TranslationsSettingsPluginsLabelsEnUs {
	_TranslationsSettingsPluginsLabelsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get version => 'Version: {version}';
	String get statusUpdatable => 'Update available';
	String get statusSearchValid => 'Search valid';
}

// Path: settings.plugins.actions
class _TranslationsSettingsPluginsActionsEnUs {
	_TranslationsSettingsPluginsActionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get newRule => 'Create rule';
	String get importFromRepo => 'Import from repository';
	String get importFromClipboard => 'Import from clipboard';
	String get cancel => 'Cancel';
	String get import => 'Import';
	String get update => 'Update';
	String get edit => 'Edit';
	String get copyToClipboard => 'Copy to clipboard';
	String get share => 'Share';
	String get delete => 'Delete';
}

// Path: settings.plugins.dialogs
class _TranslationsSettingsPluginsDialogsEnUs {
	_TranslationsSettingsPluginsDialogsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get deleteTitle => 'Delete rules';
	String get deleteMessage => 'Delete {count} selected rule(s)?';
	String get importTitle => 'Import rule';
	String get shareTitle => 'Rule link';
}

// Path: settings.plugins.toast
class _TranslationsSettingsPluginsToastEnUs {
	_TranslationsSettingsPluginsToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get allUpToDate => 'All rules are up to date.';
	String get updateCount => 'Updated {count} rule(s).';
	String get importSuccess => 'Import successful.';
	String get importFailed => 'Import failed: {error}';
	String get repoMissing => 'The repository does not contain this rule.';
	String get alreadyLatest => 'Rule is already the latest.';
	String get updateSuccess => 'Update successful.';
	String get updateIncompatible => 'Haipee is too old; this rule is incompatible.';
	String get updateFailed => 'Failed to update rule.';
	String get copySuccess => 'Copied to clipboard.';
}

// Path: settings.plugins.editor
class _TranslationsSettingsPluginsEditorEnUs {
	_TranslationsSettingsPluginsEditorEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Edit Rule';
	late final _TranslationsSettingsPluginsEditorFieldsEnUs fields = _TranslationsSettingsPluginsEditorFieldsEnUs._(_root);
	late final _TranslationsSettingsPluginsEditorAdvancedEnUs advanced = _TranslationsSettingsPluginsEditorAdvancedEnUs._(_root);
}

// Path: settings.plugins.shop
class _TranslationsSettingsPluginsShopEnUs {
	_TranslationsSettingsPluginsShopEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Rule Repository';
	late final _TranslationsSettingsPluginsShopTooltipEnUs tooltip = _TranslationsSettingsPluginsShopTooltipEnUs._(_root);
	late final _TranslationsSettingsPluginsShopLabelsEnUs labels = _TranslationsSettingsPluginsShopLabelsEnUs._(_root);
	late final _TranslationsSettingsPluginsShopButtonsEnUs buttons = _TranslationsSettingsPluginsShopButtonsEnUs._(_root);
	late final _TranslationsSettingsPluginsShopToastEnUs toast = _TranslationsSettingsPluginsShopToastEnUs._(_root);
	late final _TranslationsSettingsPluginsShopErrorEnUs error = _TranslationsSettingsPluginsShopErrorEnUs._(_root);
}

// Path: settings.player.aspectRatio
class _TranslationsSettingsPlayerAspectRatioEnUs {
	_TranslationsSettingsPlayerAspectRatioEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get auto => 'Auto';
	String get crop => 'Crop to fill';
	String get stretch => 'Stretch to fill';
}

// Path: settings.player.danmakuSources
class _TranslationsSettingsPlayerDanmakuSourcesEnUs {
	_TranslationsSettingsPlayerDanmakuSourcesEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get bilibili => 'Bilibili';
	String get gamer => 'Gamer';
	String get dandan => 'DanDan';
}

// Path: settings.player.superResolutionOptions
class _TranslationsSettingsPlayerSuperResolutionOptionsEnUs {
	_TranslationsSettingsPlayerSuperResolutionOptionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	late final _TranslationsSettingsPlayerSuperResolutionOptionsOffEnUs off = _TranslationsSettingsPlayerSuperResolutionOptionsOffEnUs._(_root);
	late final _TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyEnUs efficiency = _TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyEnUs._(_root);
	late final _TranslationsSettingsPlayerSuperResolutionOptionsQualityEnUs quality = _TranslationsSettingsPlayerSuperResolutionOptionsQualityEnUs._(_root);
}

// Path: settings.player.toast
class _TranslationsSettingsPlayerToastEnUs {
	_TranslationsSettingsPlayerToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get danmakuKeywordEmpty => 'Enter a keyword.';
	String get danmakuKeywordTooLong => 'Keyword is too long.';
	String get danmakuKeywordExists => 'Keyword already exists.';
	String get danmakuCredentialsRestored => 'Reverted to built-in credentials.';
	String get danmakuCredentialsUpdated => 'Credentials updated.';
}

// Path: settings.webdav.editor
class _TranslationsSettingsWebdavEditorEnUs {
	_TranslationsSettingsWebdavEditorEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'WebDAV Configuration';
	String get url => 'URL';
	String get username => 'Username';
	String get password => 'Password';
	late final _TranslationsSettingsWebdavEditorToastEnUs toast = _TranslationsSettingsWebdavEditorToastEnUs._(_root);
}

// Path: settings.webdav.section
class _TranslationsSettingsWebdavSectionEnUs {
	_TranslationsSettingsWebdavSectionEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get webdav => 'WebDAV';
}

// Path: settings.webdav.tile
class _TranslationsSettingsWebdavTileEnUs {
	_TranslationsSettingsWebdavTileEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get webdavToggle => 'WebDAV Sync';
	String get historyToggle => 'Watch History Sync';
	String get historyDescription => 'Allow automatic syncing of watch history';
	String get config => 'WebDAV Configuration';
	String get manualUpload => 'Manual Upload';
	String get manualDownload => 'Manual Download';
}

// Path: settings.webdav.info
class _TranslationsSettingsWebdavInfoEnUs {
	_TranslationsSettingsWebdavInfoEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get upload => 'Upload your watch history to WebDAV immediately.';
	String get download => 'Sync your watch history to this device immediately.';
}

// Path: settings.webdav.toast
class _TranslationsSettingsWebdavToastEnUs {
	_TranslationsSettingsWebdavToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get uploading => 'Attempting to upload to WebDAV...';
	String get downloading => 'Attempting to sync from WebDAV...';
	String get notConfigured => 'WebDAV sync is disabled or configuration is invalid.';
	String get connectionFailed => 'Failed to connect to WebDAV: {error}';
	String get syncFailed => 'WebDAV sync failed: {error}';
}

// Path: settings.webdav.result
class _TranslationsSettingsWebdavResultEnUs {
	_TranslationsSettingsWebdavResultEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get initFailed => 'WebDAV initialization failed: {error}';
	String get requireEnable => 'Please enable WebDAV sync first.';
	String get disabled => 'WebDAV sync is disabled or configuration is invalid.';
	String get connectionFailed => 'Failed to connect to WebDAV.';
	String get syncSuccess => 'Sync succeeded.';
	String get syncFailed => 'Sync failed: {error}';
}

// Path: settings.update.error
class _TranslationsSettingsUpdateErrorEnUs {
	_TranslationsSettingsUpdateErrorEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get invalidResponse => 'Invalid update response.';
}

// Path: settings.update.dialog
class _TranslationsSettingsUpdateDialogEnUs {
	_TranslationsSettingsUpdateDialogEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'New version {version} available';
	String get publishedAt => 'Released on {date}';
	String get installationTypeLabel => 'Select installation package';
	late final _TranslationsSettingsUpdateDialogActionsEnUs actions = _TranslationsSettingsUpdateDialogActionsEnUs._(_root);
}

// Path: settings.update.installationType
class _TranslationsSettingsUpdateInstallationTypeEnUs {
	_TranslationsSettingsUpdateInstallationTypeEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get windowsMsix => 'Windows installer (MSIX)';
	String get windowsPortable => 'Windows portable (ZIP)';
	String get linuxDeb => 'Linux package (DEB)';
	String get linuxTar => 'Linux archive (TAR.GZ)';
	String get macosDmg => 'macOS installer (DMG)';
	String get androidApk => 'Android package (APK)';
	String get ios => 'iOS app (open GitHub)';
	String get unknown => 'Other platform';
}

// Path: settings.update.toast
class _TranslationsSettingsUpdateToastEnUs {
	_TranslationsSettingsUpdateToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get alreadyLatest => 'You\'re up to date.';
	String get checkFailed => 'Failed to check for updates. Please try again later.';
	String get autoUpdateDisabled => 'Automatic updates disabled.';
	String get downloadLinkMissing => 'No download available for {type}.';
	String get downloadFailed => 'Download failed: {error}';
	String get noCompatibleLink => 'No compatible download link found.';
	String get prepareToInstall => 'Preparing to install the update. The app will exit…';
	String get openInstallerFailed => 'Unable to open installer: {error}';
	String get launchInstallerFailed => 'Failed to launch installer: {error}';
	String get revealFailed => 'Unable to open the file manager.';
	String get unknownReason => 'Unknown reason';
}

// Path: settings.update.download
class _TranslationsSettingsUpdateDownloadEnUs {
	_TranslationsSettingsUpdateDownloadEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get progressTitle => 'Downloading update';
	String get cancel => 'Cancel';
	late final _TranslationsSettingsUpdateDownloadErrorEnUs error = _TranslationsSettingsUpdateDownloadErrorEnUs._(_root);
	late final _TranslationsSettingsUpdateDownloadCompleteEnUs complete = _TranslationsSettingsUpdateDownloadCompleteEnUs._(_root);
}

// Path: settings.about.sections
class _TranslationsSettingsAboutSectionsEnUs {
	_TranslationsSettingsAboutSectionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	late final _TranslationsSettingsAboutSectionsLicensesEnUs licenses = _TranslationsSettingsAboutSectionsLicensesEnUs._(_root);
	late final _TranslationsSettingsAboutSectionsLinksEnUs links = _TranslationsSettingsAboutSectionsLinksEnUs._(_root);
	late final _TranslationsSettingsAboutSectionsCacheEnUs cache = _TranslationsSettingsAboutSectionsCacheEnUs._(_root);
	late final _TranslationsSettingsAboutSectionsUpdatesEnUs updates = _TranslationsSettingsAboutSectionsUpdatesEnUs._(_root);
}

// Path: settings.about.logs
class _TranslationsSettingsAboutLogsEnUs {
	_TranslationsSettingsAboutLogsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Application logs';
	String get empty => 'No log entries available.';
	late final _TranslationsSettingsAboutLogsToastEnUs toast = _TranslationsSettingsAboutLogsToastEnUs._(_root);
}

// Path: dialogs.updateMirror.options
class _TranslationsDialogsUpdateMirrorOptionsEnUs {
	_TranslationsDialogsUpdateMirrorOptionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get github => 'GitHub';
	String get fdroid => 'F-Droid';
}

// Path: library.common.toast
class _TranslationsLibraryCommonToastEnUs {
	_TranslationsLibraryCommonToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get editMode => 'Edit mode is active.';
}

// Path: library.popular.toast
class _TranslationsLibraryPopularToastEnUs {
	_TranslationsLibraryPopularToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get backPress => 'Press again to exit Haipee';
}

// Path: library.timeline.weekdays
class _TranslationsLibraryTimelineWeekdaysEnUs {
	_TranslationsLibraryTimelineWeekdaysEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get mon => 'Mon';
	String get tue => 'Tue';
	String get wed => 'Wed';
	String get thu => 'Thu';
	String get fri => 'Fri';
	String get sat => 'Sat';
	String get sun => 'Sun';
}

// Path: library.timeline.seasonPicker
class _TranslationsLibraryTimelineSeasonPickerEnUs {
	_TranslationsLibraryTimelineSeasonPickerEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Time Machine';
	String get yearLabel => '{year}';
}

// Path: library.timeline.season
class _TranslationsLibraryTimelineSeasonEnUs {
	_TranslationsLibraryTimelineSeasonEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => '{season} {year}';
	String get loading => 'Loading…';
	late final _TranslationsLibraryTimelineSeasonNamesEnUs names = _TranslationsLibraryTimelineSeasonNamesEnUs._(_root);
	late final _TranslationsLibraryTimelineSeasonShortEnUs short = _TranslationsLibraryTimelineSeasonShortEnUs._(_root);
}

// Path: library.timeline.sort
class _TranslationsLibraryTimelineSortEnUs {
	_TranslationsLibraryTimelineSortEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Sort order';
	String get byHeat => 'Sort by popularity';
	String get byRating => 'Sort by rating';
	String get byTime => 'Sort by schedule';
}

// Path: library.search.sort
class _TranslationsLibrarySearchSortEnUs {
	_TranslationsLibrarySearchSortEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get label => 'Sort search results';
	String get byHeat => 'Sort by popularity';
	String get byRating => 'Sort by rating';
	String get byRelevance => 'Sort by relevance';
}

// Path: library.history.chips
class _TranslationsLibraryHistoryChipsEnUs {
	_TranslationsLibraryHistoryChipsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get source => 'Source';
	String get progress => 'Progress';
	String get episodeNumber => 'Episode {number}';
}

// Path: library.history.toast
class _TranslationsLibraryHistoryToastEnUs {
	_TranslationsLibraryHistoryToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get sourceMissing => 'Associated source not found.';
}

// Path: library.history.manage
class _TranslationsLibraryHistoryManageEnUs {
	_TranslationsLibraryHistoryManageEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'History Management';
	String get confirmClear => 'Clear all watch history?';
	String get cancel => 'Cancel';
	String get confirm => 'Confirm';
}

// Path: library.info.summary
class _TranslationsLibraryInfoSummaryEnUs {
	_TranslationsLibraryInfoSummaryEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Synopsis';
	String get expand => 'Show more';
	String get collapse => 'Show less';
}

// Path: library.info.tags
class _TranslationsLibraryInfoTagsEnUs {
	_TranslationsLibraryInfoTagsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Tags';
	String get more => 'More +';
}

// Path: library.info.metadata
class _TranslationsLibraryInfoMetadataEnUs {
	_TranslationsLibraryInfoMetadataEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get refresh => 'Refresh';
	String get syncingTitle => 'Syncing metadata…';
	String get syncingSubtitle => 'The first sync may take a few seconds.';
	String get emptyTitle => 'No official metadata yet';
	String get emptySubtitle => 'Try again later or check the metadata settings.';
	String source({required Object source}) => 'Metadata source: ${source}';
	String updated({required Object timestamp, required Object language}) => 'Last updated: ${timestamp} · Language: ${language}';
	String get languageSystem => 'System default';
	String get multiSource => 'Merged sources';
}

// Path: library.info.episodes
class _TranslationsLibraryInfoEpisodesEnUs {
	_TranslationsLibraryInfoEpisodesEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Episodes';
	String get collapse => 'Collapse';
	String expand({required Object count}) => 'Show all (${count})';
	String numberedEpisode({required Object number}) => 'Episode ${number}';
	String get dateUnknown => 'Date TBD';
	String get runtimeUnknown => 'Runtime unknown';
	String runtimeMinutes({required Object minutes}) => '${minutes} minutes';
}

// Path: library.info.errors
class _TranslationsLibraryInfoErrorsEnUs {
	_TranslationsLibraryInfoErrorsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get fetchFailed => 'Failed to load, please try again.';
}

// Path: library.info.tabs
class _TranslationsLibraryInfoTabsEnUs {
	_TranslationsLibraryInfoTabsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get overview => 'Overview';
	String get comments => 'Comments';
	String get characters => 'Characters';
	String get reviews => 'Reviews';
	String get staff => 'Staff';
	String get placeholder => 'Coming soon';
}

// Path: library.info.actions
class _TranslationsLibraryInfoActionsEnUs {
	_TranslationsLibraryInfoActionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get startWatching => 'Start Watching';
}

// Path: library.info.toast
class _TranslationsLibraryInfoToastEnUs {
	_TranslationsLibraryInfoToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get characterSortFailed => 'Failed to sort characters: {details}';
}

// Path: library.info.sourceSheet
class _TranslationsLibraryInfoSourceSheetEnUs {
	_TranslationsLibraryInfoSourceSheetEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Choose playback source ({name})';
	late final _TranslationsLibraryInfoSourceSheetAliasEnUs alias = _TranslationsLibraryInfoSourceSheetAliasEnUs._(_root);
	late final _TranslationsLibraryInfoSourceSheetToastEnUs toast = _TranslationsLibraryInfoSourceSheetToastEnUs._(_root);
	late final _TranslationsLibraryInfoSourceSheetSortEnUs sort = _TranslationsLibraryInfoSourceSheetSortEnUs._(_root);
	late final _TranslationsLibraryInfoSourceSheetCardEnUs card = _TranslationsLibraryInfoSourceSheetCardEnUs._(_root);
	late final _TranslationsLibraryInfoSourceSheetActionsEnUs actions = _TranslationsLibraryInfoSourceSheetActionsEnUs._(_root);
	late final _TranslationsLibraryInfoSourceSheetStatusEnUs status = _TranslationsLibraryInfoSourceSheetStatusEnUs._(_root);
	late final _TranslationsLibraryInfoSourceSheetEmptyEnUs empty = _TranslationsLibraryInfoSourceSheetEmptyEnUs._(_root);
	late final _TranslationsLibraryInfoSourceSheetDialogEnUs dialog = _TranslationsLibraryInfoSourceSheetDialogEnUs._(_root);
}

// Path: library.my.sections
class _TranslationsLibraryMySectionsEnUs {
	_TranslationsLibraryMySectionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get video => 'Video';
}

// Path: library.my.favorites
class _TranslationsLibraryMyFavoritesEnUs {
	_TranslationsLibraryMyFavoritesEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Collections';
	String get description => 'View watching, planning, and completed lists';
	String get empty => 'No favorites yet.';
	late final _TranslationsLibraryMyFavoritesTabsEnUs tabs = _TranslationsLibraryMyFavoritesTabsEnUs._(_root);
	late final _TranslationsLibraryMyFavoritesSyncEnUs sync = _TranslationsLibraryMyFavoritesSyncEnUs._(_root);
}

// Path: library.my.history
class _TranslationsLibraryMyHistoryEnUs {
	_TranslationsLibraryMyHistoryEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Playback History';
	String get description => 'See shows you\'ve watched';
}

// Path: playback.controls.speed
class _TranslationsPlaybackControlsSpeedEnUs {
	_TranslationsPlaybackControlsSpeedEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Playback speed';
	String get reset => 'Default speed';
}

// Path: playback.controls.skip
class _TranslationsPlaybackControlsSkipEnUs {
	_TranslationsPlaybackControlsSkipEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Skip duration';
	String get tooltip => 'Long press to change duration';
}

// Path: playback.controls.status
class _TranslationsPlaybackControlsStatusEnUs {
	_TranslationsPlaybackControlsStatusEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get fastForward => 'Fast forward {seconds} s';
	String get rewind => 'Rewind {seconds} s';
	String get speed => 'Speed playback';
}

// Path: playback.controls.superResolution
class _TranslationsPlaybackControlsSuperResolutionEnUs {
	_TranslationsPlaybackControlsSuperResolutionEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get label => 'Super resolution';
	String get off => 'Off';
	String get balanced => 'Balanced';
	String get quality => 'Quality';
}

// Path: playback.controls.speedMenu
class _TranslationsPlaybackControlsSpeedMenuEnUs {
	_TranslationsPlaybackControlsSpeedMenuEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get label => 'Speed';
}

// Path: playback.controls.aspectRatio
class _TranslationsPlaybackControlsAspectRatioEnUs {
	_TranslationsPlaybackControlsAspectRatioEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get label => 'Aspect ratio';
	late final _TranslationsPlaybackControlsAspectRatioOptionsEnUs options = _TranslationsPlaybackControlsAspectRatioOptionsEnUs._(_root);
}

// Path: playback.controls.tooltips
class _TranslationsPlaybackControlsTooltipsEnUs {
	_TranslationsPlaybackControlsTooltipsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get danmakuOn => 'Turn off danmaku (d)';
	String get danmakuOff => 'Turn on danmaku (d)';
}

// Path: playback.controls.menu
class _TranslationsPlaybackControlsMenuEnUs {
	_TranslationsPlaybackControlsMenuEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get danmakuToggle => 'Danmaku switch';
	String get videoInfo => 'Video info';
	String get cast => 'Remote cast';
	String get external => 'Open in external player';
}

// Path: playback.controls.syncplay
class _TranslationsPlaybackControlsSyncplayEnUs {
	_TranslationsPlaybackControlsSyncplayEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get label => 'SyncPlay';
	String get room => 'Current room: {name}';
	String get roomEmpty => 'Not joined';
	String get latency => 'Latency: {ms} ms';
	String get join => 'Join room';
	String get switchServer => 'Switch server';
	String get disconnect => 'Disconnect';
}

// Path: playback.remote.toast
class _TranslationsPlaybackRemoteToastEnUs {
	_TranslationsPlaybackRemoteToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get searching => 'Searching…';
	String get casting => 'Attempting to cast to {device}';
	String get error => 'DLNA error: {details}\nTry reopening the DLNA panel or choosing another device.';
}

// Path: playback.debug.tabs
class _TranslationsPlaybackDebugTabsEnUs {
	_TranslationsPlaybackDebugTabsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get status => 'Status';
	String get logs => 'Logs';
}

// Path: playback.debug.sections
class _TranslationsPlaybackDebugSectionsEnUs {
	_TranslationsPlaybackDebugSectionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get source => 'Playback source';
	String get playback => 'Player status';
	String get timing => 'Timing & metrics';
	String get media => 'Media tracks';
}

// Path: playback.debug.labels
class _TranslationsPlaybackDebugLabelsEnUs {
	_TranslationsPlaybackDebugLabelsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get series => 'Series';
	String get plugin => 'Plugin';
	String get route => 'Route';
	String get episode => 'Episode';
	String get routeCount => 'Route count';
	String get sourceTitle => 'Source title';
	String get parsedUrl => 'Parsed URL';
	String get playUrl => 'Playback URL';
	String get danmakuId => 'DanDan ID';
	String get syncRoom => 'SyncPlay room';
	String get syncLatency => 'SyncPlay RTT';
	String get nativePlayer => 'Native player';
	String get parsing => 'Parsing';
	String get playerLoading => 'Player loading';
	String get playerInitializing => 'Player initializing';
	String get playing => 'Playing';
	String get buffering => 'Buffering';
	String get completed => 'Playback completed';
	String get bufferFlag => 'Buffer flag';
	String get currentPosition => 'Current position';
	String get bufferProgress => 'Buffer progress';
	String get duration => 'Duration';
	String get speed => 'Playback speed';
	String get volume => 'Volume';
	String get brightness => 'Brightness';
	String get resolution => 'Resolution';
	String get aspectRatio => 'Aspect ratio';
	String get superResolution => 'Super resolution';
	String get videoParams => 'Video params';
	String get audioParams => 'Audio params';
	String get playlist => 'Playlist';
	String get audioTracks => 'Audio tracks';
	String get videoTracks => 'Video tracks';
	String get audioBitrate => 'Audio bitrate';
}

// Path: playback.debug.values
class _TranslationsPlaybackDebugValuesEnUs {
	_TranslationsPlaybackDebugValuesEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get yes => 'Yes';
	String get no => 'No';
}

// Path: playback.debug.logs
class _TranslationsPlaybackDebugLogsEnUs {
	_TranslationsPlaybackDebugLogsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get playerEmpty => 'Player log (0)';
	String get playerSummary => 'Player log ({count} entries, showing {displayed})';
	String get webviewEmpty => 'WebView log (0)';
	String get webviewSummary => 'WebView log ({count} entries, showing {displayed})';
}

// Path: playback.syncplay.selectServer
class _TranslationsPlaybackSyncplaySelectServerEnUs {
	_TranslationsPlaybackSyncplaySelectServerEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Choose server';
	String get customTitle => 'Custom server';
	String get customHint => 'Enter server URL';
	String get duplicateOrEmpty => 'Server URL must be unique and non-empty';
}

// Path: playback.syncplay.join
class _TranslationsPlaybackSyncplayJoinEnUs {
	_TranslationsPlaybackSyncplayJoinEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Join room';
	String get roomLabel => 'Room ID';
	String get roomEmpty => 'Enter a room ID';
	String get roomInvalid => 'Room ID must be 6 to 10 digits';
	String get usernameLabel => 'Username';
	String get usernameEmpty => 'Enter a username';
	String get usernameInvalid => 'Username must be 4 to 12 letters';
}

// Path: playback.superResolution.warning
class _TranslationsPlaybackSuperResolutionWarningEnUs {
	_TranslationsPlaybackSuperResolutionWarningEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Performance warning';
	String get message => 'Enabling super resolution (quality) may cause stutter. Continue?';
	String get dontAskAgain => 'Don\'t ask again';
}

// Path: settings.appearancePage.colorScheme.labels
class _TranslationsSettingsAppearancePageColorSchemeLabelsEnUs {
	_TranslationsSettingsAppearancePageColorSchemeLabelsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get defaultLabel => 'Default';
	String get teal => 'Teal';
	String get blue => 'Blue';
	String get indigo => 'Indigo';
	String get violet => 'Violet';
	String get pink => 'Pink';
	String get yellow => 'Yellow';
	String get orange => 'Orange';
	String get deepOrange => 'Deep orange';
}

// Path: settings.plugins.sort.options
class _TranslationsSettingsPluginsSortOptionsEnUs {
	_TranslationsSettingsPluginsSortOptionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get original => 'Original order';
	String get nameAsc => 'Name (A → Z)';
	String get nameDesc => 'Name (Z → A)';
	String get failureAsc => 'Failures (Low → High)';
	String get failureDesc => 'Failures (High → Low)';
}

// Path: settings.plugins.editor.fields
class _TranslationsSettingsPluginsEditorFieldsEnUs {
	_TranslationsSettingsPluginsEditorFieldsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get name => 'Rule name';
	String get version => 'Version';
	String get baseUrl => 'Base URL';
	String get searchUrl => 'Search URL';
	String get searchList => 'Search list XPath';
	String get searchName => 'Search title XPath';
	String get searchResult => 'Search result XPath';
	String get chapterRoads => 'Playlist XPath';
	String get chapterResult => 'Playlist result XPath';
	String get userAgent => 'User-Agent';
	String get referer => 'Referer';
}

// Path: settings.plugins.editor.advanced
class _TranslationsSettingsPluginsEditorAdvancedEnUs {
	_TranslationsSettingsPluginsEditorAdvancedEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Advanced Options';
	late final _TranslationsSettingsPluginsEditorAdvancedLegacyParserEnUs legacyParser = _TranslationsSettingsPluginsEditorAdvancedLegacyParserEnUs._(_root);
	late final _TranslationsSettingsPluginsEditorAdvancedHttpPostEnUs httpPost = _TranslationsSettingsPluginsEditorAdvancedHttpPostEnUs._(_root);
	late final _TranslationsSettingsPluginsEditorAdvancedNativePlayerEnUs nativePlayer = _TranslationsSettingsPluginsEditorAdvancedNativePlayerEnUs._(_root);
}

// Path: settings.plugins.shop.tooltip
class _TranslationsSettingsPluginsShopTooltipEnUs {
	_TranslationsSettingsPluginsShopTooltipEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get sortByName => 'Sort by name';
	String get sortByUpdate => 'Sort by last update';
	String get refresh => 'Refresh rule list';
}

// Path: settings.plugins.shop.labels
class _TranslationsSettingsPluginsShopLabelsEnUs {
	_TranslationsSettingsPluginsShopLabelsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	late final _TranslationsSettingsPluginsShopLabelsPlayerTypeEnUs playerType = _TranslationsSettingsPluginsShopLabelsPlayerTypeEnUs._(_root);
	String get lastUpdated => 'Last updated: {timestamp}';
}

// Path: settings.plugins.shop.buttons
class _TranslationsSettingsPluginsShopButtonsEnUs {
	_TranslationsSettingsPluginsShopButtonsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get install => 'Add';
	String get installed => 'Added';
	String get update => 'Update';
	String get toggleMirrorEnable => 'Enable mirror';
	String get toggleMirrorDisable => 'Disable mirror';
	String get refresh => 'Refresh';
}

// Path: settings.plugins.shop.toast
class _TranslationsSettingsPluginsShopToastEnUs {
	_TranslationsSettingsPluginsShopToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get importFailed => 'Failed to import rule.';
}

// Path: settings.plugins.shop.error
class _TranslationsSettingsPluginsShopErrorEnUs {
	_TranslationsSettingsPluginsShopErrorEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get unreachable => 'Unable to reach the repository\n{status}';
	String get mirrorEnabled => 'Mirror enabled';
	String get mirrorDisabled => 'Mirror disabled';
}

// Path: settings.player.superResolutionOptions.off
class _TranslationsSettingsPlayerSuperResolutionOptionsOffEnUs {
	_TranslationsSettingsPlayerSuperResolutionOptionsOffEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get label => 'Off';
	String get description => 'Disable all upscaling enhancements.';
}

// Path: settings.player.superResolutionOptions.efficiency
class _TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyEnUs {
	_TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get label => 'Balanced';
	String get description => 'Balance performance usage and picture quality.';
}

// Path: settings.player.superResolutionOptions.quality
class _TranslationsSettingsPlayerSuperResolutionOptionsQualityEnUs {
	_TranslationsSettingsPlayerSuperResolutionOptionsQualityEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get label => 'Quality First';
	String get description => 'Maximize visual quality at the cost of resources.';
}

// Path: settings.webdav.editor.toast
class _TranslationsSettingsWebdavEditorToastEnUs {
	_TranslationsSettingsWebdavEditorToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get saveSuccess => 'Configuration saved. Starting test...';
	String get saveFailed => 'Failed to save configuration: {error}';
	String get testSuccess => 'Test succeeded.';
	String get testFailed => 'Test failed: {error}';
}

// Path: settings.update.dialog.actions
class _TranslationsSettingsUpdateDialogActionsEnUs {
	_TranslationsSettingsUpdateDialogActionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get disableAutoUpdate => 'Disable auto update';
	String get remindLater => 'Remind me later';
	String get viewDetails => 'View details';
	String get updateNow => 'Update now';
}

// Path: settings.update.download.error
class _TranslationsSettingsUpdateDownloadErrorEnUs {
	_TranslationsSettingsUpdateDownloadErrorEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Download failed';
	String get general => 'The update could not be downloaded.';
	String get permission => 'Insufficient permissions to write the file.';
	String get diskFull => 'Not enough disk space.';
	String get network => 'Network connection failed.';
	String get integrity => 'File integrity check failed. Please try again.';
	String get details => 'Technical details: {error}';
	String get confirm => 'OK';
	String get retry => 'Retry';
}

// Path: settings.update.download.complete
class _TranslationsSettingsUpdateDownloadCompleteEnUs {
	_TranslationsSettingsUpdateDownloadCompleteEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Download complete';
	String get message => 'Haipee {version} downloaded.';
	String get quitNotice => 'The app will exit during installation.';
	String get fileLocation => 'File saved to';
	late final _TranslationsSettingsUpdateDownloadCompleteButtonsEnUs buttons = _TranslationsSettingsUpdateDownloadCompleteButtonsEnUs._(_root);
}

// Path: settings.about.sections.licenses
class _TranslationsSettingsAboutSectionsLicensesEnUs {
	_TranslationsSettingsAboutSectionsLicensesEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Open source licenses';
	String get description => 'View all open source licenses';
}

// Path: settings.about.sections.links
class _TranslationsSettingsAboutSectionsLinksEnUs {
	_TranslationsSettingsAboutSectionsLinksEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'External links';
	String get project => 'Project homepage';
	String get repository => 'Source repository';
	String get icon => 'Icon design';
	String get index => 'Anime index';
	String get danmaku => 'Danmaku provider';
	String get danmakuId => 'ID: {id}';
}

// Path: settings.about.sections.cache
class _TranslationsSettingsAboutSectionsCacheEnUs {
	_TranslationsSettingsAboutSectionsCacheEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get clearAction => 'Clear cache';
	String get sizePending => 'Calculating…';
	String get sizeLabel => '{size} MB';
}

// Path: settings.about.sections.updates
class _TranslationsSettingsAboutSectionsUpdatesEnUs {
	_TranslationsSettingsAboutSectionsUpdatesEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'App updates';
	String get autoUpdate => 'Auto update';
	String get check => 'Check for updates';
	String get currentVersion => 'Current version {version}';
}

// Path: settings.about.logs.toast
class _TranslationsSettingsAboutLogsToastEnUs {
	_TranslationsSettingsAboutLogsToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get cleared => 'Logs cleared.';
	String get clearFailed => 'Failed to clear logs.';
}

// Path: library.timeline.season.names
class _TranslationsLibraryTimelineSeasonNamesEnUs {
	_TranslationsLibraryTimelineSeasonNamesEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get winter => 'Winter';
	String get spring => 'Spring';
	String get summer => 'Summer';
	String get autumn => 'Autumn';
}

// Path: library.timeline.season.short
class _TranslationsLibraryTimelineSeasonShortEnUs {
	_TranslationsLibraryTimelineSeasonShortEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get winter => 'Winter';
	String get spring => 'Spring';
	String get summer => 'Summer';
	String get autumn => 'Autumn';
}

// Path: library.info.sourceSheet.alias
class _TranslationsLibraryInfoSourceSheetAliasEnUs {
	_TranslationsLibraryInfoSourceSheetAliasEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get deleteTooltip => 'Delete alias';
	String get deleteTitle => 'Delete alias';
	String get deleteMessage => 'This cannot be undone. Delete this alias?';
}

// Path: library.info.sourceSheet.toast
class _TranslationsLibraryInfoSourceSheetToastEnUs {
	_TranslationsLibraryInfoSourceSheetToastEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get aliasEmpty => 'No aliases available. Add one manually before searching.';
	String get loadFailed => 'Failed to load playback routes.';
	String get removed => 'Removed source {plugin}.';
}

// Path: library.info.sourceSheet.sort
class _TranslationsLibraryInfoSourceSheetSortEnUs {
	_TranslationsLibraryInfoSourceSheetSortEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Sort order';
	String get tooltip => 'Sort: {label}';
	late final _TranslationsLibraryInfoSourceSheetSortOptionsEnUs options = _TranslationsLibraryInfoSourceSheetSortOptionsEnUs._(_root);
}

// Path: library.info.sourceSheet.card
class _TranslationsLibraryInfoSourceSheetCardEnUs {
	_TranslationsLibraryInfoSourceSheetCardEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Source · {plugin}';
	String get play => 'Play';
}

// Path: library.info.sourceSheet.actions
class _TranslationsLibraryInfoSourceSheetActionsEnUs {
	_TranslationsLibraryInfoSourceSheetActionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get searchAgain => 'Search again';
	String get aliasSearch => 'Alias search';
	String get removeSource => 'Remove source';
}

// Path: library.info.sourceSheet.status
class _TranslationsLibraryInfoSourceSheetStatusEnUs {
	_TranslationsLibraryInfoSourceSheetStatusEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get searching => '{plugin} searching…';
	String get failed => '{plugin} search failed';
	String get empty => '{plugin} returned no results';
}

// Path: library.info.sourceSheet.empty
class _TranslationsLibraryInfoSourceSheetEmptyEnUs {
	_TranslationsLibraryInfoSourceSheetEmptyEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get searching => 'Searching, please wait…';
	String get noResults => 'No playback sources found. Try searching again or use an alias.';
}

// Path: library.info.sourceSheet.dialog
class _TranslationsLibraryInfoSourceSheetDialogEnUs {
	_TranslationsLibraryInfoSourceSheetDialogEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get removeTitle => 'Remove source';
	String get removeMessage => 'Remove source {plugin}?';
}

// Path: library.my.favorites.tabs
class _TranslationsLibraryMyFavoritesTabsEnUs {
	_TranslationsLibraryMyFavoritesTabsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get watching => 'Watching';
	String get planned => 'Plan to Watch';
	String get completed => 'Completed';
	String get empty => 'No entries yet.';
}

// Path: library.my.favorites.sync
class _TranslationsLibraryMyFavoritesSyncEnUs {
	_TranslationsLibraryMyFavoritesSyncEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get disabled => 'WebDAV sync is disabled.';
	String get editing => 'Cannot sync while in edit mode.';
}

// Path: playback.controls.aspectRatio.options
class _TranslationsPlaybackControlsAspectRatioOptionsEnUs {
	_TranslationsPlaybackControlsAspectRatioOptionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get auto => 'Auto';
	String get crop => 'Crop to fill';
	String get stretch => 'Stretch to fill';
}

// Path: settings.plugins.editor.advanced.legacyParser
class _TranslationsSettingsPluginsEditorAdvancedLegacyParserEnUs {
	_TranslationsSettingsPluginsEditorAdvancedLegacyParserEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Enable legacy parser';
	String get subtitle => 'Use the legacy XPath parser for compatibility.';
}

// Path: settings.plugins.editor.advanced.httpPost
class _TranslationsSettingsPluginsEditorAdvancedHttpPostEnUs {
	_TranslationsSettingsPluginsEditorAdvancedHttpPostEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Send search via POST';
	String get subtitle => 'Submit search requests with HTTP POST.';
}

// Path: settings.plugins.editor.advanced.nativePlayer
class _TranslationsSettingsPluginsEditorAdvancedNativePlayerEnUs {
	_TranslationsSettingsPluginsEditorAdvancedNativePlayerEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get title => 'Force native player';
	String get subtitle => 'Prefer the built-in player when starting playback.';
}

// Path: settings.plugins.shop.labels.playerType
class _TranslationsSettingsPluginsShopLabelsPlayerTypeEnUs {
	_TranslationsSettingsPluginsShopLabelsPlayerTypeEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get native => 'native';
	String get webview => 'webview';
}

// Path: settings.update.download.complete.buttons
class _TranslationsSettingsUpdateDownloadCompleteButtonsEnUs {
	_TranslationsSettingsUpdateDownloadCompleteButtonsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get later => 'Later';
	String get openFolder => 'Open folder';
	String get installNow => 'Install now';
}

// Path: library.info.sourceSheet.sort.options
class _TranslationsLibraryInfoSourceSheetSortOptionsEnUs {
	_TranslationsLibraryInfoSourceSheetSortOptionsEnUs._(this._root);

	final AppTranslations _root; // ignore: unused_field

	// Translations
	String get original => 'Original order';
	String get nameAsc => 'Name (A → Z)';
	String get nameDesc => 'Name (Z → A)';
	String get failureAsc => 'Failures (Low → High)';
	String get failureDesc => 'Failures (High → Low)';
}

// Path: <root>
class _TranslationsJaJp extends AppTranslations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_TranslationsJaJp.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.jaJp,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super.build(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ja-JP>.
	@override final TranslationMetadata<AppLocale, AppTranslations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	@override late final _TranslationsJaJp _root = this; // ignore: unused_field

	// Translations
	@override late final _TranslationsAppJaJp app = _TranslationsAppJaJp._(_root);
	@override late final _TranslationsMetadataJaJp metadata = _TranslationsMetadataJaJp._(_root);
	@override late final _TranslationsDownloadsJaJp downloads = _TranslationsDownloadsJaJp._(_root);
	@override late final _TranslationsTorrentJaJp torrent = _TranslationsTorrentJaJp._(_root);
	@override late final _TranslationsSettingsJaJp settings = _TranslationsSettingsJaJp._(_root);
	@override late final _TranslationsExitDialogJaJp exitDialog = _TranslationsExitDialogJaJp._(_root);
	@override late final _TranslationsTrayJaJp tray = _TranslationsTrayJaJp._(_root);
	@override late final _TranslationsNavigationJaJp navigation = _TranslationsNavigationJaJp._(_root);
	@override late final _TranslationsDialogsJaJp dialogs = _TranslationsDialogsJaJp._(_root);
	@override late final _TranslationsLibraryJaJp library = _TranslationsLibraryJaJp._(_root);
	@override late final _TranslationsPlaybackJaJp playback = _TranslationsPlaybackJaJp._(_root);
	@override late final _TranslationsNetworkJaJp network = _TranslationsNetworkJaJp._(_root);
	@override late final _TranslationsSyncJaJp sync = _TranslationsSyncJaJp._(_root);
}

// Path: app
class _TranslationsAppJaJp extends _TranslationsAppEnUs {
	_TranslationsAppJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'Haipee';
	@override String get loading => '読み込み中…';
	@override String get retry => '再試行';
	@override String get confirm => '確認';
	@override String get cancel => 'キャンセル';
	@override String get delete => '削除';
}

// Path: metadata
class _TranslationsMetadataJaJp extends _TranslationsMetadataEnUs {
	_TranslationsMetadataJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get sectionTitle => 'メディア情報';
	@override String get refresh => 'メタデータの更新';
	@override late final _TranslationsMetadataSourceJaJp source = _TranslationsMetadataSourceJaJp._(_root);
	@override String get lastSynced => '最後の同期：{timestamp}';
}

// Path: downloads
class _TranslationsDownloadsJaJp extends _TranslationsDownloadsEnUs {
	_TranslationsDownloadsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get sectionTitle => 'ダウンロードキュー';
	@override String get downloadOffline => 'ダウンロードエンジンが接続されていません';
	@override String get queued => 'キューに追加';
	@override String get running => 'ダウンロード中';
	@override String get completed => '完了';
}

// Path: torrent
class _TranslationsTorrentJaJp extends _TranslationsTorrentEnUs {
	_TranslationsTorrentJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsTorrentConsentJaJp consent = _TranslationsTorrentConsentJaJp._(_root);
	@override late final _TranslationsTorrentErrorJaJp error = _TranslationsTorrentErrorJaJp._(_root);
}

// Path: settings
class _TranslationsSettingsJaJp extends _TranslationsSettingsEnUs {
	_TranslationsSettingsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '設定';
	@override String get downloads => 'ダウンロード設定';
	@override String get playback => '再生設定';
	@override late final _TranslationsSettingsGeneralJaJp general = _TranslationsSettingsGeneralJaJp._(_root);
	@override late final _TranslationsSettingsAppearancePageJaJp appearancePage = _TranslationsSettingsAppearancePageJaJp._(_root);
	@override late final _TranslationsSettingsSourceJaJp source = _TranslationsSettingsSourceJaJp._(_root);
	@override late final _TranslationsSettingsPluginsJaJp plugins = _TranslationsSettingsPluginsJaJp._(_root);
	@override late final _TranslationsSettingsMetadataJaJp metadata = _TranslationsSettingsMetadataJaJp._(_root);
	@override late final _TranslationsSettingsPlayerJaJp player = _TranslationsSettingsPlayerJaJp._(_root);
	@override late final _TranslationsSettingsWebdavJaJp webdav = _TranslationsSettingsWebdavJaJp._(_root);
	@override late final _TranslationsSettingsUpdateJaJp update = _TranslationsSettingsUpdateJaJp._(_root);
	@override late final _TranslationsSettingsOtherJaJp other = _TranslationsSettingsOtherJaJp._(_root);
	@override late final _TranslationsSettingsAboutJaJp about = _TranslationsSettingsAboutJaJp._(_root);
}

// Path: exitDialog
class _TranslationsExitDialogJaJp extends _TranslationsExitDialogEnUs {
	_TranslationsExitDialogJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '終了の確認';
	@override String get message => 'Haipeeを終了しますか？';
	@override String get dontAskAgain => '次回から聞かない';
	@override String get exit => 'Haipeeを終了';
	@override String get minimize => 'トレイに最小化';
	@override String get cancel => 'キャンセル';
}

// Path: tray
class _TranslationsTrayJaJp extends _TranslationsTrayEnUs {
	_TranslationsTrayJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get showWindow => 'ウィンドウを表示';
	@override String get exit => 'Haipeeを終了';
}

// Path: navigation
class _TranslationsNavigationJaJp extends _TranslationsNavigationEnUs {
	_TranslationsNavigationJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsNavigationTabsJaJp tabs = _TranslationsNavigationTabsJaJp._(_root);
	@override late final _TranslationsNavigationActionsJaJp actions = _TranslationsNavigationActionsJaJp._(_root);
}

// Path: dialogs
class _TranslationsDialogsJaJp extends _TranslationsDialogsEnUs {
	_TranslationsDialogsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsDialogsDisclaimerJaJp disclaimer = _TranslationsDialogsDisclaimerJaJp._(_root);
	@override late final _TranslationsDialogsUpdateMirrorJaJp updateMirror = _TranslationsDialogsUpdateMirrorJaJp._(_root);
	@override late final _TranslationsDialogsPluginUpdatesJaJp pluginUpdates = _TranslationsDialogsPluginUpdatesJaJp._(_root);
	@override late final _TranslationsDialogsWebdavJaJp webdav = _TranslationsDialogsWebdavJaJp._(_root);
	@override late final _TranslationsDialogsAboutJaJp about = _TranslationsDialogsAboutJaJp._(_root);
	@override late final _TranslationsDialogsCacheJaJp cache = _TranslationsDialogsCacheJaJp._(_root);
}

// Path: library
class _TranslationsLibraryJaJp extends _TranslationsLibraryEnUs {
	_TranslationsLibraryJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsLibraryCommonJaJp common = _TranslationsLibraryCommonJaJp._(_root);
	@override late final _TranslationsLibraryPopularJaJp popular = _TranslationsLibraryPopularJaJp._(_root);
	@override late final _TranslationsLibraryTimelineJaJp timeline = _TranslationsLibraryTimelineJaJp._(_root);
	@override late final _TranslationsLibrarySearchJaJp search = _TranslationsLibrarySearchJaJp._(_root);
	@override late final _TranslationsLibraryHistoryJaJp history = _TranslationsLibraryHistoryJaJp._(_root);
	@override late final _TranslationsLibraryInfoJaJp info = _TranslationsLibraryInfoJaJp._(_root);
	@override late final _TranslationsLibraryMyJaJp my = _TranslationsLibraryMyJaJp._(_root);
}

// Path: playback
class _TranslationsPlaybackJaJp extends _TranslationsPlaybackEnUs {
	_TranslationsPlaybackJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsPlaybackToastJaJp toast = _TranslationsPlaybackToastJaJp._(_root);
	@override late final _TranslationsPlaybackDanmakuJaJp danmaku = _TranslationsPlaybackDanmakuJaJp._(_root);
	@override late final _TranslationsPlaybackExternalPlayerJaJp externalPlayer = _TranslationsPlaybackExternalPlayerJaJp._(_root);
	@override late final _TranslationsPlaybackControlsJaJp controls = _TranslationsPlaybackControlsJaJp._(_root);
	@override late final _TranslationsPlaybackLoadingJaJp loading = _TranslationsPlaybackLoadingJaJp._(_root);
	@override late final _TranslationsPlaybackDanmakuSearchJaJp danmakuSearch = _TranslationsPlaybackDanmakuSearchJaJp._(_root);
	@override late final _TranslationsPlaybackRemoteJaJp remote = _TranslationsPlaybackRemoteJaJp._(_root);
	@override late final _TranslationsPlaybackDebugJaJp debug = _TranslationsPlaybackDebugJaJp._(_root);
	@override late final _TranslationsPlaybackSyncplayJaJp syncplay = _TranslationsPlaybackSyncplayJaJp._(_root);
	@override late final _TranslationsPlaybackPlaylistJaJp playlist = _TranslationsPlaybackPlaylistJaJp._(_root);
	@override late final _TranslationsPlaybackTabsJaJp tabs = _TranslationsPlaybackTabsJaJp._(_root);
	@override late final _TranslationsPlaybackCommentsJaJp comments = _TranslationsPlaybackCommentsJaJp._(_root);
	@override late final _TranslationsPlaybackSuperResolutionJaJp superResolution = _TranslationsPlaybackSuperResolutionJaJp._(_root);
}

// Path: network
class _TranslationsNetworkJaJp extends _TranslationsNetworkEnUs {
	_TranslationsNetworkJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsNetworkErrorJaJp error = _TranslationsNetworkErrorJaJp._(_root);
	@override late final _TranslationsNetworkStatusJaJp status = _TranslationsNetworkStatusJaJp._(_root);
}

// Path: sync
class _TranslationsSyncJaJp extends _TranslationsSyncEnUs {
	_TranslationsSyncJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
}

// Path: metadata.source
class _TranslationsMetadataSourceJaJp extends _TranslationsMetadataSourceEnUs {
	_TranslationsMetadataSourceJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get bangumi => 'Bangumi';
	@override String get tmdb => 'TMDb';
}

// Path: torrent.consent
class _TranslationsTorrentConsentJaJp extends _TranslationsTorrentConsentEnUs {
	_TranslationsTorrentConsentJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'BitTorrent使用の通知';
	@override String get description => 'BTダウンロードを有効にする前に、現地の法律を遵守し、伴うリスクを十分に理解してください。';
	@override String get agree => '理解しました、続行します';
	@override String get decline => '今回はしません';
}

// Path: torrent.error
class _TranslationsTorrentErrorJaJp extends _TranslationsTorrentErrorEnUs {
	_TranslationsTorrentErrorJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get submit => '磁気リンクを送信できませんでした。後でもう一度お試しください';
}

// Path: settings.general
class _TranslationsSettingsGeneralJaJp extends _TranslationsSettingsGeneralEnUs {
	_TranslationsSettingsGeneralJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '一般';
	@override String get appearance => '外観';
	@override String get appearanceDesc => 'アプリテーマとリフレッシュレートの設定';
	@override String get language => 'アプリ言語';
	@override String get languageDesc => 'アプリインターフェースの表示言語を選択';
	@override String get followSystem => 'システム';
	@override String get exitBehavior => '閉じる際';
	@override String get exitApp => 'Haipeeを終了';
	@override String get minimizeToTray => 'トレイに最小化';
	@override String get askEveryTime => '毎回確認';
}

// Path: settings.appearancePage
class _TranslationsSettingsAppearancePageJaJp extends _TranslationsSettingsAppearancePageEnUs {
	_TranslationsSettingsAppearancePageJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '外観';
	@override late final _TranslationsSettingsAppearancePageModeJaJp mode = _TranslationsSettingsAppearancePageModeJaJp._(_root);
	@override late final _TranslationsSettingsAppearancePageColorSchemeJaJp colorScheme = _TranslationsSettingsAppearancePageColorSchemeJaJp._(_root);
	@override late final _TranslationsSettingsAppearancePageOledJaJp oled = _TranslationsSettingsAppearancePageOledJaJp._(_root);
	@override late final _TranslationsSettingsAppearancePageWindowJaJp window = _TranslationsSettingsAppearancePageWindowJaJp._(_root);
	@override late final _TranslationsSettingsAppearancePageRefreshRateJaJp refreshRate = _TranslationsSettingsAppearancePageRefreshRateJaJp._(_root);
}

// Path: settings.source
class _TranslationsSettingsSourceJaJp extends _TranslationsSettingsSourceEnUs {
	_TranslationsSettingsSourceJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'ソース';
	@override String get ruleManagement => 'ルール管理';
	@override String get ruleManagementDesc => 'アニメリソースルールの管理';
	@override String get githubProxy => 'GitHubプロキシ';
	@override String get githubProxyDesc => 'ルールリポジトリにアクセスするためのプロキシを使用';
}

// Path: settings.plugins
class _TranslationsSettingsPluginsJaJp extends _TranslationsSettingsPluginsEnUs {
	_TranslationsSettingsPluginsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'ルール管理';
	@override String get empty => '利用可能なルールはありません';
	@override late final _TranslationsSettingsPluginsTooltipJaJp tooltip = _TranslationsSettingsPluginsTooltipJaJp._(_root);
	@override late final _TranslationsSettingsPluginsSortJaJp sort = _TranslationsSettingsPluginsSortJaJp._(_root);
	@override late final _TranslationsSettingsPluginsMultiSelectJaJp multiSelect = _TranslationsSettingsPluginsMultiSelectJaJp._(_root);
	@override late final _TranslationsSettingsPluginsLoadingJaJp loading = _TranslationsSettingsPluginsLoadingJaJp._(_root);
	@override late final _TranslationsSettingsPluginsLabelsJaJp labels = _TranslationsSettingsPluginsLabelsJaJp._(_root);
	@override late final _TranslationsSettingsPluginsActionsJaJp actions = _TranslationsSettingsPluginsActionsJaJp._(_root);
	@override late final _TranslationsSettingsPluginsDialogsJaJp dialogs = _TranslationsSettingsPluginsDialogsJaJp._(_root);
	@override late final _TranslationsSettingsPluginsToastJaJp toast = _TranslationsSettingsPluginsToastJaJp._(_root);
	@override late final _TranslationsSettingsPluginsEditorJaJp editor = _TranslationsSettingsPluginsEditorJaJp._(_root);
	@override late final _TranslationsSettingsPluginsShopJaJp shop = _TranslationsSettingsPluginsShopJaJp._(_root);
}

// Path: settings.metadata
class _TranslationsSettingsMetadataJaJp extends _TranslationsSettingsMetadataEnUs {
	_TranslationsSettingsMetadataJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'メタデータソース';
	@override String get enableBangumi => 'Bangumiメタデータソースを有効化';
	@override String get enableBangumiDesc => 'Bangumiからアニメ情報を取得';
	@override String get enableTmdb => 'TMDbメタデータソースを有効化';
	@override String get enableTmdbDesc => 'TMDbから多言語データを補充';
	@override String get preferredLanguage => '優先言語';
	@override String get preferredLanguageDesc => 'メタデータの同期時に使用する言語を設定';
	@override String get followSystemLanguage => 'システム言語に従う';
	@override String get simplifiedChinese => '简体中文（zh-CN）';
	@override String get traditionalChinese => '繁體中文（zh-TW）';
	@override String get japanese => '日本語（ja-JP）';
	@override String get english => '英語（en-US）';
	@override String get custom => 'カスタム';
}

// Path: settings.player
class _TranslationsSettingsPlayerJaJp extends _TranslationsSettingsPlayerEnUs {
	_TranslationsSettingsPlayerJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'プレイヤー設定';
	@override String get playerSettings => 'プレイヤー設定';
	@override String get playerSettingsDesc => 'プレイヤーパラメータを設定';
	@override String get hardwareDecoding => 'ハードウェアデコード';
	@override String get hardwareDecoder => 'ハードウェアデコーダー';
	@override String get hardwareDecoderDesc => 'ハードウェアデ碼りが有効な場合のみ有効';
	@override String get lowMemoryMode => '低メモリモード';
	@override String get lowMemoryModeDesc => 'メモリ使用量を減らすため高度なキャッシュを無効化';
	@override String get lowLatencyAudio => '低レイテンシ音声';
	@override String get lowLatencyAudioDesc => 'レイテンシを低くするためOpenSLES音声出力を有効化';
	@override String get superResolution => '超解像度';
	@override String get autoJump => '自動ジャンプ';
	@override String get autoJumpDesc => '最後の再生位置にジャンプ';
	@override String get disableAnimations => 'アニメーション無効化';
	@override String get disableAnimationsDesc => 'プレイヤー内のトランジションアニメーションを無効化';
	@override String get errorPrompt => 'エラープ롬プト';
	@override String get errorPromptDesc => 'プレイヤー内の内部エラープ롬プトを表示';
	@override String get debugMode => 'デバッグモード';
	@override String get debugModeDesc => '内部プレイヤーログを記録';
	@override String get privateMode => 'プライベートモード';
	@override String get privateModeDesc => '視聴履歴を保持しない';
	@override String get defaultPlaySpeed => 'デフォルト再生速度';
	@override String get defaultVideoAspectRatio => 'デフォルト動画アスペクト比';
	@override late final _TranslationsSettingsPlayerAspectRatioJaJp aspectRatio = _TranslationsSettingsPlayerAspectRatioJaJp._(_root);
	@override String get danmakuSettings => '弾幕設定';
	@override String get danmakuSettingsDesc => '弾幕パラメータを設定';
	@override String get danmaku => '弾幕';
	@override String get danmakuDefaultOn => 'デフォルトオン';
	@override String get danmakuDefaultOnDesc => '動画と一緒に弾幕をデフォルトで表示するかどうか';
	@override String get danmakuSource => '弾幕ソース';
	@override late final _TranslationsSettingsPlayerDanmakuSourcesJaJp danmakuSources = _TranslationsSettingsPlayerDanmakuSourcesJaJp._(_root);
	@override String get danmakuCredentials => '認証情報';
	@override String get danmakuDanDanCredentials => 'DanDan API認証情報';
	@override String get danmakuDanDanCredentialsDesc => 'カスタムDanDan認証情報';
	@override String get danmakuCredentialModeBuiltIn => 'ビルトイン';
	@override String get danmakuCredentialModeCustom => 'カスタム';
	@override String get danmakuCredentialHint => 'ビルトイン認証情報を使用するには空のままにします';
	@override String get danmakuCredentialNotConfigured => '未設定';
	@override String get danmakuCredentialsSummary => 'App ID: {appId}\nAPI Key: {apiKey}';
	@override String get danmakuShield => '弾幕遮蔽';
	@override String get danmakuKeywordShield => 'キーワード遮蔽';
	@override String get danmakuShieldInputHint => 'キーワードまたは正規表現を入力';
	@override String get danmakuShieldDescription => '「/」で囲まれたテキストは正規表現として扱われます，例如「/\d+/」はすべての数字を遮蔽できます';
	@override String get danmakuShieldCount => '{count} 件のキーワードを追加しました';
	@override String get danmakuStyle => '弾幕スタイル';
	@override String get danmakuDisplay => '弾幕表示';
	@override String get danmakuArea => '弾幕表示領域';
	@override String get danmakuTopDisplay => '上部弾幕';
	@override String get danmakuBottomDisplay => '下部弾幕';
	@override String get danmakuScrollDisplay => 'スクロール弾幕';
	@override String get danmakuMassiveDisplay => '大規模弾幕';
	@override String get danmakuMassiveDescription => '画面に人がたくさんいる場合にオーバーレイでレンダリング';
	@override String get danmakuOutline => '弾幕アウトライン';
	@override String get danmakuColor => '弾幕色';
	@override String get danmakuFontSize => 'フォントサイズ';
	@override String get danmakuFontWeight => 'フォント太さ';
	@override String get danmakuOpacity => '弾幕透明度';
	@override String get add => '追加';
	@override String get save => '保存';
	@override String get restoreDefault => 'デフォルトに戻す';
	@override String get superResolutionTitle => '超解像度';
	@override String get superResolutionHint => 'デフォルトのアップスケーリングソリューションを選択';
	@override late final _TranslationsSettingsPlayerSuperResolutionOptionsJaJp superResolutionOptions = _TranslationsSettingsPlayerSuperResolutionOptionsJaJp._(_root);
	@override String get superResolutionDefaultBehavior => 'デフォルト動作';
	@override String get superResolutionClosePrompt => '閉じるプロンプト';
	@override String get superResolutionClosePromptDesc => '超解像度を有効にする際のプロンプト';
	@override late final _TranslationsSettingsPlayerToastJaJp toast = _TranslationsSettingsPlayerToastJaJp._(_root);
}

// Path: settings.webdav
class _TranslationsSettingsWebdavJaJp extends _TranslationsSettingsWebdavEnUs {
	_TranslationsSettingsWebdavJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'WebDAV';
	@override String get desc => '同期パラメータを設定';
	@override String get pageTitle => '同期設定';
	@override late final _TranslationsSettingsWebdavEditorJaJp editor = _TranslationsSettingsWebdavEditorJaJp._(_root);
	@override late final _TranslationsSettingsWebdavSectionJaJp section = _TranslationsSettingsWebdavSectionJaJp._(_root);
	@override late final _TranslationsSettingsWebdavTileJaJp tile = _TranslationsSettingsWebdavTileJaJp._(_root);
	@override late final _TranslationsSettingsWebdavInfoJaJp info = _TranslationsSettingsWebdavInfoJaJp._(_root);
	@override late final _TranslationsSettingsWebdavToastJaJp toast = _TranslationsSettingsWebdavToastJaJp._(_root);
	@override late final _TranslationsSettingsWebdavResultJaJp result = _TranslationsSettingsWebdavResultJaJp._(_root);
}

// Path: settings.update
class _TranslationsSettingsUpdateJaJp extends _TranslationsSettingsUpdateEnUs {
	_TranslationsSettingsUpdateJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get fallbackDescription => 'リリースノートは提供されていません。';
	@override late final _TranslationsSettingsUpdateErrorJaJp error = _TranslationsSettingsUpdateErrorJaJp._(_root);
	@override late final _TranslationsSettingsUpdateDialogJaJp dialog = _TranslationsSettingsUpdateDialogJaJp._(_root);
	@override late final _TranslationsSettingsUpdateInstallationTypeJaJp installationType = _TranslationsSettingsUpdateInstallationTypeJaJp._(_root);
	@override late final _TranslationsSettingsUpdateToastJaJp toast = _TranslationsSettingsUpdateToastJaJp._(_root);
	@override late final _TranslationsSettingsUpdateDownloadJaJp download = _TranslationsSettingsUpdateDownloadJaJp._(_root);
}

// Path: settings.other
class _TranslationsSettingsOtherJaJp extends _TranslationsSettingsOtherEnUs {
	_TranslationsSettingsOtherJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'その他';
	@override String get about => 'アプリについて';
}

// Path: settings.about
class _TranslationsSettingsAboutJaJp extends _TranslationsSettingsAboutEnUs {
	_TranslationsSettingsAboutJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'アプリについて';
	@override late final _TranslationsSettingsAboutSectionsJaJp sections = _TranslationsSettingsAboutSectionsJaJp._(_root);
	@override late final _TranslationsSettingsAboutLogsJaJp logs = _TranslationsSettingsAboutLogsJaJp._(_root);
}

// Path: navigation.tabs
class _TranslationsNavigationTabsJaJp extends _TranslationsNavigationTabsEnUs {
	_TranslationsNavigationTabsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get popular => '人気';
	@override String get catalog => 'カテゴリ';
	@override String get media => 'オンライン動画';
	@override String get resource => 'リソース';
	@override String get timeline => 'タイムライン';
	@override String get my => 'メディアライブラリ';
	@override String get download => 'ダウンロード';
	@override String get settings => '設定';
}

// Path: navigation.actions
class _TranslationsNavigationActionsJaJp extends _TranslationsNavigationActionsEnUs {
	_TranslationsNavigationActionsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get search => '検索';
	@override String get history => '履歴';
	@override String get close => '閉じる';
}

// Path: dialogs.disclaimer
class _TranslationsDialogsDisclaimerJaJp extends _TranslationsDialogsDisclaimerEnUs {
	_TranslationsDialogsDisclaimerJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '免責事項';
	@override String get agree => '読んで同意';
	@override String get exit => '終了';
}

// Path: dialogs.updateMirror
class _TranslationsDialogsUpdateMirrorJaJp extends _TranslationsDialogsUpdateMirrorEnUs {
	_TranslationsDialogsUpdateMirrorJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '更新ミラー';
	@override String get question => 'アプリの更新をどこから取得しますか？';
	@override String get description => 'GitHub ミラーはほとんどの場合に動作します。F-Droidアプリストアを使用している場合は、F-Droidミラーを選択してください。';
	@override late final _TranslationsDialogsUpdateMirrorOptionsJaJp options = _TranslationsDialogsUpdateMirrorOptionsJaJp._(_root);
}

// Path: dialogs.pluginUpdates
class _TranslationsDialogsPluginUpdatesJaJp extends _TranslationsDialogsPluginUpdatesEnUs {
	_TranslationsDialogsPluginUpdatesJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get toast => '{count} 個のルールが更新可能です';
}

// Path: dialogs.webdav
class _TranslationsDialogsWebdavJaJp extends _TranslationsDialogsWebdavEnUs {
	_TranslationsDialogsWebdavJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get syncFailed => '視聴履歴の同期に失敗しました {error}';
}

// Path: dialogs.about
class _TranslationsDialogsAboutJaJp extends _TranslationsDialogsAboutEnUs {
	_TranslationsDialogsAboutJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get licenseLegalese => 'オープンソースライセンス';
}

// Path: dialogs.cache
class _TranslationsDialogsCacheJaJp extends _TranslationsDialogsCacheEnUs {
	_TranslationsDialogsCacheJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'キャッシュ管理';
	@override String get message => 'キャッシュにはアニメのカバーが含まれており、クリアすると読み込み時に再ダウンロードが必要です。キャッシュをクリアしてもよろしいですか？';
}

// Path: library.common
class _TranslationsLibraryCommonJaJp extends _TranslationsLibraryCommonEnUs {
	_TranslationsLibraryCommonJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get emptyState => 'コンテンツが見つかりません';
	@override String get retry => 'タップして再試行';
	@override String get backHint => 'Haipeeを終了するにはバックボタンを再度押してください';
	@override late final _TranslationsLibraryCommonToastJaJp toast = _TranslationsLibraryCommonToastJaJp._(_root);
}

// Path: library.popular
class _TranslationsLibraryPopularJaJp extends _TranslationsLibraryPopularEnUs {
	_TranslationsLibraryPopularJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '人気';
	@override String get allTag => 'すべて';
	@override late final _TranslationsLibraryPopularToastJaJp toast = _TranslationsLibraryPopularToastJaJp._(_root);
}

// Path: library.timeline
class _TranslationsLibraryTimelineJaJp extends _TranslationsLibraryTimelineEnUs {
	_TranslationsLibraryTimelineJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsLibraryTimelineWeekdaysJaJp weekdays = _TranslationsLibraryTimelineWeekdaysJaJp._(_root);
	@override late final _TranslationsLibraryTimelineSeasonPickerJaJp seasonPicker = _TranslationsLibraryTimelineSeasonPickerJaJp._(_root);
	@override late final _TranslationsLibraryTimelineSeasonJaJp season = _TranslationsLibraryTimelineSeasonJaJp._(_root);
	@override late final _TranslationsLibraryTimelineSortJaJp sort = _TranslationsLibraryTimelineSortJaJp._(_root);
}

// Path: library.search
class _TranslationsLibrarySearchJaJp extends _TranslationsLibrarySearchEnUs {
	_TranslationsLibrarySearchJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsLibrarySearchSortJaJp sort = _TranslationsLibrarySearchSortJaJp._(_root);
	@override String get noHistory => '検索履歴はまだありません';
}

// Path: library.history
class _TranslationsLibraryHistoryJaJp extends _TranslationsLibraryHistoryEnUs {
	_TranslationsLibraryHistoryJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '視聴履歴';
	@override String get empty => '視聴履歴はまだありません';
	@override late final _TranslationsLibraryHistoryChipsJaJp chips = _TranslationsLibraryHistoryChipsJaJp._(_root);
	@override late final _TranslationsLibraryHistoryToastJaJp toast = _TranslationsLibraryHistoryToastJaJp._(_root);
	@override late final _TranslationsLibraryHistoryManageJaJp manage = _TranslationsLibraryHistoryManageJaJp._(_root);
}

// Path: library.info
class _TranslationsLibraryInfoJaJp extends _TranslationsLibraryInfoEnUs {
	_TranslationsLibraryInfoJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsLibraryInfoSummaryJaJp summary = _TranslationsLibraryInfoSummaryJaJp._(_root);
	@override late final _TranslationsLibraryInfoTagsJaJp tags = _TranslationsLibraryInfoTagsJaJp._(_root);
	@override late final _TranslationsLibraryInfoMetadataJaJp metadata = _TranslationsLibraryInfoMetadataJaJp._(_root);
	@override late final _TranslationsLibraryInfoEpisodesJaJp episodes = _TranslationsLibraryInfoEpisodesJaJp._(_root);
	@override late final _TranslationsLibraryInfoErrorsJaJp errors = _TranslationsLibraryInfoErrorsJaJp._(_root);
	@override late final _TranslationsLibraryInfoTabsJaJp tabs = _TranslationsLibraryInfoTabsJaJp._(_root);
	@override late final _TranslationsLibraryInfoActionsJaJp actions = _TranslationsLibraryInfoActionsJaJp._(_root);
	@override late final _TranslationsLibraryInfoToastJaJp toast = _TranslationsLibraryInfoToastJaJp._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetJaJp sourceSheet = _TranslationsLibraryInfoSourceSheetJaJp._(_root);
}

// Path: library.my
class _TranslationsLibraryMyJaJp extends _TranslationsLibraryMyEnUs {
	_TranslationsLibraryMyJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'マイ';
	@override late final _TranslationsLibraryMySectionsJaJp sections = _TranslationsLibraryMySectionsJaJp._(_root);
	@override late final _TranslationsLibraryMyFavoritesJaJp favorites = _TranslationsLibraryMyFavoritesJaJp._(_root);
	@override late final _TranslationsLibraryMyHistoryJaJp history = _TranslationsLibraryMyHistoryJaJp._(_root);
}

// Path: playback.toast
class _TranslationsPlaybackToastJaJp extends _TranslationsPlaybackToastEnUs {
	_TranslationsPlaybackToastJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get screenshotProcessing => 'スクリーンショットを撮影中…';
	@override String get screenshotSaved => 'スクリーンショットがギャラリーに保存されました';
	@override String get screenshotSaveFailed => 'スクリーンショットの保存に失敗しました：{error}';
	@override String get screenshotError => 'スクリーンショットに失敗しました：{error}';
	@override String get playlistEmpty => 'プレイリストが空です';
	@override String get episodeLatest => 'すでに最新のエピソードです';
	@override String get loadingEpisode => '{identifier} を読み込み中';
	@override String get danmakuUnsupported => 'このエピソードでは弾幕の送信は利用できません';
	@override String get danmakuEmpty => '弾幕の内容を空にすることはできません';
	@override String get danmakuTooLong => '弾幕の内容が長すぎます';
	@override String get waitForVideo => '動画の読み込みが完了するまでお待ちください';
	@override String get enableDanmakuFirst => 'まず弾幕を有効にしてください';
	@override String get danmakuSearchError => '弾幕の検索に失敗しました：{error}';
	@override String get danmakuSearchEmpty => '一致する結果が見つかりません';
	@override String get danmakuSwitching => '弾幕を切り替え中';
	@override String get clipboardCopied => 'クリップボードにコピーされました';
	@override String get internalError => 'プレイヤー内部エラー：{details}';
}

// Path: playback.danmaku
class _TranslationsPlaybackDanmakuJaJp extends _TranslationsPlaybackDanmakuEnUs {
	_TranslationsPlaybackDanmakuJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get inputHint => 'その瞬間の友好的な弾幕を共有';
	@override String get inputDisabled => '弾幕はオフになっています';
	@override String get send => '送信';
	@override String get mobileButton => 'タップして弾幕を送信';
	@override String get mobileButtonDisabled => '弾幕は無効です';
}

// Path: playback.externalPlayer
class _TranslationsPlaybackExternalPlayerJaJp extends _TranslationsPlaybackExternalPlayerEnUs {
	_TranslationsPlaybackExternalPlayerJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get launching => '外部プレイヤーを開こうとしています';
	@override String get launchFailed => '外部プレイヤーを開くことができません';
	@override String get unavailable => '外部プレイヤーは利用できません';
	@override String get unsupportedDevice => 'このデバイスにはまだ対応していません';
	@override String get unsupportedPlugin => 'このプラグインにはまだ対応していません';
}

// Path: playback.controls
class _TranslationsPlaybackControlsJaJp extends _TranslationsPlaybackControlsEnUs {
	_TranslationsPlaybackControlsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsPlaybackControlsSpeedJaJp speed = _TranslationsPlaybackControlsSpeedJaJp._(_root);
	@override late final _TranslationsPlaybackControlsSkipJaJp skip = _TranslationsPlaybackControlsSkipJaJp._(_root);
	@override late final _TranslationsPlaybackControlsStatusJaJp status = _TranslationsPlaybackControlsStatusJaJp._(_root);
	@override late final _TranslationsPlaybackControlsSuperResolutionJaJp superResolution = _TranslationsPlaybackControlsSuperResolutionJaJp._(_root);
	@override late final _TranslationsPlaybackControlsSpeedMenuJaJp speedMenu = _TranslationsPlaybackControlsSpeedMenuJaJp._(_root);
	@override late final _TranslationsPlaybackControlsAspectRatioJaJp aspectRatio = _TranslationsPlaybackControlsAspectRatioJaJp._(_root);
	@override late final _TranslationsPlaybackControlsTooltipsJaJp tooltips = _TranslationsPlaybackControlsTooltipsJaJp._(_root);
	@override late final _TranslationsPlaybackControlsMenuJaJp menu = _TranslationsPlaybackControlsMenuJaJp._(_root);
	@override late final _TranslationsPlaybackControlsSyncplayJaJp syncplay = _TranslationsPlaybackControlsSyncplayJaJp._(_root);
}

// Path: playback.loading
class _TranslationsPlaybackLoadingJaJp extends _TranslationsPlaybackLoadingEnUs {
	_TranslationsPlaybackLoadingJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get parsing => '動画ソースを解析中…';
	@override String get player => '動画ソースが解析されました、プレイヤーを読み込み中';
	@override String get danmakuSearch => '弾幕を検索中…';
	@override String get parseFailed => '動画ソースの解析に失敗しました';
}

// Path: playback.danmakuSearch
class _TranslationsPlaybackDanmakuSearchJaJp extends _TranslationsPlaybackDanmakuSearchEnUs {
	_TranslationsPlaybackDanmakuSearchJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '弾幕検索';
	@override String get hint => 'シリーズタイトル';
	@override String get submit => '送信';
}

// Path: playback.remote
class _TranslationsPlaybackRemoteJaJp extends _TranslationsPlaybackRemoteEnUs {
	_TranslationsPlaybackRemoteJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'リモートキャスト';
	@override late final _TranslationsPlaybackRemoteToastJaJp toast = _TranslationsPlaybackRemoteToastJaJp._(_root);
}

// Path: playback.debug
class _TranslationsPlaybackDebugJaJp extends _TranslationsPlaybackDebugEnUs {
	_TranslationsPlaybackDebugJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'デバッグ情報';
	@override String get closeTooltip => 'デバッグ情報を閉じる';
	@override late final _TranslationsPlaybackDebugTabsJaJp tabs = _TranslationsPlaybackDebugTabsJaJp._(_root);
	@override late final _TranslationsPlaybackDebugSectionsJaJp sections = _TranslationsPlaybackDebugSectionsJaJp._(_root);
	@override late final _TranslationsPlaybackDebugLabelsJaJp labels = _TranslationsPlaybackDebugLabelsJaJp._(_root);
	@override late final _TranslationsPlaybackDebugValuesJaJp values = _TranslationsPlaybackDebugValuesJaJp._(_root);
	@override late final _TranslationsPlaybackDebugLogsJaJp logs = _TranslationsPlaybackDebugLogsJaJp._(_root);
}

// Path: playback.syncplay
class _TranslationsPlaybackSyncplayJaJp extends _TranslationsPlaybackSyncplayEnUs {
	_TranslationsPlaybackSyncplayJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get invalidEndpoint => 'SyncPlay：無効なサーバーアドレス {endpoint}';
	@override String get disconnected => 'SyncPlay：接続が中断されました {reason}';
	@override String get actionReconnect => '再接続';
	@override String get alone => 'SyncPlay：この部屋の唯一のユーザーです';
	@override String get followUser => 'SyncPlay：{username} の進行状況を使用';
	@override String get userLeft => 'SyncPlay：{username} が部屋を出ました';
	@override String get userJoined => 'SyncPlay：{username} が部屋に入りました';
	@override String get switchEpisode => 'SyncPlay：{username} がエピソード {episode} に切り替えました';
	@override String get chat => 'SyncPlay：{username} が言いました：{message}';
	@override String get paused => 'SyncPlay：{username} が再生を一時停止しました';
	@override String get resumed => 'SyncPlay：{username} が再生を再開しました';
	@override String get unknownUser => '不明';
	@override String get switchServerBlocked => 'SyncPlay：サーバーを切り替える前に現在の部屋を出てください';
	@override String get defaultCustomEndpoint => 'カスタムサーバー';
	@override late final _TranslationsPlaybackSyncplaySelectServerJaJp selectServer = _TranslationsPlaybackSyncplaySelectServerJaJp._(_root);
	@override late final _TranslationsPlaybackSyncplayJoinJaJp join = _TranslationsPlaybackSyncplayJoinJaJp._(_root);
}

// Path: playback.playlist
class _TranslationsPlaybackPlaylistJaJp extends _TranslationsPlaybackPlaylistEnUs {
	_TranslationsPlaybackPlaylistJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get collection => 'コレクション';
	@override String get list => 'プレイリスト {index}';
}

// Path: playback.tabs
class _TranslationsPlaybackTabsJaJp extends _TranslationsPlaybackTabsEnUs {
	_TranslationsPlaybackTabsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get episodes => 'エピソード';
	@override String get comments => 'コメント';
}

// Path: playback.comments
class _TranslationsPlaybackCommentsJaJp extends _TranslationsPlaybackCommentsEnUs {
	_TranslationsPlaybackCommentsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get sectionTitle => 'エピソードタイトル';
	@override String get manualSwitch => '手動で切り替え';
	@override String get dialogTitle => 'エピソード番号を入力';
	@override String get dialogEmpty => 'エピソード番号を入力してください';
	@override String get dialogConfirm => '更新';
}

// Path: playback.superResolution
class _TranslationsPlaybackSuperResolutionJaJp extends _TranslationsPlaybackSuperResolutionEnUs {
	_TranslationsPlaybackSuperResolutionJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsPlaybackSuperResolutionWarningJaJp warning = _TranslationsPlaybackSuperResolutionWarningJaJp._(_root);
}

// Path: network.error
class _TranslationsNetworkErrorJaJp extends _TranslationsNetworkErrorEnUs {
	_TranslationsNetworkErrorJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get badCertificate => '証明書エラー。';
	@override String get badResponse => 'サーバーエラー、後でもう一度お試しください。';
	@override String get cancel => 'リクエストがキャンセルされました、再試行してください。';
	@override String get connection => '接続エラー、ネットワーク設定を確認してください。';
	@override String get connectionTimeout => '接続タイムアウト、ネットワーク設定を確認してください。';
	@override String get receiveTimeout => '応答タイムアウト、後でもう一度お試しください。';
	@override String get sendTimeout => 'リクエストタイムアウト、ネットワーク設定を確認してください。';
	@override String get unknown => '{status} ネットワーク問題。';
}

// Path: network.status
class _TranslationsNetworkStatusJaJp extends _TranslationsNetworkStatusEnUs {
	_TranslationsNetworkStatusJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get mobile => 'cellular data を使用中';
	@override String get wifi => 'Wi‑Fi を使用中';
	@override String get ethernet => 'Ethernet を使用中';
	@override String get vpn => 'VPN接続を使用中';
	@override String get other => '他のネットワークを使用中';
	@override String get none => 'ネットワーク接続なし';
}

// Path: settings.appearancePage.mode
class _TranslationsSettingsAppearancePageModeJaJp extends _TranslationsSettingsAppearancePageModeEnUs {
	_TranslationsSettingsAppearancePageModeJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'テーマモード';
	@override String get system => 'システム';
	@override String get light => 'ライト';
	@override String get dark => 'ダーク';
}

// Path: settings.appearancePage.colorScheme
class _TranslationsSettingsAppearancePageColorSchemeJaJp extends _TranslationsSettingsAppearancePageColorSchemeEnUs {
	_TranslationsSettingsAppearancePageColorSchemeJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'アクセントカラー';
	@override String get dialogTitle => 'アクセントカラーを選択';
	@override String get dynamicColor => '動的色を使用';
	@override String get dynamicColorInfo => 'サポートされている場合、wallpaperからパレットを生成（Android 12+/Windows 11）。';
	@override late final _TranslationsSettingsAppearancePageColorSchemeLabelsJaJp labels = _TranslationsSettingsAppearancePageColorSchemeLabelsJaJp._(_root);
}

// Path: settings.appearancePage.oled
class _TranslationsSettingsAppearancePageOledJaJp extends _TranslationsSettingsAppearancePageOledEnUs {
	_TranslationsSettingsAppearancePageOledJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'OLEDコントラスト';
	@override String get description => 'OLEDディスプレイに最適化されたより深い黒を使用。';
}

// Path: settings.appearancePage.window
class _TranslationsSettingsAppearancePageWindowJaJp extends _TranslationsSettingsAppearancePageWindowEnUs {
	_TranslationsSettingsAppearancePageWindowJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'ウィンドウボタン';
	@override String get description => 'タイトルバーにウィンドウ制御ボタンを表示。';
}

// Path: settings.appearancePage.refreshRate
class _TranslationsSettingsAppearancePageRefreshRateJaJp extends _TranslationsSettingsAppearancePageRefreshRateEnUs {
	_TranslationsSettingsAppearancePageRefreshRateJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'リフレッシュレート';
}

// Path: settings.plugins.tooltip
class _TranslationsSettingsPluginsTooltipJaJp extends _TranslationsSettingsPluginsTooltipEnUs {
	_TranslationsSettingsPluginsTooltipJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get updateAll => 'すべて更新';
	@override String get addRule => 'ルールを追加';
}

// Path: settings.plugins.sort
class _TranslationsSettingsPluginsSortJaJp extends _TranslationsSettingsPluginsSortEnUs {
	_TranslationsSettingsPluginsSortJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '並び替え';
	@override String get tooltip => '並び替え';
	@override late final _TranslationsSettingsPluginsSortOptionsJaJp options = _TranslationsSettingsPluginsSortOptionsJaJp._(_root);
}

// Path: settings.plugins.multiSelect
class _TranslationsSettingsPluginsMultiSelectJaJp extends _TranslationsSettingsPluginsMultiSelectEnUs {
	_TranslationsSettingsPluginsMultiSelectJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get selectedCount => '{count} 選択中';
}

// Path: settings.plugins.loading
class _TranslationsSettingsPluginsLoadingJaJp extends _TranslationsSettingsPluginsLoadingEnUs {
	_TranslationsSettingsPluginsLoadingJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get updating => 'ルールを更新しています…';
	@override String get updatingSingle => '更新中…';
	@override String get importing => 'インポート中…';
}

// Path: settings.plugins.labels
class _TranslationsSettingsPluginsLabelsJaJp extends _TranslationsSettingsPluginsLabelsEnUs {
	_TranslationsSettingsPluginsLabelsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get version => 'バージョン: {version}';
	@override String get statusUpdatable => '更新可能';
	@override String get statusSearchValid => '検索が有効';
}

// Path: settings.plugins.actions
class _TranslationsSettingsPluginsActionsJaJp extends _TranslationsSettingsPluginsActionsEnUs {
	_TranslationsSettingsPluginsActionsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get newRule => 'ルールを作成';
	@override String get importFromRepo => 'リポジトリからインポート';
	@override String get importFromClipboard => 'クリップボードからインポート';
	@override String get cancel => 'キャンセル';
	@override String get import => 'インポート';
	@override String get update => '更新';
	@override String get edit => '編集';
	@override String get copyToClipboard => 'クリップボードにコピー';
	@override String get share => '共有';
	@override String get delete => '削除';
}

// Path: settings.plugins.dialogs
class _TranslationsSettingsPluginsDialogsJaJp extends _TranslationsSettingsPluginsDialogsEnUs {
	_TranslationsSettingsPluginsDialogsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get deleteTitle => 'ルールを削除';
	@override String get deleteMessage => '選択した {count} 件のルールを削除しますか？';
	@override String get importTitle => 'ルールをインポート';
	@override String get shareTitle => 'ルールリンク';
}

// Path: settings.plugins.toast
class _TranslationsSettingsPluginsToastJaJp extends _TranslationsSettingsPluginsToastEnUs {
	_TranslationsSettingsPluginsToastJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get allUpToDate => 'すべてのルールは最新です。';
	@override String get updateCount => '{count} 件のルールを更新しました。';
	@override String get importSuccess => 'インポートが成功しました。';
	@override String get importFailed => 'インポートに失敗しました: {error}';
	@override String get repoMissing => 'リポジトリにこのルールは含まれていません。';
	@override String get alreadyLatest => 'ルールは既に最新です。';
	@override String get updateSuccess => '更新に成功しました。';
	@override String get updateIncompatible => 'Haipee のバージョンが古いため、このルールは互換性がありません。';
	@override String get updateFailed => 'ルールの更新に失敗しました。';
	@override String get copySuccess => 'クリップボードにコピーしました。';
}

// Path: settings.plugins.editor
class _TranslationsSettingsPluginsEditorJaJp extends _TranslationsSettingsPluginsEditorEnUs {
	_TranslationsSettingsPluginsEditorJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'ルールを編集';
	@override late final _TranslationsSettingsPluginsEditorFieldsJaJp fields = _TranslationsSettingsPluginsEditorFieldsJaJp._(_root);
	@override late final _TranslationsSettingsPluginsEditorAdvancedJaJp advanced = _TranslationsSettingsPluginsEditorAdvancedJaJp._(_root);
}

// Path: settings.plugins.shop
class _TranslationsSettingsPluginsShopJaJp extends _TranslationsSettingsPluginsShopEnUs {
	_TranslationsSettingsPluginsShopJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'ルールリポジトリ';
	@override late final _TranslationsSettingsPluginsShopTooltipJaJp tooltip = _TranslationsSettingsPluginsShopTooltipJaJp._(_root);
	@override late final _TranslationsSettingsPluginsShopLabelsJaJp labels = _TranslationsSettingsPluginsShopLabelsJaJp._(_root);
	@override late final _TranslationsSettingsPluginsShopButtonsJaJp buttons = _TranslationsSettingsPluginsShopButtonsJaJp._(_root);
	@override late final _TranslationsSettingsPluginsShopToastJaJp toast = _TranslationsSettingsPluginsShopToastJaJp._(_root);
	@override late final _TranslationsSettingsPluginsShopErrorJaJp error = _TranslationsSettingsPluginsShopErrorJaJp._(_root);
}

// Path: settings.player.aspectRatio
class _TranslationsSettingsPlayerAspectRatioJaJp extends _TranslationsSettingsPlayerAspectRatioEnUs {
	_TranslationsSettingsPlayerAspectRatioJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get auto => '自動';
	@override String get crop => 'クロップして填充';
	@override String get stretch => '拉伸して填充';
}

// Path: settings.player.danmakuSources
class _TranslationsSettingsPlayerDanmakuSourcesJaJp extends _TranslationsSettingsPlayerDanmakuSourcesEnUs {
	_TranslationsSettingsPlayerDanmakuSourcesJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get bilibili => 'Bilibili';
	@override String get gamer => 'Gamer';
	@override String get dandan => 'DanDan';
}

// Path: settings.player.superResolutionOptions
class _TranslationsSettingsPlayerSuperResolutionOptionsJaJp extends _TranslationsSettingsPlayerSuperResolutionOptionsEnUs {
	_TranslationsSettingsPlayerSuperResolutionOptionsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsSettingsPlayerSuperResolutionOptionsOffJaJp off = _TranslationsSettingsPlayerSuperResolutionOptionsOffJaJp._(_root);
	@override late final _TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyJaJp efficiency = _TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyJaJp._(_root);
	@override late final _TranslationsSettingsPlayerSuperResolutionOptionsQualityJaJp quality = _TranslationsSettingsPlayerSuperResolutionOptionsQualityJaJp._(_root);
}

// Path: settings.player.toast
class _TranslationsSettingsPlayerToastJaJp extends _TranslationsSettingsPlayerToastEnUs {
	_TranslationsSettingsPlayerToastJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get danmakuKeywordEmpty => 'キーワードを入力してください。';
	@override String get danmakuKeywordTooLong => 'キーワードが長すぎます。';
	@override String get danmakuKeywordExists => 'キーワードは既に存在しています。';
	@override String get danmakuCredentialsRestored => 'ビルトイン認証情報に復元されました。';
	@override String get danmakuCredentialsUpdated => '認証情報が更新されました。';
}

// Path: settings.webdav.editor
class _TranslationsSettingsWebdavEditorJaJp extends _TranslationsSettingsWebdavEditorEnUs {
	_TranslationsSettingsWebdavEditorJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'WebDAV設定';
	@override String get url => 'URL';
	@override String get username => 'ユーザー名';
	@override String get password => 'パスワード';
	@override late final _TranslationsSettingsWebdavEditorToastJaJp toast = _TranslationsSettingsWebdavEditorToastJaJp._(_root);
}

// Path: settings.webdav.section
class _TranslationsSettingsWebdavSectionJaJp extends _TranslationsSettingsWebdavSectionEnUs {
	_TranslationsSettingsWebdavSectionJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get webdav => 'WebDAV';
}

// Path: settings.webdav.tile
class _TranslationsSettingsWebdavTileJaJp extends _TranslationsSettingsWebdavTileEnUs {
	_TranslationsSettingsWebdavTileJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get webdavToggle => 'WebDAV同期';
	@override String get historyToggle => '視聴履歴同期';
	@override String get historyDescription => '視聴履歴の自動同期を許可';
	@override String get config => 'WebDAV設定';
	@override String get manualUpload => '手動アップロード';
	@override String get manualDownload => '手動ダウンロード';
}

// Path: settings.webdav.info
class _TranslationsSettingsWebdavInfoJaJp extends _TranslationsSettingsWebdavInfoEnUs {
	_TranslationsSettingsWebdavInfoJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get upload => '視聴履歴をWebDAVに今すぐアップロードします。';
	@override String get download => '視聴履歴をこのデバイスに今すぐ同期します。';
}

// Path: settings.webdav.toast
class _TranslationsSettingsWebdavToastJaJp extends _TranslationsSettingsWebdavToastEnUs {
	_TranslationsSettingsWebdavToastJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get uploading => 'WebDAVにアップロードを試みています…';
	@override String get downloading => 'WebDAVから同期を試みています…';
	@override String get notConfigured => 'WebDAV同期は無効または設定が無効です。';
	@override String get connectionFailed => 'WebDAVへの接続に失敗しました: {error}';
	@override String get syncFailed => 'WebDAV同期に失敗しました: {error}';
}

// Path: settings.webdav.result
class _TranslationsSettingsWebdavResultJaJp extends _TranslationsSettingsWebdavResultEnUs {
	_TranslationsSettingsWebdavResultJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get initFailed => 'WebDAVの初期化に失敗しました: {error}';
	@override String get requireEnable => 'まずWebDAV同期を有効にしてください。';
	@override String get disabled => 'WebDAV同期は無効または設定が無効です。';
	@override String get connectionFailed => 'WebDAVへの接続に失敗しました。';
	@override String get syncSuccess => '同期が成功しました。';
	@override String get syncFailed => '同期に失敗しました: {error}';
}

// Path: settings.update.error
class _TranslationsSettingsUpdateErrorJaJp extends _TranslationsSettingsUpdateErrorEnUs {
	_TranslationsSettingsUpdateErrorJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get invalidResponse => '無効な更新レスポンス。';
}

// Path: settings.update.dialog
class _TranslationsSettingsUpdateDialogJaJp extends _TranslationsSettingsUpdateDialogEnUs {
	_TranslationsSettingsUpdateDialogJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '新しいバージョン {version} が利用可能です';
	@override String get publishedAt => 'Released on {date}';
	@override String get installationTypeLabel => 'インストールパッケージを選択';
	@override late final _TranslationsSettingsUpdateDialogActionsJaJp actions = _TranslationsSettingsUpdateDialogActionsJaJp._(_root);
}

// Path: settings.update.installationType
class _TranslationsSettingsUpdateInstallationTypeJaJp extends _TranslationsSettingsUpdateInstallationTypeEnUs {
	_TranslationsSettingsUpdateInstallationTypeJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get windowsMsix => 'Windows インストーラー（MSIX）';
	@override String get windowsPortable => 'Windows ポータブル（ZIP）';
	@override String get linuxDeb => 'Linux パッケージ（DEB）';
	@override String get linuxTar => 'Linux アーカイブ（TAR.GZ）';
	@override String get macosDmg => 'macOS インストーラー（DMG）';
	@override String get androidApk => 'Android パッケージ（APK）';
	@override String get ios => 'iOS アプリ（GitHubを開く）';
	@override String get unknown => 'その他のプラットフォーム';
}

// Path: settings.update.toast
class _TranslationsSettingsUpdateToastJaJp extends _TranslationsSettingsUpdateToastEnUs {
	_TranslationsSettingsUpdateToastJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get alreadyLatest => '最新です。';
	@override String get checkFailed => '更新の確認に失敗しました。後でもう一度お試しください。';
	@override String get autoUpdateDisabled => '自動更新が無効化されました。';
	@override String get downloadLinkMissing => '{type} のダウンロードは利用できません。';
	@override String get downloadFailed => 'ダウンロードに失敗しました: {error}';
	@override String get noCompatibleLink => '互換性のあるダウンロードリンクが見つかりませんでした。';
	@override String get prepareToInstall => '更新のインストールを準備しています。アプリが終了します…';
	@override String get openInstallerFailed => 'インストーラーを開くことができませんでした: {error}';
	@override String get launchInstallerFailed => 'インストーラーを起動できませんでした: {error}';
	@override String get revealFailed => 'ファイルマネージャーを開くことができませんでした。';
	@override String get unknownReason => '不明な理由';
}

// Path: settings.update.download
class _TranslationsSettingsUpdateDownloadJaJp extends _TranslationsSettingsUpdateDownloadEnUs {
	_TranslationsSettingsUpdateDownloadJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get progressTitle => '更新をダウンロード中';
	@override String get cancel => 'キャンセル';
	@override late final _TranslationsSettingsUpdateDownloadErrorJaJp error = _TranslationsSettingsUpdateDownloadErrorJaJp._(_root);
	@override late final _TranslationsSettingsUpdateDownloadCompleteJaJp complete = _TranslationsSettingsUpdateDownloadCompleteJaJp._(_root);
}

// Path: settings.about.sections
class _TranslationsSettingsAboutSectionsJaJp extends _TranslationsSettingsAboutSectionsEnUs {
	_TranslationsSettingsAboutSectionsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsSettingsAboutSectionsLicensesJaJp licenses = _TranslationsSettingsAboutSectionsLicensesJaJp._(_root);
	@override late final _TranslationsSettingsAboutSectionsLinksJaJp links = _TranslationsSettingsAboutSectionsLinksJaJp._(_root);
	@override late final _TranslationsSettingsAboutSectionsCacheJaJp cache = _TranslationsSettingsAboutSectionsCacheJaJp._(_root);
	@override late final _TranslationsSettingsAboutSectionsUpdatesJaJp updates = _TranslationsSettingsAboutSectionsUpdatesJaJp._(_root);
}

// Path: settings.about.logs
class _TranslationsSettingsAboutLogsJaJp extends _TranslationsSettingsAboutLogsEnUs {
	_TranslationsSettingsAboutLogsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'アプリログ';
	@override String get empty => '利用可能なログエントリはありません。';
	@override late final _TranslationsSettingsAboutLogsToastJaJp toast = _TranslationsSettingsAboutLogsToastJaJp._(_root);
}

// Path: dialogs.updateMirror.options
class _TranslationsDialogsUpdateMirrorOptionsJaJp extends _TranslationsDialogsUpdateMirrorOptionsEnUs {
	_TranslationsDialogsUpdateMirrorOptionsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get github => 'GitHub';
	@override String get fdroid => 'F-Droid';
}

// Path: library.common.toast
class _TranslationsLibraryCommonToastJaJp extends _TranslationsLibraryCommonToastEnUs {
	_TranslationsLibraryCommonToastJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get editMode => '編集モードが有効になりました。';
}

// Path: library.popular.toast
class _TranslationsLibraryPopularToastJaJp extends _TranslationsLibraryPopularToastEnUs {
	_TranslationsLibraryPopularToastJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get backPress => 'Haipeeを終了するにはバックボタンを再度押してください';
}

// Path: library.timeline.weekdays
class _TranslationsLibraryTimelineWeekdaysJaJp extends _TranslationsLibraryTimelineWeekdaysEnUs {
	_TranslationsLibraryTimelineWeekdaysJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get mon => '月';
	@override String get tue => '火';
	@override String get wed => '水';
	@override String get thu => '木';
	@override String get fri => '金';
	@override String get sat => '土';
	@override String get sun => '日';
}

// Path: library.timeline.seasonPicker
class _TranslationsLibraryTimelineSeasonPickerJaJp extends _TranslationsLibraryTimelineSeasonPickerEnUs {
	_TranslationsLibraryTimelineSeasonPickerJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'タイムマシン';
	@override String get yearLabel => '{year}';
}

// Path: library.timeline.season
class _TranslationsLibraryTimelineSeasonJaJp extends _TranslationsLibraryTimelineSeasonEnUs {
	_TranslationsLibraryTimelineSeasonJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '{season} {year}';
	@override String get loading => '読み込み中…';
	@override late final _TranslationsLibraryTimelineSeasonNamesJaJp names = _TranslationsLibraryTimelineSeasonNamesJaJp._(_root);
	@override late final _TranslationsLibraryTimelineSeasonShortJaJp short = _TranslationsLibraryTimelineSeasonShortJaJp._(_root);
}

// Path: library.timeline.sort
class _TranslationsLibraryTimelineSortJaJp extends _TranslationsLibraryTimelineSortEnUs {
	_TranslationsLibraryTimelineSortJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '並び替え';
	@override String get byHeat => '人気順';
	@override String get byRating => '評価順';
	@override String get byTime => '放送日時順';
}

// Path: library.search.sort
class _TranslationsLibrarySearchSortJaJp extends _TranslationsLibrarySearchSortEnUs {
	_TranslationsLibrarySearchSortJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get label => '検索並び替え';
	@override String get byHeat => '人気順';
	@override String get byRating => '評価順';
	@override String get byRelevance => '関連度順';
}

// Path: library.history.chips
class _TranslationsLibraryHistoryChipsJaJp extends _TranslationsLibraryHistoryChipsEnUs {
	_TranslationsLibraryHistoryChipsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get source => 'ソース';
	@override String get progress => '進捗';
	@override String get episodeNumber => 'エピソード {number}';
}

// Path: library.history.toast
class _TranslationsLibraryHistoryToastJaJp extends _TranslationsLibraryHistoryToastEnUs {
	_TranslationsLibraryHistoryToastJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get sourceMissing => '関連ソースが見つかりません。';
}

// Path: library.history.manage
class _TranslationsLibraryHistoryManageJaJp extends _TranslationsLibraryHistoryManageEnUs {
	_TranslationsLibraryHistoryManageJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '履歴管理';
	@override String get confirmClear => 'すべての視聴履歴をクリアしますか？';
	@override String get cancel => 'キャンセル';
	@override String get confirm => '確認';
}

// Path: library.info.summary
class _TranslationsLibraryInfoSummaryJaJp extends _TranslationsLibraryInfoSummaryEnUs {
	_TranslationsLibraryInfoSummaryJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'あらすじ';
	@override String get expand => 'すべて表示';
	@override String get collapse => '折りたたむ';
}

// Path: library.info.tags
class _TranslationsLibraryInfoTagsJaJp extends _TranslationsLibraryInfoTagsEnUs {
	_TranslationsLibraryInfoTagsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'タグ';
	@override String get more => 'もっと +';
}

// Path: library.info.metadata
class _TranslationsLibraryInfoMetadataJaJp extends _TranslationsLibraryInfoMetadataEnUs {
	_TranslationsLibraryInfoMetadataJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get refresh => '更新';
	@override String get syncingTitle => 'メタデータを同期中…';
	@override String get syncingSubtitle => '最初の同期には数秒かかる場合があります。';
	@override String get emptyTitle => '公式メタデータはまだありません';
	@override String get emptySubtitle => 'しばらくしてから再試行するか、メタデータ設定を確認してください。';
	@override String source({required Object source}) => 'メタデータソース：${source}';
	@override String updated({required Object timestamp, required Object language}) => '最終更新：${timestamp} · 言語：${language}';
	@override String get languageSystem => 'システムデフォルト';
	@override String get multiSource => '統合ソース';
}

// Path: library.info.episodes
class _TranslationsLibraryInfoEpisodesJaJp extends _TranslationsLibraryInfoEpisodesEnUs {
	_TranslationsLibraryInfoEpisodesJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'エピソード';
	@override String get collapse => '折りたたむ';
	@override String expand({required Object count}) => 'すべて表示（${count}）';
	@override String numberedEpisode({required Object number}) => 'エピソード ${number}';
	@override String get dateUnknown => '放送日未定';
	@override String get runtimeUnknown => 'Runtime unknown';
	@override String runtimeMinutes({required Object minutes}) => '${minutes} 分';
}

// Path: library.info.errors
class _TranslationsLibraryInfoErrorsJaJp extends _TranslationsLibraryInfoErrorsEnUs {
	_TranslationsLibraryInfoErrorsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get fetchFailed => '読み込みに失敗しました。再試行してください。';
}

// Path: library.info.tabs
class _TranslationsLibraryInfoTabsJaJp extends _TranslationsLibraryInfoTabsEnUs {
	_TranslationsLibraryInfoTabsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get overview => '概要';
	@override String get comments => 'コメント';
	@override String get characters => 'キャラクター';
	@override String get reviews => 'レビュー';
	@override String get staff => 'スタッフ';
	@override String get placeholder => '近日公開';
}

// Path: library.info.actions
class _TranslationsLibraryInfoActionsJaJp extends _TranslationsLibraryInfoActionsEnUs {
	_TranslationsLibraryInfoActionsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get startWatching => '視聴開始';
}

// Path: library.info.toast
class _TranslationsLibraryInfoToastJaJp extends _TranslationsLibraryInfoToastEnUs {
	_TranslationsLibraryInfoToastJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get characterSortFailed => 'キャラクターのソートに失敗しました：{details}';
}

// Path: library.info.sourceSheet
class _TranslationsLibraryInfoSourceSheetJaJp extends _TranslationsLibraryInfoSourceSheetEnUs {
	_TranslationsLibraryInfoSourceSheetJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '再生ソースを選択（{name}）';
	@override late final _TranslationsLibraryInfoSourceSheetAliasJaJp alias = _TranslationsLibraryInfoSourceSheetAliasJaJp._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetToastJaJp toast = _TranslationsLibraryInfoSourceSheetToastJaJp._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetSortJaJp sort = _TranslationsLibraryInfoSourceSheetSortJaJp._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetCardJaJp card = _TranslationsLibraryInfoSourceSheetCardJaJp._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetActionsJaJp actions = _TranslationsLibraryInfoSourceSheetActionsJaJp._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetStatusJaJp status = _TranslationsLibraryInfoSourceSheetStatusJaJp._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetEmptyJaJp empty = _TranslationsLibraryInfoSourceSheetEmptyJaJp._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetDialogJaJp dialog = _TranslationsLibraryInfoSourceSheetDialogJaJp._(_root);
}

// Path: library.my.sections
class _TranslationsLibraryMySectionsJaJp extends _TranslationsLibraryMySectionsEnUs {
	_TranslationsLibraryMySectionsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get video => '動画';
}

// Path: library.my.favorites
class _TranslationsLibraryMyFavoritesJaJp extends _TranslationsLibraryMyFavoritesEnUs {
	_TranslationsLibraryMyFavoritesJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'お気に入り';
	@override String get description => '視聴中、予定視聴、完了したリストを表示';
	@override String get empty => 'お気に入りはまだありません。';
	@override late final _TranslationsLibraryMyFavoritesTabsJaJp tabs = _TranslationsLibraryMyFavoritesTabsJaJp._(_root);
	@override late final _TranslationsLibraryMyFavoritesSyncJaJp sync = _TranslationsLibraryMyFavoritesSyncJaJp._(_root);
}

// Path: library.my.history
class _TranslationsLibraryMyHistoryJaJp extends _TranslationsLibraryMyHistoryEnUs {
	_TranslationsLibraryMyHistoryJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '再生履歴';
	@override String get description => '視聴した番組を表示';
}

// Path: playback.controls.speed
class _TranslationsPlaybackControlsSpeedJaJp extends _TranslationsPlaybackControlsSpeedEnUs {
	_TranslationsPlaybackControlsSpeedJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '再生速度';
	@override String get reset => 'デフォルト速度';
}

// Path: playback.controls.skip
class _TranslationsPlaybackControlsSkipJaJp extends _TranslationsPlaybackControlsSkipEnUs {
	_TranslationsPlaybackControlsSkipJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'スキップ時間';
	@override String get tooltip => '長押しして時間を変更';
}

// Path: playback.controls.status
class _TranslationsPlaybackControlsStatusJaJp extends _TranslationsPlaybackControlsStatusEnUs {
	_TranslationsPlaybackControlsStatusJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get fastForward => '{seconds} 秒早送り';
	@override String get rewind => '{seconds} 秒巻き戻し';
	@override String get speed => '速度再生';
}

// Path: playback.controls.superResolution
class _TranslationsPlaybackControlsSuperResolutionJaJp extends _TranslationsPlaybackControlsSuperResolutionEnUs {
	_TranslationsPlaybackControlsSuperResolutionJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get label => '超解像度';
	@override String get off => 'オフ';
	@override String get balanced => 'バランス';
	@override String get quality => '品質';
}

// Path: playback.controls.speedMenu
class _TranslationsPlaybackControlsSpeedMenuJaJp extends _TranslationsPlaybackControlsSpeedMenuEnUs {
	_TranslationsPlaybackControlsSpeedMenuJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get label => '速度';
}

// Path: playback.controls.aspectRatio
class _TranslationsPlaybackControlsAspectRatioJaJp extends _TranslationsPlaybackControlsAspectRatioEnUs {
	_TranslationsPlaybackControlsAspectRatioJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get label => 'アスペクト比';
	@override late final _TranslationsPlaybackControlsAspectRatioOptionsJaJp options = _TranslationsPlaybackControlsAspectRatioOptionsJaJp._(_root);
}

// Path: playback.controls.tooltips
class _TranslationsPlaybackControlsTooltipsJaJp extends _TranslationsPlaybackControlsTooltipsEnUs {
	_TranslationsPlaybackControlsTooltipsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get danmakuOn => '弾幕をオフにする（d）';
	@override String get danmakuOff => '弾幕をオンにする（d）';
}

// Path: playback.controls.menu
class _TranslationsPlaybackControlsMenuJaJp extends _TranslationsPlaybackControlsMenuEnUs {
	_TranslationsPlaybackControlsMenuJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get danmakuToggle => '弾幕スイッチ';
	@override String get videoInfo => '動画情報';
	@override String get cast => 'リモートキャスト';
	@override String get external => '外部プレイヤーで開く';
}

// Path: playback.controls.syncplay
class _TranslationsPlaybackControlsSyncplayJaJp extends _TranslationsPlaybackControlsSyncplayEnUs {
	_TranslationsPlaybackControlsSyncplayJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get label => 'SyncPlay';
	@override String get room => '現在の部屋：{name}';
	@override String get roomEmpty => '参加していません';
	@override String get latency => 'レイテンシ：{ms} ms';
	@override String get join => '部屋に参加';
	@override String get switchServer => 'サーバーを切り替え';
	@override String get disconnect => '切断';
}

// Path: playback.remote.toast
class _TranslationsPlaybackRemoteToastJaJp extends _TranslationsPlaybackRemoteToastEnUs {
	_TranslationsPlaybackRemoteToastJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get searching => '検索中…';
	@override String get casting => '{device} にキャストしようとています';
	@override String get error => 'DLNAエラー：{details}\nDLNAパネルを再開くか、別のデバイスを選んでください。';
}

// Path: playback.debug.tabs
class _TranslationsPlaybackDebugTabsJaJp extends _TranslationsPlaybackDebugTabsEnUs {
	_TranslationsPlaybackDebugTabsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get status => 'ステータス';
	@override String get logs => 'ログ';
}

// Path: playback.debug.sections
class _TranslationsPlaybackDebugSectionsJaJp extends _TranslationsPlaybackDebugSectionsEnUs {
	_TranslationsPlaybackDebugSectionsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get source => '再生ソース';
	@override String get playback => 'プレイヤーステータス';
	@override String get timing => 'タイミングとメトリクス';
	@override String get media => 'メディアトラック';
}

// Path: playback.debug.labels
class _TranslationsPlaybackDebugLabelsJaJp extends _TranslationsPlaybackDebugLabelsEnUs {
	_TranslationsPlaybackDebugLabelsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get series => 'シリーズ';
	@override String get plugin => 'プラグイン';
	@override String get route => 'ルート';
	@override String get episode => 'エピソード';
	@override String get routeCount => 'ルート数';
	@override String get sourceTitle => 'ソースタイトル';
	@override String get parsedUrl => '解析されたURL';
	@override String get playUrl => '再生URL';
	@override String get danmakuId => 'DanDan ID';
	@override String get syncRoom => 'SyncPlay部屋';
	@override String get syncLatency => 'SyncPlay RTT';
	@override String get nativePlayer => 'ネイティブプレイヤー';
	@override String get parsing => '解析中';
	@override String get playerLoading => 'プレイヤー読み込み中';
	@override String get playerInitializing => 'プレイヤー初期化中';
	@override String get playing => '再生中';
	@override String get buffering => 'バッファリング中';
	@override String get completed => '再生完了';
	@override String get bufferFlag => 'バッファフラグ';
	@override String get currentPosition => '現在位置';
	@override String get bufferProgress => 'バッファ進捗';
	@override String get duration => '継続時間';
	@override String get speed => '再生速度';
	@override String get volume => '音量';
	@override String get brightness => '輝度';
	@override String get resolution => '解像度';
	@override String get aspectRatio => 'アスペクト比';
	@override String get superResolution => '超解像度';
	@override String get videoParams => '動画パラメータ';
	@override String get audioParams => '音声パラメータ';
	@override String get playlist => 'プレイリスト';
	@override String get audioTracks => 'オーディオトラック';
	@override String get videoTracks => 'ビデオトラック';
	@override String get audioBitrate => 'オーディオビットレート';
}

// Path: playback.debug.values
class _TranslationsPlaybackDebugValuesJaJp extends _TranslationsPlaybackDebugValuesEnUs {
	_TranslationsPlaybackDebugValuesJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get yes => 'はい';
	@override String get no => 'いいえ';
}

// Path: playback.debug.logs
class _TranslationsPlaybackDebugLogsJaJp extends _TranslationsPlaybackDebugLogsEnUs {
	_TranslationsPlaybackDebugLogsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get playerEmpty => 'プレイヤーログ（0）';
	@override String get playerSummary => 'プレイヤーログ（{count} 項目、{displayed} を表示）';
	@override String get webviewEmpty => 'WebView ログ（0）';
	@override String get webviewSummary => 'WebView ログ（{count} 項目、{displayed} を表示）';
}

// Path: playback.syncplay.selectServer
class _TranslationsPlaybackSyncplaySelectServerJaJp extends _TranslationsPlaybackSyncplaySelectServerEnUs {
	_TranslationsPlaybackSyncplaySelectServerJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'サーバーを選択';
	@override String get customTitle => 'カスタムサーバー';
	@override String get customHint => 'サーバーURLを入力';
	@override String get duplicateOrEmpty => 'サーバーURLはユニークで空であってはいけません';
}

// Path: playback.syncplay.join
class _TranslationsPlaybackSyncplayJoinJaJp extends _TranslationsPlaybackSyncplayJoinEnUs {
	_TranslationsPlaybackSyncplayJoinJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '部屋に参加';
	@override String get roomLabel => '部屋ID';
	@override String get roomEmpty => '部屋IDを入力してください';
	@override String get roomInvalid => '部屋IDは6から10桁の数字である必要があります';
	@override String get usernameLabel => 'ユーザー名';
	@override String get usernameEmpty => 'ユーザー名を入力してください';
	@override String get usernameInvalid => 'ユーザー名は4から12文字の字母である必要があります';
}

// Path: playback.superResolution.warning
class _TranslationsPlaybackSuperResolutionWarningJaJp extends _TranslationsPlaybackSuperResolutionWarningEnUs {
	_TranslationsPlaybackSuperResolutionWarningJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'パフォーマンス警告';
	@override String get message => '超解像度（品質）を有効にすると、スト터를引起こす可能性があります。続行しますか？';
	@override String get dontAskAgain => '再び確認しない';
}

// Path: settings.appearancePage.colorScheme.labels
class _TranslationsSettingsAppearancePageColorSchemeLabelsJaJp extends _TranslationsSettingsAppearancePageColorSchemeLabelsEnUs {
	_TranslationsSettingsAppearancePageColorSchemeLabelsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get defaultLabel => 'デフォルト';
	@override String get teal => 'ティール';
	@override String get blue => 'ブルー';
	@override String get indigo => 'インディゴ';
	@override String get violet => 'バイオレット';
	@override String get pink => 'ピンク';
	@override String get yellow => '黄色';
	@override String get orange => 'オレンジ';
	@override String get deepOrange => 'ディープオレンジ';
}

// Path: settings.plugins.sort.options
class _TranslationsSettingsPluginsSortOptionsJaJp extends _TranslationsSettingsPluginsSortOptionsEnUs {
	_TranslationsSettingsPluginsSortOptionsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get original => '元の順序';
	@override String get nameAsc => '名前（Ａ → ３）';
	@override String get nameDesc => '名前（３ → Ａ）';
	@override String get failureAsc => '失敗数（低 → 高）';
	@override String get failureDesc => '失敗数（高 → 低）';
}

// Path: settings.plugins.editor.fields
class _TranslationsSettingsPluginsEditorFieldsJaJp extends _TranslationsSettingsPluginsEditorFieldsEnUs {
	_TranslationsSettingsPluginsEditorFieldsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get name => 'ルール名';
	@override String get version => 'バージョン';
	@override String get baseUrl => 'ベースURL';
	@override String get searchUrl => '検索URL';
	@override String get searchList => '検索リストXPath';
	@override String get searchName => '検索名XPath';
	@override String get searchResult => '検索結果XPath';
	@override String get chapterRoads => 'チャプターロードXPath';
	@override String get chapterResult => 'チャプター結果XPath';
	@override String get userAgent => 'User-Agent';
	@override String get referer => 'Referer';
}

// Path: settings.plugins.editor.advanced
class _TranslationsSettingsPluginsEditorAdvancedJaJp extends _TranslationsSettingsPluginsEditorAdvancedEnUs {
	_TranslationsSettingsPluginsEditorAdvancedJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '高度な設定';
	@override late final _TranslationsSettingsPluginsEditorAdvancedLegacyParserJaJp legacyParser = _TranslationsSettingsPluginsEditorAdvancedLegacyParserJaJp._(_root);
	@override late final _TranslationsSettingsPluginsEditorAdvancedHttpPostJaJp httpPost = _TranslationsSettingsPluginsEditorAdvancedHttpPostJaJp._(_root);
	@override late final _TranslationsSettingsPluginsEditorAdvancedNativePlayerJaJp nativePlayer = _TranslationsSettingsPluginsEditorAdvancedNativePlayerJaJp._(_root);
}

// Path: settings.plugins.shop.tooltip
class _TranslationsSettingsPluginsShopTooltipJaJp extends _TranslationsSettingsPluginsShopTooltipEnUs {
	_TranslationsSettingsPluginsShopTooltipJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get sortByName => '名前で並び替え';
	@override String get sortByUpdate => '更新時間で並び替え';
	@override String get refresh => 'ルールリストを更新';
}

// Path: settings.plugins.shop.labels
class _TranslationsSettingsPluginsShopLabelsJaJp extends _TranslationsSettingsPluginsShopLabelsEnUs {
	_TranslationsSettingsPluginsShopLabelsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsSettingsPluginsShopLabelsPlayerTypeJaJp playerType = _TranslationsSettingsPluginsShopLabelsPlayerTypeJaJp._(_root);
	@override String get lastUpdated => '最後の更新：{timestamp}';
}

// Path: settings.plugins.shop.buttons
class _TranslationsSettingsPluginsShopButtonsJaJp extends _TranslationsSettingsPluginsShopButtonsEnUs {
	_TranslationsSettingsPluginsShopButtonsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get install => '追加';
	@override String get installed => '追加済み';
	@override String get update => '更新';
	@override String get toggleMirrorEnable => 'ミラーを有効化';
	@override String get toggleMirrorDisable => 'ミラーを無効化';
	@override String get refresh => '更新';
}

// Path: settings.plugins.shop.toast
class _TranslationsSettingsPluginsShopToastJaJp extends _TranslationsSettingsPluginsShopToastEnUs {
	_TranslationsSettingsPluginsShopToastJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get importFailed => 'ルールのインポートに失敗しました。';
}

// Path: settings.plugins.shop.error
class _TranslationsSettingsPluginsShopErrorJaJp extends _TranslationsSettingsPluginsShopErrorEnUs {
	_TranslationsSettingsPluginsShopErrorJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get unreachable => 'リポジトリに接続できません\n{status}';
	@override String get mirrorEnabled => 'ミラーが有効化されました';
	@override String get mirrorDisabled => 'コラーーが無効化されました';
}

// Path: settings.player.superResolutionOptions.off
class _TranslationsSettingsPlayerSuperResolutionOptionsOffJaJp extends _TranslationsSettingsPlayerSuperResolutionOptionsOffEnUs {
	_TranslationsSettingsPlayerSuperResolutionOptionsOffJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get label => 'オフ';
	@override String get description => 'すべてのアップスケーリング拡張機能を無効化。';
}

// Path: settings.player.superResolutionOptions.efficiency
class _TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyJaJp extends _TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyEnUs {
	_TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get label => 'バランス';
	@override String get description => 'パフォーマンスと品質のバランス。';
}

// Path: settings.player.superResolutionOptions.quality
class _TranslationsSettingsPlayerSuperResolutionOptionsQualityJaJp extends _TranslationsSettingsPlayerSuperResolutionOptionsQualityEnUs {
	_TranslationsSettingsPlayerSuperResolutionOptionsQualityJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get label => '品質';
	@override String get description => '最適な品質のためにリソースをトレードオフ。';
}

// Path: settings.webdav.editor.toast
class _TranslationsSettingsWebdavEditorToastJaJp extends _TranslationsSettingsWebdavEditorToastEnUs {
	_TranslationsSettingsWebdavEditorToastJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get saveSuccess => '設定が保存されました。テストを開始します…';
	@override String get saveFailed => '設定の保存に失敗しました: {error}';
	@override String get testSuccess => 'テストが成功しました。';
	@override String get testFailed => 'テストに失敗しました: {error}';
}

// Path: settings.update.dialog.actions
class _TranslationsSettingsUpdateDialogActionsJaJp extends _TranslationsSettingsUpdateDialogActionsEnUs {
	_TranslationsSettingsUpdateDialogActionsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get disableAutoUpdate => '自動更新を無効化';
	@override String get remindLater => '後でリマインダー';
	@override String get viewDetails => '詳細を表示';
	@override String get updateNow => '今すぐ更新';
}

// Path: settings.update.download.error
class _TranslationsSettingsUpdateDownloadErrorJaJp extends _TranslationsSettingsUpdateDownloadErrorEnUs {
	_TranslationsSettingsUpdateDownloadErrorJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'ダウンロードに失敗';
	@override String get general => '更新をダウンロードできませんでした。';
	@override String get permission => 'ファイルを作成する権限が不足しています。';
	@override String get diskFull => 'Disk space が不足しています。';
	@override String get network => 'ネットワーク接続に失敗しました。';
	@override String get integrity => 'ファイル整合性チェックに失敗しました。もう一度お試しください。';
	@override String get details => '技術的詳細: {error}';
	@override String get confirm => 'OK';
	@override String get retry => '再試行';
}

// Path: settings.update.download.complete
class _TranslationsSettingsUpdateDownloadCompleteJaJp extends _TranslationsSettingsUpdateDownloadCompleteEnUs {
	_TranslationsSettingsUpdateDownloadCompleteJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'ダウンロード完了';
	@override String get message => 'Haipee {version} がダウンロードされました。';
	@override String get quitNotice => 'アプリのインストール中に終了します。';
	@override String get fileLocation => 'ファイルは次に保存されました';
	@override late final _TranslationsSettingsUpdateDownloadCompleteButtonsJaJp buttons = _TranslationsSettingsUpdateDownloadCompleteButtonsJaJp._(_root);
}

// Path: settings.about.sections.licenses
class _TranslationsSettingsAboutSectionsLicensesJaJp extends _TranslationsSettingsAboutSectionsLicensesEnUs {
	_TranslationsSettingsAboutSectionsLicensesJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'オープンソースライセンス';
	@override String get description => 'すべてのオープンソースライセンスを表示';
}

// Path: settings.about.sections.links
class _TranslationsSettingsAboutSectionsLinksJaJp extends _TranslationsSettingsAboutSectionsLinksEnUs {
	_TranslationsSettingsAboutSectionsLinksJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '外部リンク';
	@override String get project => 'プロジェクトホームページ';
	@override String get repository => 'ソースリポジトリ';
	@override String get icon => 'アイコン設計';
	@override String get index => 'アニメ索引';
	@override String get danmaku => '弾幕プロバイダー';
	@override String get danmakuId => 'ID: {id}';
}

// Path: settings.about.sections.cache
class _TranslationsSettingsAboutSectionsCacheJaJp extends _TranslationsSettingsAboutSectionsCacheEnUs {
	_TranslationsSettingsAboutSectionsCacheJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get clearAction => 'キャッシュをクリア';
	@override String get sizePending => '計算中…';
	@override String get sizeLabel => '{size} MB';
}

// Path: settings.about.sections.updates
class _TranslationsSettingsAboutSectionsUpdatesJaJp extends _TranslationsSettingsAboutSectionsUpdatesEnUs {
	_TranslationsSettingsAboutSectionsUpdatesJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'アプリ更新';
	@override String get autoUpdate => '自動更新';
	@override String get check => '更新を確認';
	@override String get currentVersion => '現在のバージョン {version}';
}

// Path: settings.about.logs.toast
class _TranslationsSettingsAboutLogsToastJaJp extends _TranslationsSettingsAboutLogsToastEnUs {
	_TranslationsSettingsAboutLogsToastJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get cleared => 'ログがクリアされました。';
	@override String get clearFailed => 'ログのクリアに失敗しました。';
}

// Path: library.timeline.season.names
class _TranslationsLibraryTimelineSeasonNamesJaJp extends _TranslationsLibraryTimelineSeasonNamesEnUs {
	_TranslationsLibraryTimelineSeasonNamesJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get winter => '冬';
	@override String get spring => '春';
	@override String get summer => '夏';
	@override String get autumn => '秋';
}

// Path: library.timeline.season.short
class _TranslationsLibraryTimelineSeasonShortJaJp extends _TranslationsLibraryTimelineSeasonShortEnUs {
	_TranslationsLibraryTimelineSeasonShortJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get winter => '冬';
	@override String get spring => '春';
	@override String get summer => '夏';
	@override String get autumn => '秋';
}

// Path: library.info.sourceSheet.alias
class _TranslationsLibraryInfoSourceSheetAliasJaJp extends _TranslationsLibraryInfoSourceSheetAliasEnUs {
	_TranslationsLibraryInfoSourceSheetAliasJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get deleteTooltip => '別名を削除';
	@override String get deleteTitle => '別名を削除';
	@override String get deleteMessage => 'この操作は元に戻せません。この別名を削除しますか？';
}

// Path: library.info.sourceSheet.toast
class _TranslationsLibraryInfoSourceSheetToastJaJp extends _TranslationsLibraryInfoSourceSheetToastEnUs {
	_TranslationsLibraryInfoSourceSheetToastJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get aliasEmpty => '利用可能な別名はありません。検索前に手動で追加してください。';
	@override String get loadFailed => '再生ルートの読み込みに失敗しました。';
	@override String get removed => 'ソース {plugin} を削除しました。';
}

// Path: library.info.sourceSheet.sort
class _TranslationsLibraryInfoSourceSheetSortJaJp extends _TranslationsLibraryInfoSourceSheetSortEnUs {
	_TranslationsLibraryInfoSourceSheetSortJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get tooltip => '並び替え：{label}';
	@override late final _TranslationsLibraryInfoSourceSheetSortOptionsJaJp options = _TranslationsLibraryInfoSourceSheetSortOptionsJaJp._(_root);
	@override String get title => '並び替え';
}

// Path: library.info.sourceSheet.card
class _TranslationsLibraryInfoSourceSheetCardJaJp extends _TranslationsLibraryInfoSourceSheetCardEnUs {
	_TranslationsLibraryInfoSourceSheetCardJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'ソース · {plugin}';
	@override String get play => '再生';
}

// Path: library.info.sourceSheet.actions
class _TranslationsLibraryInfoSourceSheetActionsJaJp extends _TranslationsLibraryInfoSourceSheetActionsEnUs {
	_TranslationsLibraryInfoSourceSheetActionsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get searchAgain => '再検索';
	@override String get aliasSearch => '別名検索';
	@override String get removeSource => 'ソースを削除';
}

// Path: library.info.sourceSheet.status
class _TranslationsLibraryInfoSourceSheetStatusJaJp extends _TranslationsLibraryInfoSourceSheetStatusEnUs {
	_TranslationsLibraryInfoSourceSheetStatusJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get searching => '{plugin} 検索中…';
	@override String get failed => '{plugin} 検索失敗';
	@override String get empty => '{plugin} 結果を返しませんでした';
}

// Path: library.info.sourceSheet.empty
class _TranslationsLibraryInfoSourceSheetEmptyJaJp extends _TranslationsLibraryInfoSourceSheetEmptyEnUs {
	_TranslationsLibraryInfoSourceSheetEmptyJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get searching => '検索中、お待ちください…';
	@override String get noResults => '再生ソースが見つかりませんでした。再度検索するか、別名を使用してください。';
}

// Path: library.info.sourceSheet.dialog
class _TranslationsLibraryInfoSourceSheetDialogJaJp extends _TranslationsLibraryInfoSourceSheetDialogEnUs {
	_TranslationsLibraryInfoSourceSheetDialogJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get removeTitle => 'ソースを削除';
	@override String get removeMessage => 'ソース {plugin} を削除しますか？';
}

// Path: library.my.favorites.tabs
class _TranslationsLibraryMyFavoritesTabsJaJp extends _TranslationsLibraryMyFavoritesTabsEnUs {
	_TranslationsLibraryMyFavoritesTabsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get watching => '視聴中';
	@override String get planned => '予定視聴';
	@override String get completed => '完了';
	@override String get empty => 'まだ項目がありません。';
}

// Path: library.my.favorites.sync
class _TranslationsLibraryMyFavoritesSyncJaJp extends _TranslationsLibraryMyFavoritesSyncEnUs {
	_TranslationsLibraryMyFavoritesSyncJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get disabled => 'WebDAV同期は無効です。';
	@override String get editing => '編集モード中は同期できません。';
}

// Path: playback.controls.aspectRatio.options
class _TranslationsPlaybackControlsAspectRatioOptionsJaJp extends _TranslationsPlaybackControlsAspectRatioOptionsEnUs {
	_TranslationsPlaybackControlsAspectRatioOptionsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get auto => '自動';
	@override String get crop => 'クロップして填充';
	@override String get stretch => '拉伸して填充';
}

// Path: settings.plugins.editor.advanced.legacyParser
class _TranslationsSettingsPluginsEditorAdvancedLegacyParserJaJp extends _TranslationsSettingsPluginsEditorAdvancedLegacyParserEnUs {
	_TranslationsSettingsPluginsEditorAdvancedLegacyParserJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'レガシーパーサーを有効化';
	@override String get subtitle => '互換性を向上させるためにレガシーXPath解析ロジックを使用します。';
}

// Path: settings.plugins.editor.advanced.httpPost
class _TranslationsSettingsPluginsEditorAdvancedHttpPostJaJp extends _TranslationsSettingsPluginsEditorAdvancedHttpPostEnUs {
	_TranslationsSettingsPluginsEditorAdvancedHttpPostJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => '検索をPOSTで送信';
	@override String get subtitle => 'HTTP POSTで検索要求を送信します。';
}

// Path: settings.plugins.editor.advanced.nativePlayer
class _TranslationsSettingsPluginsEditorAdvancedNativePlayerJaJp extends _TranslationsSettingsPluginsEditorAdvancedNativePlayerEnUs {
	_TranslationsSettingsPluginsEditorAdvancedNativePlayerJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get title => 'ネイティブプレイヤーの使用を強制';
	@override String get subtitle => '再生時にビルトインプレイヤーを優先します。';
}

// Path: settings.plugins.shop.labels.playerType
class _TranslationsSettingsPluginsShopLabelsPlayerTypeJaJp extends _TranslationsSettingsPluginsShopLabelsPlayerTypeEnUs {
	_TranslationsSettingsPluginsShopLabelsPlayerTypeJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get native => 'ネイティブ';
	@override String get webview => 'WebView';
}

// Path: settings.update.download.complete.buttons
class _TranslationsSettingsUpdateDownloadCompleteButtonsJaJp extends _TranslationsSettingsUpdateDownloadCompleteButtonsEnUs {
	_TranslationsSettingsUpdateDownloadCompleteButtonsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get later => '後';
	@override String get openFolder => 'フォルダーを開く';
	@override String get installNow => '今すぐインストール';
}

// Path: library.info.sourceSheet.sort.options
class _TranslationsLibraryInfoSourceSheetSortOptionsJaJp extends _TranslationsLibraryInfoSourceSheetSortOptionsEnUs {
	_TranslationsLibraryInfoSourceSheetSortOptionsJaJp._(_TranslationsJaJp root) : this._root = root, super._(root);

	@override final _TranslationsJaJp _root; // ignore: unused_field

	// Translations
	@override String get original => '元の順序';
	@override String get nameAsc => '名前（Ａ → ３）';
	@override String get nameDesc => '名前（３ → Ａ）';
	@override String get failureAsc => '失敗数（低 → 高）';
	@override String get failureDesc => '失敗数（高 → 低）';
}

// Path: <root>
class _TranslationsZhCn extends AppTranslations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_TranslationsZhCn.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.zhCn,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super.build(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh-CN>.
	@override final TranslationMetadata<AppLocale, AppTranslations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	@override late final _TranslationsZhCn _root = this; // ignore: unused_field

	// Translations
	@override late final _TranslationsAppZhCn app = _TranslationsAppZhCn._(_root);
	@override late final _TranslationsMetadataZhCn metadata = _TranslationsMetadataZhCn._(_root);
	@override late final _TranslationsDownloadsZhCn downloads = _TranslationsDownloadsZhCn._(_root);
	@override late final _TranslationsTorrentZhCn torrent = _TranslationsTorrentZhCn._(_root);
	@override late final _TranslationsSettingsZhCn settings = _TranslationsSettingsZhCn._(_root);
	@override late final _TranslationsExitDialogZhCn exitDialog = _TranslationsExitDialogZhCn._(_root);
	@override late final _TranslationsTrayZhCn tray = _TranslationsTrayZhCn._(_root);
	@override late final _TranslationsNavigationZhCn navigation = _TranslationsNavigationZhCn._(_root);
	@override late final _TranslationsDialogsZhCn dialogs = _TranslationsDialogsZhCn._(_root);
	@override late final _TranslationsLibraryZhCn library = _TranslationsLibraryZhCn._(_root);
	@override late final _TranslationsPlaybackZhCn playback = _TranslationsPlaybackZhCn._(_root);
	@override late final _TranslationsNetworkZhCn network = _TranslationsNetworkZhCn._(_root);
	@override late final _TranslationsSyncZhCn sync = _TranslationsSyncZhCn._(_root);
}

// Path: app
class _TranslationsAppZhCn extends _TranslationsAppEnUs {
	_TranslationsAppZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Haipee';
	@override String get loading => '加载中…';
	@override String get retry => '重试';
	@override String get confirm => '确认';
	@override String get cancel => '取消';
	@override String get delete => '删除';
}

// Path: metadata
class _TranslationsMetadataZhCn extends _TranslationsMetadataEnUs {
	_TranslationsMetadataZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get sectionTitle => '作品信息';
	@override String get refresh => '刷新元数据';
	@override late final _TranslationsMetadataSourceZhCn source = _TranslationsMetadataSourceZhCn._(_root);
	@override String get lastSynced => '上次同步：{timestamp}';
}

// Path: downloads
class _TranslationsDownloadsZhCn extends _TranslationsDownloadsEnUs {
	_TranslationsDownloadsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get sectionTitle => '下载队列';
	@override String get downloadOffline => '下载引擎未连接';
	@override String get queued => '排队';
	@override String get running => '下载中';
	@override String get completed => '已完成';
	@override late final _TranslationsDownloadsPageZhCn page = _TranslationsDownloadsPageZhCn._(_root);
	@override late final _TranslationsDownloadsAddDialogZhCn addDialog = _TranslationsDownloadsAddDialogZhCn._(_root);
	@override late final _TranslationsDownloadsDetailDialogZhCn detailDialog = _TranslationsDownloadsDetailDialogZhCn._(_root);
}

// Path: torrent
class _TranslationsTorrentZhCn extends _TranslationsTorrentEnUs {
	_TranslationsTorrentZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsTorrentConsentZhCn consent = _TranslationsTorrentConsentZhCn._(_root);
	@override late final _TranslationsTorrentErrorZhCn error = _TranslationsTorrentErrorZhCn._(_root);
}

// Path: settings
class _TranslationsSettingsZhCn extends _TranslationsSettingsEnUs {
	_TranslationsSettingsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '设置';
	@override String get downloads => '下载设置';
	@override String get playback => '播放偏好';
	@override late final _TranslationsSettingsGeneralZhCn general = _TranslationsSettingsGeneralZhCn._(_root);
	@override late final _TranslationsSettingsAppearancePageZhCn appearancePage = _TranslationsSettingsAppearancePageZhCn._(_root);
	@override late final _TranslationsSettingsSourceZhCn source = _TranslationsSettingsSourceZhCn._(_root);
	@override late final _TranslationsSettingsPluginsZhCn plugins = _TranslationsSettingsPluginsZhCn._(_root);
	@override late final _TranslationsSettingsMetadataZhCn metadata = _TranslationsSettingsMetadataZhCn._(_root);
	@override late final _TranslationsSettingsPlayerZhCn player = _TranslationsSettingsPlayerZhCn._(_root);
	@override late final _TranslationsSettingsWebdavZhCn webdav = _TranslationsSettingsWebdavZhCn._(_root);
	@override late final _TranslationsSettingsUpdateZhCn update = _TranslationsSettingsUpdateZhCn._(_root);
	@override late final _TranslationsSettingsOtherZhCn other = _TranslationsSettingsOtherZhCn._(_root);
	@override late final _TranslationsSettingsAboutZhCn about = _TranslationsSettingsAboutZhCn._(_root);
}

// Path: exitDialog
class _TranslationsExitDialogZhCn extends _TranslationsExitDialogEnUs {
	_TranslationsExitDialogZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '退出确认';
	@override String get message => '您想要退出 Haipee 吗？';
	@override String get dontAskAgain => '下次不再询问';
	@override String get exit => '退出 Haipee';
	@override String get minimize => '最小化至托盘';
	@override String get cancel => '取消';
}

// Path: tray
class _TranslationsTrayZhCn extends _TranslationsTrayEnUs {
	_TranslationsTrayZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get showWindow => '显示窗口';
	@override String get exit => '退出 Haipee';
}

// Path: navigation
class _TranslationsNavigationZhCn extends _TranslationsNavigationEnUs {
	_TranslationsNavigationZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsNavigationTabsZhCn tabs = _TranslationsNavigationTabsZhCn._(_root);
	@override late final _TranslationsNavigationActionsZhCn actions = _TranslationsNavigationActionsZhCn._(_root);
}

// Path: dialogs
class _TranslationsDialogsZhCn extends _TranslationsDialogsEnUs {
	_TranslationsDialogsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsDialogsDisclaimerZhCn disclaimer = _TranslationsDialogsDisclaimerZhCn._(_root);
	@override late final _TranslationsDialogsUpdateMirrorZhCn updateMirror = _TranslationsDialogsUpdateMirrorZhCn._(_root);
	@override late final _TranslationsDialogsPluginUpdatesZhCn pluginUpdates = _TranslationsDialogsPluginUpdatesZhCn._(_root);
	@override late final _TranslationsDialogsWebdavZhCn webdav = _TranslationsDialogsWebdavZhCn._(_root);
	@override late final _TranslationsDialogsAboutZhCn about = _TranslationsDialogsAboutZhCn._(_root);
	@override late final _TranslationsDialogsCacheZhCn cache = _TranslationsDialogsCacheZhCn._(_root);
}

// Path: library
class _TranslationsLibraryZhCn extends _TranslationsLibraryEnUs {
	_TranslationsLibraryZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsLibraryCommonZhCn common = _TranslationsLibraryCommonZhCn._(_root);
	@override late final _TranslationsLibraryPopularZhCn popular = _TranslationsLibraryPopularZhCn._(_root);
	@override late final _TranslationsLibraryTimelineZhCn timeline = _TranslationsLibraryTimelineZhCn._(_root);
	@override late final _TranslationsLibrarySearchZhCn search = _TranslationsLibrarySearchZhCn._(_root);
	@override late final _TranslationsLibraryHistoryZhCn history = _TranslationsLibraryHistoryZhCn._(_root);
	@override late final _TranslationsLibraryInfoZhCn info = _TranslationsLibraryInfoZhCn._(_root);
	@override late final _TranslationsLibraryMyZhCn my = _TranslationsLibraryMyZhCn._(_root);
}

// Path: playback
class _TranslationsPlaybackZhCn extends _TranslationsPlaybackEnUs {
	_TranslationsPlaybackZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsPlaybackToastZhCn toast = _TranslationsPlaybackToastZhCn._(_root);
	@override late final _TranslationsPlaybackDanmakuZhCn danmaku = _TranslationsPlaybackDanmakuZhCn._(_root);
	@override late final _TranslationsPlaybackExternalPlayerZhCn externalPlayer = _TranslationsPlaybackExternalPlayerZhCn._(_root);
	@override late final _TranslationsPlaybackControlsZhCn controls = _TranslationsPlaybackControlsZhCn._(_root);
	@override late final _TranslationsPlaybackLoadingZhCn loading = _TranslationsPlaybackLoadingZhCn._(_root);
	@override late final _TranslationsPlaybackDanmakuSearchZhCn danmakuSearch = _TranslationsPlaybackDanmakuSearchZhCn._(_root);
	@override late final _TranslationsPlaybackRemoteZhCn remote = _TranslationsPlaybackRemoteZhCn._(_root);
	@override late final _TranslationsPlaybackDebugZhCn debug = _TranslationsPlaybackDebugZhCn._(_root);
	@override late final _TranslationsPlaybackSyncplayZhCn syncplay = _TranslationsPlaybackSyncplayZhCn._(_root);
	@override late final _TranslationsPlaybackPlaylistZhCn playlist = _TranslationsPlaybackPlaylistZhCn._(_root);
	@override late final _TranslationsPlaybackTabsZhCn tabs = _TranslationsPlaybackTabsZhCn._(_root);
	@override late final _TranslationsPlaybackCommentsZhCn comments = _TranslationsPlaybackCommentsZhCn._(_root);
	@override late final _TranslationsPlaybackSuperResolutionZhCn superResolution = _TranslationsPlaybackSuperResolutionZhCn._(_root);
}

// Path: network
class _TranslationsNetworkZhCn extends _TranslationsNetworkEnUs {
	_TranslationsNetworkZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsNetworkErrorZhCn error = _TranslationsNetworkErrorZhCn._(_root);
	@override late final _TranslationsNetworkStatusZhCn status = _TranslationsNetworkStatusZhCn._(_root);
}

// Path: sync
class _TranslationsSyncZhCn extends _TranslationsSyncEnUs {
	_TranslationsSyncZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
}

// Path: metadata.source
class _TranslationsMetadataSourceZhCn extends _TranslationsMetadataSourceEnUs {
	_TranslationsMetadataSourceZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get bangumi => 'Bangumi';
	@override String get tmdb => 'TMDb';
}

// Path: downloads.page
class _TranslationsDownloadsPageZhCn extends _TranslationsDownloadsPageEnUs {
	_TranslationsDownloadsPageZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '下载管理';
	@override String selectedItems({required Object count}) => '已选择 ${count} 项';
	@override String get newDownload => '新建下载';
	@override String get batchManage => '批量管理';
	@override String get downloadSettings => '下载设置';
	@override String get refresh => '刷新';
	@override late final _TranslationsDownloadsPageTabsZhCn tabs = _TranslationsDownloadsPageTabsZhCn._(_root);
	@override late final _TranslationsDownloadsPageActionsZhCn actions = _TranslationsDownloadsPageActionsZhCn._(_root);
	@override late final _TranslationsDownloadsPageStatisticsZhCn statistics = _TranslationsDownloadsPageStatisticsZhCn._(_root);
	@override late final _TranslationsDownloadsPageSearchZhCn search = _TranslationsDownloadsPageSearchZhCn._(_root);
	@override late final _TranslationsDownloadsPageSortZhCn sort = _TranslationsDownloadsPageSortZhCn._(_root);
	@override late final _TranslationsDownloadsPageEmptyZhCn empty = _TranslationsDownloadsPageEmptyZhCn._(_root);
	@override late final _TranslationsDownloadsPageStatusZhCn status = _TranslationsDownloadsPageStatusZhCn._(_root);
	@override late final _TranslationsDownloadsPageDialogZhCn dialog = _TranslationsDownloadsPageDialogZhCn._(_root);
	@override late final _TranslationsDownloadsPageToastZhCn toast = _TranslationsDownloadsPageToastZhCn._(_root);
}

// Path: downloads.addDialog
class _TranslationsDownloadsAddDialogZhCn extends _TranslationsDownloadsAddDialogEnUs {
	_TranslationsDownloadsAddDialogZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '新建下载任务';
	@override late final _TranslationsDownloadsAddDialogTabsZhCn tabs = _TranslationsDownloadsAddDialogTabsZhCn._(_root);
	@override late final _TranslationsDownloadsAddDialogUrlZhCn url = _TranslationsDownloadsAddDialogUrlZhCn._(_root);
	@override late final _TranslationsDownloadsAddDialogTorrentZhCn torrent = _TranslationsDownloadsAddDialogTorrentZhCn._(_root);
	@override late final _TranslationsDownloadsAddDialogAdvancedZhCn advanced = _TranslationsDownloadsAddDialogAdvancedZhCn._(_root);
	@override late final _TranslationsDownloadsAddDialogActionsZhCn actions = _TranslationsDownloadsAddDialogActionsZhCn._(_root);
	@override late final _TranslationsDownloadsAddDialogErrorsZhCn errors = _TranslationsDownloadsAddDialogErrorsZhCn._(_root);
	@override late final _TranslationsDownloadsAddDialogToastZhCn toast = _TranslationsDownloadsAddDialogToastZhCn._(_root);
}

// Path: downloads.detailDialog
class _TranslationsDownloadsDetailDialogZhCn extends _TranslationsDownloadsDetailDialogEnUs {
	_TranslationsDownloadsDetailDialogZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '任务详情';
	@override late final _TranslationsDownloadsDetailDialogSectionsZhCn sections = _TranslationsDownloadsDetailDialogSectionsZhCn._(_root);
	@override late final _TranslationsDownloadsDetailDialogActionsZhCn actions = _TranslationsDownloadsDetailDialogActionsZhCn._(_root);
	@override late final _TranslationsDownloadsDetailDialogToastZhCn toast = _TranslationsDownloadsDetailDialogToastZhCn._(_root);
}

// Path: torrent.consent
class _TranslationsTorrentConsentZhCn extends _TranslationsTorrentConsentEnUs {
	_TranslationsTorrentConsentZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => 'BitTorrent 使用提示';
	@override String get description => '启用 BT 下载前，请确认遵守所在地法律并了解使用风险。';
	@override String get agree => '我已知悉，继续';
	@override String get decline => '暂不开启';
}

// Path: torrent.error
class _TranslationsTorrentErrorZhCn extends _TranslationsTorrentErrorEnUs {
	_TranslationsTorrentErrorZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get submit => '无法提交磁力链接，稍后重试';
}

// Path: settings.general
class _TranslationsSettingsGeneralZhCn extends _TranslationsSettingsGeneralEnUs {
	_TranslationsSettingsGeneralZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '通用';
	@override String get appearance => '外观设置';
	@override String get appearanceDesc => '设置应用主题和刷新率';
	@override String get language => '应用语言';
	@override String get languageDesc => '选择应用界面显示语言';
	@override String get followSystem => '系统';
	@override String get exitBehavior => '关闭时';
	@override String get exitApp => '退出 Haipee';
	@override String get minimizeToTray => '最小化至托盘';
	@override String get askEveryTime => '每次都询问';
}

// Path: settings.appearancePage
class _TranslationsSettingsAppearancePageZhCn extends _TranslationsSettingsAppearancePageEnUs {
	_TranslationsSettingsAppearancePageZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '外观设置';
	@override late final _TranslationsSettingsAppearancePageModeZhCn mode = _TranslationsSettingsAppearancePageModeZhCn._(_root);
	@override late final _TranslationsSettingsAppearancePageColorSchemeZhCn colorScheme = _TranslationsSettingsAppearancePageColorSchemeZhCn._(_root);
	@override late final _TranslationsSettingsAppearancePageOledZhCn oled = _TranslationsSettingsAppearancePageOledZhCn._(_root);
	@override late final _TranslationsSettingsAppearancePageWindowZhCn window = _TranslationsSettingsAppearancePageWindowZhCn._(_root);
	@override late final _TranslationsSettingsAppearancePageRefreshRateZhCn refreshRate = _TranslationsSettingsAppearancePageRefreshRateZhCn._(_root);
}

// Path: settings.source
class _TranslationsSettingsSourceZhCn extends _TranslationsSettingsSourceEnUs {
	_TranslationsSettingsSourceZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '源';
	@override String get ruleManagement => '规则管理';
	@override String get ruleManagementDesc => '管理视频资源规则';
	@override String get githubProxy => 'Github 镜像';
	@override String get githubProxyDesc => '使用镜像访问规则托管仓库';
}

// Path: settings.plugins
class _TranslationsSettingsPluginsZhCn extends _TranslationsSettingsPluginsEnUs {
	_TranslationsSettingsPluginsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '规则管理';
	@override String get empty => '没有可用规则';
	@override late final _TranslationsSettingsPluginsTooltipZhCn tooltip = _TranslationsSettingsPluginsTooltipZhCn._(_root);
	@override late final _TranslationsSettingsPluginsSortZhCn sort = _TranslationsSettingsPluginsSortZhCn._(_root);
	@override late final _TranslationsSettingsPluginsMultiSelectZhCn multiSelect = _TranslationsSettingsPluginsMultiSelectZhCn._(_root);
	@override late final _TranslationsSettingsPluginsLoadingZhCn loading = _TranslationsSettingsPluginsLoadingZhCn._(_root);
	@override late final _TranslationsSettingsPluginsLabelsZhCn labels = _TranslationsSettingsPluginsLabelsZhCn._(_root);
	@override late final _TranslationsSettingsPluginsActionsZhCn actions = _TranslationsSettingsPluginsActionsZhCn._(_root);
	@override late final _TranslationsSettingsPluginsDialogsZhCn dialogs = _TranslationsSettingsPluginsDialogsZhCn._(_root);
	@override late final _TranslationsSettingsPluginsToastZhCn toast = _TranslationsSettingsPluginsToastZhCn._(_root);
	@override late final _TranslationsSettingsPluginsEditorZhCn editor = _TranslationsSettingsPluginsEditorZhCn._(_root);
	@override late final _TranslationsSettingsPluginsShopZhCn shop = _TranslationsSettingsPluginsShopZhCn._(_root);
}

// Path: settings.metadata
class _TranslationsSettingsMetadataZhCn extends _TranslationsSettingsMetadataEnUs {
	_TranslationsSettingsMetadataZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '信息源';
	@override String get enableBangumi => '启用 Bangumi 信息源';
	@override String get enableBangumiDesc => '从 Bangumi 拉取视频信息';
	@override String get enableTmdb => '启用 TMDb 信息源';
	@override String get enableTmdbDesc => '从 TMDb 补充多语言资料';
	@override String get preferredLanguage => '优先语言';
	@override String get preferredLanguageDesc => '设置元数据同步时使用的语言';
	@override String get followSystemLanguage => '跟随系统语言';
	@override String get simplifiedChinese => '简体中文 (zh-CN)';
	@override String get traditionalChinese => '繁體中文 (zh-TW)';
	@override String get japanese => '日语 (ja-JP)';
	@override String get english => '英语 (en-US)';
	@override String get custom => '自定义';
}

// Path: settings.player
class _TranslationsSettingsPlayerZhCn extends _TranslationsSettingsPlayerEnUs {
	_TranslationsSettingsPlayerZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '播放器设置';
	@override String get playerSettings => '播放设置';
	@override String get playerSettingsDesc => '设置播放器相关参数';
	@override String get hardwareDecoding => '硬件解码';
	@override String get hardwareDecoder => '硬件解码器';
	@override String get hardwareDecoderDesc => '仅在硬件解码启用时生效';
	@override String get lowMemoryMode => '低内存模式';
	@override String get lowMemoryModeDesc => '禁用高级缓存以减少内存占用';
	@override String get lowLatencyAudio => '低延迟音频';
	@override String get lowLatencyAudioDesc => '启用 OpenSLES 音频输出以降低延时';
	@override String get superResolution => '超分辨率';
	@override String get autoJump => '自动跳转';
	@override String get autoJumpDesc => '跳转到上次播放位置';
	@override String get disableAnimations => '禁用视频';
	@override String get disableAnimationsDesc => '禁用播放器内的过渡视频';
	@override String get errorPrompt => '错误提示';
	@override String get errorPromptDesc => '显示播放器内部错误提示';
	@override String get debugMode => '调试模式';
	@override String get debugModeDesc => '记录播放器内部日志';
	@override String get privateMode => '隐身模式';
	@override String get privateModeDesc => '不保留观看记录';
	@override String get defaultPlaySpeed => '默认倍速';
	@override String get defaultVideoAspectRatio => '默认视频比例';
	@override late final _TranslationsSettingsPlayerAspectRatioZhCn aspectRatio = _TranslationsSettingsPlayerAspectRatioZhCn._(_root);
	@override String get danmakuSettings => '弹幕设置';
	@override String get danmakuSettingsDesc => '设置弹幕相关参数';
	@override String get danmaku => '弹幕';
	@override String get danmakuDefaultOn => '默认开启';
	@override String get danmakuDefaultOnDesc => '默认是否随视频播放弹幕';
	@override String get danmakuSource => '弹幕源';
	@override late final _TranslationsSettingsPlayerDanmakuSourcesZhCn danmakuSources = _TranslationsSettingsPlayerDanmakuSourcesZhCn._(_root);
	@override String get danmakuCredentials => '凭证';
	@override String get danmakuDanDanCredentials => 'DanDan API 凭证';
	@override String get danmakuDanDanCredentialsDesc => '自定义 DanDan 凭证';
	@override String get danmakuCredentialModeBuiltIn => '内置';
	@override String get danmakuCredentialModeCustom => '自定义';
	@override String get danmakuCredentialHint => '留空使用内置凭证';
	@override String get danmakuCredentialNotConfigured => '未配置';
	@override String get danmakuCredentialsSummary => 'AppId：{appId}\nAPI Key：{apiKey}';
	@override String get danmakuShield => '弹幕屏蔽';
	@override String get danmakuKeywordShield => '关键词屏蔽';
	@override String get danmakuShieldInputHint => '输入关键词或正则表达式';
	@override String get danmakuShieldDescription => '以"/"开头和结尾将视作正则表达式, 如"/\\d+/"表示屏蔽所有数字';
	@override String get danmakuShieldCount => '已添加{count}个关键词';
	@override String get danmakuConvert => '繁简转换';
	@override String get danmakuConvertTitle => '弹幕繁简转换';
	@override String get danmakuConvertDesc => '下次联网加载弹幕时生效，已缓存弹幕保留下载时的文字';
	@override String get danmakuConvertNone => '不转换';
	@override String get danmakuConvertSimplified => '转为简体';
	@override String get danmakuConvertTraditional => '转为繁体';
	@override String get danmakuStyle => '弹幕样式';
	@override String get danmakuDisplay => '弹幕显示';
	@override String get danmakuArea => '弹幕区域';
	@override String get danmakuTopDisplay => '顶部弹幕';
	@override String get danmakuBottomDisplay => '底部弹幕';
	@override String get danmakuScrollDisplay => '滚动弹幕';
	@override String get danmakuMassiveDisplay => '海量弹幕';
	@override String get danmakuMassiveDescription => '弹幕过多时叠加绘制';
	@override String get danmakuOutline => '弹幕描边';
	@override String get danmakuColor => '弹幕颜色';
	@override String get danmakuFontSize => '字体大小';
	@override String get danmakuFontWeight => '字体字重';
	@override String get danmakuOpacity => '弹幕不透明度';
	@override String get add => '添加';
	@override String get save => '保存';
	@override String get restoreDefault => '恢复默认';
	@override String get superResolutionTitle => '超分辨率';
	@override String get superResolutionHint => '选择默认的超分辨率模式';
	@override late final _TranslationsSettingsPlayerSuperResolutionOptionsZhCn superResolutionOptions = _TranslationsSettingsPlayerSuperResolutionOptionsZhCn._(_root);
	@override String get superResolutionDefaultBehavior => '默认行为';
	@override String get superResolutionClosePrompt => '关闭提示';
	@override String get superResolutionClosePromptDesc => '关闭每次启用超分辨率时的提示';
	@override late final _TranslationsSettingsPlayerToastZhCn toast = _TranslationsSettingsPlayerToastZhCn._(_root);
}

// Path: settings.webdav
class _TranslationsSettingsWebdavZhCn extends _TranslationsSettingsWebdavEnUs {
	_TranslationsSettingsWebdavZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => 'WebDAV';
	@override String get desc => '配置同步参数';
	@override String get pageTitle => '同步设置';
	@override late final _TranslationsSettingsWebdavEditorZhCn editor = _TranslationsSettingsWebdavEditorZhCn._(_root);
	@override late final _TranslationsSettingsWebdavSectionZhCn section = _TranslationsSettingsWebdavSectionZhCn._(_root);
	@override late final _TranslationsSettingsWebdavTileZhCn tile = _TranslationsSettingsWebdavTileZhCn._(_root);
	@override late final _TranslationsSettingsWebdavInfoZhCn info = _TranslationsSettingsWebdavInfoZhCn._(_root);
	@override late final _TranslationsSettingsWebdavToastZhCn toast = _TranslationsSettingsWebdavToastZhCn._(_root);
	@override late final _TranslationsSettingsWebdavResultZhCn result = _TranslationsSettingsWebdavResultZhCn._(_root);
}

// Path: settings.update
class _TranslationsSettingsUpdateZhCn extends _TranslationsSettingsUpdateEnUs {
	_TranslationsSettingsUpdateZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get fallbackDescription => '暂无更新说明。';
	@override late final _TranslationsSettingsUpdateErrorZhCn error = _TranslationsSettingsUpdateErrorZhCn._(_root);
	@override late final _TranslationsSettingsUpdateDialogZhCn dialog = _TranslationsSettingsUpdateDialogZhCn._(_root);
	@override late final _TranslationsSettingsUpdateInstallationTypeZhCn installationType = _TranslationsSettingsUpdateInstallationTypeZhCn._(_root);
	@override late final _TranslationsSettingsUpdateToastZhCn toast = _TranslationsSettingsUpdateToastZhCn._(_root);
	@override late final _TranslationsSettingsUpdateDownloadZhCn download = _TranslationsSettingsUpdateDownloadZhCn._(_root);
}

// Path: settings.other
class _TranslationsSettingsOtherZhCn extends _TranslationsSettingsOtherEnUs {
	_TranslationsSettingsOtherZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '其他';
	@override String get about => '关于';
}

// Path: settings.about
class _TranslationsSettingsAboutZhCn extends _TranslationsSettingsAboutEnUs {
	_TranslationsSettingsAboutZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '关于';
	@override late final _TranslationsSettingsAboutSectionsZhCn sections = _TranslationsSettingsAboutSectionsZhCn._(_root);
	@override late final _TranslationsSettingsAboutLogsZhCn logs = _TranslationsSettingsAboutLogsZhCn._(_root);
}

// Path: navigation.tabs
class _TranslationsNavigationTabsZhCn extends _TranslationsNavigationTabsEnUs {
	_TranslationsNavigationTabsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get popular => '热门';
	@override String get catalog => '资源分类';
	@override String get media => '视频直播';
	@override String get resource => '全网资源';
	@override String get timeline => '时间表';
	@override String get my => '媒体库';
	@override String get download => '任务与下载';
	@override String get settings => '设置';
}

// Path: navigation.actions
class _TranslationsNavigationActionsZhCn extends _TranslationsNavigationActionsEnUs {
	_TranslationsNavigationActionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get search => '搜索';
	@override String get history => '历史记录';
	@override String get close => '退出';
}

// Path: dialogs.disclaimer
class _TranslationsDialogsDisclaimerZhCn extends _TranslationsDialogsDisclaimerEnUs {
	_TranslationsDialogsDisclaimerZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '免责声明';
	@override String get agree => '已阅读并同意';
	@override String get exit => '退出';
}

// Path: dialogs.updateMirror
class _TranslationsDialogsUpdateMirrorZhCn extends _TranslationsDialogsUpdateMirrorEnUs {
	_TranslationsDialogsUpdateMirrorZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '更新镜像';
	@override String get question => '您希望从哪里获取应用更新？';
	@override String get description => 'Github 镜像适用于大多数情况。如果您使用 F-Droid 应用商店，请选择 F-Droid 镜像。';
	@override late final _TranslationsDialogsUpdateMirrorOptionsZhCn options = _TranslationsDialogsUpdateMirrorOptionsZhCn._(_root);
}

// Path: dialogs.pluginUpdates
class _TranslationsDialogsPluginUpdatesZhCn extends _TranslationsDialogsPluginUpdatesEnUs {
	_TranslationsDialogsPluginUpdatesZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get toast => '检测到 {count} 条规则可以更新';
}

// Path: dialogs.webdav
class _TranslationsDialogsWebdavZhCn extends _TranslationsDialogsWebdavEnUs {
	_TranslationsDialogsWebdavZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get syncFailed => '同步观看记录失败 {error}';
}

// Path: dialogs.about
class _TranslationsDialogsAboutZhCn extends _TranslationsDialogsAboutEnUs {
	_TranslationsDialogsAboutZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get licenseLegalese => '开源许可证';
}

// Path: dialogs.cache
class _TranslationsDialogsCacheZhCn extends _TranslationsDialogsCacheEnUs {
	_TranslationsDialogsCacheZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '缓存管理';
	@override String get message => '缓存包含视频封面，清除后加载时需要重新下载，确认要清除缓存吗？';
}

// Path: library.common
class _TranslationsLibraryCommonZhCn extends _TranslationsLibraryCommonEnUs {
	_TranslationsLibraryCommonZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get emptyState => '没有找到内容';
	@override String get retry => '点击重试';
	@override String get backHint => '再按一次退出应用';
	@override late final _TranslationsLibraryCommonToastZhCn toast = _TranslationsLibraryCommonToastZhCn._(_root);
}

// Path: library.popular
class _TranslationsLibraryPopularZhCn extends _TranslationsLibraryPopularEnUs {
	_TranslationsLibraryPopularZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '首页';
	@override String get allTag => '首页';
	@override late final _TranslationsLibraryPopularToastZhCn toast = _TranslationsLibraryPopularToastZhCn._(_root);
}

// Path: library.timeline
class _TranslationsLibraryTimelineZhCn extends _TranslationsLibraryTimelineEnUs {
	_TranslationsLibraryTimelineZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsLibraryTimelineWeekdaysZhCn weekdays = _TranslationsLibraryTimelineWeekdaysZhCn._(_root);
	@override late final _TranslationsLibraryTimelineSeasonPickerZhCn seasonPicker = _TranslationsLibraryTimelineSeasonPickerZhCn._(_root);
	@override late final _TranslationsLibraryTimelineSeasonZhCn season = _TranslationsLibraryTimelineSeasonZhCn._(_root);
	@override late final _TranslationsLibraryTimelineSortZhCn sort = _TranslationsLibraryTimelineSortZhCn._(_root);
}

// Path: library.search
class _TranslationsLibrarySearchZhCn extends _TranslationsLibrarySearchEnUs {
	_TranslationsLibrarySearchZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsLibrarySearchSortZhCn sort = _TranslationsLibrarySearchSortZhCn._(_root);
	@override String get noHistory => '暂无搜索记录';
}

// Path: library.history
class _TranslationsLibraryHistoryZhCn extends _TranslationsLibraryHistoryEnUs {
	_TranslationsLibraryHistoryZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '历史记录';
	@override String get empty => '没有找到历史记录';
	@override late final _TranslationsLibraryHistoryChipsZhCn chips = _TranslationsLibraryHistoryChipsZhCn._(_root);
	@override late final _TranslationsLibraryHistoryToastZhCn toast = _TranslationsLibraryHistoryToastZhCn._(_root);
	@override late final _TranslationsLibraryHistoryManageZhCn manage = _TranslationsLibraryHistoryManageZhCn._(_root);
}

// Path: library.info
class _TranslationsLibraryInfoZhCn extends _TranslationsLibraryInfoEnUs {
	_TranslationsLibraryInfoZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsLibraryInfoSummaryZhCn summary = _TranslationsLibraryInfoSummaryZhCn._(_root);
	@override late final _TranslationsLibraryInfoTagsZhCn tags = _TranslationsLibraryInfoTagsZhCn._(_root);
	@override late final _TranslationsLibraryInfoMetadataZhCn metadata = _TranslationsLibraryInfoMetadataZhCn._(_root);
	@override late final _TranslationsLibraryInfoEpisodesZhCn episodes = _TranslationsLibraryInfoEpisodesZhCn._(_root);
	@override late final _TranslationsLibraryInfoErrorsZhCn errors = _TranslationsLibraryInfoErrorsZhCn._(_root);
	@override late final _TranslationsLibraryInfoTabsZhCn tabs = _TranslationsLibraryInfoTabsZhCn._(_root);
	@override late final _TranslationsLibraryInfoActionsZhCn actions = _TranslationsLibraryInfoActionsZhCn._(_root);
	@override late final _TranslationsLibraryInfoToastZhCn toast = _TranslationsLibraryInfoToastZhCn._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetZhCn sourceSheet = _TranslationsLibraryInfoSourceSheetZhCn._(_root);
}

// Path: library.my
class _TranslationsLibraryMyZhCn extends _TranslationsLibraryMyEnUs {
	_TranslationsLibraryMyZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '我的';
	@override late final _TranslationsLibraryMySectionsZhCn sections = _TranslationsLibraryMySectionsZhCn._(_root);
	@override late final _TranslationsLibraryMyFavoritesZhCn favorites = _TranslationsLibraryMyFavoritesZhCn._(_root);
	@override late final _TranslationsLibraryMyHistoryZhCn history = _TranslationsLibraryMyHistoryZhCn._(_root);
}

// Path: playback.toast
class _TranslationsPlaybackToastZhCn extends _TranslationsPlaybackToastEnUs {
	_TranslationsPlaybackToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get screenshotProcessing => '截图中...';
	@override String get screenshotSaved => '截图保存到相簿成功';
	@override String get screenshotSaveFailed => '截图保存失败：{error}';
	@override String get screenshotError => '截图失败：{error}';
	@override String get playlistEmpty => '播放列表为空';
	@override String get episodeLatest => '已经是最新一集';
	@override String get loadingEpisode => '正在加载{identifier}';
	@override String get danmakuUnsupported => '当前剧集暂不支持发送弹幕';
	@override String get danmakuEmpty => '弹幕内容为空';
	@override String get danmakuTooLong => '弹幕内容过长';
	@override String get waitForVideo => '请等待视频加载完成';
	@override String get enableDanmakuFirst => '请先开启弹幕';
	@override String get danmakuSearchError => '弹幕检索错误: {error}';
	@override String get danmakuSearchEmpty => '未找到匹配结果';
	@override String get danmakuSwitching => '弹幕切换中';
	@override String get clipboardCopied => '已复制到剪贴板';
	@override String get internalError => '播放器内部错误：{details}';
}

// Path: playback.danmaku
class _TranslationsPlaybackDanmakuZhCn extends _TranslationsPlaybackDanmakuEnUs {
	_TranslationsPlaybackDanmakuZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get inputHint => '发个友善的弹幕见证当下';
	@override String get inputDisabled => '已关闭弹幕';
	@override String get send => '发送';
	@override String get mobileButton => '点我发弹幕';
	@override String get mobileButtonDisabled => '已关闭弹幕';
}

// Path: playback.externalPlayer
class _TranslationsPlaybackExternalPlayerZhCn extends _TranslationsPlaybackExternalPlayerEnUs {
	_TranslationsPlaybackExternalPlayerZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get launching => '尝试唤起外部播放器';
	@override String get launchFailed => '唤起外部播放器失败';
	@override String get unavailable => '无法使用外部播放器';
	@override String get unsupportedDevice => '暂不支持该设备';
	@override String get unsupportedPlugin => '暂不支持该规则';
}

// Path: playback.controls
class _TranslationsPlaybackControlsZhCn extends _TranslationsPlaybackControlsEnUs {
	_TranslationsPlaybackControlsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsPlaybackControlsSpeedZhCn speed = _TranslationsPlaybackControlsSpeedZhCn._(_root);
	@override late final _TranslationsPlaybackControlsSkipZhCn skip = _TranslationsPlaybackControlsSkipZhCn._(_root);
	@override late final _TranslationsPlaybackControlsStatusZhCn status = _TranslationsPlaybackControlsStatusZhCn._(_root);
	@override late final _TranslationsPlaybackControlsSuperResolutionZhCn superResolution = _TranslationsPlaybackControlsSuperResolutionZhCn._(_root);
	@override late final _TranslationsPlaybackControlsSpeedMenuZhCn speedMenu = _TranslationsPlaybackControlsSpeedMenuZhCn._(_root);
	@override late final _TranslationsPlaybackControlsAspectRatioZhCn aspectRatio = _TranslationsPlaybackControlsAspectRatioZhCn._(_root);
	@override late final _TranslationsPlaybackControlsTooltipsZhCn tooltips = _TranslationsPlaybackControlsTooltipsZhCn._(_root);
	@override late final _TranslationsPlaybackControlsMenuZhCn menu = _TranslationsPlaybackControlsMenuZhCn._(_root);
	@override late final _TranslationsPlaybackControlsSyncplayZhCn syncplay = _TranslationsPlaybackControlsSyncplayZhCn._(_root);
}

// Path: playback.loading
class _TranslationsPlaybackLoadingZhCn extends _TranslationsPlaybackLoadingEnUs {
	_TranslationsPlaybackLoadingZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get parsing => '视频资源解析中';
	@override String get parseFailed => '视频资源解析失败';
	@override String get player => '视频资源解析成功，播放器加载中';
	@override String get danmakuSearch => '弹幕检索中...';
}

// Path: playback.danmakuSearch
class _TranslationsPlaybackDanmakuSearchZhCn extends _TranslationsPlaybackDanmakuSearchEnUs {
	_TranslationsPlaybackDanmakuSearchZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '弹幕检索';
	@override String get hint => '视频名';
	@override String get submit => '提交';
}

// Path: playback.remote
class _TranslationsPlaybackRemoteZhCn extends _TranslationsPlaybackRemoteEnUs {
	_TranslationsPlaybackRemoteZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '远程投屏';
	@override late final _TranslationsPlaybackRemoteToastZhCn toast = _TranslationsPlaybackRemoteToastZhCn._(_root);
}

// Path: playback.debug
class _TranslationsPlaybackDebugZhCn extends _TranslationsPlaybackDebugEnUs {
	_TranslationsPlaybackDebugZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '调试信息';
	@override String get closeTooltip => '关闭调试信息';
	@override late final _TranslationsPlaybackDebugTabsZhCn tabs = _TranslationsPlaybackDebugTabsZhCn._(_root);
	@override late final _TranslationsPlaybackDebugSectionsZhCn sections = _TranslationsPlaybackDebugSectionsZhCn._(_root);
	@override late final _TranslationsPlaybackDebugLabelsZhCn labels = _TranslationsPlaybackDebugLabelsZhCn._(_root);
	@override late final _TranslationsPlaybackDebugValuesZhCn values = _TranslationsPlaybackDebugValuesZhCn._(_root);
	@override late final _TranslationsPlaybackDebugLogsZhCn logs = _TranslationsPlaybackDebugLogsZhCn._(_root);
}

// Path: playback.syncplay
class _TranslationsPlaybackSyncplayZhCn extends _TranslationsPlaybackSyncplayEnUs {
	_TranslationsPlaybackSyncplayZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get invalidEndpoint => 'SyncPlay：服务器地址不合法 {endpoint}';
	@override String get disconnected => 'SyncPlay：同步中断 {reason}';
	@override String get actionReconnect => '重新连接';
	@override String get alone => 'SyncPlay：您是当前房间中的唯一用户';
	@override String get followUser => 'SyncPlay：当前以用户 {username} 的进度为准';
	@override String get userLeft => 'SyncPlay：{username} 离开了房间';
	@override String get userJoined => 'SyncPlay：{username} 加入了房间';
	@override String get switchEpisode => 'SyncPlay：{username} 切换到第 {episode} 话';
	@override String get chat => 'SyncPlay：{username} 说：{message}';
	@override String get paused => 'SyncPlay：{username} 暂停了播放';
	@override String get resumed => 'SyncPlay：{username} 开始了播放';
	@override String get unknownUser => '未知用户';
	@override String get switchServerBlocked => 'SyncPlay：请先退出当前房间再切换服务器';
	@override String get defaultCustomEndpoint => '自定义服务器';
	@override late final _TranslationsPlaybackSyncplaySelectServerZhCn selectServer = _TranslationsPlaybackSyncplaySelectServerZhCn._(_root);
	@override late final _TranslationsPlaybackSyncplayJoinZhCn join = _TranslationsPlaybackSyncplayJoinZhCn._(_root);
}

// Path: playback.playlist
class _TranslationsPlaybackPlaylistZhCn extends _TranslationsPlaybackPlaylistEnUs {
	_TranslationsPlaybackPlaylistZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get collection => '合集';
	@override String get list => '播放列表{index}';
}

// Path: playback.tabs
class _TranslationsPlaybackTabsZhCn extends _TranslationsPlaybackTabsEnUs {
	_TranslationsPlaybackTabsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get episodes => '选集';
	@override String get comments => '评论';
}

// Path: playback.comments
class _TranslationsPlaybackCommentsZhCn extends _TranslationsPlaybackCommentsEnUs {
	_TranslationsPlaybackCommentsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get sectionTitle => '本集标题';
	@override String get manualSwitch => '手动切换';
	@override String get dialogTitle => '输入集数';
	@override String get dialogEmpty => '请输入集数';
	@override String get dialogConfirm => '刷新';
}

// Path: playback.superResolution
class _TranslationsPlaybackSuperResolutionZhCn extends _TranslationsPlaybackSuperResolutionEnUs {
	_TranslationsPlaybackSuperResolutionZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsPlaybackSuperResolutionWarningZhCn warning = _TranslationsPlaybackSuperResolutionWarningZhCn._(_root);
}

// Path: network.error
class _TranslationsNetworkErrorZhCn extends _TranslationsNetworkErrorEnUs {
	_TranslationsNetworkErrorZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get badCertificate => '证书有误！';
	@override String get badResponse => '服务器异常，请稍后重试！';
	@override String get cancel => '请求已被取消，请重新请求';
	@override String get connection => '连接错误，请检查网络设置';
	@override String get connectionTimeout => '网络连接超时，请检查网络设置';
	@override String get receiveTimeout => '响应超时，请稍后重试！';
	@override String get sendTimeout => '发送请求超时，请检查网络设置';
	@override String get unknown => '{status} 网络异常';
}

// Path: network.status
class _TranslationsNetworkStatusZhCn extends _TranslationsNetworkStatusEnUs {
	_TranslationsNetworkStatusZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get mobile => '正在使用移动流量';
	@override String get wifi => '正在使用 Wi-Fi';
	@override String get ethernet => '正在使用局域网';
	@override String get vpn => '正在使用代理网络';
	@override String get other => '正在使用其他网络';
	@override String get none => '未连接到任何网络';
}

// Path: downloads.page.tabs
class _TranslationsDownloadsPageTabsZhCn extends _TranslationsDownloadsPageTabsEnUs {
	_TranslationsDownloadsPageTabsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String downloading({required Object count}) => '下载中 (${count})';
	@override String paused({required Object count}) => '已暂停 (${count})';
	@override String completed({required Object count}) => '已完成 (${count})';
	@override String failed({required Object count}) => '下载失败 (${count})';
	@override String get all => '全部';
}

// Path: downloads.page.actions
class _TranslationsDownloadsPageActionsZhCn extends _TranslationsDownloadsPageActionsEnUs {
	_TranslationsDownloadsPageActionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get selectAll => '全选';
	@override String get resume => '继续';
	@override String get pause => '暂停';
	@override String get pauseAll => '暂停全部';
	@override String get resumeAll => '继续全部';
	@override String get clearCompleted => '清除已完成';
	@override String get deleteAll => '删除全部';
	@override String get retry => '重试';
	@override String get delete => '删除';
	@override String get open => '打开';
}

// Path: downloads.page.statistics
class _TranslationsDownloadsPageStatisticsZhCn extends _TranslationsDownloadsPageStatisticsEnUs {
	_TranslationsDownloadsPageStatisticsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String tasks({required Object count}) => '${count} 个任务';
	@override String eta({required Object time}) => '预计剩余 ${time}';
}

// Path: downloads.page.search
class _TranslationsDownloadsPageSearchZhCn extends _TranslationsDownloadsPageSearchEnUs {
	_TranslationsDownloadsPageSearchZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get placeholder => '搜索下载任务...';
	@override String get clear => '清除';
}

// Path: downloads.page.sort
class _TranslationsDownloadsPageSortZhCn extends _TranslationsDownloadsPageSortEnUs {
	_TranslationsDownloadsPageSortZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get label => '排序';
	@override String get created => '创建时间';
	@override String get name => '文件名';
	@override String get size => '文件大小';
	@override String get speed => '下载速度';
	@override String get progress => '进度';
}

// Path: downloads.page.empty
class _TranslationsDownloadsPageEmptyZhCn extends _TranslationsDownloadsPageEmptyEnUs {
	_TranslationsDownloadsPageEmptyZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get downloading => '当前没有下载任务';
	@override String get paused => '没有已暂停的下载任务';
	@override String get completed => '还没有已完成的下载';
	@override String get failed => '没有下载失败的任务';
	@override String get all => '下载列表为空';
	@override String get hint => '点击上方的新建按钮添加下载任务';
}

// Path: downloads.page.status
class _TranslationsDownloadsPageStatusZhCn extends _TranslationsDownloadsPageStatusEnUs {
	_TranslationsDownloadsPageStatusZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get active => '下载中';
	@override String get waiting => '等待中';
	@override String get paused => '已暂停';
	@override String get error => '出错';
	@override String get complete => '已完成';
	@override String get removed => '已删除';
}

// Path: downloads.page.dialog
class _TranslationsDownloadsPageDialogZhCn extends _TranslationsDownloadsPageDialogEnUs {
	_TranslationsDownloadsPageDialogZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get deleteConfirm => '确定要删除选中的下载任务吗？';
	@override String get deleteAllConfirm => '确定要删除全部下载任务吗？此操作不可撤销。';
}

// Path: downloads.page.toast
class _TranslationsDownloadsPageToastZhCn extends _TranslationsDownloadsPageToastEnUs {
	_TranslationsDownloadsPageToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get addedToQueue => '已添加到下载队列';
	@override String get resumed => '已继续下载';
	@override String get paused => '已暂停下载';
	@override String get deleted => '已删除';
	@override String get retrying => '已重新添加到下载队列';
	@override String fileLocation({required Object path}) => '文件位置: ${path}';
}

// Path: downloads.addDialog.tabs
class _TranslationsDownloadsAddDialogTabsZhCn extends _TranslationsDownloadsAddDialogTabsEnUs {
	_TranslationsDownloadsAddDialogTabsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get url => 'URL 下载';
	@override String get torrent => '种子下载';
}

// Path: downloads.addDialog.url
class _TranslationsDownloadsAddDialogUrlZhCn extends _TranslationsDownloadsAddDialogUrlEnUs {
	_TranslationsDownloadsAddDialogUrlZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get hint => '输入下载链接，每行一个\n支持：\n- HTTP/HTTPS 链接\n- FTP 链接\n- 磁力链接（magnet:?xt=...)';
}

// Path: downloads.addDialog.torrent
class _TranslationsDownloadsAddDialogTorrentZhCn extends _TranslationsDownloadsAddDialogTorrentEnUs {
	_TranslationsDownloadsAddDialogTorrentZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get dropZone => '拖入种子文件到此处';
	@override String get dropZoneWindows => '点击下方按钮选择种子文件';
	@override String get supported => '支持 .torrent 文件';
	@override String get selectFile => '选择种子文件';
}

// Path: downloads.addDialog.advanced
class _TranslationsDownloadsAddDialogAdvancedZhCn extends _TranslationsDownloadsAddDialogAdvancedEnUs {
	_TranslationsDownloadsAddDialogAdvancedZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '高级选项';
	@override String get savePath => '保存路径（可选）';
	@override String get savePathHint => '留空使用默认下载路径';
	@override String connections({required Object count}) => '单文件连接数: ${count}';
	@override String split({required Object count}) => '单任务分段数: ${count}';
}

// Path: downloads.addDialog.actions
class _TranslationsDownloadsAddDialogActionsZhCn extends _TranslationsDownloadsAddDialogActionsEnUs {
	_TranslationsDownloadsAddDialogActionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get cancel => '取消';
	@override String get start => '开始下载';
}

// Path: downloads.addDialog.errors
class _TranslationsDownloadsAddDialogErrorsZhCn extends _TranslationsDownloadsAddDialogErrorsEnUs {
	_TranslationsDownloadsAddDialogErrorsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get noUrl => '请输入至少一个下载链接';
	@override String get noTorrent => '请选择或拖入种子文件';
	@override String selectFileFailed({required Object error}) => '选择文件失败: ${error}';
	@override String selectPathFailed({required Object error}) => '选择路径失败: ${error}';
	@override String submitFailed({required Object error}) => '添加下载失败: ${error}';
}

// Path: downloads.addDialog.toast
class _TranslationsDownloadsAddDialogToastZhCn extends _TranslationsDownloadsAddDialogToastEnUs {
	_TranslationsDownloadsAddDialogToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String added({required Object count}) => '已添加 ${count} 个下载任务';
	@override String get addedTorrent => '已添加种子下载任务';
}

// Path: downloads.detailDialog.sections
class _TranslationsDownloadsDetailDialogSectionsZhCn extends _TranslationsDownloadsDetailDialogSectionsEnUs {
	_TranslationsDownloadsDetailDialogSectionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get taskName => '任务名称';
	@override String get fileName => '文件名';
	@override String get fileSize => '文件大小';
	@override String get progress => '下载进度';
	@override String get speed => '下载速度';
	@override String get uploadSpeed => '上传速度';
	@override String get connections => '连接数';
	@override String get eta => '预计剩余时间';
	@override String get filePath => '文件路径';
	@override String get gid => '任务 ID';
	@override String get createdAt => '创建时间';
}

// Path: downloads.detailDialog.actions
class _TranslationsDownloadsDetailDialogActionsZhCn extends _TranslationsDownloadsDetailDialogActionsEnUs {
	_TranslationsDownloadsDetailDialogActionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get copyPath => '复制路径';
	@override String get openFile => '打开文件';
	@override String get openFolder => '打开文件夹';
	@override String get retry => '重新下载';
	@override String get close => '关闭';
}

// Path: downloads.detailDialog.toast
class _TranslationsDownloadsDetailDialogToastZhCn extends _TranslationsDownloadsDetailDialogToastEnUs {
	_TranslationsDownloadsDetailDialogToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get pathCopied => '已复制路径';
}

// Path: settings.appearancePage.mode
class _TranslationsSettingsAppearancePageModeZhCn extends _TranslationsSettingsAppearancePageModeEnUs {
	_TranslationsSettingsAppearancePageModeZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '主题模式';
	@override String get system => '系统';
	@override String get light => '浅色';
	@override String get dark => '深色';
}

// Path: settings.appearancePage.colorScheme
class _TranslationsSettingsAppearancePageColorSchemeZhCn extends _TranslationsSettingsAppearancePageColorSchemeEnUs {
	_TranslationsSettingsAppearancePageColorSchemeZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '主题色';
	@override String get dialogTitle => '选择主题色';
	@override String get dynamicColor => '动态配色';
	@override String get dynamicColorInfo => '在支持的设备上根据系统壁纸生成调色板（Android 12+/Windows 11）。';
	@override late final _TranslationsSettingsAppearancePageColorSchemeLabelsZhCn labels = _TranslationsSettingsAppearancePageColorSchemeLabelsZhCn._(_root);
}

// Path: settings.appearancePage.oled
class _TranslationsSettingsAppearancePageOledZhCn extends _TranslationsSettingsAppearancePageOledEnUs {
	_TranslationsSettingsAppearancePageOledZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => 'OLED 增强';
	@override String get description => '针对 OLED 屏幕优化纯黑配色。';
}

// Path: settings.appearancePage.window
class _TranslationsSettingsAppearancePageWindowZhCn extends _TranslationsSettingsAppearancePageWindowEnUs {
	_TranslationsSettingsAppearancePageWindowZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '窗口按钮';
	@override String get description => '在标题栏显示窗口控制按钮。';
}

// Path: settings.appearancePage.refreshRate
class _TranslationsSettingsAppearancePageRefreshRateZhCn extends _TranslationsSettingsAppearancePageRefreshRateEnUs {
	_TranslationsSettingsAppearancePageRefreshRateZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '屏幕刷新率';
}

// Path: settings.plugins.tooltip
class _TranslationsSettingsPluginsTooltipZhCn extends _TranslationsSettingsPluginsTooltipEnUs {
	_TranslationsSettingsPluginsTooltipZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get updateAll => '更新全部';
	@override String get addRule => '添加规则';
}

// Path: settings.plugins.sort
class _TranslationsSettingsPluginsSortZhCn extends _TranslationsSettingsPluginsSortEnUs {
	_TranslationsSettingsPluginsSortZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '排序方式';
	@override String get tooltip => '排序';
	@override late final _TranslationsSettingsPluginsSortOptionsZhCn options = _TranslationsSettingsPluginsSortOptionsZhCn._(_root);
}

// Path: settings.plugins.multiSelect
class _TranslationsSettingsPluginsMultiSelectZhCn extends _TranslationsSettingsPluginsMultiSelectEnUs {
	_TranslationsSettingsPluginsMultiSelectZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get selectedCount => '已选择 {count} 项';
}

// Path: settings.plugins.loading
class _TranslationsSettingsPluginsLoadingZhCn extends _TranslationsSettingsPluginsLoadingEnUs {
	_TranslationsSettingsPluginsLoadingZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get updating => '正在更新规则…';
	@override String get updatingSingle => '更新中';
	@override String get importing => '导入中';
}

// Path: settings.plugins.labels
class _TranslationsSettingsPluginsLabelsZhCn extends _TranslationsSettingsPluginsLabelsEnUs {
	_TranslationsSettingsPluginsLabelsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get version => '版本：{version}';
	@override String get statusUpdatable => '可更新';
	@override String get statusSearchValid => '搜索有效';
}

// Path: settings.plugins.actions
class _TranslationsSettingsPluginsActionsZhCn extends _TranslationsSettingsPluginsActionsEnUs {
	_TranslationsSettingsPluginsActionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get newRule => '新建规则';
	@override String get importFromRepo => '从规则仓库导入';
	@override String get importFromClipboard => '从剪贴板导入';
	@override String get cancel => '取消';
	@override String get import => '导入';
	@override String get update => '更新';
	@override String get edit => '编辑';
	@override String get copyToClipboard => '复制到剪贴板';
	@override String get share => '分享';
	@override String get delete => '删除';
}

// Path: settings.plugins.dialogs
class _TranslationsSettingsPluginsDialogsZhCn extends _TranslationsSettingsPluginsDialogsEnUs {
	_TranslationsSettingsPluginsDialogsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get deleteTitle => '删除规则';
	@override String get deleteMessage => '确定要删除选中的 {count} 条规则吗？';
	@override String get importTitle => '导入规则';
	@override String get shareTitle => '规则链接';
}

// Path: settings.plugins.toast
class _TranslationsSettingsPluginsToastZhCn extends _TranslationsSettingsPluginsToastEnUs {
	_TranslationsSettingsPluginsToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get allUpToDate => '所有规则已是最新';
	@override String get updateCount => '已更新 {count} 条规则';
	@override String get importSuccess => '导入成功';
	@override String get importFailed => '导入失败：{error}';
	@override String get repoMissing => '规则仓库中没有当前规则';
	@override String get alreadyLatest => '规则已是最新';
	@override String get updateSuccess => '更新成功';
	@override String get updateIncompatible => 'Haipee 版本过低，此规则不兼容当前版本';
	@override String get updateFailed => '更新规则失败';
	@override String get copySuccess => '已复制到剪贴板';
}

// Path: settings.plugins.editor
class _TranslationsSettingsPluginsEditorZhCn extends _TranslationsSettingsPluginsEditorEnUs {
	_TranslationsSettingsPluginsEditorZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '编辑规则';
	@override late final _TranslationsSettingsPluginsEditorFieldsZhCn fields = _TranslationsSettingsPluginsEditorFieldsZhCn._(_root);
	@override late final _TranslationsSettingsPluginsEditorAdvancedZhCn advanced = _TranslationsSettingsPluginsEditorAdvancedZhCn._(_root);
}

// Path: settings.plugins.shop
class _TranslationsSettingsPluginsShopZhCn extends _TranslationsSettingsPluginsShopEnUs {
	_TranslationsSettingsPluginsShopZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '规则仓库';
	@override late final _TranslationsSettingsPluginsShopTooltipZhCn tooltip = _TranslationsSettingsPluginsShopTooltipZhCn._(_root);
	@override late final _TranslationsSettingsPluginsShopLabelsZhCn labels = _TranslationsSettingsPluginsShopLabelsZhCn._(_root);
	@override late final _TranslationsSettingsPluginsShopButtonsZhCn buttons = _TranslationsSettingsPluginsShopButtonsZhCn._(_root);
	@override late final _TranslationsSettingsPluginsShopToastZhCn toast = _TranslationsSettingsPluginsShopToastZhCn._(_root);
	@override late final _TranslationsSettingsPluginsShopErrorZhCn error = _TranslationsSettingsPluginsShopErrorZhCn._(_root);
}

// Path: settings.player.aspectRatio
class _TranslationsSettingsPlayerAspectRatioZhCn extends _TranslationsSettingsPlayerAspectRatioEnUs {
	_TranslationsSettingsPlayerAspectRatioZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get auto => '自动';
	@override String get crop => '裁切填充';
	@override String get stretch => '拉伸填充';
}

// Path: settings.player.danmakuSources
class _TranslationsSettingsPlayerDanmakuSourcesZhCn extends _TranslationsSettingsPlayerDanmakuSourcesEnUs {
	_TranslationsSettingsPlayerDanmakuSourcesZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get bilibili => 'Bilibili';
	@override String get gamer => 'Gamer';
	@override String get dandan => 'DanDan';
}

// Path: settings.player.superResolutionOptions
class _TranslationsSettingsPlayerSuperResolutionOptionsZhCn extends _TranslationsSettingsPlayerSuperResolutionOptionsEnUs {
	_TranslationsSettingsPlayerSuperResolutionOptionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsSettingsPlayerSuperResolutionOptionsOffZhCn off = _TranslationsSettingsPlayerSuperResolutionOptionsOffZhCn._(_root);
	@override late final _TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyZhCn efficiency = _TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyZhCn._(_root);
	@override late final _TranslationsSettingsPlayerSuperResolutionOptionsQualityZhCn quality = _TranslationsSettingsPlayerSuperResolutionOptionsQualityZhCn._(_root);
}

// Path: settings.player.toast
class _TranslationsSettingsPlayerToastZhCn extends _TranslationsSettingsPlayerToastEnUs {
	_TranslationsSettingsPlayerToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get danmakuKeywordEmpty => '请输入关键词';
	@override String get danmakuKeywordTooLong => '关键词过长';
	@override String get danmakuKeywordExists => '已存在该关键词';
	@override String get danmakuCredentialsRestored => '已恢复内置凭证';
	@override String get danmakuCredentialsUpdated => '凭证已更新';
}

// Path: settings.webdav.editor
class _TranslationsSettingsWebdavEditorZhCn extends _TranslationsSettingsWebdavEditorEnUs {
	_TranslationsSettingsWebdavEditorZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => 'WebDAV 配置';
	@override String get url => 'URL';
	@override String get username => '用户名';
	@override String get password => '密码';
	@override late final _TranslationsSettingsWebdavEditorToastZhCn toast = _TranslationsSettingsWebdavEditorToastZhCn._(_root);
}

// Path: settings.webdav.section
class _TranslationsSettingsWebdavSectionZhCn extends _TranslationsSettingsWebdavSectionEnUs {
	_TranslationsSettingsWebdavSectionZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get webdav => 'WebDAV';
}

// Path: settings.webdav.tile
class _TranslationsSettingsWebdavTileZhCn extends _TranslationsSettingsWebdavTileEnUs {
	_TranslationsSettingsWebdavTileZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get webdavToggle => 'WebDAV 同步';
	@override String get historyToggle => '观看记录同步';
	@override String get historyDescription => '允许自动同步观看记录';
	@override String get config => 'WebDAV 配置';
	@override String get manualUpload => '手动上传';
	@override String get manualDownload => '手动下载';
}

// Path: settings.webdav.info
class _TranslationsSettingsWebdavInfoZhCn extends _TranslationsSettingsWebdavInfoEnUs {
	_TranslationsSettingsWebdavInfoZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get upload => '立即将观看记录上传到 WebDAV。';
	@override String get download => '立即将观看记录同步到本地。';
}

// Path: settings.webdav.toast
class _TranslationsSettingsWebdavToastZhCn extends _TranslationsSettingsWebdavToastEnUs {
	_TranslationsSettingsWebdavToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get uploading => '正在尝试上传到 WebDAV...';
	@override String get downloading => '正在尝试从 WebDAV 同步...';
	@override String get notConfigured => '未开启 WebDAV 同步或配置无效。';
	@override String get connectionFailed => 'WebDAV 连接失败：{error}';
	@override String get syncFailed => 'WebDAV 同步失败：{error}';
}

// Path: settings.webdav.result
class _TranslationsSettingsWebdavResultZhCn extends _TranslationsSettingsWebdavResultEnUs {
	_TranslationsSettingsWebdavResultZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get initFailed => 'WebDAV 初始化失败：{error}';
	@override String get requireEnable => '请先开启 WebDAV 同步。';
	@override String get disabled => '未开启 WebDAV 同步或配置无效。';
	@override String get connectionFailed => 'WebDAV 连接失败。';
	@override String get syncSuccess => '同步成功。';
	@override String get syncFailed => '同步失败：{error}';
}

// Path: settings.update.error
class _TranslationsSettingsUpdateErrorZhCn extends _TranslationsSettingsUpdateErrorEnUs {
	_TranslationsSettingsUpdateErrorZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get invalidResponse => '更新响应无效。';
}

// Path: settings.update.dialog
class _TranslationsSettingsUpdateDialogZhCn extends _TranslationsSettingsUpdateDialogEnUs {
	_TranslationsSettingsUpdateDialogZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '发现新版本 {version}';
	@override String get publishedAt => '发布于 {date}';
	@override String get installationTypeLabel => '选择安装包';
	@override late final _TranslationsSettingsUpdateDialogActionsZhCn actions = _TranslationsSettingsUpdateDialogActionsZhCn._(_root);
}

// Path: settings.update.installationType
class _TranslationsSettingsUpdateInstallationTypeZhCn extends _TranslationsSettingsUpdateInstallationTypeEnUs {
	_TranslationsSettingsUpdateInstallationTypeZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get windowsMsix => 'Windows 安装包（MSIX）';
	@override String get windowsPortable => 'Windows 便携版（ZIP）';
	@override String get linuxDeb => 'Linux 安装包（DEB）';
	@override String get linuxTar => 'Linux 压缩包（TAR.GZ）';
	@override String get macosDmg => 'macOS 安装包（DMG）';
	@override String get androidApk => 'Android 安装包（APK）';
	@override String get ios => 'iOS 版本（前往 GitHub）';
	@override String get unknown => '其他平台';
}

// Path: settings.update.toast
class _TranslationsSettingsUpdateToastZhCn extends _TranslationsSettingsUpdateToastEnUs {
	_TranslationsSettingsUpdateToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get alreadyLatest => '当前已是最新版本';
	@override String get checkFailed => '检查更新失败，请稍后重试。';
	@override String get autoUpdateDisabled => '已关闭自动更新';
	@override String get downloadLinkMissing => '没有找到 {type} 的下载链接';
	@override String get downloadFailed => '下载失败：{error}';
	@override String get noCompatibleLink => '未找到适用的下载链接';
	@override String get prepareToInstall => '正在准备安装更新，应用即将退出…';
	@override String get openInstallerFailed => '无法打开安装文件：{error}';
	@override String get launchInstallerFailed => '启动安装程序失败：{error}';
	@override String get revealFailed => '无法打开文件管理器';
	@override String get unknownReason => '未知原因';
}

// Path: settings.update.download
class _TranslationsSettingsUpdateDownloadZhCn extends _TranslationsSettingsUpdateDownloadEnUs {
	_TranslationsSettingsUpdateDownloadZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get progressTitle => '正在下载更新';
	@override String get cancel => '取消';
	@override late final _TranslationsSettingsUpdateDownloadErrorZhCn error = _TranslationsSettingsUpdateDownloadErrorZhCn._(_root);
	@override late final _TranslationsSettingsUpdateDownloadCompleteZhCn complete = _TranslationsSettingsUpdateDownloadCompleteZhCn._(_root);
}

// Path: settings.about.sections
class _TranslationsSettingsAboutSectionsZhCn extends _TranslationsSettingsAboutSectionsEnUs {
	_TranslationsSettingsAboutSectionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsSettingsAboutSectionsLicensesZhCn licenses = _TranslationsSettingsAboutSectionsLicensesZhCn._(_root);
	@override late final _TranslationsSettingsAboutSectionsLinksZhCn links = _TranslationsSettingsAboutSectionsLinksZhCn._(_root);
	@override late final _TranslationsSettingsAboutSectionsCacheZhCn cache = _TranslationsSettingsAboutSectionsCacheZhCn._(_root);
	@override late final _TranslationsSettingsAboutSectionsUpdatesZhCn updates = _TranslationsSettingsAboutSectionsUpdatesZhCn._(_root);
}

// Path: settings.about.logs
class _TranslationsSettingsAboutLogsZhCn extends _TranslationsSettingsAboutLogsEnUs {
	_TranslationsSettingsAboutLogsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '应用日志';
	@override String get empty => '暂无日志内容。';
	@override late final _TranslationsSettingsAboutLogsToastZhCn toast = _TranslationsSettingsAboutLogsToastZhCn._(_root);
}

// Path: dialogs.updateMirror.options
class _TranslationsDialogsUpdateMirrorOptionsZhCn extends _TranslationsDialogsUpdateMirrorOptionsEnUs {
	_TranslationsDialogsUpdateMirrorOptionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get github => 'Github';
	@override String get fdroid => 'F-Droid';
}

// Path: library.common.toast
class _TranslationsLibraryCommonToastZhCn extends _TranslationsLibraryCommonToastEnUs {
	_TranslationsLibraryCommonToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get editMode => '当前为编辑模式';
}

// Path: library.popular.toast
class _TranslationsLibraryPopularToastZhCn extends _TranslationsLibraryPopularToastEnUs {
	_TranslationsLibraryPopularToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get backPress => '再按一次退出应用';
}

// Path: library.timeline.weekdays
class _TranslationsLibraryTimelineWeekdaysZhCn extends _TranslationsLibraryTimelineWeekdaysEnUs {
	_TranslationsLibraryTimelineWeekdaysZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get mon => '一';
	@override String get tue => '二';
	@override String get wed => '三';
	@override String get thu => '四';
	@override String get fri => '五';
	@override String get sat => '六';
	@override String get sun => '日';
}

// Path: library.timeline.seasonPicker
class _TranslationsLibraryTimelineSeasonPickerZhCn extends _TranslationsLibraryTimelineSeasonPickerEnUs {
	_TranslationsLibraryTimelineSeasonPickerZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '时间机器';
	@override String get yearLabel => '{year}年';
}

// Path: library.timeline.season
class _TranslationsLibraryTimelineSeasonZhCn extends _TranslationsLibraryTimelineSeasonEnUs {
	_TranslationsLibraryTimelineSeasonZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '{year}年{season}新番';
	@override String get loading => '加载中…';
	@override late final _TranslationsLibraryTimelineSeasonNamesZhCn names = _TranslationsLibraryTimelineSeasonNamesZhCn._(_root);
	@override late final _TranslationsLibraryTimelineSeasonShortZhCn short = _TranslationsLibraryTimelineSeasonShortZhCn._(_root);
}

// Path: library.timeline.sort
class _TranslationsLibraryTimelineSortZhCn extends _TranslationsLibraryTimelineSortEnUs {
	_TranslationsLibraryTimelineSortZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '排序方式';
	@override String get byHeat => '按热度排序';
	@override String get byRating => '按评分排序';
	@override String get byTime => '按时间排序';
}

// Path: library.search.sort
class _TranslationsLibrarySearchSortZhCn extends _TranslationsLibrarySearchSortEnUs {
	_TranslationsLibrarySearchSortZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get label => '搜索排序';
	@override String get byHeat => '按热度排序';
	@override String get byRating => '按评分排序';
	@override String get byRelevance => '按相关度排序';
}

// Path: library.history.chips
class _TranslationsLibraryHistoryChipsZhCn extends _TranslationsLibraryHistoryChipsEnUs {
	_TranslationsLibraryHistoryChipsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get source => '来源';
	@override String get progress => '已看到';
	@override String get episodeNumber => '第{number}话';
}

// Path: library.history.toast
class _TranslationsLibraryHistoryToastZhCn extends _TranslationsLibraryHistoryToastEnUs {
	_TranslationsLibraryHistoryToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get sourceMissing => '未找到关联视频源';
}

// Path: library.history.manage
class _TranslationsLibraryHistoryManageZhCn extends _TranslationsLibraryHistoryManageEnUs {
	_TranslationsLibraryHistoryManageZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '记录管理';
	@override String get confirmClear => '确认要清除所有历史记录吗？';
	@override String get cancel => '取消';
	@override String get confirm => '确认';
}

// Path: library.info.summary
class _TranslationsLibraryInfoSummaryZhCn extends _TranslationsLibraryInfoSummaryEnUs {
	_TranslationsLibraryInfoSummaryZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '简介';
	@override String get expand => '加载更多';
	@override String get collapse => '加载更少';
}

// Path: library.info.tags
class _TranslationsLibraryInfoTagsZhCn extends _TranslationsLibraryInfoTagsEnUs {
	_TranslationsLibraryInfoTagsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '标签';
	@override String get more => '更多 +';
}

// Path: library.info.metadata
class _TranslationsLibraryInfoMetadataZhCn extends _TranslationsLibraryInfoMetadataEnUs {
	_TranslationsLibraryInfoMetadataZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get refresh => '刷新';
	@override String get syncingTitle => '正在同步元数据…';
	@override String get syncingSubtitle => '首次同步可能需要几秒钟。';
	@override String get emptyTitle => '尚未获取官方元数据';
	@override String get emptySubtitle => '稍后重试或检查设置中的元数据开关。';
	@override String source({required Object source}) => '元数据来自 ${source}';
	@override String updated({required Object timestamp, required Object language}) => '最后更新：${timestamp} · 语言：${language}';
	@override String get languageSystem => '系统默认';
	@override String get multiSource => '多源合并';
}

// Path: library.info.episodes
class _TranslationsLibraryInfoEpisodesZhCn extends _TranslationsLibraryInfoEpisodesEnUs {
	_TranslationsLibraryInfoEpisodesZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '剧集';
	@override String get collapse => '收起';
	@override String expand({required Object count}) => '展开全部 (${count})';
	@override String numberedEpisode({required Object number}) => '第${number}话';
	@override String get dateUnknown => '日期待定';
	@override String get runtimeUnknown => '时长未知';
	@override String runtimeMinutes({required Object minutes}) => '${minutes} 分钟';
}

// Path: library.info.errors
class _TranslationsLibraryInfoErrorsZhCn extends _TranslationsLibraryInfoErrorsEnUs {
	_TranslationsLibraryInfoErrorsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get fetchFailed => '获取失败，请重试';
}

// Path: library.info.tabs
class _TranslationsLibraryInfoTabsZhCn extends _TranslationsLibraryInfoTabsEnUs {
	_TranslationsLibraryInfoTabsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get overview => '概览';
	@override String get comments => '短评';
	@override String get characters => '角色';
	@override String get reviews => '评论';
	@override String get staff => '制作人员';
	@override String get placeholder => '施工中';
}

// Path: library.info.actions
class _TranslationsLibraryInfoActionsZhCn extends _TranslationsLibraryInfoActionsEnUs {
	_TranslationsLibraryInfoActionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get startWatching => '开始观看';
}

// Path: library.info.toast
class _TranslationsLibraryInfoToastZhCn extends _TranslationsLibraryInfoToastEnUs {
	_TranslationsLibraryInfoToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get characterSortFailed => '角色排序失败：{details}';
}

// Path: library.info.sourceSheet
class _TranslationsLibraryInfoSourceSheetZhCn extends _TranslationsLibraryInfoSourceSheetEnUs {
	_TranslationsLibraryInfoSourceSheetZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '选择播放源 ({name})';
	@override late final _TranslationsLibraryInfoSourceSheetAliasZhCn alias = _TranslationsLibraryInfoSourceSheetAliasZhCn._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetToastZhCn toast = _TranslationsLibraryInfoSourceSheetToastZhCn._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetSortZhCn sort = _TranslationsLibraryInfoSourceSheetSortZhCn._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetCardZhCn card = _TranslationsLibraryInfoSourceSheetCardZhCn._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetActionsZhCn actions = _TranslationsLibraryInfoSourceSheetActionsZhCn._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetStatusZhCn status = _TranslationsLibraryInfoSourceSheetStatusZhCn._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetEmptyZhCn empty = _TranslationsLibraryInfoSourceSheetEmptyZhCn._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetDialogZhCn dialog = _TranslationsLibraryInfoSourceSheetDialogZhCn._(_root);
}

// Path: library.my.sections
class _TranslationsLibraryMySectionsZhCn extends _TranslationsLibraryMySectionsEnUs {
	_TranslationsLibraryMySectionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get video => '视频';
}

// Path: library.my.favorites
class _TranslationsLibraryMyFavoritesZhCn extends _TranslationsLibraryMyFavoritesEnUs {
	_TranslationsLibraryMyFavoritesZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '收藏';
	@override String get description => '查看在看、想看、看过';
	@override String get empty => '暂无收藏记录。';
	@override late final _TranslationsLibraryMyFavoritesTabsZhCn tabs = _TranslationsLibraryMyFavoritesTabsZhCn._(_root);
	@override late final _TranslationsLibraryMyFavoritesSyncZhCn sync = _TranslationsLibraryMyFavoritesSyncZhCn._(_root);
}

// Path: library.my.history
class _TranslationsLibraryMyHistoryZhCn extends _TranslationsLibraryMyHistoryEnUs {
	_TranslationsLibraryMyHistoryZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '播放历史记录';
	@override String get description => '查看播放过的视频';
}

// Path: playback.controls.speed
class _TranslationsPlaybackControlsSpeedZhCn extends _TranslationsPlaybackControlsSpeedEnUs {
	_TranslationsPlaybackControlsSpeedZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '播放速度';
	@override String get reset => '默认速度';
}

// Path: playback.controls.skip
class _TranslationsPlaybackControlsSkipZhCn extends _TranslationsPlaybackControlsSkipEnUs {
	_TranslationsPlaybackControlsSkipZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '跳过秒数';
	@override String get tooltip => '长按修改时间';
}

// Path: playback.controls.status
class _TranslationsPlaybackControlsStatusZhCn extends _TranslationsPlaybackControlsStatusEnUs {
	_TranslationsPlaybackControlsStatusZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get fastForward => '快进 {seconds} 秒';
	@override String get rewind => '快退 {seconds} 秒';
	@override String get speed => '倍速播放';
}

// Path: playback.controls.superResolution
class _TranslationsPlaybackControlsSuperResolutionZhCn extends _TranslationsPlaybackControlsSuperResolutionEnUs {
	_TranslationsPlaybackControlsSuperResolutionZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get label => '超分辨率';
	@override String get off => '关闭';
	@override String get balanced => '效率档';
	@override String get quality => '质量档';
}

// Path: playback.controls.speedMenu
class _TranslationsPlaybackControlsSpeedMenuZhCn extends _TranslationsPlaybackControlsSpeedMenuEnUs {
	_TranslationsPlaybackControlsSpeedMenuZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get label => '倍速';
}

// Path: playback.controls.aspectRatio
class _TranslationsPlaybackControlsAspectRatioZhCn extends _TranslationsPlaybackControlsAspectRatioEnUs {
	_TranslationsPlaybackControlsAspectRatioZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get label => '视频比例';
	@override late final _TranslationsPlaybackControlsAspectRatioOptionsZhCn options = _TranslationsPlaybackControlsAspectRatioOptionsZhCn._(_root);
}

// Path: playback.controls.tooltips
class _TranslationsPlaybackControlsTooltipsZhCn extends _TranslationsPlaybackControlsTooltipsEnUs {
	_TranslationsPlaybackControlsTooltipsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get danmakuOn => '关闭弹幕(d)';
	@override String get danmakuOff => '打开弹幕(d)';
}

// Path: playback.controls.menu
class _TranslationsPlaybackControlsMenuZhCn extends _TranslationsPlaybackControlsMenuEnUs {
	_TranslationsPlaybackControlsMenuZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get danmakuToggle => '弹幕切换';
	@override String get videoInfo => '视频详情';
	@override String get cast => '远程投屏';
	@override String get external => '外部播放';
}

// Path: playback.controls.syncplay
class _TranslationsPlaybackControlsSyncplayZhCn extends _TranslationsPlaybackControlsSyncplayEnUs {
	_TranslationsPlaybackControlsSyncplayZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get label => '一起看';
	@override String get room => '当前房间：{name}';
	@override String get roomEmpty => '未加入';
	@override String get latency => '网络延时：{ms}ms';
	@override String get join => '加入房间';
	@override String get switchServer => '切换服务器';
	@override String get disconnect => '断开连接';
}

// Path: playback.remote.toast
class _TranslationsPlaybackRemoteToastZhCn extends _TranslationsPlaybackRemoteToastEnUs {
	_TranslationsPlaybackRemoteToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get searching => '开始搜索';
	@override String get casting => '尝试投屏至 {device}';
	@override String get error => 'DLNA 异常: {details}\n尝试重新进入 DLNA 投屏或切换设备';
}

// Path: playback.debug.tabs
class _TranslationsPlaybackDebugTabsZhCn extends _TranslationsPlaybackDebugTabsEnUs {
	_TranslationsPlaybackDebugTabsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get status => '状态';
	@override String get logs => '日志';
}

// Path: playback.debug.sections
class _TranslationsPlaybackDebugSectionsZhCn extends _TranslationsPlaybackDebugSectionsEnUs {
	_TranslationsPlaybackDebugSectionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get source => '播放源';
	@override String get playback => '播放器状态';
	@override String get timing => '时间与参数';
	@override String get media => '媒体轨道';
}

// Path: playback.debug.labels
class _TranslationsPlaybackDebugLabelsZhCn extends _TranslationsPlaybackDebugLabelsEnUs {
	_TranslationsPlaybackDebugLabelsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get series => '视频';
	@override String get plugin => '插件';
	@override String get route => '线路';
	@override String get episode => '集数';
	@override String get routeCount => '线路数量';
	@override String get sourceTitle => '源标题';
	@override String get parsedUrl => '解析地址';
	@override String get playUrl => '播放地址';
	@override String get danmakuId => 'DanDan ID';
	@override String get syncRoom => 'SyncPlay 房间';
	@override String get syncLatency => 'SyncPlay RTT';
	@override String get nativePlayer => '原生播放器';
	@override String get parsing => '解析中';
	@override String get playerLoading => '播放器加载';
	@override String get playerInitializing => '播放器初始化';
	@override String get playing => '播放中';
	@override String get buffering => '缓冲中';
	@override String get completed => '播放完成';
	@override String get bufferFlag => '缓冲标志';
	@override String get currentPosition => '当前位置';
	@override String get bufferProgress => '缓冲进度';
	@override String get duration => '总时长';
	@override String get speed => '播放速度';
	@override String get volume => '音量';
	@override String get brightness => '亮度';
	@override String get resolution => '分辨率';
	@override String get aspectRatio => '视频比例';
	@override String get superResolution => '超分辨率';
	@override String get videoParams => '视频参数';
	@override String get audioParams => '音频参数';
	@override String get playlist => '播放列表';
	@override String get audioTracks => '音频轨';
	@override String get videoTracks => '视频轨';
	@override String get audioBitrate => '音频码率';
}

// Path: playback.debug.values
class _TranslationsPlaybackDebugValuesZhCn extends _TranslationsPlaybackDebugValuesEnUs {
	_TranslationsPlaybackDebugValuesZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get yes => '是';
	@override String get no => '否';
}

// Path: playback.debug.logs
class _TranslationsPlaybackDebugLogsZhCn extends _TranslationsPlaybackDebugLogsEnUs {
	_TranslationsPlaybackDebugLogsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get playerEmpty => '播放器日志（0）';
	@override String get playerSummary => '播放器日志（{count} 条，展示 {displayed} 条）';
	@override String get webviewEmpty => 'WebView 日志（0）';
	@override String get webviewSummary => 'WebView 日志（{count} 条，展示 {displayed} 条）';
}

// Path: playback.syncplay.selectServer
class _TranslationsPlaybackSyncplaySelectServerZhCn extends _TranslationsPlaybackSyncplaySelectServerEnUs {
	_TranslationsPlaybackSyncplaySelectServerZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '选择服务器';
	@override String get customTitle => '自定义服务器';
	@override String get customHint => '请输入服务器地址';
	@override String get duplicateOrEmpty => '服务器地址不能重复或为空';
}

// Path: playback.syncplay.join
class _TranslationsPlaybackSyncplayJoinZhCn extends _TranslationsPlaybackSyncplayJoinEnUs {
	_TranslationsPlaybackSyncplayJoinZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '加入房间';
	@override String get roomLabel => '房间号';
	@override String get roomEmpty => '请输入房间号';
	@override String get roomInvalid => '房间号需要6到10位数字';
	@override String get usernameLabel => '用户名';
	@override String get usernameEmpty => '请输入用户名';
	@override String get usernameInvalid => '用户名必须为4到12位英文字符';
}

// Path: playback.superResolution.warning
class _TranslationsPlaybackSuperResolutionWarningZhCn extends _TranslationsPlaybackSuperResolutionWarningEnUs {
	_TranslationsPlaybackSuperResolutionWarningZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '性能提示';
	@override String get message => '启用超分辨率（质量档）可能会造成设备卡顿，是否继续？';
	@override String get dontAskAgain => '下次不再询问';
}

// Path: settings.appearancePage.colorScheme.labels
class _TranslationsSettingsAppearancePageColorSchemeLabelsZhCn extends _TranslationsSettingsAppearancePageColorSchemeLabelsEnUs {
	_TranslationsSettingsAppearancePageColorSchemeLabelsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get defaultLabel => '默认';
	@override String get teal => '青色';
	@override String get blue => '蓝色';
	@override String get indigo => '靛蓝';
	@override String get violet => '紫罗兰';
	@override String get pink => '粉色';
	@override String get yellow => '黄色';
	@override String get orange => '橙色';
	@override String get deepOrange => '深橙色';
}

// Path: settings.plugins.sort.options
class _TranslationsSettingsPluginsSortOptionsZhCn extends _TranslationsSettingsPluginsSortOptionsEnUs {
	_TranslationsSettingsPluginsSortOptionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get original => '默认顺序';
	@override String get nameAsc => '名称升序';
	@override String get nameDesc => '名称降序';
	@override String get failureAsc => '失败次数升序';
	@override String get failureDesc => '失败次数降序';
}

// Path: settings.plugins.editor.fields
class _TranslationsSettingsPluginsEditorFieldsZhCn extends _TranslationsSettingsPluginsEditorFieldsEnUs {
	_TranslationsSettingsPluginsEditorFieldsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get name => '规则名称';
	@override String get version => '版本';
	@override String get baseUrl => '基础 URL';
	@override String get searchUrl => '搜索 URL';
	@override String get searchList => '搜索列表 XPath';
	@override String get searchName => '搜索标题 XPath';
	@override String get searchResult => '搜索结果 XPath';
	@override String get chapterRoads => '剧集线路 XPath';
	@override String get chapterResult => '剧集结果 XPath';
	@override String get userAgent => 'User-Agent';
	@override String get referer => 'Referer';
}

// Path: settings.plugins.editor.advanced
class _TranslationsSettingsPluginsEditorAdvancedZhCn extends _TranslationsSettingsPluginsEditorAdvancedEnUs {
	_TranslationsSettingsPluginsEditorAdvancedZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '高级配置';
	@override late final _TranslationsSettingsPluginsEditorAdvancedLegacyParserZhCn legacyParser = _TranslationsSettingsPluginsEditorAdvancedLegacyParserZhCn._(_root);
	@override late final _TranslationsSettingsPluginsEditorAdvancedHttpPostZhCn httpPost = _TranslationsSettingsPluginsEditorAdvancedHttpPostZhCn._(_root);
	@override late final _TranslationsSettingsPluginsEditorAdvancedNativePlayerZhCn nativePlayer = _TranslationsSettingsPluginsEditorAdvancedNativePlayerZhCn._(_root);
}

// Path: settings.plugins.shop.tooltip
class _TranslationsSettingsPluginsShopTooltipZhCn extends _TranslationsSettingsPluginsShopTooltipEnUs {
	_TranslationsSettingsPluginsShopTooltipZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get sortByName => '按名称排序';
	@override String get sortByUpdate => '按更新时间排序';
	@override String get refresh => '刷新规则列表';
}

// Path: settings.plugins.shop.labels
class _TranslationsSettingsPluginsShopLabelsZhCn extends _TranslationsSettingsPluginsShopLabelsEnUs {
	_TranslationsSettingsPluginsShopLabelsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsSettingsPluginsShopLabelsPlayerTypeZhCn playerType = _TranslationsSettingsPluginsShopLabelsPlayerTypeZhCn._(_root);
	@override String get lastUpdated => '更新时间: {timestamp}';
}

// Path: settings.plugins.shop.buttons
class _TranslationsSettingsPluginsShopButtonsZhCn extends _TranslationsSettingsPluginsShopButtonsEnUs {
	_TranslationsSettingsPluginsShopButtonsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get install => '添加';
	@override String get installed => '已添加';
	@override String get update => '更新';
	@override String get toggleMirrorEnable => '启用镜像';
	@override String get toggleMirrorDisable => '禁用镜像';
	@override String get refresh => '刷新';
}

// Path: settings.plugins.shop.toast
class _TranslationsSettingsPluginsShopToastZhCn extends _TranslationsSettingsPluginsShopToastEnUs {
	_TranslationsSettingsPluginsShopToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get importFailed => '导入规则失败';
}

// Path: settings.plugins.shop.error
class _TranslationsSettingsPluginsShopErrorZhCn extends _TranslationsSettingsPluginsShopErrorEnUs {
	_TranslationsSettingsPluginsShopErrorZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get unreachable => '无法访问远程仓库\n{status}';
	@override String get mirrorEnabled => '镜像已启用';
	@override String get mirrorDisabled => '镜像已禁用';
}

// Path: settings.player.superResolutionOptions.off
class _TranslationsSettingsPlayerSuperResolutionOptionsOffZhCn extends _TranslationsSettingsPlayerSuperResolutionOptionsOffEnUs {
	_TranslationsSettingsPlayerSuperResolutionOptionsOffZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get label => '关闭';
	@override String get description => '不启用画面增强。';
}

// Path: settings.player.superResolutionOptions.efficiency
class _TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyZhCn extends _TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyEnUs {
	_TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get label => '高效模式';
	@override String get description => '在性能消耗与画质提升之间取得平衡。';
}

// Path: settings.player.superResolutionOptions.quality
class _TranslationsSettingsPlayerSuperResolutionOptionsQualityZhCn extends _TranslationsSettingsPlayerSuperResolutionOptionsQualityEnUs {
	_TranslationsSettingsPlayerSuperResolutionOptionsQualityZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get label => '画质优先';
	@override String get description => '最大化画质提升，可能增加资源消耗。';
}

// Path: settings.webdav.editor.toast
class _TranslationsSettingsWebdavEditorToastZhCn extends _TranslationsSettingsWebdavEditorToastEnUs {
	_TranslationsSettingsWebdavEditorToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get saveSuccess => '配置已保存，开始测试...';
	@override String get saveFailed => '配置失败：{error}';
	@override String get testSuccess => '测试成功。';
	@override String get testFailed => '测试失败：{error}';
}

// Path: settings.update.dialog.actions
class _TranslationsSettingsUpdateDialogActionsZhCn extends _TranslationsSettingsUpdateDialogActionsEnUs {
	_TranslationsSettingsUpdateDialogActionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get disableAutoUpdate => '关闭自动更新';
	@override String get remindLater => '稍后提醒';
	@override String get viewDetails => '查看详情';
	@override String get updateNow => '立即更新';
}

// Path: settings.update.download.error
class _TranslationsSettingsUpdateDownloadErrorZhCn extends _TranslationsSettingsUpdateDownloadErrorEnUs {
	_TranslationsSettingsUpdateDownloadErrorZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '下载失败';
	@override String get general => '无法下载更新。';
	@override String get permission => '没有写入文件的权限。';
	@override String get diskFull => '磁盘空间不足。';
	@override String get network => '网络连接失败。';
	@override String get integrity => '文件校验失败，请重新下载。';
	@override String get details => '详细信息：{error}';
	@override String get confirm => '确定';
	@override String get retry => '重试';
}

// Path: settings.update.download.complete
class _TranslationsSettingsUpdateDownloadCompleteZhCn extends _TranslationsSettingsUpdateDownloadCompleteEnUs {
	_TranslationsSettingsUpdateDownloadCompleteZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '下载完成';
	@override String get message => '已下载 Haipee {version}。';
	@override String get quitNotice => '安装过程中应用将退出。';
	@override String get fileLocation => '文件位置';
	@override late final _TranslationsSettingsUpdateDownloadCompleteButtonsZhCn buttons = _TranslationsSettingsUpdateDownloadCompleteButtonsZhCn._(_root);
}

// Path: settings.about.sections.licenses
class _TranslationsSettingsAboutSectionsLicensesZhCn extends _TranslationsSettingsAboutSectionsLicensesEnUs {
	_TranslationsSettingsAboutSectionsLicensesZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '开源许可证';
	@override String get description => '查看所有开源许可证';
}

// Path: settings.about.sections.links
class _TranslationsSettingsAboutSectionsLinksZhCn extends _TranslationsSettingsAboutSectionsLinksEnUs {
	_TranslationsSettingsAboutSectionsLinksZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '外部链接';
	@override String get project => '项目主页';
	@override String get repository => '代码仓库';
	@override String get icon => '图标创作';
	@override String get index => '视频索引';
	@override String get danmaku => '弹幕源';
	@override String get danmakuId => 'ID：{id}';
}

// Path: settings.about.sections.cache
class _TranslationsSettingsAboutSectionsCacheZhCn extends _TranslationsSettingsAboutSectionsCacheEnUs {
	_TranslationsSettingsAboutSectionsCacheZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get clearAction => '清除缓存';
	@override String get sizePending => '统计中…';
	@override String get sizeLabel => '{size} MB';
}

// Path: settings.about.sections.updates
class _TranslationsSettingsAboutSectionsUpdatesZhCn extends _TranslationsSettingsAboutSectionsUpdatesEnUs {
	_TranslationsSettingsAboutSectionsUpdatesZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '应用更新';
	@override String get autoUpdate => '自动更新';
	@override String get check => '检查更新';
	@override String get currentVersion => '当前版本 {version}';
}

// Path: settings.about.logs.toast
class _TranslationsSettingsAboutLogsToastZhCn extends _TranslationsSettingsAboutLogsToastEnUs {
	_TranslationsSettingsAboutLogsToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get cleared => '日志已清空。';
	@override String get clearFailed => '清空日志失败。';
}

// Path: library.timeline.season.names
class _TranslationsLibraryTimelineSeasonNamesZhCn extends _TranslationsLibraryTimelineSeasonNamesEnUs {
	_TranslationsLibraryTimelineSeasonNamesZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get winter => '冬季';
	@override String get spring => '春季';
	@override String get summer => '夏季';
	@override String get autumn => '秋季';
}

// Path: library.timeline.season.short
class _TranslationsLibraryTimelineSeasonShortZhCn extends _TranslationsLibraryTimelineSeasonShortEnUs {
	_TranslationsLibraryTimelineSeasonShortZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get winter => '冬';
	@override String get spring => '春';
	@override String get summer => '夏';
	@override String get autumn => '秋';
}

// Path: library.info.sourceSheet.alias
class _TranslationsLibraryInfoSourceSheetAliasZhCn extends _TranslationsLibraryInfoSourceSheetAliasEnUs {
	_TranslationsLibraryInfoSourceSheetAliasZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get deleteTooltip => '删除别名';
	@override String get deleteTitle => '删除别名';
	@override String get deleteMessage => '删除后无法恢复，确认要永久删除这个别名吗？';
}

// Path: library.info.sourceSheet.toast
class _TranslationsLibraryInfoSourceSheetToastZhCn extends _TranslationsLibraryInfoSourceSheetToastEnUs {
	_TranslationsLibraryInfoSourceSheetToastZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get aliasEmpty => '暂无可用别名，请先手动添加后再检索。';
	@override String get loadFailed => '获取视频播放列表失败。';
	@override String get removed => '已删除源 {plugin}。';
}

// Path: library.info.sourceSheet.sort
class _TranslationsLibraryInfoSourceSheetSortZhCn extends _TranslationsLibraryInfoSourceSheetSortEnUs {
	_TranslationsLibraryInfoSourceSheetSortZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '排序方式';
	@override String get tooltip => '排序：{label}';
	@override late final _TranslationsLibraryInfoSourceSheetSortOptionsZhCn options = _TranslationsLibraryInfoSourceSheetSortOptionsZhCn._(_root);
}

// Path: library.info.sourceSheet.card
class _TranslationsLibraryInfoSourceSheetCardZhCn extends _TranslationsLibraryInfoSourceSheetCardEnUs {
	_TranslationsLibraryInfoSourceSheetCardZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '源 · {plugin}';
	@override String get play => '播放';
}

// Path: library.info.sourceSheet.actions
class _TranslationsLibraryInfoSourceSheetActionsZhCn extends _TranslationsLibraryInfoSourceSheetActionsEnUs {
	_TranslationsLibraryInfoSourceSheetActionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get searchAgain => '重新检索';
	@override String get aliasSearch => '别名检索';
	@override String get removeSource => '删除源';
}

// Path: library.info.sourceSheet.status
class _TranslationsLibraryInfoSourceSheetStatusZhCn extends _TranslationsLibraryInfoSourceSheetStatusEnUs {
	_TranslationsLibraryInfoSourceSheetStatusZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get searching => '{plugin} 检索中…';
	@override String get failed => '{plugin} 检索失败';
	@override String get empty => '{plugin} 无检索结果';
}

// Path: library.info.sourceSheet.empty
class _TranslationsLibraryInfoSourceSheetEmptyZhCn extends _TranslationsLibraryInfoSourceSheetEmptyEnUs {
	_TranslationsLibraryInfoSourceSheetEmptyZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get searching => '检索中，请稍候…';
	@override String get noResults => '暂无可用视频源，请尝试重新检索或使用别名检索。';
}

// Path: library.info.sourceSheet.dialog
class _TranslationsLibraryInfoSourceSheetDialogZhCn extends _TranslationsLibraryInfoSourceSheetDialogEnUs {
	_TranslationsLibraryInfoSourceSheetDialogZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get removeTitle => '删除源';
	@override String get removeMessage => '确定要删除源 {plugin} 吗？';
}

// Path: library.my.favorites.tabs
class _TranslationsLibraryMyFavoritesTabsZhCn extends _TranslationsLibraryMyFavoritesTabsEnUs {
	_TranslationsLibraryMyFavoritesTabsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get watching => '在看';
	@override String get planned => '想看';
	@override String get completed => '看过';
	@override String get empty => '暂无记录。';
}

// Path: library.my.favorites.sync
class _TranslationsLibraryMyFavoritesSyncZhCn extends _TranslationsLibraryMyFavoritesSyncEnUs {
	_TranslationsLibraryMyFavoritesSyncZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get disabled => '未启用 WebDAV，同步功能不可用。';
	@override String get editing => '编辑模式下无法执行同步。';
}

// Path: playback.controls.aspectRatio.options
class _TranslationsPlaybackControlsAspectRatioOptionsZhCn extends _TranslationsPlaybackControlsAspectRatioOptionsEnUs {
	_TranslationsPlaybackControlsAspectRatioOptionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get auto => '自动';
	@override String get crop => '裁切填充';
	@override String get stretch => '拉伸填充';
}

// Path: settings.plugins.editor.advanced.legacyParser
class _TranslationsSettingsPluginsEditorAdvancedLegacyParserZhCn extends _TranslationsSettingsPluginsEditorAdvancedLegacyParserEnUs {
	_TranslationsSettingsPluginsEditorAdvancedLegacyParserZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '启用旧版解析';
	@override String get subtitle => '使用旧版 XPath 解析逻辑以兼容部分规则。';
}

// Path: settings.plugins.editor.advanced.httpPost
class _TranslationsSettingsPluginsEditorAdvancedHttpPostZhCn extends _TranslationsSettingsPluginsEditorAdvancedHttpPostEnUs {
	_TranslationsSettingsPluginsEditorAdvancedHttpPostZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '使用 POST 请求';
	@override String get subtitle => '以 HTTP POST 方式发送搜索请求。';
}

// Path: settings.plugins.editor.advanced.nativePlayer
class _TranslationsSettingsPluginsEditorAdvancedNativePlayerZhCn extends _TranslationsSettingsPluginsEditorAdvancedNativePlayerEnUs {
	_TranslationsSettingsPluginsEditorAdvancedNativePlayerZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get title => '强制原生播放器';
	@override String get subtitle => '优先使用内置播放器播放链接。';
}

// Path: settings.plugins.shop.labels.playerType
class _TranslationsSettingsPluginsShopLabelsPlayerTypeZhCn extends _TranslationsSettingsPluginsShopLabelsPlayerTypeEnUs {
	_TranslationsSettingsPluginsShopLabelsPlayerTypeZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get native => 'native';
	@override String get webview => 'webview';
}

// Path: settings.update.download.complete.buttons
class _TranslationsSettingsUpdateDownloadCompleteButtonsZhCn extends _TranslationsSettingsUpdateDownloadCompleteButtonsEnUs {
	_TranslationsSettingsUpdateDownloadCompleteButtonsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get later => '稍后再说';
	@override String get openFolder => '打开文件夹';
	@override String get installNow => '立即安装';
}

// Path: library.info.sourceSheet.sort.options
class _TranslationsLibraryInfoSourceSheetSortOptionsZhCn extends _TranslationsLibraryInfoSourceSheetSortOptionsEnUs {
	_TranslationsLibraryInfoSourceSheetSortOptionsZhCn._(_TranslationsZhCn root) : this._root = root, super._(root);

	@override final _TranslationsZhCn _root; // ignore: unused_field

	// Translations
	@override String get original => '默认顺序';
	@override String get nameAsc => '名称升序';
	@override String get nameDesc => '名称降序';
	@override String get failureAsc => '失败次数升序';
	@override String get failureDesc => '失败次数降序';
}

// Path: <root>
class _TranslationsZhTw extends AppTranslations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	_TranslationsZhTw.build({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = TranslationMetadata(
		    locale: AppLocale.zhTw,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super.build(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh-TW>.
	@override final TranslationMetadata<AppLocale, AppTranslations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	@override late final _TranslationsZhTw _root = this; // ignore: unused_field

	// Translations
	@override late final _TranslationsAppZhTw app = _TranslationsAppZhTw._(_root);
	@override late final _TranslationsMetadataZhTw metadata = _TranslationsMetadataZhTw._(_root);
	@override late final _TranslationsDownloadsZhTw downloads = _TranslationsDownloadsZhTw._(_root);
	@override late final _TranslationsTorrentZhTw torrent = _TranslationsTorrentZhTw._(_root);
	@override late final _TranslationsSettingsZhTw settings = _TranslationsSettingsZhTw._(_root);
	@override late final _TranslationsExitDialogZhTw exitDialog = _TranslationsExitDialogZhTw._(_root);
	@override late final _TranslationsTrayZhTw tray = _TranslationsTrayZhTw._(_root);
	@override late final _TranslationsNavigationZhTw navigation = _TranslationsNavigationZhTw._(_root);
	@override late final _TranslationsDialogsZhTw dialogs = _TranslationsDialogsZhTw._(_root);
	@override late final _TranslationsLibraryZhTw library = _TranslationsLibraryZhTw._(_root);
	@override late final _TranslationsPlaybackZhTw playback = _TranslationsPlaybackZhTw._(_root);
	@override late final _TranslationsNetworkZhTw network = _TranslationsNetworkZhTw._(_root);
	@override late final _TranslationsSyncZhTw sync = _TranslationsSyncZhTw._(_root);
}

// Path: app
class _TranslationsAppZhTw extends _TranslationsAppEnUs {
	_TranslationsAppZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => 'Haipee';
	@override String get loading => '載入中…';
	@override String get retry => '重試';
	@override String get confirm => '確認';
	@override String get cancel => '取消';
	@override String get delete => '刪除';
}

// Path: metadata
class _TranslationsMetadataZhTw extends _TranslationsMetadataEnUs {
	_TranslationsMetadataZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get sectionTitle => '媒體資訊';
	@override String get refresh => '重新整理中繼資料';
	@override late final _TranslationsMetadataSourceZhTw source = _TranslationsMetadataSourceZhTw._(_root);
	@override String get lastSynced => '最後同步：{timestamp}';
}

// Path: downloads
class _TranslationsDownloadsZhTw extends _TranslationsDownloadsEnUs {
	_TranslationsDownloadsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get sectionTitle => '下載佇列';
	@override String get downloadOffline => '下載引擎未連線';
	@override String get queued => '排隊中';
	@override String get running => '下載中';
	@override String get completed => '已完成';
}

// Path: torrent
class _TranslationsTorrentZhTw extends _TranslationsTorrentEnUs {
	_TranslationsTorrentZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsTorrentConsentZhTw consent = _TranslationsTorrentConsentZhTw._(_root);
	@override late final _TranslationsTorrentErrorZhTw error = _TranslationsTorrentErrorZhTw._(_root);
}

// Path: settings
class _TranslationsSettingsZhTw extends _TranslationsSettingsEnUs {
	_TranslationsSettingsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '設定';
	@override String get downloads => '下載設定';
	@override String get playback => '播放偏好';
	@override late final _TranslationsSettingsGeneralZhTw general = _TranslationsSettingsGeneralZhTw._(_root);
	@override late final _TranslationsSettingsAppearancePageZhTw appearancePage = _TranslationsSettingsAppearancePageZhTw._(_root);
	@override late final _TranslationsSettingsSourceZhTw source = _TranslationsSettingsSourceZhTw._(_root);
	@override late final _TranslationsSettingsPluginsZhTw plugins = _TranslationsSettingsPluginsZhTw._(_root);
	@override late final _TranslationsSettingsMetadataZhTw metadata = _TranslationsSettingsMetadataZhTw._(_root);
	@override late final _TranslationsSettingsPlayerZhTw player = _TranslationsSettingsPlayerZhTw._(_root);
	@override late final _TranslationsSettingsWebdavZhTw webdav = _TranslationsSettingsWebdavZhTw._(_root);
	@override late final _TranslationsSettingsUpdateZhTw update = _TranslationsSettingsUpdateZhTw._(_root);
	@override late final _TranslationsSettingsOtherZhTw other = _TranslationsSettingsOtherZhTw._(_root);
	@override late final _TranslationsSettingsAboutZhTw about = _TranslationsSettingsAboutZhTw._(_root);
}

// Path: exitDialog
class _TranslationsExitDialogZhTw extends _TranslationsExitDialogEnUs {
	_TranslationsExitDialogZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '結束確認';
	@override String get message => '您想要結束 Haipee 嗎？';
	@override String get dontAskAgain => '下次不要再詢問';
	@override String get exit => '結束 Haipee';
	@override String get minimize => '最小化至系統匣';
	@override String get cancel => '取消';
}

// Path: tray
class _TranslationsTrayZhTw extends _TranslationsTrayEnUs {
	_TranslationsTrayZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get showWindow => '顯示視窗';
	@override String get exit => '結束 Haipee';
}

// Path: navigation
class _TranslationsNavigationZhTw extends _TranslationsNavigationEnUs {
	_TranslationsNavigationZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsNavigationTabsZhTw tabs = _TranslationsNavigationTabsZhTw._(_root);
	@override late final _TranslationsNavigationActionsZhTw actions = _TranslationsNavigationActionsZhTw._(_root);
}

// Path: dialogs
class _TranslationsDialogsZhTw extends _TranslationsDialogsEnUs {
	_TranslationsDialogsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsDialogsDisclaimerZhTw disclaimer = _TranslationsDialogsDisclaimerZhTw._(_root);
	@override late final _TranslationsDialogsUpdateMirrorZhTw updateMirror = _TranslationsDialogsUpdateMirrorZhTw._(_root);
	@override late final _TranslationsDialogsPluginUpdatesZhTw pluginUpdates = _TranslationsDialogsPluginUpdatesZhTw._(_root);
	@override late final _TranslationsDialogsWebdavZhTw webdav = _TranslationsDialogsWebdavZhTw._(_root);
	@override late final _TranslationsDialogsAboutZhTw about = _TranslationsDialogsAboutZhTw._(_root);
	@override late final _TranslationsDialogsCacheZhTw cache = _TranslationsDialogsCacheZhTw._(_root);
}

// Path: library
class _TranslationsLibraryZhTw extends _TranslationsLibraryEnUs {
	_TranslationsLibraryZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsLibraryCommonZhTw common = _TranslationsLibraryCommonZhTw._(_root);
	@override late final _TranslationsLibraryPopularZhTw popular = _TranslationsLibraryPopularZhTw._(_root);
	@override late final _TranslationsLibraryTimelineZhTw timeline = _TranslationsLibraryTimelineZhTw._(_root);
	@override late final _TranslationsLibrarySearchZhTw search = _TranslationsLibrarySearchZhTw._(_root);
	@override late final _TranslationsLibraryHistoryZhTw history = _TranslationsLibraryHistoryZhTw._(_root);
	@override late final _TranslationsLibraryInfoZhTw info = _TranslationsLibraryInfoZhTw._(_root);
	@override late final _TranslationsLibraryMyZhTw my = _TranslationsLibraryMyZhTw._(_root);
}

// Path: playback
class _TranslationsPlaybackZhTw extends _TranslationsPlaybackEnUs {
	_TranslationsPlaybackZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsPlaybackToastZhTw toast = _TranslationsPlaybackToastZhTw._(_root);
	@override late final _TranslationsPlaybackDanmakuZhTw danmaku = _TranslationsPlaybackDanmakuZhTw._(_root);
	@override late final _TranslationsPlaybackExternalPlayerZhTw externalPlayer = _TranslationsPlaybackExternalPlayerZhTw._(_root);
	@override late final _TranslationsPlaybackControlsZhTw controls = _TranslationsPlaybackControlsZhTw._(_root);
	@override late final _TranslationsPlaybackLoadingZhTw loading = _TranslationsPlaybackLoadingZhTw._(_root);
	@override late final _TranslationsPlaybackDanmakuSearchZhTw danmakuSearch = _TranslationsPlaybackDanmakuSearchZhTw._(_root);
	@override late final _TranslationsPlaybackRemoteZhTw remote = _TranslationsPlaybackRemoteZhTw._(_root);
	@override late final _TranslationsPlaybackDebugZhTw debug = _TranslationsPlaybackDebugZhTw._(_root);
	@override late final _TranslationsPlaybackSyncplayZhTw syncplay = _TranslationsPlaybackSyncplayZhTw._(_root);
	@override late final _TranslationsPlaybackPlaylistZhTw playlist = _TranslationsPlaybackPlaylistZhTw._(_root);
	@override late final _TranslationsPlaybackTabsZhTw tabs = _TranslationsPlaybackTabsZhTw._(_root);
	@override late final _TranslationsPlaybackCommentsZhTw comments = _TranslationsPlaybackCommentsZhTw._(_root);
	@override late final _TranslationsPlaybackSuperResolutionZhTw superResolution = _TranslationsPlaybackSuperResolutionZhTw._(_root);
}

// Path: network
class _TranslationsNetworkZhTw extends _TranslationsNetworkEnUs {
	_TranslationsNetworkZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsNetworkErrorZhTw error = _TranslationsNetworkErrorZhTw._(_root);
	@override late final _TranslationsNetworkStatusZhTw status = _TranslationsNetworkStatusZhTw._(_root);
}

// Path: sync
class _TranslationsSyncZhTw extends _TranslationsSyncEnUs {
	_TranslationsSyncZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
}

// Path: metadata.source
class _TranslationsMetadataSourceZhTw extends _TranslationsMetadataSourceEnUs {
	_TranslationsMetadataSourceZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get bangumi => 'Bangumi';
	@override String get tmdb => 'TMDb';
}

// Path: torrent.consent
class _TranslationsTorrentConsentZhTw extends _TranslationsTorrentConsentEnUs {
	_TranslationsTorrentConsentZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => 'BitTorrent 使用通知';
	@override String get description => '啟用 BT 下載前，請確認遵守所在地法律並了解使用風險。';
	@override String get agree => '我已知悉，繼續';
	@override String get decline => '暫不開啟';
}

// Path: torrent.error
class _TranslationsTorrentErrorZhTw extends _TranslationsTorrentErrorEnUs {
	_TranslationsTorrentErrorZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get submit => '無法提交磁力連結，稍後重試';
}

// Path: settings.general
class _TranslationsSettingsGeneralZhTw extends _TranslationsSettingsGeneralEnUs {
	_TranslationsSettingsGeneralZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '一般';
	@override String get appearance => '外觀';
	@override String get appearanceDesc => '設定應用程式主題和刷新率';
	@override String get language => '應用程式語言';
	@override String get languageDesc => '選擇應用程式介面的顯示語言';
	@override String get followSystem => '系統';
	@override String get exitBehavior => '關閉時';
	@override String get exitApp => '結束 Haipee';
	@override String get minimizeToTray => '最小化至系統匣';
	@override String get askEveryTime => '每次詢問';
}

// Path: settings.appearancePage
class _TranslationsSettingsAppearancePageZhTw extends _TranslationsSettingsAppearancePageEnUs {
	_TranslationsSettingsAppearancePageZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '外觀';
	@override late final _TranslationsSettingsAppearancePageModeZhTw mode = _TranslationsSettingsAppearancePageModeZhTw._(_root);
	@override late final _TranslationsSettingsAppearancePageColorSchemeZhTw colorScheme = _TranslationsSettingsAppearancePageColorSchemeZhTw._(_root);
	@override late final _TranslationsSettingsAppearancePageOledZhTw oled = _TranslationsSettingsAppearancePageOledZhTw._(_root);
	@override late final _TranslationsSettingsAppearancePageWindowZhTw window = _TranslationsSettingsAppearancePageWindowZhTw._(_root);
	@override late final _TranslationsSettingsAppearancePageRefreshRateZhTw refreshRate = _TranslationsSettingsAppearancePageRefreshRateZhTw._(_root);
}

// Path: settings.source
class _TranslationsSettingsSourceZhTw extends _TranslationsSettingsSourceEnUs {
	_TranslationsSettingsSourceZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '來源';
	@override String get ruleManagement => '規則管理';
	@override String get ruleManagementDesc => '管理動畫資源規則';
	@override String get githubProxy => 'GitHub 代理';
	@override String get githubProxyDesc => '使用代理存取規則儲存庫';
}

// Path: settings.plugins
class _TranslationsSettingsPluginsZhTw extends _TranslationsSettingsPluginsEnUs {
	_TranslationsSettingsPluginsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '規則管理';
	@override String get empty => '沒有可用的規則';
	@override late final _TranslationsSettingsPluginsTooltipZhTw tooltip = _TranslationsSettingsPluginsTooltipZhTw._(_root);
	@override late final _TranslationsSettingsPluginsSortZhTw sort = _TranslationsSettingsPluginsSortZhTw._(_root);
	@override late final _TranslationsSettingsPluginsMultiSelectZhTw multiSelect = _TranslationsSettingsPluginsMultiSelectZhTw._(_root);
	@override late final _TranslationsSettingsPluginsLoadingZhTw loading = _TranslationsSettingsPluginsLoadingZhTw._(_root);
	@override late final _TranslationsSettingsPluginsLabelsZhTw labels = _TranslationsSettingsPluginsLabelsZhTw._(_root);
	@override late final _TranslationsSettingsPluginsActionsZhTw actions = _TranslationsSettingsPluginsActionsZhTw._(_root);
	@override late final _TranslationsSettingsPluginsDialogsZhTw dialogs = _TranslationsSettingsPluginsDialogsZhTw._(_root);
	@override late final _TranslationsSettingsPluginsToastZhTw toast = _TranslationsSettingsPluginsToastZhTw._(_root);
	@override late final _TranslationsSettingsPluginsEditorZhTw editor = _TranslationsSettingsPluginsEditorZhTw._(_root);
	@override late final _TranslationsSettingsPluginsShopZhTw shop = _TranslationsSettingsPluginsShopZhTw._(_root);
}

// Path: settings.metadata
class _TranslationsSettingsMetadataZhTw extends _TranslationsSettingsMetadataEnUs {
	_TranslationsSettingsMetadataZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '資訊來源';
	@override String get enableBangumi => '啟用 Bangumi 資訊來源';
	@override String get enableBangumiDesc => '從 Bangumi 獲取動畫資訊';
	@override String get enableTmdb => '啟用 TMDb 資訊來源';
	@override String get enableTmdbDesc => '從 TMDb 補充多語言資料';
	@override String get preferredLanguage => '偏好語言';
	@override String get preferredLanguageDesc => '設定中繼資料同步的語言';
	@override String get followSystemLanguage => '跟隨系統語言';
	@override String get simplifiedChinese => '簡體中文（zh-CN）';
	@override String get traditionalChinese => '繁體中文（zh-TW）';
	@override String get japanese => '日語（ja-JP）';
	@override String get english => '英語（en-US）';
	@override String get custom => '自訂';
}

// Path: settings.player
class _TranslationsSettingsPlayerZhTw extends _TranslationsSettingsPlayerEnUs {
	_TranslationsSettingsPlayerZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '播放器設定';
	@override String get playerSettings => '播放器設定';
	@override String get playerSettingsDesc => '設定播放器參數';
	@override String get hardwareDecoding => '硬體解碼';
	@override String get hardwareDecoder => '硬體解碼器';
	@override String get hardwareDecoderDesc => '僅在硬體解碼啟用時生效';
	@override String get lowMemoryMode => '低記憶體模式';
	@override String get lowMemoryModeDesc => '停用進階快取以減少記憶體使用量';
	@override String get lowLatencyAudio => '低延遲音訊';
	@override String get lowLatencyAudioDesc => '啟用 OpenSLES 音訊輸出以降低延遲';
	@override String get superResolution => '超解析度';
	@override String get autoJump => '自動跳轉';
	@override String get autoJumpDesc => '跳轉到上次播放位置';
	@override String get disableAnimations => '停用過渡動畫';
	@override String get disableAnimationsDesc => '停用播放器內的過渡動畫';
	@override String get errorPrompt => '錯誤提示';
	@override String get errorPromptDesc => '顯示播放器內部錯誤提示';
	@override String get debugMode => '除錯模式';
	@override String get debugModeDesc => '記錄播放器內部日誌';
	@override String get privateMode => '私密模式';
	@override String get privateModeDesc => '不保留觀看歷史';
	@override String get defaultPlaySpeed => '預設播放速度';
	@override String get defaultVideoAspectRatio => '預設影片比例';
	@override late final _TranslationsSettingsPlayerAspectRatioZhTw aspectRatio = _TranslationsSettingsPlayerAspectRatioZhTw._(_root);
	@override String get danmakuSettings => '彈幕設定';
	@override String get danmakuSettingsDesc => '設定彈幕參數';
	@override String get danmaku => '彈幕';
	@override String get danmakuDefaultOn => '預設開啟';
	@override String get danmakuDefaultOnDesc => '是否預設與影片一起播放彈幕';
	@override String get danmakuSource => '彈幕來源';
	@override late final _TranslationsSettingsPlayerDanmakuSourcesZhTw danmakuSources = _TranslationsSettingsPlayerDanmakuSourcesZhTw._(_root);
	@override String get danmakuCredentials => '憑證';
	@override String get danmakuDanDanCredentials => 'DanDan API 憑證';
	@override String get danmakuDanDanCredentialsDesc => '自訂 DanDan 憑證';
	@override String get danmakuCredentialModeBuiltIn => '內建';
	@override String get danmakuCredentialModeCustom => '自訂';
	@override String get danmakuCredentialHint => '留空使用內建憑證';
	@override String get danmakuCredentialNotConfigured => '未設定';
	@override String get danmakuCredentialsSummary => 'App ID: {appId}\nAPI Key: {apiKey}';
	@override String get danmakuShield => '彈幕遮罩';
	@override String get danmakuKeywordShield => '關鍵字遮罩';
	@override String get danmakuShieldInputHint => '輸入關鍵字或正規表示式';
	@override String get danmakuShieldDescription => '以「/」開頭和結尾的文字將視為正規表示式，例如「/\\d+/」遮罩所有數字';
	@override String get danmakuShieldCount => '已新增 {count} 個關鍵字';
	@override String get danmakuStyle => '彈幕樣式';
	@override String get danmakuDisplay => '彈幕顯示';
	@override String get danmakuArea => '彈幕區域';
	@override String get danmakuTopDisplay => '頂部彈幕';
	@override String get danmakuBottomDisplay => '底部彈幕';
	@override String get danmakuScrollDisplay => '滾動彈幕';
	@override String get danmakuMassiveDisplay => '大量彈幕';
	@override String get danmakuMassiveDescription => '當螢幕擁擠時以重疊方式渲染';
	@override String get danmakuOutline => '彈幕描邊';
	@override String get danmakuColor => '彈幕顏色';
	@override String get danmakuFontSize => '字體大小';
	@override String get danmakuFontWeight => '字體粗細';
	@override String get danmakuOpacity => '彈幕透明度';
	@override String get add => '新增';
	@override String get save => '儲存';
	@override String get restoreDefault => '恢復預設';
	@override String get superResolutionTitle => '超解析度';
	@override String get superResolutionHint => '選擇預設的升級配置';
	@override late final _TranslationsSettingsPlayerSuperResolutionOptionsZhTw superResolutionOptions = _TranslationsSettingsPlayerSuperResolutionOptionsZhTw._(_root);
	@override String get superResolutionDefaultBehavior => '預設行為';
	@override String get superResolutionClosePrompt => '關閉提示';
	@override String get superResolutionClosePromptDesc => '啟用超解析度時關閉提示';
	@override late final _TranslationsSettingsPlayerToastZhTw toast = _TranslationsSettingsPlayerToastZhTw._(_root);
}

// Path: settings.webdav
class _TranslationsSettingsWebdavZhTw extends _TranslationsSettingsWebdavEnUs {
	_TranslationsSettingsWebdavZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => 'WebDAV';
	@override String get desc => '設定同步參數';
	@override String get pageTitle => '同步設定';
	@override late final _TranslationsSettingsWebdavEditorZhTw editor = _TranslationsSettingsWebdavEditorZhTw._(_root);
	@override late final _TranslationsSettingsWebdavSectionZhTw section = _TranslationsSettingsWebdavSectionZhTw._(_root);
	@override late final _TranslationsSettingsWebdavTileZhTw tile = _TranslationsSettingsWebdavTileZhTw._(_root);
	@override late final _TranslationsSettingsWebdavInfoZhTw info = _TranslationsSettingsWebdavInfoZhTw._(_root);
	@override late final _TranslationsSettingsWebdavToastZhTw toast = _TranslationsSettingsWebdavToastZhTw._(_root);
	@override late final _TranslationsSettingsWebdavResultZhTw result = _TranslationsSettingsWebdavResultZhTw._(_root);
}

// Path: settings.update
class _TranslationsSettingsUpdateZhTw extends _TranslationsSettingsUpdateEnUs {
	_TranslationsSettingsUpdateZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get fallbackDescription => '未提供發行說明。';
	@override late final _TranslationsSettingsUpdateErrorZhTw error = _TranslationsSettingsUpdateErrorZhTw._(_root);
	@override late final _TranslationsSettingsUpdateDialogZhTw dialog = _TranslationsSettingsUpdateDialogZhTw._(_root);
	@override late final _TranslationsSettingsUpdateInstallationTypeZhTw installationType = _TranslationsSettingsUpdateInstallationTypeZhTw._(_root);
	@override late final _TranslationsSettingsUpdateToastZhTw toast = _TranslationsSettingsUpdateToastZhTw._(_root);
	@override late final _TranslationsSettingsUpdateDownloadZhTw download = _TranslationsSettingsUpdateDownloadZhTw._(_root);
}

// Path: settings.other
class _TranslationsSettingsOtherZhTw extends _TranslationsSettingsOtherEnUs {
	_TranslationsSettingsOtherZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '其他';
	@override String get about => '關於';
}

// Path: settings.about
class _TranslationsSettingsAboutZhTw extends _TranslationsSettingsAboutEnUs {
	_TranslationsSettingsAboutZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '關於';
	@override late final _TranslationsSettingsAboutSectionsZhTw sections = _TranslationsSettingsAboutSectionsZhTw._(_root);
	@override late final _TranslationsSettingsAboutLogsZhTw logs = _TranslationsSettingsAboutLogsZhTw._(_root);
}

// Path: navigation.tabs
class _TranslationsNavigationTabsZhTw extends _TranslationsNavigationTabsEnUs {
	_TranslationsNavigationTabsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get popular => '熱門';
	@override String get catalog => '資源分類';
	@override String get media => '視頻直播';
	@override String get resource => '全網資源';
	@override String get timeline => '時間表';
	@override String get my => '媒體庫';
	@override String get download => '任務與下載';
	@override String get settings => '設定';
}

// Path: navigation.actions
class _TranslationsNavigationActionsZhTw extends _TranslationsNavigationActionsEnUs {
	_TranslationsNavigationActionsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get search => '搜尋';
	@override String get history => '歷史紀錄';
	@override String get close => '關閉';
}

// Path: dialogs.disclaimer
class _TranslationsDialogsDisclaimerZhTw extends _TranslationsDialogsDisclaimerEnUs {
	_TranslationsDialogsDisclaimerZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '免責聲明';
	@override String get agree => '已閱讀並同意';
	@override String get exit => '結束';
}

// Path: dialogs.updateMirror
class _TranslationsDialogsUpdateMirrorZhTw extends _TranslationsDialogsUpdateMirrorEnUs {
	_TranslationsDialogsUpdateMirrorZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '更新鏡像';
	@override String get question => '您希望從哪裡取得應用程式更新？';
	@override String get description => 'GitHub 鏡像適用於大多數情況。如果您使用 F-Droid 應用程式商店，請選擇 F-Droid 鏡像。';
	@override late final _TranslationsDialogsUpdateMirrorOptionsZhTw options = _TranslationsDialogsUpdateMirrorOptionsZhTw._(_root);
}

// Path: dialogs.pluginUpdates
class _TranslationsDialogsPluginUpdatesZhTw extends _TranslationsDialogsPluginUpdatesEnUs {
	_TranslationsDialogsPluginUpdatesZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get toast => '偵測到 {count} 個規則可以更新';
}

// Path: dialogs.webdav
class _TranslationsDialogsWebdavZhTw extends _TranslationsDialogsWebdavEnUs {
	_TranslationsDialogsWebdavZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get syncFailed => '同步觀看紀錄失敗 {error}';
}

// Path: dialogs.about
class _TranslationsDialogsAboutZhTw extends _TranslationsDialogsAboutEnUs {
	_TranslationsDialogsAboutZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get licenseLegalese => '開放原始碼授權';
}

// Path: dialogs.cache
class _TranslationsDialogsCacheZhTw extends _TranslationsDialogsCacheEnUs {
	_TranslationsDialogsCacheZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '快取管理';
	@override String get message => '快取包含番劇封面，清除後載入時需要重新下載，確認要清除快取嗎？';
}

// Path: library.common
class _TranslationsLibraryCommonZhTw extends _TranslationsLibraryCommonEnUs {
	_TranslationsLibraryCommonZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get emptyState => '找不到內容';
	@override String get retry => '點擊重試';
	@override String get backHint => '再按一次以結束 Haipee';
	@override late final _TranslationsLibraryCommonToastZhTw toast = _TranslationsLibraryCommonToastZhTw._(_root);
}

// Path: library.popular
class _TranslationsLibraryPopularZhTw extends _TranslationsLibraryPopularEnUs {
	_TranslationsLibraryPopularZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '熱門番組';
	@override String get allTag => '全部';
	@override late final _TranslationsLibraryPopularToastZhTw toast = _TranslationsLibraryPopularToastZhTw._(_root);
}

// Path: library.timeline
class _TranslationsLibraryTimelineZhTw extends _TranslationsLibraryTimelineEnUs {
	_TranslationsLibraryTimelineZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsLibraryTimelineWeekdaysZhTw weekdays = _TranslationsLibraryTimelineWeekdaysZhTw._(_root);
	@override late final _TranslationsLibraryTimelineSeasonPickerZhTw seasonPicker = _TranslationsLibraryTimelineSeasonPickerZhTw._(_root);
	@override late final _TranslationsLibraryTimelineSeasonZhTw season = _TranslationsLibraryTimelineSeasonZhTw._(_root);
	@override late final _TranslationsLibraryTimelineSortZhTw sort = _TranslationsLibraryTimelineSortZhTw._(_root);
}

// Path: library.search
class _TranslationsLibrarySearchZhTw extends _TranslationsLibrarySearchEnUs {
	_TranslationsLibrarySearchZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsLibrarySearchSortZhTw sort = _TranslationsLibrarySearchSortZhTw._(_root);
	@override String get noHistory => '尚無搜尋紀錄';
}

// Path: library.history
class _TranslationsLibraryHistoryZhTw extends _TranslationsLibraryHistoryEnUs {
	_TranslationsLibraryHistoryZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '觀看紀錄';
	@override String get empty => '尚無觀看紀錄';
	@override late final _TranslationsLibraryHistoryChipsZhTw chips = _TranslationsLibraryHistoryChipsZhTw._(_root);
	@override late final _TranslationsLibraryHistoryToastZhTw toast = _TranslationsLibraryHistoryToastZhTw._(_root);
	@override late final _TranslationsLibraryHistoryManageZhTw manage = _TranslationsLibraryHistoryManageZhTw._(_root);
}

// Path: library.info
class _TranslationsLibraryInfoZhTw extends _TranslationsLibraryInfoEnUs {
	_TranslationsLibraryInfoZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsLibraryInfoSummaryZhTw summary = _TranslationsLibraryInfoSummaryZhTw._(_root);
	@override late final _TranslationsLibraryInfoTagsZhTw tags = _TranslationsLibraryInfoTagsZhTw._(_root);
	@override late final _TranslationsLibraryInfoMetadataZhTw metadata = _TranslationsLibraryInfoMetadataZhTw._(_root);
	@override late final _TranslationsLibraryInfoEpisodesZhTw episodes = _TranslationsLibraryInfoEpisodesZhTw._(_root);
	@override late final _TranslationsLibraryInfoErrorsZhTw errors = _TranslationsLibraryInfoErrorsZhTw._(_root);
	@override late final _TranslationsLibraryInfoTabsZhTw tabs = _TranslationsLibraryInfoTabsZhTw._(_root);
	@override late final _TranslationsLibraryInfoActionsZhTw actions = _TranslationsLibraryInfoActionsZhTw._(_root);
	@override late final _TranslationsLibraryInfoToastZhTw toast = _TranslationsLibraryInfoToastZhTw._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetZhTw sourceSheet = _TranslationsLibraryInfoSourceSheetZhTw._(_root);
}

// Path: library.my
class _TranslationsLibraryMyZhTw extends _TranslationsLibraryMyEnUs {
	_TranslationsLibraryMyZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '我的';
	@override late final _TranslationsLibraryMySectionsZhTw sections = _TranslationsLibraryMySectionsZhTw._(_root);
	@override late final _TranslationsLibraryMyFavoritesZhTw favorites = _TranslationsLibraryMyFavoritesZhTw._(_root);
	@override late final _TranslationsLibraryMyHistoryZhTw history = _TranslationsLibraryMyHistoryZhTw._(_root);
}

// Path: playback.toast
class _TranslationsPlaybackToastZhTw extends _TranslationsPlaybackToastEnUs {
	_TranslationsPlaybackToastZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get screenshotProcessing => '正在擷取螢幕截圖…';
	@override String get screenshotSaved => '螢幕截圖已儲存至相簿';
	@override String get screenshotSaveFailed => '儲存螢幕截圖失敗：{error}';
	@override String get screenshotError => '螢幕截圖失敗：{error}';
	@override String get playlistEmpty => '播放清單為空';
	@override String get episodeLatest => '已經是最新的集數';
	@override String get loadingEpisode => '正在載入 {identifier}';
	@override String get danmakuUnsupported => '此集數不支援發送彈幕';
	@override String get danmakuEmpty => '彈幕內容不能為空';
	@override String get danmakuTooLong => '彈幕內容過長';
	@override String get waitForVideo => '請等待影片載入完成';
	@override String get enableDanmakuFirst => '請先開啟彈幕';
	@override String get danmakuSearchError => '彈幕搜尋失敗：{error}';
	@override String get danmakuSearchEmpty => '找不到相符的結果';
	@override String get danmakuSwitching => '正在切換彈幕';
	@override String get clipboardCopied => '已複製到剪貼簿';
	@override String get internalError => '播放器內部錯誤：{details}';
}

// Path: playback.danmaku
class _TranslationsPlaybackDanmakuZhTw extends _TranslationsPlaybackDanmakuEnUs {
	_TranslationsPlaybackDanmakuZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get inputHint => '分享友善的彈幕';
	@override String get inputDisabled => '彈幕已關閉';
	@override String get send => '發送';
	@override String get mobileButton => '點擊發送彈幕';
	@override String get mobileButtonDisabled => '彈幕已停用';
}

// Path: playback.externalPlayer
class _TranslationsPlaybackExternalPlayerZhTw extends _TranslationsPlaybackExternalPlayerEnUs {
	_TranslationsPlaybackExternalPlayerZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get launching => '正在嘗試開啟外部播放器';
	@override String get launchFailed => '無法開啟外部播放器';
	@override String get unavailable => '外部播放器不可用';
	@override String get unsupportedDevice => '此裝置尚未支援';
	@override String get unsupportedPlugin => '此外掛程式尚未支援';
}

// Path: playback.controls
class _TranslationsPlaybackControlsZhTw extends _TranslationsPlaybackControlsEnUs {
	_TranslationsPlaybackControlsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsPlaybackControlsSpeedZhTw speed = _TranslationsPlaybackControlsSpeedZhTw._(_root);
	@override late final _TranslationsPlaybackControlsSkipZhTw skip = _TranslationsPlaybackControlsSkipZhTw._(_root);
	@override late final _TranslationsPlaybackControlsStatusZhTw status = _TranslationsPlaybackControlsStatusZhTw._(_root);
	@override late final _TranslationsPlaybackControlsSuperResolutionZhTw superResolution = _TranslationsPlaybackControlsSuperResolutionZhTw._(_root);
	@override late final _TranslationsPlaybackControlsSpeedMenuZhTw speedMenu = _TranslationsPlaybackControlsSpeedMenuZhTw._(_root);
	@override late final _TranslationsPlaybackControlsAspectRatioZhTw aspectRatio = _TranslationsPlaybackControlsAspectRatioZhTw._(_root);
	@override late final _TranslationsPlaybackControlsTooltipsZhTw tooltips = _TranslationsPlaybackControlsTooltipsZhTw._(_root);
	@override late final _TranslationsPlaybackControlsMenuZhTw menu = _TranslationsPlaybackControlsMenuZhTw._(_root);
	@override late final _TranslationsPlaybackControlsSyncplayZhTw syncplay = _TranslationsPlaybackControlsSyncplayZhTw._(_root);
}

// Path: playback.loading
class _TranslationsPlaybackLoadingZhTw extends _TranslationsPlaybackLoadingEnUs {
	_TranslationsPlaybackLoadingZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get parsing => '正在解析影片來源…';
	@override String get parseFailed => '影片來源解析失敗';
	@override String get player => '影片來源已解析，正在載入播放器';
	@override String get danmakuSearch => '搜尋彈幕中…';
}

// Path: playback.danmakuSearch
class _TranslationsPlaybackDanmakuSearchZhTw extends _TranslationsPlaybackDanmakuSearchEnUs {
	_TranslationsPlaybackDanmakuSearchZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '彈幕搜尋';
	@override String get hint => '系列標題';
	@override String get submit => '提交';
}

// Path: playback.remote
class _TranslationsPlaybackRemoteZhTw extends _TranslationsPlaybackRemoteEnUs {
	_TranslationsPlaybackRemoteZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '遠端投射';
	@override late final _TranslationsPlaybackRemoteToastZhTw toast = _TranslationsPlaybackRemoteToastZhTw._(_root);
}

// Path: playback.debug
class _TranslationsPlaybackDebugZhTw extends _TranslationsPlaybackDebugEnUs {
	_TranslationsPlaybackDebugZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '除錯資訊';
	@override String get closeTooltip => '關閉除錯資訊';
	@override late final _TranslationsPlaybackDebugTabsZhTw tabs = _TranslationsPlaybackDebugTabsZhTw._(_root);
	@override late final _TranslationsPlaybackDebugSectionsZhTw sections = _TranslationsPlaybackDebugSectionsZhTw._(_root);
	@override late final _TranslationsPlaybackDebugLabelsZhTw labels = _TranslationsPlaybackDebugLabelsZhTw._(_root);
	@override late final _TranslationsPlaybackDebugValuesZhTw values = _TranslationsPlaybackDebugValuesZhTw._(_root);
	@override late final _TranslationsPlaybackDebugLogsZhTw logs = _TranslationsPlaybackDebugLogsZhTw._(_root);
}

// Path: playback.syncplay
class _TranslationsPlaybackSyncplayZhTw extends _TranslationsPlaybackSyncplayEnUs {
	_TranslationsPlaybackSyncplayZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get invalidEndpoint => 'SyncPlay：無效的伺服器地址 {endpoint}';
	@override String get disconnected => 'SyncPlay：連線中斷 {reason}';
	@override String get actionReconnect => '重新連線';
	@override String get alone => 'SyncPlay：您是此房間的唯一使用者';
	@override String get followUser => 'SyncPlay：使用 {username} 的進度';
	@override String get userLeft => 'SyncPlay：{username} 離開了房間';
	@override String get userJoined => 'SyncPlay：{username} 加入了房間';
	@override String get switchEpisode => 'SyncPlay：{username} 切換到第 {episode} 集';
	@override String get chat => 'SyncPlay：{username} 說：{message}';
	@override String get paused => 'SyncPlay：{username} 暫停了播放';
	@override String get resumed => 'SyncPlay：{username} 恢復了播放';
	@override String get unknownUser => '未知';
	@override String get switchServerBlocked => 'SyncPlay：切換伺服器前請先離開目前房間';
	@override String get defaultCustomEndpoint => '自訂伺服器';
	@override late final _TranslationsPlaybackSyncplaySelectServerZhTw selectServer = _TranslationsPlaybackSyncplaySelectServerZhTw._(_root);
	@override late final _TranslationsPlaybackSyncplayJoinZhTw join = _TranslationsPlaybackSyncplayJoinZhTw._(_root);
}

// Path: playback.playlist
class _TranslationsPlaybackPlaylistZhTw extends _TranslationsPlaybackPlaylistEnUs {
	_TranslationsPlaybackPlaylistZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get collection => '合集';
	@override String get list => '播放清單 {index}';
}

// Path: playback.tabs
class _TranslationsPlaybackTabsZhTw extends _TranslationsPlaybackTabsEnUs {
	_TranslationsPlaybackTabsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get episodes => '分集';
	@override String get comments => '評論';
}

// Path: playback.comments
class _TranslationsPlaybackCommentsZhTw extends _TranslationsPlaybackCommentsEnUs {
	_TranslationsPlaybackCommentsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get sectionTitle => '集數標題';
	@override String get manualSwitch => '手動切換';
	@override String get dialogTitle => '輸入集數';
	@override String get dialogEmpty => '請輸入集數';
	@override String get dialogConfirm => '重新整理';
}

// Path: playback.superResolution
class _TranslationsPlaybackSuperResolutionZhTw extends _TranslationsPlaybackSuperResolutionEnUs {
	_TranslationsPlaybackSuperResolutionZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsPlaybackSuperResolutionWarningZhTw warning = _TranslationsPlaybackSuperResolutionWarningZhTw._(_root);
}

// Path: network.error
class _TranslationsNetworkErrorZhTw extends _TranslationsNetworkErrorEnUs {
	_TranslationsNetworkErrorZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get badCertificate => '憑證錯誤。';
	@override String get badResponse => '伺服器錯誤，請稍後再試。';
	@override String get cancel => '請求已取消，請重試。';
	@override String get connection => '連線錯誤，請檢查網路設定。';
	@override String get connectionTimeout => '連線逾時，請檢查網路設定。';
	@override String get receiveTimeout => '接收回應逾時，請稍後再試。';
	@override String get sendTimeout => '傳送逾時，請檢查網路設定。';
	@override String get unknown => '{status} 網路問題。';
}

// Path: network.status
class _TranslationsNetworkStatusZhTw extends _TranslationsNetworkStatusEnUs {
	_TranslationsNetworkStatusZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get mobile => '使用行動數據';
	@override String get wifi => '使用 Wi‑Fi';
	@override String get ethernet => '使用有線網路';
	@override String get vpn => '使用 VPN 連線';
	@override String get other => '使用其他網路';
	@override String get none => '無網路連線';
}

// Path: settings.appearancePage.mode
class _TranslationsSettingsAppearancePageModeZhTw extends _TranslationsSettingsAppearancePageModeEnUs {
	_TranslationsSettingsAppearancePageModeZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '主題模式';
	@override String get system => '系統';
	@override String get light => '淺色';
	@override String get dark => '深色';
}

// Path: settings.appearancePage.colorScheme
class _TranslationsSettingsAppearancePageColorSchemeZhTw extends _TranslationsSettingsAppearancePageColorSchemeEnUs {
	_TranslationsSettingsAppearancePageColorSchemeZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '強調色';
	@override String get dialogTitle => '選擇強調色';
	@override String get dynamicColor => '使用動態色彩';
	@override String get dynamicColorInfo => '在支援的裝置上根據您的桌布生成調色板（Android 12+ / Windows 11）。';
	@override late final _TranslationsSettingsAppearancePageColorSchemeLabelsZhTw labels = _TranslationsSettingsAppearancePageColorSchemeLabelsZhTw._(_root);
}

// Path: settings.appearancePage.oled
class _TranslationsSettingsAppearancePageOledZhTw extends _TranslationsSettingsAppearancePageOledEnUs {
	_TranslationsSettingsAppearancePageOledZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => 'OLED 對比';
	@override String get description => '使用針對 OLED 顯示器最佳化的更深黑色。';
}

// Path: settings.appearancePage.window
class _TranslationsSettingsAppearancePageWindowZhTw extends _TranslationsSettingsAppearancePageWindowEnUs {
	_TranslationsSettingsAppearancePageWindowZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '視窗按鈕';
	@override String get description => '在標題欄顯示視窗控制按鈕。';
}

// Path: settings.appearancePage.refreshRate
class _TranslationsSettingsAppearancePageRefreshRateZhTw extends _TranslationsSettingsAppearancePageRefreshRateEnUs {
	_TranslationsSettingsAppearancePageRefreshRateZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '刷新率';
}

// Path: settings.plugins.tooltip
class _TranslationsSettingsPluginsTooltipZhTw extends _TranslationsSettingsPluginsTooltipEnUs {
	_TranslationsSettingsPluginsTooltipZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get updateAll => '全部更新';
	@override String get addRule => '新增規則';
}

// Path: settings.plugins.sort
class _TranslationsSettingsPluginsSortZhTw extends _TranslationsSettingsPluginsSortEnUs {
	_TranslationsSettingsPluginsSortZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '排序方式';
	@override String get tooltip => '排序';
	@override late final _TranslationsSettingsPluginsSortOptionsZhTw options = _TranslationsSettingsPluginsSortOptionsZhTw._(_root);
}

// Path: settings.plugins.multiSelect
class _TranslationsSettingsPluginsMultiSelectZhTw extends _TranslationsSettingsPluginsMultiSelectEnUs {
	_TranslationsSettingsPluginsMultiSelectZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get selectedCount => '已選擇 {count} 項';
}

// Path: settings.plugins.loading
class _TranslationsSettingsPluginsLoadingZhTw extends _TranslationsSettingsPluginsLoadingEnUs {
	_TranslationsSettingsPluginsLoadingZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get updating => '正在更新規則…';
	@override String get updatingSingle => '更新中…';
	@override String get importing => '導入中…';
}

// Path: settings.plugins.labels
class _TranslationsSettingsPluginsLabelsZhTw extends _TranslationsSettingsPluginsLabelsEnUs {
	_TranslationsSettingsPluginsLabelsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get version => '版本：{version}';
	@override String get statusUpdatable => '可更新';
	@override String get statusSearchValid => '搜尋有效';
}

// Path: settings.plugins.actions
class _TranslationsSettingsPluginsActionsZhTw extends _TranslationsSettingsPluginsActionsEnUs {
	_TranslationsSettingsPluginsActionsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get newRule => '建立規則';
	@override String get importFromRepo => '從儲存庫匯入';
	@override String get importFromClipboard => '從剪貼簿匯入';
	@override String get cancel => '取消';
	@override String get import => '匯入';
	@override String get update => '更新';
	@override String get edit => '編輯';
	@override String get copyToClipboard => '複製到剪貼簿';
	@override String get share => '分享';
	@override String get delete => '刪除';
}

// Path: settings.plugins.dialogs
class _TranslationsSettingsPluginsDialogsZhTw extends _TranslationsSettingsPluginsDialogsEnUs {
	_TranslationsSettingsPluginsDialogsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get deleteTitle => '刪除規則';
	@override String get deleteMessage => '確定要刪除選定的 {count} 個規則嗎？';
	@override String get importTitle => '匯入規則';
	@override String get shareTitle => '規則連結';
}

// Path: settings.plugins.toast
class _TranslationsSettingsPluginsToastZhTw extends _TranslationsSettingsPluginsToastEnUs {
	_TranslationsSettingsPluginsToastZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get allUpToDate => '所有規則都是最新的。';
	@override String get updateCount => '已更新 {count} 個規則。';
	@override String get importSuccess => '匯入成功。';
	@override String get importFailed => '匯入失敗：{error}';
	@override String get repoMissing => '儲存庫中沒有此規則。';
	@override String get alreadyLatest => '規則已經是最新的。';
	@override String get updateSuccess => '更新成功。';
	@override String get updateIncompatible => 'Haipee 版本過舊；此規則不相容。';
	@override String get updateFailed => '規則更新失敗。';
	@override String get copySuccess => '已複製到剪貼簿。';
}

// Path: settings.plugins.editor
class _TranslationsSettingsPluginsEditorZhTw extends _TranslationsSettingsPluginsEditorEnUs {
	_TranslationsSettingsPluginsEditorZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '編輯規則';
	@override late final _TranslationsSettingsPluginsEditorFieldsZhTw fields = _TranslationsSettingsPluginsEditorFieldsZhTw._(_root);
	@override late final _TranslationsSettingsPluginsEditorAdvancedZhTw advanced = _TranslationsSettingsPluginsEditorAdvancedZhTw._(_root);
}

// Path: settings.plugins.shop
class _TranslationsSettingsPluginsShopZhTw extends _TranslationsSettingsPluginsShopEnUs {
	_TranslationsSettingsPluginsShopZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '規則儲存庫';
	@override late final _TranslationsSettingsPluginsShopTooltipZhTw tooltip = _TranslationsSettingsPluginsShopTooltipZhTw._(_root);
	@override late final _TranslationsSettingsPluginsShopLabelsZhTw labels = _TranslationsSettingsPluginsShopLabelsZhTw._(_root);
	@override late final _TranslationsSettingsPluginsShopButtonsZhTw buttons = _TranslationsSettingsPluginsShopButtonsZhTw._(_root);
	@override late final _TranslationsSettingsPluginsShopToastZhTw toast = _TranslationsSettingsPluginsShopToastZhTw._(_root);
	@override late final _TranslationsSettingsPluginsShopErrorZhTw error = _TranslationsSettingsPluginsShopErrorZhTw._(_root);
}

// Path: settings.player.aspectRatio
class _TranslationsSettingsPlayerAspectRatioZhTw extends _TranslationsSettingsPlayerAspectRatioEnUs {
	_TranslationsSettingsPlayerAspectRatioZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get auto => '自動';
	@override String get crop => '裁切填充';
	@override String get stretch => '拉伸填充';
}

// Path: settings.player.danmakuSources
class _TranslationsSettingsPlayerDanmakuSourcesZhTw extends _TranslationsSettingsPlayerDanmakuSourcesEnUs {
	_TranslationsSettingsPlayerDanmakuSourcesZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get bilibili => 'Bilibili';
	@override String get gamer => 'Gamer';
	@override String get dandan => 'DanDan';
}

// Path: settings.player.superResolutionOptions
class _TranslationsSettingsPlayerSuperResolutionOptionsZhTw extends _TranslationsSettingsPlayerSuperResolutionOptionsEnUs {
	_TranslationsSettingsPlayerSuperResolutionOptionsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsSettingsPlayerSuperResolutionOptionsOffZhTw off = _TranslationsSettingsPlayerSuperResolutionOptionsOffZhTw._(_root);
	@override late final _TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyZhTw efficiency = _TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyZhTw._(_root);
	@override late final _TranslationsSettingsPlayerSuperResolutionOptionsQualityZhTw quality = _TranslationsSettingsPlayerSuperResolutionOptionsQualityZhTw._(_root);
}

// Path: settings.player.toast
class _TranslationsSettingsPlayerToastZhTw extends _TranslationsSettingsPlayerToastEnUs {
	_TranslationsSettingsPlayerToastZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get danmakuKeywordEmpty => '請輸入關鍵字。';
	@override String get danmakuKeywordTooLong => '關鍵字太長。';
	@override String get danmakuKeywordExists => '關鍵字已存在。';
	@override String get danmakuCredentialsRestored => '已恢復內建憑證。';
	@override String get danmakuCredentialsUpdated => '憑證已更新。';
}

// Path: settings.webdav.editor
class _TranslationsSettingsWebdavEditorZhTw extends _TranslationsSettingsWebdavEditorEnUs {
	_TranslationsSettingsWebdavEditorZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => 'WebDAV 設定';
	@override String get url => '網址';
	@override String get username => '使用者名稱';
	@override String get password => '密碼';
	@override late final _TranslationsSettingsWebdavEditorToastZhTw toast = _TranslationsSettingsWebdavEditorToastZhTw._(_root);
}

// Path: settings.webdav.section
class _TranslationsSettingsWebdavSectionZhTw extends _TranslationsSettingsWebdavSectionEnUs {
	_TranslationsSettingsWebdavSectionZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get webdav => 'WebDAV';
}

// Path: settings.webdav.tile
class _TranslationsSettingsWebdavTileZhTw extends _TranslationsSettingsWebdavTileEnUs {
	_TranslationsSettingsWebdavTileZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get webdavToggle => 'WebDAV 同步';
	@override String get historyToggle => '觀看歷史同步';
	@override String get historyDescription => '允許自動同步觀看歷史';
	@override String get config => 'WebDAV 設定';
	@override String get manualUpload => '手動上傳';
	@override String get manualDownload => '手動下載';
}

// Path: settings.webdav.info
class _TranslationsSettingsWebdavInfoZhTw extends _TranslationsSettingsWebdavInfoEnUs {
	_TranslationsSettingsWebdavInfoZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get upload => '立即將您的觀看歷史上傳至 WebDAV。';
	@override String get download => '立即將您的觀看歷史同步到此裝置。';
}

// Path: settings.webdav.toast
class _TranslationsSettingsWebdavToastZhTw extends _TranslationsSettingsWebdavToastEnUs {
	_TranslationsSettingsWebdavToastZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get uploading => '嘗試上傳至 WebDAV…';
	@override String get downloading => '嘗試從 WebDAV 同步…';
	@override String get notConfigured => 'WebDAV 同步已停用或設定無效。';
	@override String get connectionFailed => '連線到 WebDAV 失敗：{error}';
	@override String get syncFailed => 'WebDAV 同步失敗：{error}';
}

// Path: settings.webdav.result
class _TranslationsSettingsWebdavResultZhTw extends _TranslationsSettingsWebdavResultEnUs {
	_TranslationsSettingsWebdavResultZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get initFailed => 'WebDAV 初始化失敗：{error}';
	@override String get requireEnable => '請先啟用 WebDAV 同步。';
	@override String get disabled => 'WebDAV 同步已停用或設定無效。';
	@override String get connectionFailed => '連線到 WebDAV 失敗。';
	@override String get syncSuccess => '同步成功。';
	@override String get syncFailed => '同步失敗：{error}';
}

// Path: settings.update.error
class _TranslationsSettingsUpdateErrorZhTw extends _TranslationsSettingsUpdateErrorEnUs {
	_TranslationsSettingsUpdateErrorZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get invalidResponse => '無效的更新回應。';
}

// Path: settings.update.dialog
class _TranslationsSettingsUpdateDialogZhTw extends _TranslationsSettingsUpdateDialogEnUs {
	_TranslationsSettingsUpdateDialogZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '有新的版本 {version} 可用';
	@override String get publishedAt => '發布於 {date}';
	@override String get installationTypeLabel => '選擇安裝套件';
	@override late final _TranslationsSettingsUpdateDialogActionsZhTw actions = _TranslationsSettingsUpdateDialogActionsZhTw._(_root);
}

// Path: settings.update.installationType
class _TranslationsSettingsUpdateInstallationTypeZhTw extends _TranslationsSettingsUpdateInstallationTypeEnUs {
	_TranslationsSettingsUpdateInstallationTypeZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get windowsMsix => 'Windows 安裝程式 (MSIX)';
	@override String get windowsPortable => 'Windows 攜帶版 (ZIP)';
	@override String get linuxDeb => 'Linux 套件 (DEB)';
	@override String get linuxTar => 'Linux 封存檔 (TAR.GZ)';
	@override String get macosDmg => 'macOS 安裝程式 (DMG)';
	@override String get androidApk => 'Android 套件 (APK)';
	@override String get ios => 'iOS 應用程式（開啟 GitHub）';
	@override String get unknown => '其他平台';
}

// Path: settings.update.toast
class _TranslationsSettingsUpdateToastZhTw extends _TranslationsSettingsUpdateToastEnUs {
	_TranslationsSettingsUpdateToastZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get alreadyLatest => '您已是最新版本。';
	@override String get checkFailed => '檢查更新失敗。請稍後再試。';
	@override String get autoUpdateDisabled => '自動更新已停用。';
	@override String get downloadLinkMissing => '沒有 {type} 的下載連結。';
	@override String get downloadFailed => '下載失敗：{error}';
	@override String get noCompatibleLink => '找不到相容的下載連結。';
	@override String get prepareToInstall => '正在準備安裝更新。應用程式將離開…';
	@override String get openInstallerFailed => '無法開啟安裝程式：{error}';
	@override String get launchInstallerFailed => '啟動安裝程式失敗：{error}';
	@override String get revealFailed => '無法開啟檔案管理器。';
	@override String get unknownReason => '未知原因';
}

// Path: settings.update.download
class _TranslationsSettingsUpdateDownloadZhTw extends _TranslationsSettingsUpdateDownloadEnUs {
	_TranslationsSettingsUpdateDownloadZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get progressTitle => '正在下載更新';
	@override String get cancel => '取消';
	@override late final _TranslationsSettingsUpdateDownloadErrorZhTw error = _TranslationsSettingsUpdateDownloadErrorZhTw._(_root);
	@override late final _TranslationsSettingsUpdateDownloadCompleteZhTw complete = _TranslationsSettingsUpdateDownloadCompleteZhTw._(_root);
}

// Path: settings.about.sections
class _TranslationsSettingsAboutSectionsZhTw extends _TranslationsSettingsAboutSectionsEnUs {
	_TranslationsSettingsAboutSectionsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsSettingsAboutSectionsLicensesZhTw licenses = _TranslationsSettingsAboutSectionsLicensesZhTw._(_root);
	@override late final _TranslationsSettingsAboutSectionsLinksZhTw links = _TranslationsSettingsAboutSectionsLinksZhTw._(_root);
	@override late final _TranslationsSettingsAboutSectionsCacheZhTw cache = _TranslationsSettingsAboutSectionsCacheZhTw._(_root);
	@override late final _TranslationsSettingsAboutSectionsUpdatesZhTw updates = _TranslationsSettingsAboutSectionsUpdatesZhTw._(_root);
}

// Path: settings.about.logs
class _TranslationsSettingsAboutLogsZhTw extends _TranslationsSettingsAboutLogsEnUs {
	_TranslationsSettingsAboutLogsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '應用程式日誌';
	@override String get empty => '沒有可用的日誌條目。';
	@override late final _TranslationsSettingsAboutLogsToastZhTw toast = _TranslationsSettingsAboutLogsToastZhTw._(_root);
}

// Path: dialogs.updateMirror.options
class _TranslationsDialogsUpdateMirrorOptionsZhTw extends _TranslationsDialogsUpdateMirrorOptionsEnUs {
	_TranslationsDialogsUpdateMirrorOptionsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get github => 'GitHub';
	@override String get fdroid => 'F-Droid';
}

// Path: library.common.toast
class _TranslationsLibraryCommonToastZhTw extends _TranslationsLibraryCommonToastEnUs {
	_TranslationsLibraryCommonToastZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get editMode => '編輯模式已啟用。';
}

// Path: library.popular.toast
class _TranslationsLibraryPopularToastZhTw extends _TranslationsLibraryPopularToastEnUs {
	_TranslationsLibraryPopularToastZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get backPress => '再按一次以結束 Haipee';
}

// Path: library.timeline.weekdays
class _TranslationsLibraryTimelineWeekdaysZhTw extends _TranslationsLibraryTimelineWeekdaysEnUs {
	_TranslationsLibraryTimelineWeekdaysZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get mon => '一';
	@override String get tue => '二';
	@override String get wed => '三';
	@override String get thu => '四';
	@override String get fri => '五';
	@override String get sat => '六';
	@override String get sun => '日';
}

// Path: library.timeline.seasonPicker
class _TranslationsLibraryTimelineSeasonPickerZhTw extends _TranslationsLibraryTimelineSeasonPickerEnUs {
	_TranslationsLibraryTimelineSeasonPickerZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '時光機';
	@override String get yearLabel => '{year}';
}

// Path: library.timeline.season
class _TranslationsLibraryTimelineSeasonZhTw extends _TranslationsLibraryTimelineSeasonEnUs {
	_TranslationsLibraryTimelineSeasonZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '{season} {year}';
	@override String get loading => '載入中…';
	@override late final _TranslationsLibraryTimelineSeasonNamesZhTw names = _TranslationsLibraryTimelineSeasonNamesZhTw._(_root);
	@override late final _TranslationsLibraryTimelineSeasonShortZhTw short = _TranslationsLibraryTimelineSeasonShortZhTw._(_root);
}

// Path: library.timeline.sort
class _TranslationsLibraryTimelineSortZhTw extends _TranslationsLibraryTimelineSortEnUs {
	_TranslationsLibraryTimelineSortZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '排序方式';
	@override String get byHeat => '依人氣排序';
	@override String get byRating => '依評分排序';
	@override String get byTime => '依播出時間排序';
}

// Path: library.search.sort
class _TranslationsLibrarySearchSortZhTw extends _TranslationsLibrarySearchSortEnUs {
	_TranslationsLibrarySearchSortZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get label => '搜尋排序';
	@override String get byHeat => '依熱門度排序';
	@override String get byRating => '依評分排序';
	@override String get byRelevance => '依相關度排序';
}

// Path: library.history.chips
class _TranslationsLibraryHistoryChipsZhTw extends _TranslationsLibraryHistoryChipsEnUs {
	_TranslationsLibraryHistoryChipsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get source => '來源';
	@override String get progress => '進度';
	@override String get episodeNumber => '第 {number} 集';
}

// Path: library.history.toast
class _TranslationsLibraryHistoryToastZhTw extends _TranslationsLibraryHistoryToastEnUs {
	_TranslationsLibraryHistoryToastZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get sourceMissing => '找不到關聯的來源。';
}

// Path: library.history.manage
class _TranslationsLibraryHistoryManageZhTw extends _TranslationsLibraryHistoryManageEnUs {
	_TranslationsLibraryHistoryManageZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '紀錄管理';
	@override String get confirmClear => '要清除所有觀看紀錄嗎？';
	@override String get cancel => '取消';
	@override String get confirm => '確認';
}

// Path: library.info.summary
class _TranslationsLibraryInfoSummaryZhTw extends _TranslationsLibraryInfoSummaryEnUs {
	_TranslationsLibraryInfoSummaryZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '劇情簡介';
	@override String get expand => '顯示更多';
	@override String get collapse => '顯示較少';
}

// Path: library.info.tags
class _TranslationsLibraryInfoTagsZhTw extends _TranslationsLibraryInfoTagsEnUs {
	_TranslationsLibraryInfoTagsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '標籤';
	@override String get more => '更多 +';
}

// Path: library.info.metadata
class _TranslationsLibraryInfoMetadataZhTw extends _TranslationsLibraryInfoMetadataEnUs {
	_TranslationsLibraryInfoMetadataZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get refresh => '重新整理';
	@override String get syncingTitle => '同步中繼資料中…';
	@override String get syncingSubtitle => '首次同步可能需要幾秒鐘。';
	@override String get emptyTitle => '尚無官方中繼資料';
	@override String get emptySubtitle => '請稍後重試或檢查中繼資料設定。';
	@override String source({required Object source}) => '中繼資料來源：${source}';
	@override String updated({required Object timestamp, required Object language}) => '最後更新：${timestamp} · 語言：${language}';
	@override String get languageSystem => '系統預設';
	@override String get multiSource => '合併來源';
}

// Path: library.info.episodes
class _TranslationsLibraryInfoEpisodesZhTw extends _TranslationsLibraryInfoEpisodesEnUs {
	_TranslationsLibraryInfoEpisodesZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '分集';
	@override String get collapse => '摺疊';
	@override String expand({required Object count}) => '顯示全部（${count}）';
	@override String numberedEpisode({required Object number}) => '第 ${number} 集';
	@override String get dateUnknown => '播出日期待定';
	@override String get runtimeUnknown => '片長未知';
	@override String runtimeMinutes({required Object minutes}) => '${minutes} 分鐘';
}

// Path: library.info.errors
class _TranslationsLibraryInfoErrorsZhTw extends _TranslationsLibraryInfoErrorsEnUs {
	_TranslationsLibraryInfoErrorsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get fetchFailed => '載入失敗，請重試。';
}

// Path: library.info.tabs
class _TranslationsLibraryInfoTabsZhTw extends _TranslationsLibraryInfoTabsEnUs {
	_TranslationsLibraryInfoTabsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get overview => '總覽';
	@override String get comments => '評論';
	@override String get characters => '角色';
	@override String get reviews => '心得';
	@override String get staff => '製作人員';
	@override String get placeholder => '即將推出';
}

// Path: library.info.actions
class _TranslationsLibraryInfoActionsZhTw extends _TranslationsLibraryInfoActionsEnUs {
	_TranslationsLibraryInfoActionsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get startWatching => '開始觀看';
}

// Path: library.info.toast
class _TranslationsLibraryInfoToastZhTw extends _TranslationsLibraryInfoToastEnUs {
	_TranslationsLibraryInfoToastZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get characterSortFailed => '排序角色失敗：{details}';
}

// Path: library.info.sourceSheet
class _TranslationsLibraryInfoSourceSheetZhTw extends _TranslationsLibraryInfoSourceSheetEnUs {
	_TranslationsLibraryInfoSourceSheetZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '選擇播放來源 ({name})';
	@override late final _TranslationsLibraryInfoSourceSheetAliasZhTw alias = _TranslationsLibraryInfoSourceSheetAliasZhTw._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetToastZhTw toast = _TranslationsLibraryInfoSourceSheetToastZhTw._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetSortZhTw sort = _TranslationsLibraryInfoSourceSheetSortZhTw._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetCardZhTw card = _TranslationsLibraryInfoSourceSheetCardZhTw._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetActionsZhTw actions = _TranslationsLibraryInfoSourceSheetActionsZhTw._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetStatusZhTw status = _TranslationsLibraryInfoSourceSheetStatusZhTw._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetEmptyZhTw empty = _TranslationsLibraryInfoSourceSheetEmptyZhTw._(_root);
	@override late final _TranslationsLibraryInfoSourceSheetDialogZhTw dialog = _TranslationsLibraryInfoSourceSheetDialogZhTw._(_root);
}

// Path: library.my.sections
class _TranslationsLibraryMySectionsZhTw extends _TranslationsLibraryMySectionsEnUs {
	_TranslationsLibraryMySectionsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get video => '影片';
}

// Path: library.my.favorites
class _TranslationsLibraryMyFavoritesZhTw extends _TranslationsLibraryMyFavoritesEnUs {
	_TranslationsLibraryMyFavoritesZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '收藏';
	@override String get description => '查看追看、計劃與已看完清單';
	@override String get empty => '尚無收藏項目。';
	@override late final _TranslationsLibraryMyFavoritesTabsZhTw tabs = _TranslationsLibraryMyFavoritesTabsZhTw._(_root);
	@override late final _TranslationsLibraryMyFavoritesSyncZhTw sync = _TranslationsLibraryMyFavoritesSyncZhTw._(_root);
}

// Path: library.my.history
class _TranslationsLibraryMyHistoryZhTw extends _TranslationsLibraryMyHistoryEnUs {
	_TranslationsLibraryMyHistoryZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '播放歷史';
	@override String get description => '查看您看過的節目';
}

// Path: playback.controls.speed
class _TranslationsPlaybackControlsSpeedZhTw extends _TranslationsPlaybackControlsSpeedEnUs {
	_TranslationsPlaybackControlsSpeedZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '播放速度';
	@override String get reset => '預設速度';
}

// Path: playback.controls.skip
class _TranslationsPlaybackControlsSkipZhTw extends _TranslationsPlaybackControlsSkipEnUs {
	_TranslationsPlaybackControlsSkipZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '跳過時長';
	@override String get tooltip => '長按變更時長';
}

// Path: playback.controls.status
class _TranslationsPlaybackControlsStatusZhTw extends _TranslationsPlaybackControlsStatusEnUs {
	_TranslationsPlaybackControlsStatusZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get fastForward => '快進 {seconds} 秒';
	@override String get rewind => '快退 {seconds} 秒';
	@override String get speed => '倍速播放';
}

// Path: playback.controls.superResolution
class _TranslationsPlaybackControlsSuperResolutionZhTw extends _TranslationsPlaybackControlsSuperResolutionEnUs {
	_TranslationsPlaybackControlsSuperResolutionZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get label => '超解析度';
	@override String get off => '關閉';
	@override String get balanced => '平衡';
	@override String get quality => '品質';
}

// Path: playback.controls.speedMenu
class _TranslationsPlaybackControlsSpeedMenuZhTw extends _TranslationsPlaybackControlsSpeedMenuEnUs {
	_TranslationsPlaybackControlsSpeedMenuZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get label => '速度';
}

// Path: playback.controls.aspectRatio
class _TranslationsPlaybackControlsAspectRatioZhTw extends _TranslationsPlaybackControlsAspectRatioEnUs {
	_TranslationsPlaybackControlsAspectRatioZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get label => '畫面比例';
	@override late final _TranslationsPlaybackControlsAspectRatioOptionsZhTw options = _TranslationsPlaybackControlsAspectRatioOptionsZhTw._(_root);
}

// Path: playback.controls.tooltips
class _TranslationsPlaybackControlsTooltipsZhTw extends _TranslationsPlaybackControlsTooltipsEnUs {
	_TranslationsPlaybackControlsTooltipsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get danmakuOn => '關閉彈幕 (d)';
	@override String get danmakuOff => '開啟彈幕 (d)';
}

// Path: playback.controls.menu
class _TranslationsPlaybackControlsMenuZhTw extends _TranslationsPlaybackControlsMenuEnUs {
	_TranslationsPlaybackControlsMenuZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get danmakuToggle => '彈幕開關';
	@override String get videoInfo => '影片資訊';
	@override String get cast => '遠端投射';
	@override String get external => '使用外部播放器開啟';
}

// Path: playback.controls.syncplay
class _TranslationsPlaybackControlsSyncplayZhTw extends _TranslationsPlaybackControlsSyncplayEnUs {
	_TranslationsPlaybackControlsSyncplayZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get label => 'SyncPlay';
	@override String get room => '目前房間：{name}';
	@override String get roomEmpty => '未加入';
	@override String get latency => '延遲：{ms} ms';
	@override String get join => '加入房間';
	@override String get switchServer => '切換伺服器';
	@override String get disconnect => '中斷連線';
}

// Path: playback.remote.toast
class _TranslationsPlaybackRemoteToastZhTw extends _TranslationsPlaybackRemoteToastEnUs {
	_TranslationsPlaybackRemoteToastZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get searching => '搜尋中…';
	@override String get casting => '嘗試投射到 {device}';
	@override String get error => 'DLNA 錯誤：{details}\n嘗試重新開啟 DLNA 面板或選擇其他裝置。';
}

// Path: playback.debug.tabs
class _TranslationsPlaybackDebugTabsZhTw extends _TranslationsPlaybackDebugTabsEnUs {
	_TranslationsPlaybackDebugTabsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get status => '狀態';
	@override String get logs => '日誌';
}

// Path: playback.debug.sections
class _TranslationsPlaybackDebugSectionsZhTw extends _TranslationsPlaybackDebugSectionsEnUs {
	_TranslationsPlaybackDebugSectionsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get source => '播放來源';
	@override String get playback => '播放器狀態';
	@override String get timing => '時間與指標';
	@override String get media => '媒體軌';
}

// Path: playback.debug.labels
class _TranslationsPlaybackDebugLabelsZhTw extends _TranslationsPlaybackDebugLabelsEnUs {
	_TranslationsPlaybackDebugLabelsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get series => '系列';
	@override String get plugin => '外掛程式';
	@override String get route => '路線';
	@override String get episode => '集數';
	@override String get routeCount => '路線數量';
	@override String get sourceTitle => '來源標題';
	@override String get parsedUrl => '解析的網址';
	@override String get playUrl => '播放網址';
	@override String get danmakuId => 'DanDan ID';
	@override String get syncRoom => 'SyncPlay 房間';
	@override String get syncLatency => 'SyncPlay RTT';
	@override String get nativePlayer => '原生播放器';
	@override String get parsing => '解析中';
	@override String get playerLoading => '播放器載入中';
	@override String get playerInitializing => '播放器初始化中';
	@override String get playing => '播放中';
	@override String get buffering => '緩衝中';
	@override String get completed => '播放完成';
	@override String get bufferFlag => '緩衝旗標';
	@override String get currentPosition => '目前位置';
	@override String get bufferProgress => '緩衝進度';
	@override String get duration => '時長';
	@override String get speed => '播放速度';
	@override String get volume => '音量';
	@override String get brightness => '亮度';
	@override String get resolution => '解析度';
	@override String get aspectRatio => '畫面比例';
	@override String get superResolution => '超解析度';
	@override String get videoParams => '影片參數';
	@override String get audioParams => '音訊參數';
	@override String get playlist => '播放清單';
	@override String get audioTracks => '音訊軌';
	@override String get videoTracks => '視訊軌';
	@override String get audioBitrate => '音訊位元率';
}

// Path: playback.debug.values
class _TranslationsPlaybackDebugValuesZhTw extends _TranslationsPlaybackDebugValuesEnUs {
	_TranslationsPlaybackDebugValuesZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get yes => '是';
	@override String get no => '否';
}

// Path: playback.debug.logs
class _TranslationsPlaybackDebugLogsZhTw extends _TranslationsPlaybackDebugLogsEnUs {
	_TranslationsPlaybackDebugLogsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get playerEmpty => '播放器日誌 (0)';
	@override String get playerSummary => '播放器日誌（{count} 條，顯示 {displayed} 條）';
	@override String get webviewEmpty => 'WebView 日誌 (0)';
	@override String get webviewSummary => 'WebView 日誌（{count} 條，顯示 {displayed} 條）';
}

// Path: playback.syncplay.selectServer
class _TranslationsPlaybackSyncplaySelectServerZhTw extends _TranslationsPlaybackSyncplaySelectServerEnUs {
	_TranslationsPlaybackSyncplaySelectServerZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '選擇伺服器';
	@override String get customTitle => '自訂伺服器';
	@override String get customHint => '輸入伺服器網址';
	@override String get duplicateOrEmpty => '伺服器網址必須是唯一的且不能為空';
}

// Path: playback.syncplay.join
class _TranslationsPlaybackSyncplayJoinZhTw extends _TranslationsPlaybackSyncplayJoinEnUs {
	_TranslationsPlaybackSyncplayJoinZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '加入房間';
	@override String get roomLabel => '房間 ID';
	@override String get roomEmpty => '輸入房間 ID';
	@override String get roomInvalid => '房間 ID 必須是 6 到 10 位數字';
	@override String get usernameLabel => '使用者名稱';
	@override String get usernameEmpty => '輸入使用者名稱';
	@override String get usernameInvalid => '使用者名稱必須是 4 到 12 個字母';
}

// Path: playback.superResolution.warning
class _TranslationsPlaybackSuperResolutionWarningZhTw extends _TranslationsPlaybackSuperResolutionWarningEnUs {
	_TranslationsPlaybackSuperResolutionWarningZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '效能警告';
	@override String get message => '啟用超解析度（品質）可能會造成卡頓。是否繼續？';
	@override String get dontAskAgain => '不要再詢問';
}

// Path: settings.appearancePage.colorScheme.labels
class _TranslationsSettingsAppearancePageColorSchemeLabelsZhTw extends _TranslationsSettingsAppearancePageColorSchemeLabelsEnUs {
	_TranslationsSettingsAppearancePageColorSchemeLabelsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get defaultLabel => '預設';
	@override String get teal => '青色';
	@override String get blue => '藍色';
	@override String get indigo => '靛藍';
	@override String get violet => '紫羅蘭';
	@override String get pink => '粉色';
	@override String get yellow => '黃色';
	@override String get orange => '橙色';
	@override String get deepOrange => '深橙色';
}

// Path: settings.plugins.sort.options
class _TranslationsSettingsPluginsSortOptionsZhTw extends _TranslationsSettingsPluginsSortOptionsEnUs {
	_TranslationsSettingsPluginsSortOptionsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get original => '原始順序';
	@override String get nameAsc => '名稱（Ａ → ３）';
	@override String get nameDesc => '名稱（３ → Ａ）';
	@override String get failureAsc => '失敗次數（低 → 高）';
	@override String get failureDesc => '失敗次數（高 → 低）';
}

// Path: settings.plugins.editor.fields
class _TranslationsSettingsPluginsEditorFieldsZhTw extends _TranslationsSettingsPluginsEditorFieldsEnUs {
	_TranslationsSettingsPluginsEditorFieldsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get name => '規則名稱';
	@override String get version => '版本';
	@override String get baseUrl => '基礎 URL';
	@override String get searchUrl => '搜尋 URL';
	@override String get searchList => '搜尋列表 XPath';
	@override String get searchName => '搜尋標題 XPath';
	@override String get searchResult => '搜尋結果 XPath';
	@override String get chapterRoads => '播放清單 XPath';
	@override String get chapterResult => '播放清單結果 XPath';
	@override String get userAgent => 'User-Agent';
	@override String get referer => 'Referer';
}

// Path: settings.plugins.editor.advanced
class _TranslationsSettingsPluginsEditorAdvancedZhTw extends _TranslationsSettingsPluginsEditorAdvancedEnUs {
	_TranslationsSettingsPluginsEditorAdvancedZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '進階選項';
	@override late final _TranslationsSettingsPluginsEditorAdvancedLegacyParserZhTw legacyParser = _TranslationsSettingsPluginsEditorAdvancedLegacyParserZhTw._(_root);
	@override late final _TranslationsSettingsPluginsEditorAdvancedHttpPostZhTw httpPost = _TranslationsSettingsPluginsEditorAdvancedHttpPostZhTw._(_root);
	@override late final _TranslationsSettingsPluginsEditorAdvancedNativePlayerZhTw nativePlayer = _TranslationsSettingsPluginsEditorAdvancedNativePlayerZhTw._(_root);
}

// Path: settings.plugins.shop.tooltip
class _TranslationsSettingsPluginsShopTooltipZhTw extends _TranslationsSettingsPluginsShopTooltipEnUs {
	_TranslationsSettingsPluginsShopTooltipZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get sortByName => '按名稱排序';
	@override String get sortByUpdate => '按最後更新排序';
	@override String get refresh => '重新整理規則列表';
}

// Path: settings.plugins.shop.labels
class _TranslationsSettingsPluginsShopLabelsZhTw extends _TranslationsSettingsPluginsShopLabelsEnUs {
	_TranslationsSettingsPluginsShopLabelsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override late final _TranslationsSettingsPluginsShopLabelsPlayerTypeZhTw playerType = _TranslationsSettingsPluginsShopLabelsPlayerTypeZhTw._(_root);
	@override String get lastUpdated => '最後更新：{timestamp}';
}

// Path: settings.plugins.shop.buttons
class _TranslationsSettingsPluginsShopButtonsZhTw extends _TranslationsSettingsPluginsShopButtonsEnUs {
	_TranslationsSettingsPluginsShopButtonsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get install => '新增';
	@override String get installed => '已新增';
	@override String get update => '更新';
	@override String get toggleMirrorEnable => '啟用鏡像';
	@override String get toggleMirrorDisable => '停用鏡像';
	@override String get refresh => '重新整理';
}

// Path: settings.plugins.shop.toast
class _TranslationsSettingsPluginsShopToastZhTw extends _TranslationsSettingsPluginsShopToastEnUs {
	_TranslationsSettingsPluginsShopToastZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get importFailed => '規則匯入失敗。';
}

// Path: settings.plugins.shop.error
class _TranslationsSettingsPluginsShopErrorZhTw extends _TranslationsSettingsPluginsShopErrorEnUs {
	_TranslationsSettingsPluginsShopErrorZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get unreachable => '無法連線到儲存庫\n{status}';
	@override String get mirrorEnabled => '鏡像已啟用';
	@override String get mirrorDisabled => '鏡像已停用';
}

// Path: settings.player.superResolutionOptions.off
class _TranslationsSettingsPlayerSuperResolutionOptionsOffZhTw extends _TranslationsSettingsPlayerSuperResolutionOptionsOffEnUs {
	_TranslationsSettingsPlayerSuperResolutionOptionsOffZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get label => '關閉';
	@override String get description => '停用所有升級增強功能。';
}

// Path: settings.player.superResolutionOptions.efficiency
class _TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyZhTw extends _TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyEnUs {
	_TranslationsSettingsPlayerSuperResolutionOptionsEfficiencyZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get label => '平衡';
	@override String get description => '平衡效能使用與畫質。';
}

// Path: settings.player.superResolutionOptions.quality
class _TranslationsSettingsPlayerSuperResolutionOptionsQualityZhTw extends _TranslationsSettingsPlayerSuperResolutionOptionsQualityEnUs {
	_TranslationsSettingsPlayerSuperResolutionOptionsQualityZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get label => '品質優先';
	@override String get description => '最大化視覺品質，消耗更多資源。';
}

// Path: settings.webdav.editor.toast
class _TranslationsSettingsWebdavEditorToastZhTw extends _TranslationsSettingsWebdavEditorToastEnUs {
	_TranslationsSettingsWebdavEditorToastZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get saveSuccess => '設定已儲存。開始測試…';
	@override String get saveFailed => '儲存設定失敗：{error}';
	@override String get testSuccess => '測試成功。';
	@override String get testFailed => '測試失敗：{error}';
}

// Path: settings.update.dialog.actions
class _TranslationsSettingsUpdateDialogActionsZhTw extends _TranslationsSettingsUpdateDialogActionsEnUs {
	_TranslationsSettingsUpdateDialogActionsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get disableAutoUpdate => '停用自動更新';
	@override String get remindLater => '稍後提醒';
	@override String get viewDetails => '檢視詳情';
	@override String get updateNow => '立即更新';
}

// Path: settings.update.download.error
class _TranslationsSettingsUpdateDownloadErrorZhTw extends _TranslationsSettingsUpdateDownloadErrorEnUs {
	_TranslationsSettingsUpdateDownloadErrorZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '下載失敗';
	@override String get general => '無法下載更新。';
	@override String get permission => '權限不足，無法寫入檔案。';
	@override String get diskFull => '磁碟空間不足。';
	@override String get network => '網路連線失敗。';
	@override String get integrity => '檔案完整性檢查失敗。請重試。';
	@override String get details => '技術詳情：{error}';
	@override String get confirm => '確定';
	@override String get retry => '重試';
}

// Path: settings.update.download.complete
class _TranslationsSettingsUpdateDownloadCompleteZhTw extends _TranslationsSettingsUpdateDownloadCompleteEnUs {
	_TranslationsSettingsUpdateDownloadCompleteZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '下載完成';
	@override String get message => '已下載 Haipee {version}。';
	@override String get quitNotice => '應用程式將在安裝期間離開。';
	@override String get fileLocation => '檔案儲存至';
	@override late final _TranslationsSettingsUpdateDownloadCompleteButtonsZhTw buttons = _TranslationsSettingsUpdateDownloadCompleteButtonsZhTw._(_root);
}

// Path: settings.about.sections.licenses
class _TranslationsSettingsAboutSectionsLicensesZhTw extends _TranslationsSettingsAboutSectionsLicensesEnUs {
	_TranslationsSettingsAboutSectionsLicensesZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '開源許可證';
	@override String get description => '查看所有開源許可證';
}

// Path: settings.about.sections.links
class _TranslationsSettingsAboutSectionsLinksZhTw extends _TranslationsSettingsAboutSectionsLinksEnUs {
	_TranslationsSettingsAboutSectionsLinksZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '外部連結';
	@override String get project => '專案首頁';
	@override String get repository => '原始碼儲存庫';
	@override String get icon => '圖標設計';
	@override String get index => '動畫索引';
	@override String get danmaku => '彈幕提供者';
	@override String get danmakuId => 'ID：{id}';
}

// Path: settings.about.sections.cache
class _TranslationsSettingsAboutSectionsCacheZhTw extends _TranslationsSettingsAboutSectionsCacheEnUs {
	_TranslationsSettingsAboutSectionsCacheZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get clearAction => '清除快取';
	@override String get sizePending => '計算中…';
	@override String get sizeLabel => '{size} MB';
}

// Path: settings.about.sections.updates
class _TranslationsSettingsAboutSectionsUpdatesZhTw extends _TranslationsSettingsAboutSectionsUpdatesEnUs {
	_TranslationsSettingsAboutSectionsUpdatesZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '應用程式更新';
	@override String get autoUpdate => '自動更新';
	@override String get check => '檢查更新';
	@override String get currentVersion => '目前版本 {version}';
}

// Path: settings.about.logs.toast
class _TranslationsSettingsAboutLogsToastZhTw extends _TranslationsSettingsAboutLogsToastEnUs {
	_TranslationsSettingsAboutLogsToastZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get cleared => '日誌已清除。';
	@override String get clearFailed => '清除日誌失敗。';
}

// Path: library.timeline.season.names
class _TranslationsLibraryTimelineSeasonNamesZhTw extends _TranslationsLibraryTimelineSeasonNamesEnUs {
	_TranslationsLibraryTimelineSeasonNamesZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get winter => '冬';
	@override String get spring => '春';
	@override String get summer => '夏';
	@override String get autumn => '秋';
}

// Path: library.timeline.season.short
class _TranslationsLibraryTimelineSeasonShortZhTw extends _TranslationsLibraryTimelineSeasonShortEnUs {
	_TranslationsLibraryTimelineSeasonShortZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get winter => '冬';
	@override String get spring => '春';
	@override String get summer => '夏';
	@override String get autumn => '秋';
}

// Path: library.info.sourceSheet.alias
class _TranslationsLibraryInfoSourceSheetAliasZhTw extends _TranslationsLibraryInfoSourceSheetAliasEnUs {
	_TranslationsLibraryInfoSourceSheetAliasZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get deleteTooltip => '刪除別名';
	@override String get deleteTitle => '刪除別名';
	@override String get deleteMessage => '此操作無法撤銷。確定要刪除此別名嗎？';
}

// Path: library.info.sourceSheet.toast
class _TranslationsLibraryInfoSourceSheetToastZhTw extends _TranslationsLibraryInfoSourceSheetToastEnUs {
	_TranslationsLibraryInfoSourceSheetToastZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get aliasEmpty => '沒有可用的別名。請先手動新增後再搜尋。';
	@override String get loadFailed => '載入播放路線失敗。';
	@override String get removed => '已移除來源 {plugin}。';
}

// Path: library.info.sourceSheet.sort
class _TranslationsLibraryInfoSourceSheetSortZhTw extends _TranslationsLibraryInfoSourceSheetSortEnUs {
	_TranslationsLibraryInfoSourceSheetSortZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '排序方式';
	@override String get tooltip => '排序：{label}';
	@override late final _TranslationsLibraryInfoSourceSheetSortOptionsZhTw options = _TranslationsLibraryInfoSourceSheetSortOptionsZhTw._(_root);
}

// Path: library.info.sourceSheet.card
class _TranslationsLibraryInfoSourceSheetCardZhTw extends _TranslationsLibraryInfoSourceSheetCardEnUs {
	_TranslationsLibraryInfoSourceSheetCardZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '來源 · {plugin}';
	@override String get play => '播放';
}

// Path: library.info.sourceSheet.actions
class _TranslationsLibraryInfoSourceSheetActionsZhTw extends _TranslationsLibraryInfoSourceSheetActionsEnUs {
	_TranslationsLibraryInfoSourceSheetActionsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get searchAgain => '重新搜尋';
	@override String get aliasSearch => '別名搜尋';
	@override String get removeSource => '移除來源';
}

// Path: library.info.sourceSheet.status
class _TranslationsLibraryInfoSourceSheetStatusZhTw extends _TranslationsLibraryInfoSourceSheetStatusEnUs {
	_TranslationsLibraryInfoSourceSheetStatusZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get searching => '{plugin} 搜尋中…';
	@override String get failed => '{plugin} 搜尋失敗';
	@override String get empty => '{plugin} 沒有回傳結果';
}

// Path: library.info.sourceSheet.empty
class _TranslationsLibraryInfoSourceSheetEmptyZhTw extends _TranslationsLibraryInfoSourceSheetEmptyEnUs {
	_TranslationsLibraryInfoSourceSheetEmptyZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get searching => '搜尋中，請稍候…';
	@override String get noResults => '找不到播放來源。請嘗試重新搜尋或使用別名。';
}

// Path: library.info.sourceSheet.dialog
class _TranslationsLibraryInfoSourceSheetDialogZhTw extends _TranslationsLibraryInfoSourceSheetDialogEnUs {
	_TranslationsLibraryInfoSourceSheetDialogZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get removeTitle => '移除來源';
	@override String get removeMessage => '移除來源 {plugin}？';
}

// Path: library.my.favorites.tabs
class _TranslationsLibraryMyFavoritesTabsZhTw extends _TranslationsLibraryMyFavoritesTabsEnUs {
	_TranslationsLibraryMyFavoritesTabsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get watching => '觀看中';
	@override String get planned => '計劃觀看';
	@override String get completed => '已完成';
	@override String get empty => '尚無項目。';
}

// Path: library.my.favorites.sync
class _TranslationsLibraryMyFavoritesSyncZhTw extends _TranslationsLibraryMyFavoritesSyncEnUs {
	_TranslationsLibraryMyFavoritesSyncZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get disabled => 'WebDAV 同步已停用。';
	@override String get editing => '編輯模式下無法同步。';
}

// Path: playback.controls.aspectRatio.options
class _TranslationsPlaybackControlsAspectRatioOptionsZhTw extends _TranslationsPlaybackControlsAspectRatioOptionsEnUs {
	_TranslationsPlaybackControlsAspectRatioOptionsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get auto => '自動';
	@override String get crop => '裁切填充';
	@override String get stretch => '拉伸填充';
}

// Path: settings.plugins.editor.advanced.legacyParser
class _TranslationsSettingsPluginsEditorAdvancedLegacyParserZhTw extends _TranslationsSettingsPluginsEditorAdvancedLegacyParserEnUs {
	_TranslationsSettingsPluginsEditorAdvancedLegacyParserZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '啟用舊版解析器';
	@override String get subtitle => '使用舊版 XPath 解析器以保持相容性。';
}

// Path: settings.plugins.editor.advanced.httpPost
class _TranslationsSettingsPluginsEditorAdvancedHttpPostZhTw extends _TranslationsSettingsPluginsEditorAdvancedHttpPostEnUs {
	_TranslationsSettingsPluginsEditorAdvancedHttpPostZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '透過 POST 發送搜尋';
	@override String get subtitle => '使用 HTTP POST 提交搜尋要求。';
}

// Path: settings.plugins.editor.advanced.nativePlayer
class _TranslationsSettingsPluginsEditorAdvancedNativePlayerZhTw extends _TranslationsSettingsPluginsEditorAdvancedNativePlayerEnUs {
	_TranslationsSettingsPluginsEditorAdvancedNativePlayerZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get title => '強制原生播放器';
	@override String get subtitle => '啟動播放時優先使用內建播放器。';
}

// Path: settings.plugins.shop.labels.playerType
class _TranslationsSettingsPluginsShopLabelsPlayerTypeZhTw extends _TranslationsSettingsPluginsShopLabelsPlayerTypeEnUs {
	_TranslationsSettingsPluginsShopLabelsPlayerTypeZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get native => '原生';
	@override String get webview => '網頁檢視';
}

// Path: settings.update.download.complete.buttons
class _TranslationsSettingsUpdateDownloadCompleteButtonsZhTw extends _TranslationsSettingsUpdateDownloadCompleteButtonsEnUs {
	_TranslationsSettingsUpdateDownloadCompleteButtonsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get later => '稍後';
	@override String get openFolder => '開啟資料夾';
	@override String get installNow => '立即安裝';
}

// Path: library.info.sourceSheet.sort.options
class _TranslationsLibraryInfoSourceSheetSortOptionsZhTw extends _TranslationsLibraryInfoSourceSheetSortOptionsEnUs {
	_TranslationsLibraryInfoSourceSheetSortOptionsZhTw._(_TranslationsZhTw root) : this._root = root, super._(root);

	@override final _TranslationsZhTw _root; // ignore: unused_field

	// Translations
	@override String get original => '原始順序';
	@override String get nameAsc => '名稱（Ａ → ３）';
	@override String get nameDesc => '名稱（３ → Ａ）';
	@override String get failureAsc => '失敗次數（低 → 高）';
	@override String get failureDesc => '失敗次數（高 → 低）';
}

/// Flat map(s) containing all translations.
/// Only for edge cases! For simple maps, use the map function of this library.

extension on AppTranslations {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'app.title': return 'Haipee';
			case 'app.loading': return 'Loading…';
			case 'app.retry': return 'Retry';
			case 'app.confirm': return 'Confirm';
			case 'app.cancel': return 'Cancel';
			case 'app.delete': return 'Delete';
			case 'metadata.sectionTitle': return 'Media Information';
			case 'metadata.refresh': return 'Refresh Metadata';
			case 'metadata.source.bangumi': return 'Bangumi';
			case 'metadata.source.tmdb': return 'TMDb';
			case 'metadata.lastSynced': return 'Last synced: {timestamp}';
			case 'downloads.sectionTitle': return 'Download Queue';
			case 'downloads.downloadOffline': return 'Download engine not connected';
			case 'downloads.queued': return 'Queued';
			case 'downloads.running': return 'Downloading';
			case 'downloads.completed': return 'Completed';
			case 'downloads.page.title': return 'Download Manager';
			case 'downloads.page.selectedItems': return ({required Object count}) => '${count} items selected';
			case 'downloads.page.newDownload': return 'New Download';
			case 'downloads.page.batchManage': return 'Batch Manage';
			case 'downloads.page.downloadSettings': return 'Download Settings';
			case 'downloads.page.refresh': return 'Refresh';
			case 'downloads.page.tabs.downloading': return ({required Object count}) => 'Downloading (${count})';
			case 'downloads.page.tabs.paused': return ({required Object count}) => 'Paused (${count})';
			case 'downloads.page.tabs.completed': return ({required Object count}) => 'Completed (${count})';
			case 'downloads.page.tabs.failed': return ({required Object count}) => 'Failed (${count})';
			case 'downloads.page.tabs.all': return 'All';
			case 'downloads.page.actions.selectAll': return 'Select All';
			case 'downloads.page.actions.resume': return 'Resume';
			case 'downloads.page.actions.pause': return 'Pause';
			case 'downloads.page.actions.pauseAll': return 'Pause All';
			case 'downloads.page.actions.resumeAll': return 'Resume All';
			case 'downloads.page.actions.clearCompleted': return 'Clear Completed';
			case 'downloads.page.actions.deleteAll': return 'Delete All';
			case 'downloads.page.actions.retry': return 'Retry';
			case 'downloads.page.actions.delete': return 'Delete';
			case 'downloads.page.actions.open': return 'Open';
			case 'downloads.page.statistics.tasks': return ({required Object count}) => '${count} tasks';
			case 'downloads.page.statistics.eta': return ({required Object time}) => 'ETA ${time}';
			case 'downloads.page.search.placeholder': return 'Search downloads...';
			case 'downloads.page.search.clear': return 'Clear';
			case 'downloads.page.sort.label': return 'Sort';
			case 'downloads.page.sort.created': return 'Created Time';
			case 'downloads.page.sort.name': return 'File Name';
			case 'downloads.page.sort.size': return 'File Size';
			case 'downloads.page.sort.speed': return 'Download Speed';
			case 'downloads.page.sort.progress': return 'Progress';
			case 'downloads.page.empty.downloading': return 'No active downloads';
			case 'downloads.page.empty.paused': return 'No paused downloads';
			case 'downloads.page.empty.completed': return 'No completed downloads yet';
			case 'downloads.page.empty.failed': return 'No failed downloads';
			case 'downloads.page.empty.all': return 'Download list is empty';
			case 'downloads.page.empty.hint': return 'Click the new button above to add downloads';
			case 'downloads.page.status.active': return 'Downloading';
			case 'downloads.page.status.waiting': return 'Waiting';
			case 'downloads.page.status.paused': return 'Paused';
			case 'downloads.page.status.error': return 'Error';
			case 'downloads.page.status.complete': return 'Completed';
			case 'downloads.page.status.removed': return 'Removed';
			case 'downloads.page.dialog.deleteConfirm': return 'Are you sure you want to delete the selected downloads?';
			case 'downloads.page.dialog.deleteAllConfirm': return 'Are you sure you want to delete all downloads? This action cannot be undone.';
			case 'downloads.page.toast.addedToQueue': return 'Added to download queue';
			case 'downloads.page.toast.resumed': return 'Download resumed';
			case 'downloads.page.toast.paused': return 'Download paused';
			case 'downloads.page.toast.deleted': return 'Deleted';
			case 'downloads.page.toast.retrying': return 'Re-added to download queue';
			case 'downloads.page.toast.fileLocation': return ({required Object path}) => 'File location: ${path}';
			case 'downloads.addDialog.title': return 'New Download Task';
			case 'downloads.addDialog.tabs.url': return 'URL Download';
			case 'downloads.addDialog.tabs.torrent': return 'Torrent Download';
			case 'downloads.addDialog.url.hint': return 'Enter download links, one per line\nSupported:\n- HTTP/HTTPS links\n- FTP links\n- Magnet links (magnet:?xt=...)';
			case 'downloads.addDialog.torrent.dropZone': return 'Drop torrent file here';
			case 'downloads.addDialog.torrent.dropZoneWindows': return 'Click the button below to select torrent file';
			case 'downloads.addDialog.torrent.supported': return 'Supports .torrent files';
			case 'downloads.addDialog.torrent.selectFile': return 'Select Torrent File';
			case 'downloads.addDialog.advanced.title': return 'Advanced Options';
			case 'downloads.addDialog.advanced.savePath': return 'Save Path (Optional)';
			case 'downloads.addDialog.advanced.savePathHint': return 'Leave empty to use default download path';
			case 'downloads.addDialog.advanced.connections': return ({required Object count}) => 'Connections per file: ${count}';
			case 'downloads.addDialog.advanced.split': return ({required Object count}) => 'Split per task: ${count}';
			case 'downloads.addDialog.actions.cancel': return 'Cancel';
			case 'downloads.addDialog.actions.start': return 'Start Download';
			case 'downloads.addDialog.errors.noUrl': return 'Please enter at least one download link';
			case 'downloads.addDialog.errors.noTorrent': return 'Please select or drop a torrent file';
			case 'downloads.addDialog.errors.selectFileFailed': return ({required Object error}) => 'Failed to select file: ${error}';
			case 'downloads.addDialog.errors.selectPathFailed': return ({required Object error}) => 'Failed to select path: ${error}';
			case 'downloads.addDialog.errors.submitFailed': return ({required Object error}) => 'Failed to add download: ${error}';
			case 'downloads.addDialog.toast.added': return ({required Object count}) => 'Added ${count} download tasks';
			case 'downloads.addDialog.toast.addedTorrent': return 'Added torrent download task';
			case 'downloads.detailDialog.title': return 'Task Details';
			case 'downloads.detailDialog.sections.taskName': return 'Task Name';
			case 'downloads.detailDialog.sections.fileName': return 'File Name';
			case 'downloads.detailDialog.sections.fileSize': return 'File Size';
			case 'downloads.detailDialog.sections.progress': return 'Download Progress';
			case 'downloads.detailDialog.sections.speed': return 'Download Speed';
			case 'downloads.detailDialog.sections.uploadSpeed': return 'Upload Speed';
			case 'downloads.detailDialog.sections.connections': return 'Connections';
			case 'downloads.detailDialog.sections.eta': return 'Estimated Time';
			case 'downloads.detailDialog.sections.filePath': return 'File Path';
			case 'downloads.detailDialog.sections.gid': return 'Task ID';
			case 'downloads.detailDialog.sections.createdAt': return 'Created At';
			case 'downloads.detailDialog.actions.copyPath': return 'Copy Path';
			case 'downloads.detailDialog.actions.openFile': return 'Open File';
			case 'downloads.detailDialog.actions.openFolder': return 'Open Folder';
			case 'downloads.detailDialog.actions.retry': return 'Retry Download';
			case 'downloads.detailDialog.actions.close': return 'Close';
			case 'downloads.detailDialog.toast.pathCopied': return 'Path copied';
			case 'torrent.consent.title': return 'BitTorrent Usage Notice';
			case 'torrent.consent.description': return 'Before enabling BT downloads, please confirm compliance with local laws and understand the risks involved.';
			case 'torrent.consent.agree': return 'I understand, continue';
			case 'torrent.consent.decline': return 'Not now';
			case 'torrent.error.submit': return 'Unable to submit magnet link, please try again later';
			case 'settings.title': return 'Settings';
			case 'settings.downloads': return 'Download Settings';
			case 'settings.playback': return 'Playback Preferences';
			case 'settings.general.title': return 'General';
			case 'settings.general.appearance': return 'Appearance';
			case 'settings.general.appearanceDesc': return 'Configure app theme and refresh rate';
			case 'settings.general.language': return 'App Language';
			case 'settings.general.languageDesc': return 'Choose the display language for the app interface';
			case 'settings.general.followSystem': return 'System';
			case 'settings.general.exitBehavior': return 'On Close';
			case 'settings.general.exitApp': return 'Exit Haipee';
			case 'settings.general.minimizeToTray': return 'Minimize to Tray';
			case 'settings.general.askEveryTime': return 'Ask Every Time';
			case 'settings.appearancePage.title': return 'Appearance';
			case 'settings.appearancePage.mode.title': return 'Theme mode';
			case 'settings.appearancePage.mode.system': return 'system';
			case 'settings.appearancePage.mode.light': return 'Light';
			case 'settings.appearancePage.mode.dark': return 'Dark';
			case 'settings.appearancePage.colorScheme.title': return 'Accent color';
			case 'settings.appearancePage.colorScheme.dialogTitle': return 'Choose an accent color';
			case 'settings.appearancePage.colorScheme.dynamicColor': return 'Use dynamic color';
			case 'settings.appearancePage.colorScheme.dynamicColorInfo': return 'Generate a palette from your wallpaper when supported (Android 12+ / Windows 11).';
			case 'settings.appearancePage.colorScheme.labels.defaultLabel': return 'Default';
			case 'settings.appearancePage.colorScheme.labels.teal': return 'Teal';
			case 'settings.appearancePage.colorScheme.labels.blue': return 'Blue';
			case 'settings.appearancePage.colorScheme.labels.indigo': return 'Indigo';
			case 'settings.appearancePage.colorScheme.labels.violet': return 'Violet';
			case 'settings.appearancePage.colorScheme.labels.pink': return 'Pink';
			case 'settings.appearancePage.colorScheme.labels.yellow': return 'Yellow';
			case 'settings.appearancePage.colorScheme.labels.orange': return 'Orange';
			case 'settings.appearancePage.colorScheme.labels.deepOrange': return 'Deep orange';
			case 'settings.appearancePage.oled.title': return 'OLED contrast';
			case 'settings.appearancePage.oled.description': return 'Use deeper blacks optimized for OLED displays.';
			case 'settings.appearancePage.window.title': return 'Window buttons';
			case 'settings.appearancePage.window.description': return 'Show window control buttons in the title bar.';
			case 'settings.appearancePage.refreshRate.title': return 'Refresh rate';
			case 'settings.source.title': return 'Source';
			case 'settings.source.ruleManagement': return 'Rule Management';
			case 'settings.source.ruleManagementDesc': return 'Manage anime resource rules';
			case 'settings.source.githubProxy': return 'GitHub Proxy';
			case 'settings.source.githubProxyDesc': return 'Use proxy to access rule repository';
			case 'settings.plugins.title': return 'Rule Management';
			case 'settings.plugins.empty': return 'No rules available';
			case 'settings.plugins.tooltip.updateAll': return 'Update all';
			case 'settings.plugins.tooltip.addRule': return 'Add rule';
			case 'settings.plugins.sort.title': return 'Sort order';
			case 'settings.plugins.sort.tooltip': return 'Sort';
			case 'settings.plugins.sort.options.original': return 'Original order';
			case 'settings.plugins.sort.options.nameAsc': return 'Name (A → Z)';
			case 'settings.plugins.sort.options.nameDesc': return 'Name (Z → A)';
			case 'settings.plugins.sort.options.failureAsc': return 'Failures (Low → High)';
			case 'settings.plugins.sort.options.failureDesc': return 'Failures (High → Low)';
			case 'settings.plugins.multiSelect.selectedCount': return '{count} selected';
			case 'settings.plugins.loading.updating': return 'Updating rules…';
			case 'settings.plugins.loading.updatingSingle': return 'Updating…';
			case 'settings.plugins.loading.importing': return 'Importing…';
			case 'settings.plugins.labels.version': return 'Version: {version}';
			case 'settings.plugins.labels.statusUpdatable': return 'Update available';
			case 'settings.plugins.labels.statusSearchValid': return 'Search valid';
			case 'settings.plugins.actions.newRule': return 'Create rule';
			case 'settings.plugins.actions.importFromRepo': return 'Import from repository';
			case 'settings.plugins.actions.importFromClipboard': return 'Import from clipboard';
			case 'settings.plugins.actions.cancel': return 'Cancel';
			case 'settings.plugins.actions.import': return 'Import';
			case 'settings.plugins.actions.update': return 'Update';
			case 'settings.plugins.actions.edit': return 'Edit';
			case 'settings.plugins.actions.copyToClipboard': return 'Copy to clipboard';
			case 'settings.plugins.actions.share': return 'Share';
			case 'settings.plugins.actions.delete': return 'Delete';
			case 'settings.plugins.dialogs.deleteTitle': return 'Delete rules';
			case 'settings.plugins.dialogs.deleteMessage': return 'Delete {count} selected rule(s)?';
			case 'settings.plugins.dialogs.importTitle': return 'Import rule';
			case 'settings.plugins.dialogs.shareTitle': return 'Rule link';
			case 'settings.plugins.toast.allUpToDate': return 'All rules are up to date.';
			case 'settings.plugins.toast.updateCount': return 'Updated {count} rule(s).';
			case 'settings.plugins.toast.importSuccess': return 'Import successful.';
			case 'settings.plugins.toast.importFailed': return 'Import failed: {error}';
			case 'settings.plugins.toast.repoMissing': return 'The repository does not contain this rule.';
			case 'settings.plugins.toast.alreadyLatest': return 'Rule is already the latest.';
			case 'settings.plugins.toast.updateSuccess': return 'Update successful.';
			case 'settings.plugins.toast.updateIncompatible': return 'Haipee is too old; this rule is incompatible.';
			case 'settings.plugins.toast.updateFailed': return 'Failed to update rule.';
			case 'settings.plugins.toast.copySuccess': return 'Copied to clipboard.';
			case 'settings.plugins.editor.title': return 'Edit Rule';
			case 'settings.plugins.editor.fields.name': return 'Rule name';
			case 'settings.plugins.editor.fields.version': return 'Version';
			case 'settings.plugins.editor.fields.baseUrl': return 'Base URL';
			case 'settings.plugins.editor.fields.searchUrl': return 'Search URL';
			case 'settings.plugins.editor.fields.searchList': return 'Search list XPath';
			case 'settings.plugins.editor.fields.searchName': return 'Search title XPath';
			case 'settings.plugins.editor.fields.searchResult': return 'Search result XPath';
			case 'settings.plugins.editor.fields.chapterRoads': return 'Playlist XPath';
			case 'settings.plugins.editor.fields.chapterResult': return 'Playlist result XPath';
			case 'settings.plugins.editor.fields.userAgent': return 'User-Agent';
			case 'settings.plugins.editor.fields.referer': return 'Referer';
			case 'settings.plugins.editor.advanced.title': return 'Advanced Options';
			case 'settings.plugins.editor.advanced.legacyParser.title': return 'Enable legacy parser';
			case 'settings.plugins.editor.advanced.legacyParser.subtitle': return 'Use the legacy XPath parser for compatibility.';
			case 'settings.plugins.editor.advanced.httpPost.title': return 'Send search via POST';
			case 'settings.plugins.editor.advanced.httpPost.subtitle': return 'Submit search requests with HTTP POST.';
			case 'settings.plugins.editor.advanced.nativePlayer.title': return 'Force native player';
			case 'settings.plugins.editor.advanced.nativePlayer.subtitle': return 'Prefer the built-in player when starting playback.';
			case 'settings.plugins.shop.title': return 'Rule Repository';
			case 'settings.plugins.shop.tooltip.sortByName': return 'Sort by name';
			case 'settings.plugins.shop.tooltip.sortByUpdate': return 'Sort by last update';
			case 'settings.plugins.shop.tooltip.refresh': return 'Refresh rule list';
			case 'settings.plugins.shop.labels.playerType.native': return 'native';
			case 'settings.plugins.shop.labels.playerType.webview': return 'webview';
			case 'settings.plugins.shop.labels.lastUpdated': return 'Last updated: {timestamp}';
			case 'settings.plugins.shop.buttons.install': return 'Add';
			case 'settings.plugins.shop.buttons.installed': return 'Added';
			case 'settings.plugins.shop.buttons.update': return 'Update';
			case 'settings.plugins.shop.buttons.toggleMirrorEnable': return 'Enable mirror';
			case 'settings.plugins.shop.buttons.toggleMirrorDisable': return 'Disable mirror';
			case 'settings.plugins.shop.buttons.refresh': return 'Refresh';
			case 'settings.plugins.shop.toast.importFailed': return 'Failed to import rule.';
			case 'settings.plugins.shop.error.unreachable': return 'Unable to reach the repository\n{status}';
			case 'settings.plugins.shop.error.mirrorEnabled': return 'Mirror enabled';
			case 'settings.plugins.shop.error.mirrorDisabled': return 'Mirror disabled';
			case 'settings.metadata.title': return 'Information Sources';
			case 'settings.metadata.enableBangumi': return 'Enable Bangumi Information Source';
			case 'settings.metadata.enableBangumiDesc': return 'Fetch anime information from Bangumi';
			case 'settings.metadata.enableTmdb': return 'Enable TMDb Information Source';
			case 'settings.metadata.enableTmdbDesc': return 'Supplement multilingual data from TMDb';
			case 'settings.metadata.preferredLanguage': return 'Preferred Language';
			case 'settings.metadata.preferredLanguageDesc': return 'Set the language for metadata synchronization';
			case 'settings.metadata.followSystemLanguage': return 'Follow System Language';
			case 'settings.metadata.simplifiedChinese': return 'Simplified Chinese (zh-CN)';
			case 'settings.metadata.traditionalChinese': return 'Traditional Chinese (zh-TW)';
			case 'settings.metadata.japanese': return 'Japanese (ja-JP)';
			case 'settings.metadata.english': return 'English (en-US)';
			case 'settings.metadata.custom': return 'Custom';
			case 'settings.player.title': return 'Player Settings';
			case 'settings.player.playerSettings': return 'Player Settings';
			case 'settings.player.playerSettingsDesc': return 'Configure player parameters';
			case 'settings.player.hardwareDecoding': return 'Hardware Decoding';
			case 'settings.player.hardwareDecoder': return 'Hardware Decoder';
			case 'settings.player.hardwareDecoderDesc': return 'Only takes effect when hardware decoding is enabled';
			case 'settings.player.lowMemoryMode': return 'Low Memory Mode';
			case 'settings.player.lowMemoryModeDesc': return 'Disable advanced caching to reduce memory usage';
			case 'settings.player.lowLatencyAudio': return 'Low Latency Audio';
			case 'settings.player.lowLatencyAudioDesc': return 'Enable OpenSLES audio output to reduce latency';
			case 'settings.player.superResolution': return 'Super Resolution';
			case 'settings.player.autoJump': return 'Auto Jump';
			case 'settings.player.autoJumpDesc': return 'Jump to last playback position';
			case 'settings.player.disableAnimations': return 'Disable transition animations';
			case 'settings.player.disableAnimationsDesc': return 'Disable transition animations in the player';
			case 'settings.player.errorPrompt': return 'Error Prompt';
			case 'settings.player.errorPromptDesc': return 'Show player internal error prompts';
			case 'settings.player.debugMode': return 'Debug Mode';
			case 'settings.player.debugModeDesc': return 'Log player internal logs';
			case 'settings.player.privateMode': return 'Private Mode';
			case 'settings.player.privateModeDesc': return 'Don\'t keep viewing history';
			case 'settings.player.defaultPlaySpeed': return 'Default Playback Speed';
			case 'settings.player.defaultVideoAspectRatio': return 'Default Video Aspect Ratio';
			case 'settings.player.aspectRatio.auto': return 'Auto';
			case 'settings.player.aspectRatio.crop': return 'Crop to fill';
			case 'settings.player.aspectRatio.stretch': return 'Stretch to fill';
			case 'settings.player.danmakuSettings': return 'Danmaku Settings';
			case 'settings.player.danmakuSettingsDesc': return 'Configure danmaku parameters';
			case 'settings.player.danmaku': return 'Danmaku';
			case 'settings.player.danmakuDefaultOn': return 'Default On';
			case 'settings.player.danmakuDefaultOnDesc': return 'Whether to play danmaku with video by default';
			case 'settings.player.danmakuSource': return 'Danmaku Source';
			case 'settings.player.danmakuSources.bilibili': return 'Bilibili';
			case 'settings.player.danmakuSources.gamer': return 'Gamer';
			case 'settings.player.danmakuSources.dandan': return 'DanDan';
			case 'settings.player.danmakuCredentials': return 'Credentials';
			case 'settings.player.danmakuDanDanCredentials': return 'DanDan API Credentials';
			case 'settings.player.danmakuDanDanCredentialsDesc': return 'Customize DanDan credentials';
			case 'settings.player.danmakuCredentialModeBuiltIn': return 'Built-in';
			case 'settings.player.danmakuCredentialModeCustom': return 'Custom';
			case 'settings.player.danmakuCredentialHint': return 'Leave blank to use built-in credentials';
			case 'settings.player.danmakuCredentialNotConfigured': return 'Not configured';
			case 'settings.player.danmakuCredentialsSummary': return 'App ID: {appId}\nAPI Key: {apiKey}';
			case 'settings.player.danmakuShield': return 'Danmaku Shield';
			case 'settings.player.danmakuKeywordShield': return 'Keyword Shield';
			case 'settings.player.danmakuShieldInputHint': return 'Enter a keyword or regular expression';
			case 'settings.player.danmakuShieldDescription': return 'Text starting and ending with "/" will be treated as regular expressions, e.g. "/\\d+/" blocks all numbers';
			case 'settings.player.danmakuShieldCount': return 'Added {count} keywords';
			case 'settings.player.danmakuConvert': return 'Conversion';
			case 'settings.player.danmakuConvertTitle': return 'Danmaku Simplified/Traditional Conversion';
			case 'settings.player.danmakuConvertDesc': return 'Takes effect upon next online load. Cached danmaku retains original text';
			case 'settings.player.danmakuConvertNone': return 'No conversion';
			case 'settings.player.danmakuConvertSimplified': return 'Convert to Simplified';
			case 'settings.player.danmakuConvertTraditional': return 'Convert to Traditional';
			case 'settings.player.danmakuStyle': return 'Danmaku Style';
			case 'settings.player.danmakuDisplay': return 'Danmaku Display';
			case 'settings.player.danmakuArea': return 'Danmaku Area';
			case 'settings.player.danmakuTopDisplay': return 'Top Danmaku';
			case 'settings.player.danmakuBottomDisplay': return 'Bottom Danmaku';
			case 'settings.player.danmakuScrollDisplay': return 'Scrolling Danmaku';
			case 'settings.player.danmakuMassiveDisplay': return 'Massive Danmaku';
			case 'settings.player.danmakuMassiveDescription': return 'Overlay rendering when the screen is crowded';
			case 'settings.player.danmakuOutline': return 'Danmaku Outline';
			case 'settings.player.danmakuColor': return 'Danmaku Color';
			case 'settings.player.danmakuFontSize': return 'Font Size';
			case 'settings.player.danmakuFontWeight': return 'Font Weight';
			case 'settings.player.danmakuOpacity': return 'Danmaku Opacity';
			case 'settings.player.add': return 'Add';
			case 'settings.player.save': return 'Save';
			case 'settings.player.restoreDefault': return 'Restore Default';
			case 'settings.player.superResolutionTitle': return 'Super Resolution';
			case 'settings.player.superResolutionHint': return 'Choose the default upscaling profile';
			case 'settings.player.superResolutionOptions.off.label': return 'Off';
			case 'settings.player.superResolutionOptions.off.description': return 'Disable all upscaling enhancements.';
			case 'settings.player.superResolutionOptions.efficiency.label': return 'Balanced';
			case 'settings.player.superResolutionOptions.efficiency.description': return 'Balance performance usage and picture quality.';
			case 'settings.player.superResolutionOptions.quality.label': return 'Quality First';
			case 'settings.player.superResolutionOptions.quality.description': return 'Maximize visual quality at the cost of resources.';
			case 'settings.player.superResolutionDefaultBehavior': return 'Default Behavior';
			case 'settings.player.superResolutionClosePrompt': return 'Close Prompt';
			case 'settings.player.superResolutionClosePromptDesc': return 'Close the prompt when enabling super resolution';
			case 'settings.player.toast.danmakuKeywordEmpty': return 'Enter a keyword.';
			case 'settings.player.toast.danmakuKeywordTooLong': return 'Keyword is too long.';
			case 'settings.player.toast.danmakuKeywordExists': return 'Keyword already exists.';
			case 'settings.player.toast.danmakuCredentialsRestored': return 'Reverted to built-in credentials.';
			case 'settings.player.toast.danmakuCredentialsUpdated': return 'Credentials updated.';
			case 'settings.webdav.title': return 'WebDAV';
			case 'settings.webdav.desc': return 'Configure sync parameters';
			case 'settings.webdav.pageTitle': return 'Sync Settings';
			case 'settings.webdav.editor.title': return 'WebDAV Configuration';
			case 'settings.webdav.editor.url': return 'URL';
			case 'settings.webdav.editor.username': return 'Username';
			case 'settings.webdav.editor.password': return 'Password';
			case 'settings.webdav.editor.toast.saveSuccess': return 'Configuration saved. Starting test...';
			case 'settings.webdav.editor.toast.saveFailed': return 'Failed to save configuration: {error}';
			case 'settings.webdav.editor.toast.testSuccess': return 'Test succeeded.';
			case 'settings.webdav.editor.toast.testFailed': return 'Test failed: {error}';
			case 'settings.webdav.section.webdav': return 'WebDAV';
			case 'settings.webdav.tile.webdavToggle': return 'WebDAV Sync';
			case 'settings.webdav.tile.historyToggle': return 'Watch History Sync';
			case 'settings.webdav.tile.historyDescription': return 'Allow automatic syncing of watch history';
			case 'settings.webdav.tile.config': return 'WebDAV Configuration';
			case 'settings.webdav.tile.manualUpload': return 'Manual Upload';
			case 'settings.webdav.tile.manualDownload': return 'Manual Download';
			case 'settings.webdav.info.upload': return 'Upload your watch history to WebDAV immediately.';
			case 'settings.webdav.info.download': return 'Sync your watch history to this device immediately.';
			case 'settings.webdav.toast.uploading': return 'Attempting to upload to WebDAV...';
			case 'settings.webdav.toast.downloading': return 'Attempting to sync from WebDAV...';
			case 'settings.webdav.toast.notConfigured': return 'WebDAV sync is disabled or configuration is invalid.';
			case 'settings.webdav.toast.connectionFailed': return 'Failed to connect to WebDAV: {error}';
			case 'settings.webdav.toast.syncFailed': return 'WebDAV sync failed: {error}';
			case 'settings.webdav.result.initFailed': return 'WebDAV initialization failed: {error}';
			case 'settings.webdav.result.requireEnable': return 'Please enable WebDAV sync first.';
			case 'settings.webdav.result.disabled': return 'WebDAV sync is disabled or configuration is invalid.';
			case 'settings.webdav.result.connectionFailed': return 'Failed to connect to WebDAV.';
			case 'settings.webdav.result.syncSuccess': return 'Sync succeeded.';
			case 'settings.webdav.result.syncFailed': return 'Sync failed: {error}';
			case 'settings.update.fallbackDescription': return 'No release notes provided.';
			case 'settings.update.error.invalidResponse': return 'Invalid update response.';
			case 'settings.update.dialog.title': return 'New version {version} available';
			case 'settings.update.dialog.publishedAt': return 'Released on {date}';
			case 'settings.update.dialog.installationTypeLabel': return 'Select installation package';
			case 'settings.update.dialog.actions.disableAutoUpdate': return 'Disable auto update';
			case 'settings.update.dialog.actions.remindLater': return 'Remind me later';
			case 'settings.update.dialog.actions.viewDetails': return 'View details';
			case 'settings.update.dialog.actions.updateNow': return 'Update now';
			case 'settings.update.installationType.windowsMsix': return 'Windows installer (MSIX)';
			case 'settings.update.installationType.windowsPortable': return 'Windows portable (ZIP)';
			case 'settings.update.installationType.linuxDeb': return 'Linux package (DEB)';
			case 'settings.update.installationType.linuxTar': return 'Linux archive (TAR.GZ)';
			case 'settings.update.installationType.macosDmg': return 'macOS installer (DMG)';
			case 'settings.update.installationType.androidApk': return 'Android package (APK)';
			case 'settings.update.installationType.ios': return 'iOS app (open GitHub)';
			case 'settings.update.installationType.unknown': return 'Other platform';
			case 'settings.update.toast.alreadyLatest': return 'You\'re up to date.';
			case 'settings.update.toast.checkFailed': return 'Failed to check for updates. Please try again later.';
			case 'settings.update.toast.autoUpdateDisabled': return 'Automatic updates disabled.';
			case 'settings.update.toast.downloadLinkMissing': return 'No download available for {type}.';
			case 'settings.update.toast.downloadFailed': return 'Download failed: {error}';
			case 'settings.update.toast.noCompatibleLink': return 'No compatible download link found.';
			case 'settings.update.toast.prepareToInstall': return 'Preparing to install the update. The app will exit…';
			case 'settings.update.toast.openInstallerFailed': return 'Unable to open installer: {error}';
			case 'settings.update.toast.launchInstallerFailed': return 'Failed to launch installer: {error}';
			case 'settings.update.toast.revealFailed': return 'Unable to open the file manager.';
			case 'settings.update.toast.unknownReason': return 'Unknown reason';
			case 'settings.update.download.progressTitle': return 'Downloading update';
			case 'settings.update.download.cancel': return 'Cancel';
			case 'settings.update.download.error.title': return 'Download failed';
			case 'settings.update.download.error.general': return 'The update could not be downloaded.';
			case 'settings.update.download.error.permission': return 'Insufficient permissions to write the file.';
			case 'settings.update.download.error.diskFull': return 'Not enough disk space.';
			case 'settings.update.download.error.network': return 'Network connection failed.';
			case 'settings.update.download.error.integrity': return 'File integrity check failed. Please try again.';
			case 'settings.update.download.error.details': return 'Technical details: {error}';
			case 'settings.update.download.error.confirm': return 'OK';
			case 'settings.update.download.error.retry': return 'Retry';
			case 'settings.update.download.complete.title': return 'Download complete';
			case 'settings.update.download.complete.message': return 'Haipee {version} downloaded.';
			case 'settings.update.download.complete.quitNotice': return 'The app will exit during installation.';
			case 'settings.update.download.complete.fileLocation': return 'File saved to';
			case 'settings.update.download.complete.buttons.later': return 'Later';
			case 'settings.update.download.complete.buttons.openFolder': return 'Open folder';
			case 'settings.update.download.complete.buttons.installNow': return 'Install now';
			case 'settings.other.title': return 'Other';
			case 'settings.other.about': return 'About';
			case 'settings.about.title': return 'About';
			case 'settings.about.sections.licenses.title': return 'Open source licenses';
			case 'settings.about.sections.licenses.description': return 'View all open source licenses';
			case 'settings.about.sections.links.title': return 'External links';
			case 'settings.about.sections.links.project': return 'Project homepage';
			case 'settings.about.sections.links.repository': return 'Source repository';
			case 'settings.about.sections.links.icon': return 'Icon design';
			case 'settings.about.sections.links.index': return 'Anime index';
			case 'settings.about.sections.links.danmaku': return 'Danmaku provider';
			case 'settings.about.sections.links.danmakuId': return 'ID: {id}';
			case 'settings.about.sections.cache.clearAction': return 'Clear cache';
			case 'settings.about.sections.cache.sizePending': return 'Calculating…';
			case 'settings.about.sections.cache.sizeLabel': return '{size} MB';
			case 'settings.about.sections.updates.title': return 'App updates';
			case 'settings.about.sections.updates.autoUpdate': return 'Auto update';
			case 'settings.about.sections.updates.check': return 'Check for updates';
			case 'settings.about.sections.updates.currentVersion': return 'Current version {version}';
			case 'settings.about.logs.title': return 'Application logs';
			case 'settings.about.logs.empty': return 'No log entries available.';
			case 'settings.about.logs.toast.cleared': return 'Logs cleared.';
			case 'settings.about.logs.toast.clearFailed': return 'Failed to clear logs.';
			case 'exitDialog.title': return 'Exit Confirmation';
			case 'exitDialog.message': return 'Do you want to exit Haipee?';
			case 'exitDialog.dontAskAgain': return 'Don\'t ask again';
			case 'exitDialog.exit': return 'Exit Haipee';
			case 'exitDialog.minimize': return 'Minimize to Tray';
			case 'exitDialog.cancel': return 'Cancel';
			case 'tray.showWindow': return 'Show Window';
			case 'tray.exit': return 'Exit Haipee';
			case 'navigation.tabs.popular': return 'Popular';
			case 'navigation.tabs.catalog': return 'Catalog';
			case 'navigation.tabs.media': return 'Online Video';
			case 'navigation.tabs.resource': return 'Resources';
			case 'navigation.tabs.timeline': return 'Timeline';
			case 'navigation.tabs.my': return 'Media Library';
			case 'navigation.tabs.download': return 'Downloads';
			case 'navigation.tabs.settings': return 'Settings';
			case 'navigation.actions.search': return 'Search';
			case 'navigation.actions.history': return 'History';
			case 'navigation.actions.close': return 'Quit';
			case 'dialogs.disclaimer.title': return 'Disclaimer';
			case 'dialogs.disclaimer.agree': return 'I have read and agree';
			case 'dialogs.disclaimer.exit': return 'Exit';
			case 'dialogs.updateMirror.title': return 'Update Mirror';
			case 'dialogs.updateMirror.question': return 'Where would you like to fetch app updates?';
			case 'dialogs.updateMirror.description': return 'GitHub mirror works best for most users. Choose F-Droid if you use the F-Droid store.';
			case 'dialogs.updateMirror.options.github': return 'GitHub';
			case 'dialogs.updateMirror.options.fdroid': return 'F-Droid';
			case 'dialogs.pluginUpdates.toast': return 'Detected {count} rule updates';
			case 'dialogs.webdav.syncFailed': return 'Failed to sync watch history: {error}';
			case 'dialogs.about.licenseLegalese': return 'Open Source Licenses';
			case 'dialogs.cache.title': return 'Cache Management';
			case 'dialogs.cache.message': return 'Cached data includes poster art. Clearing it will require re-downloading assets. Do you want to continue?';
			case 'library.common.emptyState': return 'No content found';
			case 'library.common.retry': return 'Tap to retry';
			case 'library.common.backHint': return 'Press again to exit Haipee';
			case 'library.common.toast.editMode': return 'Edit mode is active.';
			case 'library.popular.title': return 'Home';
			case 'library.popular.allTag': return 'Home';
			case 'library.popular.toast.backPress': return 'Press again to exit Haipee';
			case 'library.timeline.weekdays.mon': return 'Mon';
			case 'library.timeline.weekdays.tue': return 'Tue';
			case 'library.timeline.weekdays.wed': return 'Wed';
			case 'library.timeline.weekdays.thu': return 'Thu';
			case 'library.timeline.weekdays.fri': return 'Fri';
			case 'library.timeline.weekdays.sat': return 'Sat';
			case 'library.timeline.weekdays.sun': return 'Sun';
			case 'library.timeline.seasonPicker.title': return 'Time Machine';
			case 'library.timeline.seasonPicker.yearLabel': return '{year}';
			case 'library.timeline.season.title': return '{season} {year}';
			case 'library.timeline.season.loading': return 'Loading…';
			case 'library.timeline.season.names.winter': return 'Winter';
			case 'library.timeline.season.names.spring': return 'Spring';
			case 'library.timeline.season.names.summer': return 'Summer';
			case 'library.timeline.season.names.autumn': return 'Autumn';
			case 'library.timeline.season.short.winter': return 'Winter';
			case 'library.timeline.season.short.spring': return 'Spring';
			case 'library.timeline.season.short.summer': return 'Summer';
			case 'library.timeline.season.short.autumn': return 'Autumn';
			case 'library.timeline.sort.title': return 'Sort order';
			case 'library.timeline.sort.byHeat': return 'Sort by popularity';
			case 'library.timeline.sort.byRating': return 'Sort by rating';
			case 'library.timeline.sort.byTime': return 'Sort by schedule';
			case 'library.search.sort.label': return 'Sort search results';
			case 'library.search.sort.byHeat': return 'Sort by popularity';
			case 'library.search.sort.byRating': return 'Sort by rating';
			case 'library.search.sort.byRelevance': return 'Sort by relevance';
			case 'library.search.noHistory': return 'No search history yet.';
			case 'library.history.title': return 'Watch History';
			case 'library.history.empty': return 'No watch history found';
			case 'library.history.chips.source': return 'Source';
			case 'library.history.chips.progress': return 'Progress';
			case 'library.history.chips.episodeNumber': return 'Episode {number}';
			case 'library.history.toast.sourceMissing': return 'Associated source not found.';
			case 'library.history.manage.title': return 'History Management';
			case 'library.history.manage.confirmClear': return 'Clear all watch history?';
			case 'library.history.manage.cancel': return 'Cancel';
			case 'library.history.manage.confirm': return 'Confirm';
			case 'library.info.summary.title': return 'Synopsis';
			case 'library.info.summary.expand': return 'Show more';
			case 'library.info.summary.collapse': return 'Show less';
			case 'library.info.tags.title': return 'Tags';
			case 'library.info.tags.more': return 'More +';
			case 'library.info.metadata.refresh': return 'Refresh';
			case 'library.info.metadata.syncingTitle': return 'Syncing metadata…';
			case 'library.info.metadata.syncingSubtitle': return 'The first sync may take a few seconds.';
			case 'library.info.metadata.emptyTitle': return 'No official metadata yet';
			case 'library.info.metadata.emptySubtitle': return 'Try again later or check the metadata settings.';
			case 'library.info.metadata.source': return ({required Object source}) => 'Metadata source: ${source}';
			case 'library.info.metadata.updated': return ({required Object timestamp, required Object language}) => 'Last updated: ${timestamp} · Language: ${language}';
			case 'library.info.metadata.languageSystem': return 'System default';
			case 'library.info.metadata.multiSource': return 'Merged sources';
			case 'library.info.episodes.title': return 'Episodes';
			case 'library.info.episodes.collapse': return 'Collapse';
			case 'library.info.episodes.expand': return ({required Object count}) => 'Show all (${count})';
			case 'library.info.episodes.numberedEpisode': return ({required Object number}) => 'Episode ${number}';
			case 'library.info.episodes.dateUnknown': return 'Date TBD';
			case 'library.info.episodes.runtimeUnknown': return 'Runtime unknown';
			case 'library.info.episodes.runtimeMinutes': return ({required Object minutes}) => '${minutes} minutes';
			case 'library.info.errors.fetchFailed': return 'Failed to load, please try again.';
			case 'library.info.tabs.overview': return 'Overview';
			case 'library.info.tabs.comments': return 'Comments';
			case 'library.info.tabs.characters': return 'Characters';
			case 'library.info.tabs.reviews': return 'Reviews';
			case 'library.info.tabs.staff': return 'Staff';
			case 'library.info.tabs.placeholder': return 'Coming soon';
			case 'library.info.actions.startWatching': return 'Start Watching';
			case 'library.info.toast.characterSortFailed': return 'Failed to sort characters: {details}';
			case 'library.info.sourceSheet.title': return 'Choose playback source ({name})';
			case 'library.info.sourceSheet.alias.deleteTooltip': return 'Delete alias';
			case 'library.info.sourceSheet.alias.deleteTitle': return 'Delete alias';
			case 'library.info.sourceSheet.alias.deleteMessage': return 'This cannot be undone. Delete this alias?';
			case 'library.info.sourceSheet.toast.aliasEmpty': return 'No aliases available. Add one manually before searching.';
			case 'library.info.sourceSheet.toast.loadFailed': return 'Failed to load playback routes.';
			case 'library.info.sourceSheet.toast.removed': return 'Removed source {plugin}.';
			case 'library.info.sourceSheet.sort.title': return 'Sort order';
			case 'library.info.sourceSheet.sort.tooltip': return 'Sort: {label}';
			case 'library.info.sourceSheet.sort.options.original': return 'Original order';
			case 'library.info.sourceSheet.sort.options.nameAsc': return 'Name (A → Z)';
			case 'library.info.sourceSheet.sort.options.nameDesc': return 'Name (Z → A)';
			case 'library.info.sourceSheet.sort.options.failureAsc': return 'Failures (Low → High)';
			case 'library.info.sourceSheet.sort.options.failureDesc': return 'Failures (High → Low)';
			case 'library.info.sourceSheet.card.title': return 'Source · {plugin}';
			case 'library.info.sourceSheet.card.play': return 'Play';
			case 'library.info.sourceSheet.actions.searchAgain': return 'Search again';
			case 'library.info.sourceSheet.actions.aliasSearch': return 'Alias search';
			case 'library.info.sourceSheet.actions.removeSource': return 'Remove source';
			case 'library.info.sourceSheet.status.searching': return '{plugin} searching…';
			case 'library.info.sourceSheet.status.failed': return '{plugin} search failed';
			case 'library.info.sourceSheet.status.empty': return '{plugin} returned no results';
			case 'library.info.sourceSheet.empty.searching': return 'Searching, please wait…';
			case 'library.info.sourceSheet.empty.noResults': return 'No playback sources found. Try searching again or use an alias.';
			case 'library.info.sourceSheet.dialog.removeTitle': return 'Remove source';
			case 'library.info.sourceSheet.dialog.removeMessage': return 'Remove source {plugin}?';
			case 'library.my.title': return 'My';
			case 'library.my.sections.video': return 'Video';
			case 'library.my.favorites.title': return 'Collections';
			case 'library.my.favorites.description': return 'View watching, planning, and completed lists';
			case 'library.my.favorites.empty': return 'No favorites yet.';
			case 'library.my.favorites.tabs.watching': return 'Watching';
			case 'library.my.favorites.tabs.planned': return 'Plan to Watch';
			case 'library.my.favorites.tabs.completed': return 'Completed';
			case 'library.my.favorites.tabs.empty': return 'No entries yet.';
			case 'library.my.favorites.sync.disabled': return 'WebDAV sync is disabled.';
			case 'library.my.favorites.sync.editing': return 'Cannot sync while in edit mode.';
			case 'library.my.history.title': return 'Playback History';
			case 'library.my.history.description': return 'See shows you\'ve watched';
			case 'playback.toast.screenshotProcessing': return 'Capturing screenshot…';
			case 'playback.toast.screenshotSaved': return 'Screenshot saved to gallery';
			case 'playback.toast.screenshotSaveFailed': return 'Failed to save screenshot: {error}';
			case 'playback.toast.screenshotError': return 'Screenshot failed: {error}';
			case 'playback.toast.playlistEmpty': return 'Playlist is empty';
			case 'playback.toast.episodeLatest': return 'Already at the latest episode';
			case 'playback.toast.loadingEpisode': return 'Loading {identifier}';
			case 'playback.toast.danmakuUnsupported': return 'Danmaku sending is unavailable for this episode';
			case 'playback.toast.danmakuEmpty': return 'Danmaku content cannot be empty';
			case 'playback.toast.danmakuTooLong': return 'Danmaku content is too long';
			case 'playback.toast.waitForVideo': return 'Please wait until the video finishes loading';
			case 'playback.toast.enableDanmakuFirst': return 'Turn on danmaku first';
			case 'playback.toast.danmakuSearchError': return 'Danmaku search failed: {error}';
			case 'playback.toast.danmakuSearchEmpty': return 'No matching results found';
			case 'playback.toast.danmakuSwitching': return 'Switching danmaku';
			case 'playback.toast.clipboardCopied': return 'Copied to clipboard';
			case 'playback.toast.internalError': return 'Player internal error: {details}';
			case 'playback.danmaku.inputHint': return 'Share a friendly danmaku in the moment';
			case 'playback.danmaku.inputDisabled': return 'Danmaku is turned off';
			case 'playback.danmaku.send': return 'Send';
			case 'playback.danmaku.mobileButton': return 'Tap to send danmaku';
			case 'playback.danmaku.mobileButtonDisabled': return 'Danmaku disabled';
			case 'playback.externalPlayer.launching': return 'Trying to open external player';
			case 'playback.externalPlayer.launchFailed': return 'Unable to open external player';
			case 'playback.externalPlayer.unavailable': return 'External player is not available';
			case 'playback.externalPlayer.unsupportedDevice': return 'This device is not supported yet';
			case 'playback.externalPlayer.unsupportedPlugin': return 'This plugin is not supported yet';
			case 'playback.controls.speed.title': return 'Playback speed';
			case 'playback.controls.speed.reset': return 'Default speed';
			case 'playback.controls.skip.title': return 'Skip duration';
			case 'playback.controls.skip.tooltip': return 'Long press to change duration';
			case 'playback.controls.status.fastForward': return 'Fast forward {seconds} s';
			case 'playback.controls.status.rewind': return 'Rewind {seconds} s';
			case 'playback.controls.status.speed': return 'Speed playback';
			case 'playback.controls.superResolution.label': return 'Super resolution';
			case 'playback.controls.superResolution.off': return 'Off';
			case 'playback.controls.superResolution.balanced': return 'Balanced';
			case 'playback.controls.superResolution.quality': return 'Quality';
			case 'playback.controls.speedMenu.label': return 'Speed';
			case 'playback.controls.aspectRatio.label': return 'Aspect ratio';
			case 'playback.controls.aspectRatio.options.auto': return 'Auto';
			case 'playback.controls.aspectRatio.options.crop': return 'Crop to fill';
			case 'playback.controls.aspectRatio.options.stretch': return 'Stretch to fill';
			case 'playback.controls.tooltips.danmakuOn': return 'Turn off danmaku (d)';
			case 'playback.controls.tooltips.danmakuOff': return 'Turn on danmaku (d)';
			case 'playback.controls.menu.danmakuToggle': return 'Danmaku switch';
			case 'playback.controls.menu.videoInfo': return 'Video info';
			case 'playback.controls.menu.cast': return 'Remote cast';
			case 'playback.controls.menu.external': return 'Open in external player';
			case 'playback.controls.syncplay.label': return 'SyncPlay';
			case 'playback.controls.syncplay.room': return 'Current room: {name}';
			case 'playback.controls.syncplay.roomEmpty': return 'Not joined';
			case 'playback.controls.syncplay.latency': return 'Latency: {ms} ms';
			case 'playback.controls.syncplay.join': return 'Join room';
			case 'playback.controls.syncplay.switchServer': return 'Switch server';
			case 'playback.controls.syncplay.disconnect': return 'Disconnect';
			case 'playback.loading.parsing': return 'Parsing video source…';
			case 'playback.loading.parseFailed': return 'Video source parsing failed';
			case 'playback.loading.player': return 'Video source parsed, loading player';
			case 'playback.loading.danmakuSearch': return 'Searching danmaku…';
			case 'playback.danmakuSearch.title': return 'Danmaku search';
			case 'playback.danmakuSearch.hint': return 'Series title';
			case 'playback.danmakuSearch.submit': return 'Submit';
			case 'playback.remote.title': return 'Remote cast';
			case 'playback.remote.toast.searching': return 'Searching…';
			case 'playback.remote.toast.casting': return 'Attempting to cast to {device}';
			case 'playback.remote.toast.error': return 'DLNA error: {details}\nTry reopening the DLNA panel or choosing another device.';
			case 'playback.debug.title': return 'Debug info';
			case 'playback.debug.closeTooltip': return 'Close debug info';
			case 'playback.debug.tabs.status': return 'Status';
			case 'playback.debug.tabs.logs': return 'Logs';
			case 'playback.debug.sections.source': return 'Playback source';
			case 'playback.debug.sections.playback': return 'Player status';
			case 'playback.debug.sections.timing': return 'Timing & metrics';
			case 'playback.debug.sections.media': return 'Media tracks';
			case 'playback.debug.labels.series': return 'Series';
			case 'playback.debug.labels.plugin': return 'Plugin';
			case 'playback.debug.labels.route': return 'Route';
			case 'playback.debug.labels.episode': return 'Episode';
			case 'playback.debug.labels.routeCount': return 'Route count';
			case 'playback.debug.labels.sourceTitle': return 'Source title';
			case 'playback.debug.labels.parsedUrl': return 'Parsed URL';
			case 'playback.debug.labels.playUrl': return 'Playback URL';
			case 'playback.debug.labels.danmakuId': return 'DanDan ID';
			case 'playback.debug.labels.syncRoom': return 'SyncPlay room';
			case 'playback.debug.labels.syncLatency': return 'SyncPlay RTT';
			case 'playback.debug.labels.nativePlayer': return 'Native player';
			case 'playback.debug.labels.parsing': return 'Parsing';
			case 'playback.debug.labels.playerLoading': return 'Player loading';
			case 'playback.debug.labels.playerInitializing': return 'Player initializing';
			case 'playback.debug.labels.playing': return 'Playing';
			case 'playback.debug.labels.buffering': return 'Buffering';
			case 'playback.debug.labels.completed': return 'Playback completed';
			case 'playback.debug.labels.bufferFlag': return 'Buffer flag';
			case 'playback.debug.labels.currentPosition': return 'Current position';
			case 'playback.debug.labels.bufferProgress': return 'Buffer progress';
			case 'playback.debug.labels.duration': return 'Duration';
			case 'playback.debug.labels.speed': return 'Playback speed';
			case 'playback.debug.labels.volume': return 'Volume';
			case 'playback.debug.labels.brightness': return 'Brightness';
			case 'playback.debug.labels.resolution': return 'Resolution';
			case 'playback.debug.labels.aspectRatio': return 'Aspect ratio';
			case 'playback.debug.labels.superResolution': return 'Super resolution';
			case 'playback.debug.labels.videoParams': return 'Video params';
			case 'playback.debug.labels.audioParams': return 'Audio params';
			case 'playback.debug.labels.playlist': return 'Playlist';
			case 'playback.debug.labels.audioTracks': return 'Audio tracks';
			case 'playback.debug.labels.videoTracks': return 'Video tracks';
			case 'playback.debug.labels.audioBitrate': return 'Audio bitrate';
			case 'playback.debug.values.yes': return 'Yes';
			case 'playback.debug.values.no': return 'No';
			case 'playback.debug.logs.playerEmpty': return 'Player log (0)';
			case 'playback.debug.logs.playerSummary': return 'Player log ({count} entries, showing {displayed})';
			case 'playback.debug.logs.webviewEmpty': return 'WebView log (0)';
			case 'playback.debug.logs.webviewSummary': return 'WebView log ({count} entries, showing {displayed})';
			case 'playback.syncplay.invalidEndpoint': return 'SyncPlay: Invalid server address {endpoint}';
			case 'playback.syncplay.disconnected': return 'SyncPlay: Connection interrupted {reason}';
			case 'playback.syncplay.actionReconnect': return 'Reconnect';
			case 'playback.syncplay.alone': return 'SyncPlay: You are the only user in this room';
			case 'playback.syncplay.followUser': return 'SyncPlay: Using {username}\'s progress';
			case 'playback.syncplay.userLeft': return 'SyncPlay: {username} left the room';
			case 'playback.syncplay.userJoined': return 'SyncPlay: {username} joined the room';
			case 'playback.syncplay.switchEpisode': return 'SyncPlay: {username} switched to episode {episode}';
			case 'playback.syncplay.chat': return 'SyncPlay: {username} said: {message}';
			case 'playback.syncplay.paused': return 'SyncPlay: {username} paused playback';
			case 'playback.syncplay.resumed': return 'SyncPlay: {username} resumed playback';
			case 'playback.syncplay.unknownUser': return 'unknown';
			case 'playback.syncplay.switchServerBlocked': return 'SyncPlay: Exit the current room before switching servers';
			case 'playback.syncplay.defaultCustomEndpoint': return 'Custom server';
			case 'playback.syncplay.selectServer.title': return 'Choose server';
			case 'playback.syncplay.selectServer.customTitle': return 'Custom server';
			case 'playback.syncplay.selectServer.customHint': return 'Enter server URL';
			case 'playback.syncplay.selectServer.duplicateOrEmpty': return 'Server URL must be unique and non-empty';
			case 'playback.syncplay.join.title': return 'Join room';
			case 'playback.syncplay.join.roomLabel': return 'Room ID';
			case 'playback.syncplay.join.roomEmpty': return 'Enter a room ID';
			case 'playback.syncplay.join.roomInvalid': return 'Room ID must be 6 to 10 digits';
			case 'playback.syncplay.join.usernameLabel': return 'Username';
			case 'playback.syncplay.join.usernameEmpty': return 'Enter a username';
			case 'playback.syncplay.join.usernameInvalid': return 'Username must be 4 to 12 letters';
			case 'playback.playlist.collection': return 'Collection';
			case 'playback.playlist.list': return 'Playlist {index}';
			case 'playback.tabs.episodes': return 'Episodes';
			case 'playback.tabs.comments': return 'Comments';
			case 'playback.comments.sectionTitle': return 'Episode title';
			case 'playback.comments.manualSwitch': return 'Switch manually';
			case 'playback.comments.dialogTitle': return 'Enter episode number';
			case 'playback.comments.dialogEmpty': return 'Please enter an episode number';
			case 'playback.comments.dialogConfirm': return 'Refresh';
			case 'playback.superResolution.warning.title': return 'Performance warning';
			case 'playback.superResolution.warning.message': return 'Enabling super resolution (quality) may cause stutter. Continue?';
			case 'playback.superResolution.warning.dontAskAgain': return 'Don\'t ask again';
			case 'network.error.badCertificate': return 'Certificate error.';
			case 'network.error.badResponse': return 'Server error. Please try again later.';
			case 'network.error.cancel': return 'Request was cancelled. Please retry.';
			case 'network.error.connection': return 'Connection error. Check your network settings.';
			case 'network.error.connectionTimeout': return 'Connection timed out. Check your network settings.';
			case 'network.error.receiveTimeout': return 'Response timed out. Please try again.';
			case 'network.error.sendTimeout': return 'Request timed out. Check your network settings.';
			case 'network.error.unknown': return '{status} network issue.';
			case 'network.status.mobile': return 'Using mobile data';
			case 'network.status.wifi': return 'Using Wi-Fi';
			case 'network.status.ethernet': return 'Using Ethernet';
			case 'network.status.vpn': return 'Using VPN connection';
			case 'network.status.other': return 'Using another network';
			case 'network.status.none': return 'No network connection';
			default: return null;
		}
	}
}

extension on _TranslationsJaJp {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'app.title': return 'Haipee';
			case 'app.loading': return '読み込み中…';
			case 'app.retry': return '再試行';
			case 'app.confirm': return '確認';
			case 'app.cancel': return 'キャンセル';
			case 'app.delete': return '削除';
			case 'metadata.sectionTitle': return 'メディア情報';
			case 'metadata.refresh': return 'メタデータの更新';
			case 'metadata.source.bangumi': return 'Bangumi';
			case 'metadata.source.tmdb': return 'TMDb';
			case 'metadata.lastSynced': return '最後の同期：{timestamp}';
			case 'downloads.sectionTitle': return 'ダウンロードキュー';
			case 'downloads.downloadOffline': return 'ダウンロードエンジンが接続されていません';
			case 'downloads.queued': return 'キューに追加';
			case 'downloads.running': return 'ダウンロード中';
			case 'downloads.completed': return '完了';
			case 'torrent.consent.title': return 'BitTorrent使用の通知';
			case 'torrent.consent.description': return 'BTダウンロードを有効にする前に、現地の法律を遵守し、伴うリスクを十分に理解してください。';
			case 'torrent.consent.agree': return '理解しました、続行します';
			case 'torrent.consent.decline': return '今回はしません';
			case 'torrent.error.submit': return '磁気リンクを送信できませんでした。後でもう一度お試しください';
			case 'settings.title': return '設定';
			case 'settings.downloads': return 'ダウンロード設定';
			case 'settings.playback': return '再生設定';
			case 'settings.general.title': return '一般';
			case 'settings.general.appearance': return '外観';
			case 'settings.general.appearanceDesc': return 'アプリテーマとリフレッシュレートの設定';
			case 'settings.general.language': return 'アプリ言語';
			case 'settings.general.languageDesc': return 'アプリインターフェースの表示言語を選択';
			case 'settings.general.followSystem': return 'システム';
			case 'settings.general.exitBehavior': return '閉じる際';
			case 'settings.general.exitApp': return 'Haipeeを終了';
			case 'settings.general.minimizeToTray': return 'トレイに最小化';
			case 'settings.general.askEveryTime': return '毎回確認';
			case 'settings.appearancePage.title': return '外観';
			case 'settings.appearancePage.mode.title': return 'テーマモード';
			case 'settings.appearancePage.mode.system': return 'システム';
			case 'settings.appearancePage.mode.light': return 'ライト';
			case 'settings.appearancePage.mode.dark': return 'ダーク';
			case 'settings.appearancePage.colorScheme.title': return 'アクセントカラー';
			case 'settings.appearancePage.colorScheme.dialogTitle': return 'アクセントカラーを選択';
			case 'settings.appearancePage.colorScheme.dynamicColor': return '動的色を使用';
			case 'settings.appearancePage.colorScheme.dynamicColorInfo': return 'サポートされている場合、wallpaperからパレットを生成（Android 12+/Windows 11）。';
			case 'settings.appearancePage.colorScheme.labels.defaultLabel': return 'デフォルト';
			case 'settings.appearancePage.colorScheme.labels.teal': return 'ティール';
			case 'settings.appearancePage.colorScheme.labels.blue': return 'ブルー';
			case 'settings.appearancePage.colorScheme.labels.indigo': return 'インディゴ';
			case 'settings.appearancePage.colorScheme.labels.violet': return 'バイオレット';
			case 'settings.appearancePage.colorScheme.labels.pink': return 'ピンク';
			case 'settings.appearancePage.colorScheme.labels.yellow': return '黄色';
			case 'settings.appearancePage.colorScheme.labels.orange': return 'オレンジ';
			case 'settings.appearancePage.colorScheme.labels.deepOrange': return 'ディープオレンジ';
			case 'settings.appearancePage.oled.title': return 'OLEDコントラスト';
			case 'settings.appearancePage.oled.description': return 'OLEDディスプレイに最適化されたより深い黒を使用。';
			case 'settings.appearancePage.window.title': return 'ウィンドウボタン';
			case 'settings.appearancePage.window.description': return 'タイトルバーにウィンドウ制御ボタンを表示。';
			case 'settings.appearancePage.refreshRate.title': return 'リフレッシュレート';
			case 'settings.source.title': return 'ソース';
			case 'settings.source.ruleManagement': return 'ルール管理';
			case 'settings.source.ruleManagementDesc': return 'アニメリソースルールの管理';
			case 'settings.source.githubProxy': return 'GitHubプロキシ';
			case 'settings.source.githubProxyDesc': return 'ルールリポジトリにアクセスするためのプロキシを使用';
			case 'settings.plugins.title': return 'ルール管理';
			case 'settings.plugins.empty': return '利用可能なルールはありません';
			case 'settings.plugins.tooltip.updateAll': return 'すべて更新';
			case 'settings.plugins.tooltip.addRule': return 'ルールを追加';
			case 'settings.plugins.sort.title': return '並び替え';
			case 'settings.plugins.sort.tooltip': return '並び替え';
			case 'settings.plugins.sort.options.original': return '元の順序';
			case 'settings.plugins.sort.options.nameAsc': return '名前（Ａ → ３）';
			case 'settings.plugins.sort.options.nameDesc': return '名前（３ → Ａ）';
			case 'settings.plugins.sort.options.failureAsc': return '失敗数（低 → 高）';
			case 'settings.plugins.sort.options.failureDesc': return '失敗数（高 → 低）';
			case 'settings.plugins.multiSelect.selectedCount': return '{count} 選択中';
			case 'settings.plugins.loading.updating': return 'ルールを更新しています…';
			case 'settings.plugins.loading.updatingSingle': return '更新中…';
			case 'settings.plugins.loading.importing': return 'インポート中…';
			case 'settings.plugins.labels.version': return 'バージョン: {version}';
			case 'settings.plugins.labels.statusUpdatable': return '更新可能';
			case 'settings.plugins.labels.statusSearchValid': return '検索が有効';
			case 'settings.plugins.actions.newRule': return 'ルールを作成';
			case 'settings.plugins.actions.importFromRepo': return 'リポジトリからインポート';
			case 'settings.plugins.actions.importFromClipboard': return 'クリップボードからインポート';
			case 'settings.plugins.actions.cancel': return 'キャンセル';
			case 'settings.plugins.actions.import': return 'インポート';
			case 'settings.plugins.actions.update': return '更新';
			case 'settings.plugins.actions.edit': return '編集';
			case 'settings.plugins.actions.copyToClipboard': return 'クリップボードにコピー';
			case 'settings.plugins.actions.share': return '共有';
			case 'settings.plugins.actions.delete': return '削除';
			case 'settings.plugins.dialogs.deleteTitle': return 'ルールを削除';
			case 'settings.plugins.dialogs.deleteMessage': return '選択した {count} 件のルールを削除しますか？';
			case 'settings.plugins.dialogs.importTitle': return 'ルールをインポート';
			case 'settings.plugins.dialogs.shareTitle': return 'ルールリンク';
			case 'settings.plugins.toast.allUpToDate': return 'すべてのルールは最新です。';
			case 'settings.plugins.toast.updateCount': return '{count} 件のルールを更新しました。';
			case 'settings.plugins.toast.importSuccess': return 'インポートが成功しました。';
			case 'settings.plugins.toast.importFailed': return 'インポートに失敗しました: {error}';
			case 'settings.plugins.toast.repoMissing': return 'リポジトリにこのルールは含まれていません。';
			case 'settings.plugins.toast.alreadyLatest': return 'ルールは既に最新です。';
			case 'settings.plugins.toast.updateSuccess': return '更新に成功しました。';
			case 'settings.plugins.toast.updateIncompatible': return 'Haipee のバージョンが古いため、このルールは互換性がありません。';
			case 'settings.plugins.toast.updateFailed': return 'ルールの更新に失敗しました。';
			case 'settings.plugins.toast.copySuccess': return 'クリップボードにコピーしました。';
			case 'settings.plugins.editor.title': return 'ルールを編集';
			case 'settings.plugins.editor.fields.name': return 'ルール名';
			case 'settings.plugins.editor.fields.version': return 'バージョン';
			case 'settings.plugins.editor.fields.baseUrl': return 'ベースURL';
			case 'settings.plugins.editor.fields.searchUrl': return '検索URL';
			case 'settings.plugins.editor.fields.searchList': return '検索リストXPath';
			case 'settings.plugins.editor.fields.searchName': return '検索名XPath';
			case 'settings.plugins.editor.fields.searchResult': return '検索結果XPath';
			case 'settings.plugins.editor.fields.chapterRoads': return 'チャプターロードXPath';
			case 'settings.plugins.editor.fields.chapterResult': return 'チャプター結果XPath';
			case 'settings.plugins.editor.fields.userAgent': return 'User-Agent';
			case 'settings.plugins.editor.fields.referer': return 'Referer';
			case 'settings.plugins.editor.advanced.title': return '高度な設定';
			case 'settings.plugins.editor.advanced.legacyParser.title': return 'レガシーパーサーを有効化';
			case 'settings.plugins.editor.advanced.legacyParser.subtitle': return '互換性を向上させるためにレガシーXPath解析ロジックを使用します。';
			case 'settings.plugins.editor.advanced.httpPost.title': return '検索をPOSTで送信';
			case 'settings.plugins.editor.advanced.httpPost.subtitle': return 'HTTP POSTで検索要求を送信します。';
			case 'settings.plugins.editor.advanced.nativePlayer.title': return 'ネイティブプレイヤーの使用を強制';
			case 'settings.plugins.editor.advanced.nativePlayer.subtitle': return '再生時にビルトインプレイヤーを優先します。';
			case 'settings.plugins.shop.title': return 'ルールリポジトリ';
			case 'settings.plugins.shop.tooltip.sortByName': return '名前で並び替え';
			case 'settings.plugins.shop.tooltip.sortByUpdate': return '更新時間で並び替え';
			case 'settings.plugins.shop.tooltip.refresh': return 'ルールリストを更新';
			case 'settings.plugins.shop.labels.playerType.native': return 'ネイティブ';
			case 'settings.plugins.shop.labels.playerType.webview': return 'WebView';
			case 'settings.plugins.shop.labels.lastUpdated': return '最後の更新：{timestamp}';
			case 'settings.plugins.shop.buttons.install': return '追加';
			case 'settings.plugins.shop.buttons.installed': return '追加済み';
			case 'settings.plugins.shop.buttons.update': return '更新';
			case 'settings.plugins.shop.buttons.toggleMirrorEnable': return 'ミラーを有効化';
			case 'settings.plugins.shop.buttons.toggleMirrorDisable': return 'ミラーを無効化';
			case 'settings.plugins.shop.buttons.refresh': return '更新';
			case 'settings.plugins.shop.toast.importFailed': return 'ルールのインポートに失敗しました。';
			case 'settings.plugins.shop.error.unreachable': return 'リポジトリに接続できません\n{status}';
			case 'settings.plugins.shop.error.mirrorEnabled': return 'ミラーが有効化されました';
			case 'settings.plugins.shop.error.mirrorDisabled': return 'コラーーが無効化されました';
			case 'settings.metadata.title': return 'メタデータソース';
			case 'settings.metadata.enableBangumi': return 'Bangumiメタデータソースを有効化';
			case 'settings.metadata.enableBangumiDesc': return 'Bangumiからアニメ情報を取得';
			case 'settings.metadata.enableTmdb': return 'TMDbメタデータソースを有効化';
			case 'settings.metadata.enableTmdbDesc': return 'TMDbから多言語データを補充';
			case 'settings.metadata.preferredLanguage': return '優先言語';
			case 'settings.metadata.preferredLanguageDesc': return 'メタデータの同期時に使用する言語を設定';
			case 'settings.metadata.followSystemLanguage': return 'システム言語に従う';
			case 'settings.metadata.simplifiedChinese': return '简体中文（zh-CN）';
			case 'settings.metadata.traditionalChinese': return '繁體中文（zh-TW）';
			case 'settings.metadata.japanese': return '日本語（ja-JP）';
			case 'settings.metadata.english': return '英語（en-US）';
			case 'settings.metadata.custom': return 'カスタム';
			case 'settings.player.title': return 'プレイヤー設定';
			case 'settings.player.playerSettings': return 'プレイヤー設定';
			case 'settings.player.playerSettingsDesc': return 'プレイヤーパラメータを設定';
			case 'settings.player.hardwareDecoding': return 'ハードウェアデコード';
			case 'settings.player.hardwareDecoder': return 'ハードウェアデコーダー';
			case 'settings.player.hardwareDecoderDesc': return 'ハードウェアデ碼りが有効な場合のみ有効';
			case 'settings.player.lowMemoryMode': return '低メモリモード';
			case 'settings.player.lowMemoryModeDesc': return 'メモリ使用量を減らすため高度なキャッシュを無効化';
			case 'settings.player.lowLatencyAudio': return '低レイテンシ音声';
			case 'settings.player.lowLatencyAudioDesc': return 'レイテンシを低くするためOpenSLES音声出力を有効化';
			case 'settings.player.superResolution': return '超解像度';
			case 'settings.player.autoJump': return '自動ジャンプ';
			case 'settings.player.autoJumpDesc': return '最後の再生位置にジャンプ';
			case 'settings.player.disableAnimations': return 'アニメーション無効化';
			case 'settings.player.disableAnimationsDesc': return 'プレイヤー内のトランジションアニメーションを無効化';
			case 'settings.player.errorPrompt': return 'エラープ롬プト';
			case 'settings.player.errorPromptDesc': return 'プレイヤー内の内部エラープ롬プトを表示';
			case 'settings.player.debugMode': return 'デバッグモード';
			case 'settings.player.debugModeDesc': return '内部プレイヤーログを記録';
			case 'settings.player.privateMode': return 'プライベートモード';
			case 'settings.player.privateModeDesc': return '視聴履歴を保持しない';
			case 'settings.player.defaultPlaySpeed': return 'デフォルト再生速度';
			case 'settings.player.defaultVideoAspectRatio': return 'デフォルト動画アスペクト比';
			case 'settings.player.aspectRatio.auto': return '自動';
			case 'settings.player.aspectRatio.crop': return 'クロップして填充';
			case 'settings.player.aspectRatio.stretch': return '拉伸して填充';
			case 'settings.player.danmakuSettings': return '弾幕設定';
			case 'settings.player.danmakuSettingsDesc': return '弾幕パラメータを設定';
			case 'settings.player.danmaku': return '弾幕';
			case 'settings.player.danmakuDefaultOn': return 'デフォルトオン';
			case 'settings.player.danmakuDefaultOnDesc': return '動画と一緒に弾幕をデフォルトで表示するかどうか';
			case 'settings.player.danmakuSource': return '弾幕ソース';
			case 'settings.player.danmakuSources.bilibili': return 'Bilibili';
			case 'settings.player.danmakuSources.gamer': return 'Gamer';
			case 'settings.player.danmakuSources.dandan': return 'DanDan';
			case 'settings.player.danmakuCredentials': return '認証情報';
			case 'settings.player.danmakuDanDanCredentials': return 'DanDan API認証情報';
			case 'settings.player.danmakuDanDanCredentialsDesc': return 'カスタムDanDan認証情報';
			case 'settings.player.danmakuCredentialModeBuiltIn': return 'ビルトイン';
			case 'settings.player.danmakuCredentialModeCustom': return 'カスタム';
			case 'settings.player.danmakuCredentialHint': return 'ビルトイン認証情報を使用するには空のままにします';
			case 'settings.player.danmakuCredentialNotConfigured': return '未設定';
			case 'settings.player.danmakuCredentialsSummary': return 'App ID: {appId}\nAPI Key: {apiKey}';
			case 'settings.player.danmakuShield': return '弾幕遮蔽';
			case 'settings.player.danmakuKeywordShield': return 'キーワード遮蔽';
			case 'settings.player.danmakuShieldInputHint': return 'キーワードまたは正規表現を入力';
			case 'settings.player.danmakuShieldDescription': return '「/」で囲まれたテキストは正規表現として扱われます，例如「/\d+/」はすべての数字を遮蔽できます';
			case 'settings.player.danmakuShieldCount': return '{count} 件のキーワードを追加しました';
			case 'settings.player.danmakuStyle': return '弾幕スタイル';
			case 'settings.player.danmakuDisplay': return '弾幕表示';
			case 'settings.player.danmakuArea': return '弾幕表示領域';
			case 'settings.player.danmakuTopDisplay': return '上部弾幕';
			case 'settings.player.danmakuBottomDisplay': return '下部弾幕';
			case 'settings.player.danmakuScrollDisplay': return 'スクロール弾幕';
			case 'settings.player.danmakuMassiveDisplay': return '大規模弾幕';
			case 'settings.player.danmakuMassiveDescription': return '画面に人がたくさんいる場合にオーバーレイでレンダリング';
			case 'settings.player.danmakuOutline': return '弾幕アウトライン';
			case 'settings.player.danmakuColor': return '弾幕色';
			case 'settings.player.danmakuFontSize': return 'フォントサイズ';
			case 'settings.player.danmakuFontWeight': return 'フォント太さ';
			case 'settings.player.danmakuOpacity': return '弾幕透明度';
			case 'settings.player.add': return '追加';
			case 'settings.player.save': return '保存';
			case 'settings.player.restoreDefault': return 'デフォルトに戻す';
			case 'settings.player.superResolutionTitle': return '超解像度';
			case 'settings.player.superResolutionHint': return 'デフォルトのアップスケーリングソリューションを選択';
			case 'settings.player.superResolutionOptions.off.label': return 'オフ';
			case 'settings.player.superResolutionOptions.off.description': return 'すべてのアップスケーリング拡張機能を無効化。';
			case 'settings.player.superResolutionOptions.efficiency.label': return 'バランス';
			case 'settings.player.superResolutionOptions.efficiency.description': return 'パフォーマンスと品質のバランス。';
			case 'settings.player.superResolutionOptions.quality.label': return '品質';
			case 'settings.player.superResolutionOptions.quality.description': return '最適な品質のためにリソースをトレードオフ。';
			case 'settings.player.superResolutionDefaultBehavior': return 'デフォルト動作';
			case 'settings.player.superResolutionClosePrompt': return '閉じるプロンプト';
			case 'settings.player.superResolutionClosePromptDesc': return '超解像度を有効にする際のプロンプト';
			case 'settings.player.toast.danmakuKeywordEmpty': return 'キーワードを入力してください。';
			case 'settings.player.toast.danmakuKeywordTooLong': return 'キーワードが長すぎます。';
			case 'settings.player.toast.danmakuKeywordExists': return 'キーワードは既に存在しています。';
			case 'settings.player.toast.danmakuCredentialsRestored': return 'ビルトイン認証情報に復元されました。';
			case 'settings.player.toast.danmakuCredentialsUpdated': return '認証情報が更新されました。';
			case 'settings.webdav.title': return 'WebDAV';
			case 'settings.webdav.desc': return '同期パラメータを設定';
			case 'settings.webdav.pageTitle': return '同期設定';
			case 'settings.webdav.editor.title': return 'WebDAV設定';
			case 'settings.webdav.editor.url': return 'URL';
			case 'settings.webdav.editor.username': return 'ユーザー名';
			case 'settings.webdav.editor.password': return 'パスワード';
			case 'settings.webdav.editor.toast.saveSuccess': return '設定が保存されました。テストを開始します…';
			case 'settings.webdav.editor.toast.saveFailed': return '設定の保存に失敗しました: {error}';
			case 'settings.webdav.editor.toast.testSuccess': return 'テストが成功しました。';
			case 'settings.webdav.editor.toast.testFailed': return 'テストに失敗しました: {error}';
			case 'settings.webdav.section.webdav': return 'WebDAV';
			case 'settings.webdav.tile.webdavToggle': return 'WebDAV同期';
			case 'settings.webdav.tile.historyToggle': return '視聴履歴同期';
			case 'settings.webdav.tile.historyDescription': return '視聴履歴の自動同期を許可';
			case 'settings.webdav.tile.config': return 'WebDAV設定';
			case 'settings.webdav.tile.manualUpload': return '手動アップロード';
			case 'settings.webdav.tile.manualDownload': return '手動ダウンロード';
			case 'settings.webdav.info.upload': return '視聴履歴をWebDAVに今すぐアップロードします。';
			case 'settings.webdav.info.download': return '視聴履歴をこのデバイスに今すぐ同期します。';
			case 'settings.webdav.toast.uploading': return 'WebDAVにアップロードを試みています…';
			case 'settings.webdav.toast.downloading': return 'WebDAVから同期を試みています…';
			case 'settings.webdav.toast.notConfigured': return 'WebDAV同期は無効または設定が無効です。';
			case 'settings.webdav.toast.connectionFailed': return 'WebDAVへの接続に失敗しました: {error}';
			case 'settings.webdav.toast.syncFailed': return 'WebDAV同期に失敗しました: {error}';
			case 'settings.webdav.result.initFailed': return 'WebDAVの初期化に失敗しました: {error}';
			case 'settings.webdav.result.requireEnable': return 'まずWebDAV同期を有効にしてください。';
			case 'settings.webdav.result.disabled': return 'WebDAV同期は無効または設定が無効です。';
			case 'settings.webdav.result.connectionFailed': return 'WebDAVへの接続に失敗しました。';
			case 'settings.webdav.result.syncSuccess': return '同期が成功しました。';
			case 'settings.webdav.result.syncFailed': return '同期に失敗しました: {error}';
			case 'settings.update.fallbackDescription': return 'リリースノートは提供されていません。';
			case 'settings.update.error.invalidResponse': return '無効な更新レスポンス。';
			case 'settings.update.dialog.title': return '新しいバージョン {version} が利用可能です';
			case 'settings.update.dialog.publishedAt': return 'Released on {date}';
			case 'settings.update.dialog.installationTypeLabel': return 'インストールパッケージを選択';
			case 'settings.update.dialog.actions.disableAutoUpdate': return '自動更新を無効化';
			case 'settings.update.dialog.actions.remindLater': return '後でリマインダー';
			case 'settings.update.dialog.actions.viewDetails': return '詳細を表示';
			case 'settings.update.dialog.actions.updateNow': return '今すぐ更新';
			case 'settings.update.installationType.windowsMsix': return 'Windows インストーラー（MSIX）';
			case 'settings.update.installationType.windowsPortable': return 'Windows ポータブル（ZIP）';
			case 'settings.update.installationType.linuxDeb': return 'Linux パッケージ（DEB）';
			case 'settings.update.installationType.linuxTar': return 'Linux アーカイブ（TAR.GZ）';
			case 'settings.update.installationType.macosDmg': return 'macOS インストーラー（DMG）';
			case 'settings.update.installationType.androidApk': return 'Android パッケージ（APK）';
			case 'settings.update.installationType.ios': return 'iOS アプリ（GitHubを開く）';
			case 'settings.update.installationType.unknown': return 'その他のプラットフォーム';
			case 'settings.update.toast.alreadyLatest': return '最新です。';
			case 'settings.update.toast.checkFailed': return '更新の確認に失敗しました。後でもう一度お試しください。';
			case 'settings.update.toast.autoUpdateDisabled': return '自動更新が無効化されました。';
			case 'settings.update.toast.downloadLinkMissing': return '{type} のダウンロードは利用できません。';
			case 'settings.update.toast.downloadFailed': return 'ダウンロードに失敗しました: {error}';
			case 'settings.update.toast.noCompatibleLink': return '互換性のあるダウンロードリンクが見つかりませんでした。';
			case 'settings.update.toast.prepareToInstall': return '更新のインストールを準備しています。アプリが終了します…';
			case 'settings.update.toast.openInstallerFailed': return 'インストーラーを開くことができませんでした: {error}';
			case 'settings.update.toast.launchInstallerFailed': return 'インストーラーを起動できませんでした: {error}';
			case 'settings.update.toast.revealFailed': return 'ファイルマネージャーを開くことができませんでした。';
			case 'settings.update.toast.unknownReason': return '不明な理由';
			case 'settings.update.download.progressTitle': return '更新をダウンロード中';
			case 'settings.update.download.cancel': return 'キャンセル';
			case 'settings.update.download.error.title': return 'ダウンロードに失敗';
			case 'settings.update.download.error.general': return '更新をダウンロードできませんでした。';
			case 'settings.update.download.error.permission': return 'ファイルを作成する権限が不足しています。';
			case 'settings.update.download.error.diskFull': return 'Disk space が不足しています。';
			case 'settings.update.download.error.network': return 'ネットワーク接続に失敗しました。';
			case 'settings.update.download.error.integrity': return 'ファイル整合性チェックに失敗しました。もう一度お試しください。';
			case 'settings.update.download.error.details': return '技術的詳細: {error}';
			case 'settings.update.download.error.confirm': return 'OK';
			case 'settings.update.download.error.retry': return '再試行';
			case 'settings.update.download.complete.title': return 'ダウンロード完了';
			case 'settings.update.download.complete.message': return 'Haipee {version} がダウンロードされました。';
			case 'settings.update.download.complete.quitNotice': return 'アプリのインストール中に終了します。';
			case 'settings.update.download.complete.fileLocation': return 'ファイルは次に保存されました';
			case 'settings.update.download.complete.buttons.later': return '後';
			case 'settings.update.download.complete.buttons.openFolder': return 'フォルダーを開く';
			case 'settings.update.download.complete.buttons.installNow': return '今すぐインストール';
			case 'settings.other.title': return 'その他';
			case 'settings.other.about': return 'アプリについて';
			case 'settings.about.title': return 'アプリについて';
			case 'settings.about.sections.licenses.title': return 'オープンソースライセンス';
			case 'settings.about.sections.licenses.description': return 'すべてのオープンソースライセンスを表示';
			case 'settings.about.sections.links.title': return '外部リンク';
			case 'settings.about.sections.links.project': return 'プロジェクトホームページ';
			case 'settings.about.sections.links.repository': return 'ソースリポジトリ';
			case 'settings.about.sections.links.icon': return 'アイコン設計';
			case 'settings.about.sections.links.index': return 'アニメ索引';
			case 'settings.about.sections.links.danmaku': return '弾幕プロバイダー';
			case 'settings.about.sections.links.danmakuId': return 'ID: {id}';
			case 'settings.about.sections.cache.clearAction': return 'キャッシュをクリア';
			case 'settings.about.sections.cache.sizePending': return '計算中…';
			case 'settings.about.sections.cache.sizeLabel': return '{size} MB';
			case 'settings.about.sections.updates.title': return 'アプリ更新';
			case 'settings.about.sections.updates.autoUpdate': return '自動更新';
			case 'settings.about.sections.updates.check': return '更新を確認';
			case 'settings.about.sections.updates.currentVersion': return '現在のバージョン {version}';
			case 'settings.about.logs.title': return 'アプリログ';
			case 'settings.about.logs.empty': return '利用可能なログエントリはありません。';
			case 'settings.about.logs.toast.cleared': return 'ログがクリアされました。';
			case 'settings.about.logs.toast.clearFailed': return 'ログのクリアに失敗しました。';
			case 'exitDialog.title': return '終了の確認';
			case 'exitDialog.message': return 'Haipeeを終了しますか？';
			case 'exitDialog.dontAskAgain': return '次回から聞かない';
			case 'exitDialog.exit': return 'Haipeeを終了';
			case 'exitDialog.minimize': return 'トレイに最小化';
			case 'exitDialog.cancel': return 'キャンセル';
			case 'tray.showWindow': return 'ウィンドウを表示';
			case 'tray.exit': return 'Haipeeを終了';
			case 'navigation.tabs.popular': return '人気';
			case 'navigation.tabs.catalog': return 'カテゴリ';
			case 'navigation.tabs.media': return 'オンライン動画';
			case 'navigation.tabs.resource': return 'リソース';
			case 'navigation.tabs.timeline': return 'タイムライン';
			case 'navigation.tabs.my': return 'メディアライブラリ';
			case 'navigation.tabs.download': return 'ダウンロード';
			case 'navigation.tabs.settings': return '設定';
			case 'navigation.actions.search': return '検索';
			case 'navigation.actions.history': return '履歴';
			case 'navigation.actions.close': return '閉じる';
			case 'dialogs.disclaimer.title': return '免責事項';
			case 'dialogs.disclaimer.agree': return '読んで同意';
			case 'dialogs.disclaimer.exit': return '終了';
			case 'dialogs.updateMirror.title': return '更新ミラー';
			case 'dialogs.updateMirror.question': return 'アプリの更新をどこから取得しますか？';
			case 'dialogs.updateMirror.description': return 'GitHub ミラーはほとんどの場合に動作します。F-Droidアプリストアを使用している場合は、F-Droidミラーを選択してください。';
			case 'dialogs.updateMirror.options.github': return 'GitHub';
			case 'dialogs.updateMirror.options.fdroid': return 'F-Droid';
			case 'dialogs.pluginUpdates.toast': return '{count} 個のルールが更新可能です';
			case 'dialogs.webdav.syncFailed': return '視聴履歴の同期に失敗しました {error}';
			case 'dialogs.about.licenseLegalese': return 'オープンソースライセンス';
			case 'dialogs.cache.title': return 'キャッシュ管理';
			case 'dialogs.cache.message': return 'キャッシュにはアニメのカバーが含まれており、クリアすると読み込み時に再ダウンロードが必要です。キャッシュをクリアしてもよろしいですか？';
			case 'library.common.emptyState': return 'コンテンツが見つかりません';
			case 'library.common.retry': return 'タップして再試行';
			case 'library.common.backHint': return 'Haipeeを終了するにはバックボタンを再度押してください';
			case 'library.common.toast.editMode': return '編集モードが有効になりました。';
			case 'library.popular.title': return '人気';
			case 'library.popular.allTag': return 'すべて';
			case 'library.popular.toast.backPress': return 'Haipeeを終了するにはバックボタンを再度押してください';
			case 'library.timeline.weekdays.mon': return '月';
			case 'library.timeline.weekdays.tue': return '火';
			case 'library.timeline.weekdays.wed': return '水';
			case 'library.timeline.weekdays.thu': return '木';
			case 'library.timeline.weekdays.fri': return '金';
			case 'library.timeline.weekdays.sat': return '土';
			case 'library.timeline.weekdays.sun': return '日';
			case 'library.timeline.seasonPicker.title': return 'タイムマシン';
			case 'library.timeline.seasonPicker.yearLabel': return '{year}';
			case 'library.timeline.season.title': return '{season} {year}';
			case 'library.timeline.season.loading': return '読み込み中…';
			case 'library.timeline.season.names.winter': return '冬';
			case 'library.timeline.season.names.spring': return '春';
			case 'library.timeline.season.names.summer': return '夏';
			case 'library.timeline.season.names.autumn': return '秋';
			case 'library.timeline.season.short.winter': return '冬';
			case 'library.timeline.season.short.spring': return '春';
			case 'library.timeline.season.short.summer': return '夏';
			case 'library.timeline.season.short.autumn': return '秋';
			case 'library.timeline.sort.title': return '並び替え';
			case 'library.timeline.sort.byHeat': return '人気順';
			case 'library.timeline.sort.byRating': return '評価順';
			case 'library.timeline.sort.byTime': return '放送日時順';
			case 'library.search.sort.label': return '検索並び替え';
			case 'library.search.sort.byHeat': return '人気順';
			case 'library.search.sort.byRating': return '評価順';
			case 'library.search.sort.byRelevance': return '関連度順';
			case 'library.search.noHistory': return '検索履歴はまだありません';
			case 'library.history.title': return '視聴履歴';
			case 'library.history.empty': return '視聴履歴はまだありません';
			case 'library.history.chips.source': return 'ソース';
			case 'library.history.chips.progress': return '進捗';
			case 'library.history.chips.episodeNumber': return 'エピソード {number}';
			case 'library.history.toast.sourceMissing': return '関連ソースが見つかりません。';
			case 'library.history.manage.title': return '履歴管理';
			case 'library.history.manage.confirmClear': return 'すべての視聴履歴をクリアしますか？';
			case 'library.history.manage.cancel': return 'キャンセル';
			case 'library.history.manage.confirm': return '確認';
			case 'library.info.summary.title': return 'あらすじ';
			case 'library.info.summary.expand': return 'すべて表示';
			case 'library.info.summary.collapse': return '折りたたむ';
			case 'library.info.tags.title': return 'タグ';
			case 'library.info.tags.more': return 'もっと +';
			case 'library.info.metadata.refresh': return '更新';
			case 'library.info.metadata.syncingTitle': return 'メタデータを同期中…';
			case 'library.info.metadata.syncingSubtitle': return '最初の同期には数秒かかる場合があります。';
			case 'library.info.metadata.emptyTitle': return '公式メタデータはまだありません';
			case 'library.info.metadata.emptySubtitle': return 'しばらくしてから再試行するか、メタデータ設定を確認してください。';
			case 'library.info.metadata.source': return ({required Object source}) => 'メタデータソース：${source}';
			case 'library.info.metadata.updated': return ({required Object timestamp, required Object language}) => '最終更新：${timestamp} · 言語：${language}';
			case 'library.info.metadata.languageSystem': return 'システムデフォルト';
			case 'library.info.metadata.multiSource': return '統合ソース';
			case 'library.info.episodes.title': return 'エピソード';
			case 'library.info.episodes.collapse': return '折りたたむ';
			case 'library.info.episodes.expand': return ({required Object count}) => 'すべて表示（${count}）';
			case 'library.info.episodes.numberedEpisode': return ({required Object number}) => 'エピソード ${number}';
			case 'library.info.episodes.dateUnknown': return '放送日未定';
			case 'library.info.episodes.runtimeUnknown': return 'Runtime unknown';
			case 'library.info.episodes.runtimeMinutes': return ({required Object minutes}) => '${minutes} 分';
			case 'library.info.errors.fetchFailed': return '読み込みに失敗しました。再試行してください。';
			case 'library.info.tabs.overview': return '概要';
			case 'library.info.tabs.comments': return 'コメント';
			case 'library.info.tabs.characters': return 'キャラクター';
			case 'library.info.tabs.reviews': return 'レビュー';
			case 'library.info.tabs.staff': return 'スタッフ';
			case 'library.info.tabs.placeholder': return '近日公開';
			case 'library.info.actions.startWatching': return '視聴開始';
			case 'library.info.toast.characterSortFailed': return 'キャラクターのソートに失敗しました：{details}';
			case 'library.info.sourceSheet.title': return '再生ソースを選択（{name}）';
			case 'library.info.sourceSheet.alias.deleteTooltip': return '別名を削除';
			case 'library.info.sourceSheet.alias.deleteTitle': return '別名を削除';
			case 'library.info.sourceSheet.alias.deleteMessage': return 'この操作は元に戻せません。この別名を削除しますか？';
			case 'library.info.sourceSheet.toast.aliasEmpty': return '利用可能な別名はありません。検索前に手動で追加してください。';
			case 'library.info.sourceSheet.toast.loadFailed': return '再生ルートの読み込みに失敗しました。';
			case 'library.info.sourceSheet.toast.removed': return 'ソース {plugin} を削除しました。';
			case 'library.info.sourceSheet.sort.tooltip': return '並び替え：{label}';
			case 'library.info.sourceSheet.sort.options.original': return '元の順序';
			case 'library.info.sourceSheet.sort.options.nameAsc': return '名前（Ａ → ３）';
			case 'library.info.sourceSheet.sort.options.nameDesc': return '名前（３ → Ａ）';
			case 'library.info.sourceSheet.sort.options.failureAsc': return '失敗数（低 → 高）';
			case 'library.info.sourceSheet.sort.options.failureDesc': return '失敗数（高 → 低）';
			case 'library.info.sourceSheet.sort.title': return '並び替え';
			case 'library.info.sourceSheet.card.title': return 'ソース · {plugin}';
			case 'library.info.sourceSheet.card.play': return '再生';
			case 'library.info.sourceSheet.actions.searchAgain': return '再検索';
			case 'library.info.sourceSheet.actions.aliasSearch': return '別名検索';
			case 'library.info.sourceSheet.actions.removeSource': return 'ソースを削除';
			case 'library.info.sourceSheet.status.searching': return '{plugin} 検索中…';
			case 'library.info.sourceSheet.status.failed': return '{plugin} 検索失敗';
			case 'library.info.sourceSheet.status.empty': return '{plugin} 結果を返しませんでした';
			case 'library.info.sourceSheet.empty.searching': return '検索中、お待ちください…';
			case 'library.info.sourceSheet.empty.noResults': return '再生ソースが見つかりませんでした。再度検索するか、別名を使用してください。';
			case 'library.info.sourceSheet.dialog.removeTitle': return 'ソースを削除';
			case 'library.info.sourceSheet.dialog.removeMessage': return 'ソース {plugin} を削除しますか？';
			case 'library.my.title': return 'マイ';
			case 'library.my.sections.video': return '動画';
			case 'library.my.favorites.title': return 'お気に入り';
			case 'library.my.favorites.description': return '視聴中、予定視聴、完了したリストを表示';
			case 'library.my.favorites.empty': return 'お気に入りはまだありません。';
			case 'library.my.favorites.tabs.watching': return '視聴中';
			case 'library.my.favorites.tabs.planned': return '予定視聴';
			case 'library.my.favorites.tabs.completed': return '完了';
			case 'library.my.favorites.tabs.empty': return 'まだ項目がありません。';
			case 'library.my.favorites.sync.disabled': return 'WebDAV同期は無効です。';
			case 'library.my.favorites.sync.editing': return '編集モード中は同期できません。';
			case 'library.my.history.title': return '再生履歴';
			case 'library.my.history.description': return '視聴した番組を表示';
			case 'playback.toast.screenshotProcessing': return 'スクリーンショットを撮影中…';
			case 'playback.toast.screenshotSaved': return 'スクリーンショットがギャラリーに保存されました';
			case 'playback.toast.screenshotSaveFailed': return 'スクリーンショットの保存に失敗しました：{error}';
			case 'playback.toast.screenshotError': return 'スクリーンショットに失敗しました：{error}';
			case 'playback.toast.playlistEmpty': return 'プレイリストが空です';
			case 'playback.toast.episodeLatest': return 'すでに最新のエピソードです';
			case 'playback.toast.loadingEpisode': return '{identifier} を読み込み中';
			case 'playback.toast.danmakuUnsupported': return 'このエピソードでは弾幕の送信は利用できません';
			case 'playback.toast.danmakuEmpty': return '弾幕の内容を空にすることはできません';
			case 'playback.toast.danmakuTooLong': return '弾幕の内容が長すぎます';
			case 'playback.toast.waitForVideo': return '動画の読み込みが完了するまでお待ちください';
			case 'playback.toast.enableDanmakuFirst': return 'まず弾幕を有効にしてください';
			case 'playback.toast.danmakuSearchError': return '弾幕の検索に失敗しました：{error}';
			case 'playback.toast.danmakuSearchEmpty': return '一致する結果が見つかりません';
			case 'playback.toast.danmakuSwitching': return '弾幕を切り替え中';
			case 'playback.toast.clipboardCopied': return 'クリップボードにコピーされました';
			case 'playback.toast.internalError': return 'プレイヤー内部エラー：{details}';
			case 'playback.danmaku.inputHint': return 'その瞬間の友好的な弾幕を共有';
			case 'playback.danmaku.inputDisabled': return '弾幕はオフになっています';
			case 'playback.danmaku.send': return '送信';
			case 'playback.danmaku.mobileButton': return 'タップして弾幕を送信';
			case 'playback.danmaku.mobileButtonDisabled': return '弾幕は無効です';
			case 'playback.externalPlayer.launching': return '外部プレイヤーを開こうとしています';
			case 'playback.externalPlayer.launchFailed': return '外部プレイヤーを開くことができません';
			case 'playback.externalPlayer.unavailable': return '外部プレイヤーは利用できません';
			case 'playback.externalPlayer.unsupportedDevice': return 'このデバイスにはまだ対応していません';
			case 'playback.externalPlayer.unsupportedPlugin': return 'このプラグインにはまだ対応していません';
			case 'playback.controls.speed.title': return '再生速度';
			case 'playback.controls.speed.reset': return 'デフォルト速度';
			case 'playback.controls.skip.title': return 'スキップ時間';
			case 'playback.controls.skip.tooltip': return '長押しして時間を変更';
			case 'playback.controls.status.fastForward': return '{seconds} 秒早送り';
			case 'playback.controls.status.rewind': return '{seconds} 秒巻き戻し';
			case 'playback.controls.status.speed': return '速度再生';
			case 'playback.controls.superResolution.label': return '超解像度';
			case 'playback.controls.superResolution.off': return 'オフ';
			case 'playback.controls.superResolution.balanced': return 'バランス';
			case 'playback.controls.superResolution.quality': return '品質';
			case 'playback.controls.speedMenu.label': return '速度';
			case 'playback.controls.aspectRatio.label': return 'アスペクト比';
			case 'playback.controls.aspectRatio.options.auto': return '自動';
			case 'playback.controls.aspectRatio.options.crop': return 'クロップして填充';
			case 'playback.controls.aspectRatio.options.stretch': return '拉伸して填充';
			case 'playback.controls.tooltips.danmakuOn': return '弾幕をオフにする（d）';
			case 'playback.controls.tooltips.danmakuOff': return '弾幕をオンにする（d）';
			case 'playback.controls.menu.danmakuToggle': return '弾幕スイッチ';
			case 'playback.controls.menu.videoInfo': return '動画情報';
			case 'playback.controls.menu.cast': return 'リモートキャスト';
			case 'playback.controls.menu.external': return '外部プレイヤーで開く';
			case 'playback.controls.syncplay.label': return 'SyncPlay';
			case 'playback.controls.syncplay.room': return '現在の部屋：{name}';
			case 'playback.controls.syncplay.roomEmpty': return '参加していません';
			case 'playback.controls.syncplay.latency': return 'レイテンシ：{ms} ms';
			case 'playback.controls.syncplay.join': return '部屋に参加';
			case 'playback.controls.syncplay.switchServer': return 'サーバーを切り替え';
			case 'playback.controls.syncplay.disconnect': return '切断';
			case 'playback.loading.parsing': return '動画ソースを解析中…';
			case 'playback.loading.player': return '動画ソースが解析されました、プレイヤーを読み込み中';
			case 'playback.loading.danmakuSearch': return '弾幕を検索中…';
			case 'playback.loading.parseFailed': return '動画ソースの解析に失敗しました';
			case 'playback.danmakuSearch.title': return '弾幕検索';
			case 'playback.danmakuSearch.hint': return 'シリーズタイトル';
			case 'playback.danmakuSearch.submit': return '送信';
			case 'playback.remote.title': return 'リモートキャスト';
			case 'playback.remote.toast.searching': return '検索中…';
			case 'playback.remote.toast.casting': return '{device} にキャストしようとています';
			case 'playback.remote.toast.error': return 'DLNAエラー：{details}\nDLNAパネルを再開くか、別のデバイスを選んでください。';
			case 'playback.debug.title': return 'デバッグ情報';
			case 'playback.debug.closeTooltip': return 'デバッグ情報を閉じる';
			case 'playback.debug.tabs.status': return 'ステータス';
			case 'playback.debug.tabs.logs': return 'ログ';
			case 'playback.debug.sections.source': return '再生ソース';
			case 'playback.debug.sections.playback': return 'プレイヤーステータス';
			case 'playback.debug.sections.timing': return 'タイミングとメトリクス';
			case 'playback.debug.sections.media': return 'メディアトラック';
			case 'playback.debug.labels.series': return 'シリーズ';
			case 'playback.debug.labels.plugin': return 'プラグイン';
			case 'playback.debug.labels.route': return 'ルート';
			case 'playback.debug.labels.episode': return 'エピソード';
			case 'playback.debug.labels.routeCount': return 'ルート数';
			case 'playback.debug.labels.sourceTitle': return 'ソースタイトル';
			case 'playback.debug.labels.parsedUrl': return '解析されたURL';
			case 'playback.debug.labels.playUrl': return '再生URL';
			case 'playback.debug.labels.danmakuId': return 'DanDan ID';
			case 'playback.debug.labels.syncRoom': return 'SyncPlay部屋';
			case 'playback.debug.labels.syncLatency': return 'SyncPlay RTT';
			case 'playback.debug.labels.nativePlayer': return 'ネイティブプレイヤー';
			case 'playback.debug.labels.parsing': return '解析中';
			case 'playback.debug.labels.playerLoading': return 'プレイヤー読み込み中';
			case 'playback.debug.labels.playerInitializing': return 'プレイヤー初期化中';
			case 'playback.debug.labels.playing': return '再生中';
			case 'playback.debug.labels.buffering': return 'バッファリング中';
			case 'playback.debug.labels.completed': return '再生完了';
			case 'playback.debug.labels.bufferFlag': return 'バッファフラグ';
			case 'playback.debug.labels.currentPosition': return '現在位置';
			case 'playback.debug.labels.bufferProgress': return 'バッファ進捗';
			case 'playback.debug.labels.duration': return '継続時間';
			case 'playback.debug.labels.speed': return '再生速度';
			case 'playback.debug.labels.volume': return '音量';
			case 'playback.debug.labels.brightness': return '輝度';
			case 'playback.debug.labels.resolution': return '解像度';
			case 'playback.debug.labels.aspectRatio': return 'アスペクト比';
			case 'playback.debug.labels.superResolution': return '超解像度';
			case 'playback.debug.labels.videoParams': return '動画パラメータ';
			case 'playback.debug.labels.audioParams': return '音声パラメータ';
			case 'playback.debug.labels.playlist': return 'プレイリスト';
			case 'playback.debug.labels.audioTracks': return 'オーディオトラック';
			case 'playback.debug.labels.videoTracks': return 'ビデオトラック';
			case 'playback.debug.labels.audioBitrate': return 'オーディオビットレート';
			case 'playback.debug.values.yes': return 'はい';
			case 'playback.debug.values.no': return 'いいえ';
			case 'playback.debug.logs.playerEmpty': return 'プレイヤーログ（0）';
			case 'playback.debug.logs.playerSummary': return 'プレイヤーログ（{count} 項目、{displayed} を表示）';
			case 'playback.debug.logs.webviewEmpty': return 'WebView ログ（0）';
			case 'playback.debug.logs.webviewSummary': return 'WebView ログ（{count} 項目、{displayed} を表示）';
			case 'playback.syncplay.invalidEndpoint': return 'SyncPlay：無効なサーバーアドレス {endpoint}';
			case 'playback.syncplay.disconnected': return 'SyncPlay：接続が中断されました {reason}';
			case 'playback.syncplay.actionReconnect': return '再接続';
			case 'playback.syncplay.alone': return 'SyncPlay：この部屋の唯一のユーザーです';
			case 'playback.syncplay.followUser': return 'SyncPlay：{username} の進行状況を使用';
			case 'playback.syncplay.userLeft': return 'SyncPlay：{username} が部屋を出ました';
			case 'playback.syncplay.userJoined': return 'SyncPlay：{username} が部屋に入りました';
			case 'playback.syncplay.switchEpisode': return 'SyncPlay：{username} がエピソード {episode} に切り替えました';
			case 'playback.syncplay.chat': return 'SyncPlay：{username} が言いました：{message}';
			case 'playback.syncplay.paused': return 'SyncPlay：{username} が再生を一時停止しました';
			case 'playback.syncplay.resumed': return 'SyncPlay：{username} が再生を再開しました';
			case 'playback.syncplay.unknownUser': return '不明';
			case 'playback.syncplay.switchServerBlocked': return 'SyncPlay：サーバーを切り替える前に現在の部屋を出てください';
			case 'playback.syncplay.defaultCustomEndpoint': return 'カスタムサーバー';
			case 'playback.syncplay.selectServer.title': return 'サーバーを選択';
			case 'playback.syncplay.selectServer.customTitle': return 'カスタムサーバー';
			case 'playback.syncplay.selectServer.customHint': return 'サーバーURLを入力';
			case 'playback.syncplay.selectServer.duplicateOrEmpty': return 'サーバーURLはユニークで空であってはいけません';
			case 'playback.syncplay.join.title': return '部屋に参加';
			case 'playback.syncplay.join.roomLabel': return '部屋ID';
			case 'playback.syncplay.join.roomEmpty': return '部屋IDを入力してください';
			case 'playback.syncplay.join.roomInvalid': return '部屋IDは6から10桁の数字である必要があります';
			case 'playback.syncplay.join.usernameLabel': return 'ユーザー名';
			case 'playback.syncplay.join.usernameEmpty': return 'ユーザー名を入力してください';
			case 'playback.syncplay.join.usernameInvalid': return 'ユーザー名は4から12文字の字母である必要があります';
			case 'playback.playlist.collection': return 'コレクション';
			case 'playback.playlist.list': return 'プレイリスト {index}';
			case 'playback.tabs.episodes': return 'エピソード';
			case 'playback.tabs.comments': return 'コメント';
			case 'playback.comments.sectionTitle': return 'エピソードタイトル';
			case 'playback.comments.manualSwitch': return '手動で切り替え';
			case 'playback.comments.dialogTitle': return 'エピソード番号を入力';
			case 'playback.comments.dialogEmpty': return 'エピソード番号を入力してください';
			case 'playback.comments.dialogConfirm': return '更新';
			case 'playback.superResolution.warning.title': return 'パフォーマンス警告';
			case 'playback.superResolution.warning.message': return '超解像度（品質）を有効にすると、スト터를引起こす可能性があります。続行しますか？';
			case 'playback.superResolution.warning.dontAskAgain': return '再び確認しない';
			case 'network.error.badCertificate': return '証明書エラー。';
			case 'network.error.badResponse': return 'サーバーエラー、後でもう一度お試しください。';
			case 'network.error.cancel': return 'リクエストがキャンセルされました、再試行してください。';
			case 'network.error.connection': return '接続エラー、ネットワーク設定を確認してください。';
			case 'network.error.connectionTimeout': return '接続タイムアウト、ネットワーク設定を確認してください。';
			case 'network.error.receiveTimeout': return '応答タイムアウト、後でもう一度お試しください。';
			case 'network.error.sendTimeout': return 'リクエストタイムアウト、ネットワーク設定を確認してください。';
			case 'network.error.unknown': return '{status} ネットワーク問題。';
			case 'network.status.mobile': return 'cellular data を使用中';
			case 'network.status.wifi': return 'Wi‑Fi を使用中';
			case 'network.status.ethernet': return 'Ethernet を使用中';
			case 'network.status.vpn': return 'VPN接続を使用中';
			case 'network.status.other': return '他のネットワークを使用中';
			case 'network.status.none': return 'ネットワーク接続なし';
			default: return null;
		}
	}
}

extension on _TranslationsZhCn {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'app.title': return 'Haipee';
			case 'app.loading': return '加载中…';
			case 'app.retry': return '重试';
			case 'app.confirm': return '确认';
			case 'app.cancel': return '取消';
			case 'app.delete': return '删除';
			case 'metadata.sectionTitle': return '作品信息';
			case 'metadata.refresh': return '刷新元数据';
			case 'metadata.source.bangumi': return 'Bangumi';
			case 'metadata.source.tmdb': return 'TMDb';
			case 'metadata.lastSynced': return '上次同步：{timestamp}';
			case 'downloads.sectionTitle': return '下载队列';
			case 'downloads.downloadOffline': return '下载引擎未连接';
			case 'downloads.queued': return '排队';
			case 'downloads.running': return '下载中';
			case 'downloads.completed': return '已完成';
			case 'downloads.page.title': return '下载管理';
			case 'downloads.page.selectedItems': return ({required Object count}) => '已选择 ${count} 项';
			case 'downloads.page.newDownload': return '新建下载';
			case 'downloads.page.batchManage': return '批量管理';
			case 'downloads.page.downloadSettings': return '下载设置';
			case 'downloads.page.refresh': return '刷新';
			case 'downloads.page.tabs.downloading': return ({required Object count}) => '下载中 (${count})';
			case 'downloads.page.tabs.paused': return ({required Object count}) => '已暂停 (${count})';
			case 'downloads.page.tabs.completed': return ({required Object count}) => '已完成 (${count})';
			case 'downloads.page.tabs.failed': return ({required Object count}) => '下载失败 (${count})';
			case 'downloads.page.tabs.all': return '全部';
			case 'downloads.page.actions.selectAll': return '全选';
			case 'downloads.page.actions.resume': return '继续';
			case 'downloads.page.actions.pause': return '暂停';
			case 'downloads.page.actions.pauseAll': return '暂停全部';
			case 'downloads.page.actions.resumeAll': return '继续全部';
			case 'downloads.page.actions.clearCompleted': return '清除已完成';
			case 'downloads.page.actions.deleteAll': return '删除全部';
			case 'downloads.page.actions.retry': return '重试';
			case 'downloads.page.actions.delete': return '删除';
			case 'downloads.page.actions.open': return '打开';
			case 'downloads.page.statistics.tasks': return ({required Object count}) => '${count} 个任务';
			case 'downloads.page.statistics.eta': return ({required Object time}) => '预计剩余 ${time}';
			case 'downloads.page.search.placeholder': return '搜索下载任务...';
			case 'downloads.page.search.clear': return '清除';
			case 'downloads.page.sort.label': return '排序';
			case 'downloads.page.sort.created': return '创建时间';
			case 'downloads.page.sort.name': return '文件名';
			case 'downloads.page.sort.size': return '文件大小';
			case 'downloads.page.sort.speed': return '下载速度';
			case 'downloads.page.sort.progress': return '进度';
			case 'downloads.page.empty.downloading': return '当前没有下载任务';
			case 'downloads.page.empty.paused': return '没有已暂停的下载任务';
			case 'downloads.page.empty.completed': return '还没有已完成的下载';
			case 'downloads.page.empty.failed': return '没有下载失败的任务';
			case 'downloads.page.empty.all': return '下载列表为空';
			case 'downloads.page.empty.hint': return '点击上方的新建按钮添加下载任务';
			case 'downloads.page.status.active': return '下载中';
			case 'downloads.page.status.waiting': return '等待中';
			case 'downloads.page.status.paused': return '已暂停';
			case 'downloads.page.status.error': return '出错';
			case 'downloads.page.status.complete': return '已完成';
			case 'downloads.page.status.removed': return '已删除';
			case 'downloads.page.dialog.deleteConfirm': return '确定要删除选中的下载任务吗？';
			case 'downloads.page.dialog.deleteAllConfirm': return '确定要删除全部下载任务吗？此操作不可撤销。';
			case 'downloads.page.toast.addedToQueue': return '已添加到下载队列';
			case 'downloads.page.toast.resumed': return '已继续下载';
			case 'downloads.page.toast.paused': return '已暂停下载';
			case 'downloads.page.toast.deleted': return '已删除';
			case 'downloads.page.toast.retrying': return '已重新添加到下载队列';
			case 'downloads.page.toast.fileLocation': return ({required Object path}) => '文件位置: ${path}';
			case 'downloads.addDialog.title': return '新建下载任务';
			case 'downloads.addDialog.tabs.url': return 'URL 下载';
			case 'downloads.addDialog.tabs.torrent': return '种子下载';
			case 'downloads.addDialog.url.hint': return '输入下载链接，每行一个\n支持：\n- HTTP/HTTPS 链接\n- FTP 链接\n- 磁力链接（magnet:?xt=...)';
			case 'downloads.addDialog.torrent.dropZone': return '拖入种子文件到此处';
			case 'downloads.addDialog.torrent.dropZoneWindows': return '点击下方按钮选择种子文件';
			case 'downloads.addDialog.torrent.supported': return '支持 .torrent 文件';
			case 'downloads.addDialog.torrent.selectFile': return '选择种子文件';
			case 'downloads.addDialog.advanced.title': return '高级选项';
			case 'downloads.addDialog.advanced.savePath': return '保存路径（可选）';
			case 'downloads.addDialog.advanced.savePathHint': return '留空使用默认下载路径';
			case 'downloads.addDialog.advanced.connections': return ({required Object count}) => '单文件连接数: ${count}';
			case 'downloads.addDialog.advanced.split': return ({required Object count}) => '单任务分段数: ${count}';
			case 'downloads.addDialog.actions.cancel': return '取消';
			case 'downloads.addDialog.actions.start': return '开始下载';
			case 'downloads.addDialog.errors.noUrl': return '请输入至少一个下载链接';
			case 'downloads.addDialog.errors.noTorrent': return '请选择或拖入种子文件';
			case 'downloads.addDialog.errors.selectFileFailed': return ({required Object error}) => '选择文件失败: ${error}';
			case 'downloads.addDialog.errors.selectPathFailed': return ({required Object error}) => '选择路径失败: ${error}';
			case 'downloads.addDialog.errors.submitFailed': return ({required Object error}) => '添加下载失败: ${error}';
			case 'downloads.addDialog.toast.added': return ({required Object count}) => '已添加 ${count} 个下载任务';
			case 'downloads.addDialog.toast.addedTorrent': return '已添加种子下载任务';
			case 'downloads.detailDialog.title': return '任务详情';
			case 'downloads.detailDialog.sections.taskName': return '任务名称';
			case 'downloads.detailDialog.sections.fileName': return '文件名';
			case 'downloads.detailDialog.sections.fileSize': return '文件大小';
			case 'downloads.detailDialog.sections.progress': return '下载进度';
			case 'downloads.detailDialog.sections.speed': return '下载速度';
			case 'downloads.detailDialog.sections.uploadSpeed': return '上传速度';
			case 'downloads.detailDialog.sections.connections': return '连接数';
			case 'downloads.detailDialog.sections.eta': return '预计剩余时间';
			case 'downloads.detailDialog.sections.filePath': return '文件路径';
			case 'downloads.detailDialog.sections.gid': return '任务 ID';
			case 'downloads.detailDialog.sections.createdAt': return '创建时间';
			case 'downloads.detailDialog.actions.copyPath': return '复制路径';
			case 'downloads.detailDialog.actions.openFile': return '打开文件';
			case 'downloads.detailDialog.actions.openFolder': return '打开文件夹';
			case 'downloads.detailDialog.actions.retry': return '重新下载';
			case 'downloads.detailDialog.actions.close': return '关闭';
			case 'downloads.detailDialog.toast.pathCopied': return '已复制路径';
			case 'torrent.consent.title': return 'BitTorrent 使用提示';
			case 'torrent.consent.description': return '启用 BT 下载前，请确认遵守所在地法律并了解使用风险。';
			case 'torrent.consent.agree': return '我已知悉，继续';
			case 'torrent.consent.decline': return '暂不开启';
			case 'torrent.error.submit': return '无法提交磁力链接，稍后重试';
			case 'settings.title': return '设置';
			case 'settings.downloads': return '下载设置';
			case 'settings.playback': return '播放偏好';
			case 'settings.general.title': return '通用';
			case 'settings.general.appearance': return '外观设置';
			case 'settings.general.appearanceDesc': return '设置应用主题和刷新率';
			case 'settings.general.language': return '应用语言';
			case 'settings.general.languageDesc': return '选择应用界面显示语言';
			case 'settings.general.followSystem': return '系统';
			case 'settings.general.exitBehavior': return '关闭时';
			case 'settings.general.exitApp': return '退出 Haipee';
			case 'settings.general.minimizeToTray': return '最小化至托盘';
			case 'settings.general.askEveryTime': return '每次都询问';
			case 'settings.appearancePage.title': return '外观设置';
			case 'settings.appearancePage.mode.title': return '主题模式';
			case 'settings.appearancePage.mode.system': return '系统';
			case 'settings.appearancePage.mode.light': return '浅色';
			case 'settings.appearancePage.mode.dark': return '深色';
			case 'settings.appearancePage.colorScheme.title': return '主题色';
			case 'settings.appearancePage.colorScheme.dialogTitle': return '选择主题色';
			case 'settings.appearancePage.colorScheme.dynamicColor': return '动态配色';
			case 'settings.appearancePage.colorScheme.dynamicColorInfo': return '在支持的设备上根据系统壁纸生成调色板（Android 12+/Windows 11）。';
			case 'settings.appearancePage.colorScheme.labels.defaultLabel': return '默认';
			case 'settings.appearancePage.colorScheme.labels.teal': return '青色';
			case 'settings.appearancePage.colorScheme.labels.blue': return '蓝色';
			case 'settings.appearancePage.colorScheme.labels.indigo': return '靛蓝';
			case 'settings.appearancePage.colorScheme.labels.violet': return '紫罗兰';
			case 'settings.appearancePage.colorScheme.labels.pink': return '粉色';
			case 'settings.appearancePage.colorScheme.labels.yellow': return '黄色';
			case 'settings.appearancePage.colorScheme.labels.orange': return '橙色';
			case 'settings.appearancePage.colorScheme.labels.deepOrange': return '深橙色';
			case 'settings.appearancePage.oled.title': return 'OLED 增强';
			case 'settings.appearancePage.oled.description': return '针对 OLED 屏幕优化纯黑配色。';
			case 'settings.appearancePage.window.title': return '窗口按钮';
			case 'settings.appearancePage.window.description': return '在标题栏显示窗口控制按钮。';
			case 'settings.appearancePage.refreshRate.title': return '屏幕刷新率';
			case 'settings.source.title': return '源';
			case 'settings.source.ruleManagement': return '规则管理';
			case 'settings.source.ruleManagementDesc': return '管理视频资源规则';
			case 'settings.source.githubProxy': return 'Github 镜像';
			case 'settings.source.githubProxyDesc': return '使用镜像访问规则托管仓库';
			case 'settings.plugins.title': return '规则管理';
			case 'settings.plugins.empty': return '没有可用规则';
			case 'settings.plugins.tooltip.updateAll': return '更新全部';
			case 'settings.plugins.tooltip.addRule': return '添加规则';
			case 'settings.plugins.sort.title': return '排序方式';
			case 'settings.plugins.sort.tooltip': return '排序';
			case 'settings.plugins.sort.options.original': return '默认顺序';
			case 'settings.plugins.sort.options.nameAsc': return '名称升序';
			case 'settings.plugins.sort.options.nameDesc': return '名称降序';
			case 'settings.plugins.sort.options.failureAsc': return '失败次数升序';
			case 'settings.plugins.sort.options.failureDesc': return '失败次数降序';
			case 'settings.plugins.multiSelect.selectedCount': return '已选择 {count} 项';
			case 'settings.plugins.loading.updating': return '正在更新规则…';
			case 'settings.plugins.loading.updatingSingle': return '更新中';
			case 'settings.plugins.loading.importing': return '导入中';
			case 'settings.plugins.labels.version': return '版本：{version}';
			case 'settings.plugins.labels.statusUpdatable': return '可更新';
			case 'settings.plugins.labels.statusSearchValid': return '搜索有效';
			case 'settings.plugins.actions.newRule': return '新建规则';
			case 'settings.plugins.actions.importFromRepo': return '从规则仓库导入';
			case 'settings.plugins.actions.importFromClipboard': return '从剪贴板导入';
			case 'settings.plugins.actions.cancel': return '取消';
			case 'settings.plugins.actions.import': return '导入';
			case 'settings.plugins.actions.update': return '更新';
			case 'settings.plugins.actions.edit': return '编辑';
			case 'settings.plugins.actions.copyToClipboard': return '复制到剪贴板';
			case 'settings.plugins.actions.share': return '分享';
			case 'settings.plugins.actions.delete': return '删除';
			case 'settings.plugins.dialogs.deleteTitle': return '删除规则';
			case 'settings.plugins.dialogs.deleteMessage': return '确定要删除选中的 {count} 条规则吗？';
			case 'settings.plugins.dialogs.importTitle': return '导入规则';
			case 'settings.plugins.dialogs.shareTitle': return '规则链接';
			case 'settings.plugins.toast.allUpToDate': return '所有规则已是最新';
			case 'settings.plugins.toast.updateCount': return '已更新 {count} 条规则';
			case 'settings.plugins.toast.importSuccess': return '导入成功';
			case 'settings.plugins.toast.importFailed': return '导入失败：{error}';
			case 'settings.plugins.toast.repoMissing': return '规则仓库中没有当前规则';
			case 'settings.plugins.toast.alreadyLatest': return '规则已是最新';
			case 'settings.plugins.toast.updateSuccess': return '更新成功';
			case 'settings.plugins.toast.updateIncompatible': return 'Haipee 版本过低，此规则不兼容当前版本';
			case 'settings.plugins.toast.updateFailed': return '更新规则失败';
			case 'settings.plugins.toast.copySuccess': return '已复制到剪贴板';
			case 'settings.plugins.editor.title': return '编辑规则';
			case 'settings.plugins.editor.fields.name': return '规则名称';
			case 'settings.plugins.editor.fields.version': return '版本';
			case 'settings.plugins.editor.fields.baseUrl': return '基础 URL';
			case 'settings.plugins.editor.fields.searchUrl': return '搜索 URL';
			case 'settings.plugins.editor.fields.searchList': return '搜索列表 XPath';
			case 'settings.plugins.editor.fields.searchName': return '搜索标题 XPath';
			case 'settings.plugins.editor.fields.searchResult': return '搜索结果 XPath';
			case 'settings.plugins.editor.fields.chapterRoads': return '剧集线路 XPath';
			case 'settings.plugins.editor.fields.chapterResult': return '剧集结果 XPath';
			case 'settings.plugins.editor.fields.userAgent': return 'User-Agent';
			case 'settings.plugins.editor.fields.referer': return 'Referer';
			case 'settings.plugins.editor.advanced.title': return '高级配置';
			case 'settings.plugins.editor.advanced.legacyParser.title': return '启用旧版解析';
			case 'settings.plugins.editor.advanced.legacyParser.subtitle': return '使用旧版 XPath 解析逻辑以兼容部分规则。';
			case 'settings.plugins.editor.advanced.httpPost.title': return '使用 POST 请求';
			case 'settings.plugins.editor.advanced.httpPost.subtitle': return '以 HTTP POST 方式发送搜索请求。';
			case 'settings.plugins.editor.advanced.nativePlayer.title': return '强制原生播放器';
			case 'settings.plugins.editor.advanced.nativePlayer.subtitle': return '优先使用内置播放器播放链接。';
			case 'settings.plugins.shop.title': return '规则仓库';
			case 'settings.plugins.shop.tooltip.sortByName': return '按名称排序';
			case 'settings.plugins.shop.tooltip.sortByUpdate': return '按更新时间排序';
			case 'settings.plugins.shop.tooltip.refresh': return '刷新规则列表';
			case 'settings.plugins.shop.labels.playerType.native': return 'native';
			case 'settings.plugins.shop.labels.playerType.webview': return 'webview';
			case 'settings.plugins.shop.labels.lastUpdated': return '更新时间: {timestamp}';
			case 'settings.plugins.shop.buttons.install': return '添加';
			case 'settings.plugins.shop.buttons.installed': return '已添加';
			case 'settings.plugins.shop.buttons.update': return '更新';
			case 'settings.plugins.shop.buttons.toggleMirrorEnable': return '启用镜像';
			case 'settings.plugins.shop.buttons.toggleMirrorDisable': return '禁用镜像';
			case 'settings.plugins.shop.buttons.refresh': return '刷新';
			case 'settings.plugins.shop.toast.importFailed': return '导入规则失败';
			case 'settings.plugins.shop.error.unreachable': return '无法访问远程仓库\n{status}';
			case 'settings.plugins.shop.error.mirrorEnabled': return '镜像已启用';
			case 'settings.plugins.shop.error.mirrorDisabled': return '镜像已禁用';
			case 'settings.metadata.title': return '信息源';
			case 'settings.metadata.enableBangumi': return '启用 Bangumi 信息源';
			case 'settings.metadata.enableBangumiDesc': return '从 Bangumi 拉取视频信息';
			case 'settings.metadata.enableTmdb': return '启用 TMDb 信息源';
			case 'settings.metadata.enableTmdbDesc': return '从 TMDb 补充多语言资料';
			case 'settings.metadata.preferredLanguage': return '优先语言';
			case 'settings.metadata.preferredLanguageDesc': return '设置元数据同步时使用的语言';
			case 'settings.metadata.followSystemLanguage': return '跟随系统语言';
			case 'settings.metadata.simplifiedChinese': return '简体中文 (zh-CN)';
			case 'settings.metadata.traditionalChinese': return '繁體中文 (zh-TW)';
			case 'settings.metadata.japanese': return '日语 (ja-JP)';
			case 'settings.metadata.english': return '英语 (en-US)';
			case 'settings.metadata.custom': return '自定义';
			case 'settings.player.title': return '播放器设置';
			case 'settings.player.playerSettings': return '播放设置';
			case 'settings.player.playerSettingsDesc': return '设置播放器相关参数';
			case 'settings.player.hardwareDecoding': return '硬件解码';
			case 'settings.player.hardwareDecoder': return '硬件解码器';
			case 'settings.player.hardwareDecoderDesc': return '仅在硬件解码启用时生效';
			case 'settings.player.lowMemoryMode': return '低内存模式';
			case 'settings.player.lowMemoryModeDesc': return '禁用高级缓存以减少内存占用';
			case 'settings.player.lowLatencyAudio': return '低延迟音频';
			case 'settings.player.lowLatencyAudioDesc': return '启用 OpenSLES 音频输出以降低延时';
			case 'settings.player.superResolution': return '超分辨率';
			case 'settings.player.autoJump': return '自动跳转';
			case 'settings.player.autoJumpDesc': return '跳转到上次播放位置';
			case 'settings.player.disableAnimations': return '禁用视频';
			case 'settings.player.disableAnimationsDesc': return '禁用播放器内的过渡视频';
			case 'settings.player.errorPrompt': return '错误提示';
			case 'settings.player.errorPromptDesc': return '显示播放器内部错误提示';
			case 'settings.player.debugMode': return '调试模式';
			case 'settings.player.debugModeDesc': return '记录播放器内部日志';
			case 'settings.player.privateMode': return '隐身模式';
			case 'settings.player.privateModeDesc': return '不保留观看记录';
			case 'settings.player.defaultPlaySpeed': return '默认倍速';
			case 'settings.player.defaultVideoAspectRatio': return '默认视频比例';
			case 'settings.player.aspectRatio.auto': return '自动';
			case 'settings.player.aspectRatio.crop': return '裁切填充';
			case 'settings.player.aspectRatio.stretch': return '拉伸填充';
			case 'settings.player.danmakuSettings': return '弹幕设置';
			case 'settings.player.danmakuSettingsDesc': return '设置弹幕相关参数';
			case 'settings.player.danmaku': return '弹幕';
			case 'settings.player.danmakuDefaultOn': return '默认开启';
			case 'settings.player.danmakuDefaultOnDesc': return '默认是否随视频播放弹幕';
			case 'settings.player.danmakuSource': return '弹幕源';
			case 'settings.player.danmakuSources.bilibili': return 'Bilibili';
			case 'settings.player.danmakuSources.gamer': return 'Gamer';
			case 'settings.player.danmakuSources.dandan': return 'DanDan';
			case 'settings.player.danmakuCredentials': return '凭证';
			case 'settings.player.danmakuDanDanCredentials': return 'DanDan API 凭证';
			case 'settings.player.danmakuDanDanCredentialsDesc': return '自定义 DanDan 凭证';
			case 'settings.player.danmakuCredentialModeBuiltIn': return '内置';
			case 'settings.player.danmakuCredentialModeCustom': return '自定义';
			case 'settings.player.danmakuCredentialHint': return '留空使用内置凭证';
			case 'settings.player.danmakuCredentialNotConfigured': return '未配置';
			case 'settings.player.danmakuCredentialsSummary': return 'AppId：{appId}\nAPI Key：{apiKey}';
			case 'settings.player.danmakuShield': return '弹幕屏蔽';
			case 'settings.player.danmakuKeywordShield': return '关键词屏蔽';
			case 'settings.player.danmakuShieldInputHint': return '输入关键词或正则表达式';
			case 'settings.player.danmakuShieldDescription': return '以"/"开头和结尾将视作正则表达式, 如"/\\d+/"表示屏蔽所有数字';
			case 'settings.player.danmakuShieldCount': return '已添加{count}个关键词';
			case 'settings.player.danmakuConvert': return '繁简转换';
			case 'settings.player.danmakuConvertTitle': return '弹幕繁简转换';
			case 'settings.player.danmakuConvertDesc': return '下次联网加载弹幕时生效，已缓存弹幕保留下载时的文字';
			case 'settings.player.danmakuConvertNone': return '不转换';
			case 'settings.player.danmakuConvertSimplified': return '转为简体';
			case 'settings.player.danmakuConvertTraditional': return '转为繁体';
			case 'settings.player.danmakuStyle': return '弹幕样式';
			case 'settings.player.danmakuDisplay': return '弹幕显示';
			case 'settings.player.danmakuArea': return '弹幕区域';
			case 'settings.player.danmakuTopDisplay': return '顶部弹幕';
			case 'settings.player.danmakuBottomDisplay': return '底部弹幕';
			case 'settings.player.danmakuScrollDisplay': return '滚动弹幕';
			case 'settings.player.danmakuMassiveDisplay': return '海量弹幕';
			case 'settings.player.danmakuMassiveDescription': return '弹幕过多时叠加绘制';
			case 'settings.player.danmakuOutline': return '弹幕描边';
			case 'settings.player.danmakuColor': return '弹幕颜色';
			case 'settings.player.danmakuFontSize': return '字体大小';
			case 'settings.player.danmakuFontWeight': return '字体字重';
			case 'settings.player.danmakuOpacity': return '弹幕不透明度';
			case 'settings.player.add': return '添加';
			case 'settings.player.save': return '保存';
			case 'settings.player.restoreDefault': return '恢复默认';
			case 'settings.player.superResolutionTitle': return '超分辨率';
			case 'settings.player.superResolutionHint': return '选择默认的超分辨率模式';
			case 'settings.player.superResolutionOptions.off.label': return '关闭';
			case 'settings.player.superResolutionOptions.off.description': return '不启用画面增强。';
			case 'settings.player.superResolutionOptions.efficiency.label': return '高效模式';
			case 'settings.player.superResolutionOptions.efficiency.description': return '在性能消耗与画质提升之间取得平衡。';
			case 'settings.player.superResolutionOptions.quality.label': return '画质优先';
			case 'settings.player.superResolutionOptions.quality.description': return '最大化画质提升，可能增加资源消耗。';
			case 'settings.player.superResolutionDefaultBehavior': return '默认行为';
			case 'settings.player.superResolutionClosePrompt': return '关闭提示';
			case 'settings.player.superResolutionClosePromptDesc': return '关闭每次启用超分辨率时的提示';
			case 'settings.player.toast.danmakuKeywordEmpty': return '请输入关键词';
			case 'settings.player.toast.danmakuKeywordTooLong': return '关键词过长';
			case 'settings.player.toast.danmakuKeywordExists': return '已存在该关键词';
			case 'settings.player.toast.danmakuCredentialsRestored': return '已恢复内置凭证';
			case 'settings.player.toast.danmakuCredentialsUpdated': return '凭证已更新';
			case 'settings.webdav.title': return 'WebDAV';
			case 'settings.webdav.desc': return '配置同步参数';
			case 'settings.webdav.pageTitle': return '同步设置';
			case 'settings.webdav.editor.title': return 'WebDAV 配置';
			case 'settings.webdav.editor.url': return 'URL';
			case 'settings.webdav.editor.username': return '用户名';
			case 'settings.webdav.editor.password': return '密码';
			case 'settings.webdav.editor.toast.saveSuccess': return '配置已保存，开始测试...';
			case 'settings.webdav.editor.toast.saveFailed': return '配置失败：{error}';
			case 'settings.webdav.editor.toast.testSuccess': return '测试成功。';
			case 'settings.webdav.editor.toast.testFailed': return '测试失败：{error}';
			case 'settings.webdav.section.webdav': return 'WebDAV';
			case 'settings.webdav.tile.webdavToggle': return 'WebDAV 同步';
			case 'settings.webdav.tile.historyToggle': return '观看记录同步';
			case 'settings.webdav.tile.historyDescription': return '允许自动同步观看记录';
			case 'settings.webdav.tile.config': return 'WebDAV 配置';
			case 'settings.webdav.tile.manualUpload': return '手动上传';
			case 'settings.webdav.tile.manualDownload': return '手动下载';
			case 'settings.webdav.info.upload': return '立即将观看记录上传到 WebDAV。';
			case 'settings.webdav.info.download': return '立即将观看记录同步到本地。';
			case 'settings.webdav.toast.uploading': return '正在尝试上传到 WebDAV...';
			case 'settings.webdav.toast.downloading': return '正在尝试从 WebDAV 同步...';
			case 'settings.webdav.toast.notConfigured': return '未开启 WebDAV 同步或配置无效。';
			case 'settings.webdav.toast.connectionFailed': return 'WebDAV 连接失败：{error}';
			case 'settings.webdav.toast.syncFailed': return 'WebDAV 同步失败：{error}';
			case 'settings.webdav.result.initFailed': return 'WebDAV 初始化失败：{error}';
			case 'settings.webdav.result.requireEnable': return '请先开启 WebDAV 同步。';
			case 'settings.webdav.result.disabled': return '未开启 WebDAV 同步或配置无效。';
			case 'settings.webdav.result.connectionFailed': return 'WebDAV 连接失败。';
			case 'settings.webdav.result.syncSuccess': return '同步成功。';
			case 'settings.webdav.result.syncFailed': return '同步失败：{error}';
			case 'settings.update.fallbackDescription': return '暂无更新说明。';
			case 'settings.update.error.invalidResponse': return '更新响应无效。';
			case 'settings.update.dialog.title': return '发现新版本 {version}';
			case 'settings.update.dialog.publishedAt': return '发布于 {date}';
			case 'settings.update.dialog.installationTypeLabel': return '选择安装包';
			case 'settings.update.dialog.actions.disableAutoUpdate': return '关闭自动更新';
			case 'settings.update.dialog.actions.remindLater': return '稍后提醒';
			case 'settings.update.dialog.actions.viewDetails': return '查看详情';
			case 'settings.update.dialog.actions.updateNow': return '立即更新';
			case 'settings.update.installationType.windowsMsix': return 'Windows 安装包（MSIX）';
			case 'settings.update.installationType.windowsPortable': return 'Windows 便携版（ZIP）';
			case 'settings.update.installationType.linuxDeb': return 'Linux 安装包（DEB）';
			case 'settings.update.installationType.linuxTar': return 'Linux 压缩包（TAR.GZ）';
			case 'settings.update.installationType.macosDmg': return 'macOS 安装包（DMG）';
			case 'settings.update.installationType.androidApk': return 'Android 安装包（APK）';
			case 'settings.update.installationType.ios': return 'iOS 版本（前往 GitHub）';
			case 'settings.update.installationType.unknown': return '其他平台';
			case 'settings.update.toast.alreadyLatest': return '当前已是最新版本';
			case 'settings.update.toast.checkFailed': return '检查更新失败，请稍后重试。';
			case 'settings.update.toast.autoUpdateDisabled': return '已关闭自动更新';
			case 'settings.update.toast.downloadLinkMissing': return '没有找到 {type} 的下载链接';
			case 'settings.update.toast.downloadFailed': return '下载失败：{error}';
			case 'settings.update.toast.noCompatibleLink': return '未找到适用的下载链接';
			case 'settings.update.toast.prepareToInstall': return '正在准备安装更新，应用即将退出…';
			case 'settings.update.toast.openInstallerFailed': return '无法打开安装文件：{error}';
			case 'settings.update.toast.launchInstallerFailed': return '启动安装程序失败：{error}';
			case 'settings.update.toast.revealFailed': return '无法打开文件管理器';
			case 'settings.update.toast.unknownReason': return '未知原因';
			case 'settings.update.download.progressTitle': return '正在下载更新';
			case 'settings.update.download.cancel': return '取消';
			case 'settings.update.download.error.title': return '下载失败';
			case 'settings.update.download.error.general': return '无法下载更新。';
			case 'settings.update.download.error.permission': return '没有写入文件的权限。';
			case 'settings.update.download.error.diskFull': return '磁盘空间不足。';
			case 'settings.update.download.error.network': return '网络连接失败。';
			case 'settings.update.download.error.integrity': return '文件校验失败，请重新下载。';
			case 'settings.update.download.error.details': return '详细信息：{error}';
			case 'settings.update.download.error.confirm': return '确定';
			case 'settings.update.download.error.retry': return '重试';
			case 'settings.update.download.complete.title': return '下载完成';
			case 'settings.update.download.complete.message': return '已下载 Haipee {version}。';
			case 'settings.update.download.complete.quitNotice': return '安装过程中应用将退出。';
			case 'settings.update.download.complete.fileLocation': return '文件位置';
			case 'settings.update.download.complete.buttons.later': return '稍后再说';
			case 'settings.update.download.complete.buttons.openFolder': return '打开文件夹';
			case 'settings.update.download.complete.buttons.installNow': return '立即安装';
			case 'settings.other.title': return '其他';
			case 'settings.other.about': return '关于';
			case 'settings.about.title': return '关于';
			case 'settings.about.sections.licenses.title': return '开源许可证';
			case 'settings.about.sections.licenses.description': return '查看所有开源许可证';
			case 'settings.about.sections.links.title': return '外部链接';
			case 'settings.about.sections.links.project': return '项目主页';
			case 'settings.about.sections.links.repository': return '代码仓库';
			case 'settings.about.sections.links.icon': return '图标创作';
			case 'settings.about.sections.links.index': return '视频索引';
			case 'settings.about.sections.links.danmaku': return '弹幕源';
			case 'settings.about.sections.links.danmakuId': return 'ID：{id}';
			case 'settings.about.sections.cache.clearAction': return '清除缓存';
			case 'settings.about.sections.cache.sizePending': return '统计中…';
			case 'settings.about.sections.cache.sizeLabel': return '{size} MB';
			case 'settings.about.sections.updates.title': return '应用更新';
			case 'settings.about.sections.updates.autoUpdate': return '自动更新';
			case 'settings.about.sections.updates.check': return '检查更新';
			case 'settings.about.sections.updates.currentVersion': return '当前版本 {version}';
			case 'settings.about.logs.title': return '应用日志';
			case 'settings.about.logs.empty': return '暂无日志内容。';
			case 'settings.about.logs.toast.cleared': return '日志已清空。';
			case 'settings.about.logs.toast.clearFailed': return '清空日志失败。';
			case 'exitDialog.title': return '退出确认';
			case 'exitDialog.message': return '您想要退出 Haipee 吗？';
			case 'exitDialog.dontAskAgain': return '下次不再询问';
			case 'exitDialog.exit': return '退出 Haipee';
			case 'exitDialog.minimize': return '最小化至托盘';
			case 'exitDialog.cancel': return '取消';
			case 'tray.showWindow': return '显示窗口';
			case 'tray.exit': return '退出 Haipee';
			case 'navigation.tabs.popular': return '热门';
			case 'navigation.tabs.catalog': return '资源分类';
			case 'navigation.tabs.media': return '视频直播';
			case 'navigation.tabs.resource': return '全网资源';
			case 'navigation.tabs.timeline': return '时间表';
			case 'navigation.tabs.my': return '媒体库';
			case 'navigation.tabs.download': return '任务与下载';
			case 'navigation.tabs.settings': return '设置';
			case 'navigation.actions.search': return '搜索';
			case 'navigation.actions.history': return '历史记录';
			case 'navigation.actions.close': return '退出';
			case 'dialogs.disclaimer.title': return '免责声明';
			case 'dialogs.disclaimer.agree': return '已阅读并同意';
			case 'dialogs.disclaimer.exit': return '退出';
			case 'dialogs.updateMirror.title': return '更新镜像';
			case 'dialogs.updateMirror.question': return '您希望从哪里获取应用更新？';
			case 'dialogs.updateMirror.description': return 'Github 镜像适用于大多数情况。如果您使用 F-Droid 应用商店，请选择 F-Droid 镜像。';
			case 'dialogs.updateMirror.options.github': return 'Github';
			case 'dialogs.updateMirror.options.fdroid': return 'F-Droid';
			case 'dialogs.pluginUpdates.toast': return '检测到 {count} 条规则可以更新';
			case 'dialogs.webdav.syncFailed': return '同步观看记录失败 {error}';
			case 'dialogs.about.licenseLegalese': return '开源许可证';
			case 'dialogs.cache.title': return '缓存管理';
			case 'dialogs.cache.message': return '缓存包含视频封面，清除后加载时需要重新下载，确认要清除缓存吗？';
			case 'library.common.emptyState': return '没有找到内容';
			case 'library.common.retry': return '点击重试';
			case 'library.common.backHint': return '再按一次退出应用';
			case 'library.common.toast.editMode': return '当前为编辑模式';
			case 'library.popular.title': return '首页';
			case 'library.popular.allTag': return '首页';
			case 'library.popular.toast.backPress': return '再按一次退出应用';
			case 'library.timeline.weekdays.mon': return '一';
			case 'library.timeline.weekdays.tue': return '二';
			case 'library.timeline.weekdays.wed': return '三';
			case 'library.timeline.weekdays.thu': return '四';
			case 'library.timeline.weekdays.fri': return '五';
			case 'library.timeline.weekdays.sat': return '六';
			case 'library.timeline.weekdays.sun': return '日';
			case 'library.timeline.seasonPicker.title': return '时间机器';
			case 'library.timeline.seasonPicker.yearLabel': return '{year}年';
			case 'library.timeline.season.title': return '{year}年{season}新番';
			case 'library.timeline.season.loading': return '加载中…';
			case 'library.timeline.season.names.winter': return '冬季';
			case 'library.timeline.season.names.spring': return '春季';
			case 'library.timeline.season.names.summer': return '夏季';
			case 'library.timeline.season.names.autumn': return '秋季';
			case 'library.timeline.season.short.winter': return '冬';
			case 'library.timeline.season.short.spring': return '春';
			case 'library.timeline.season.short.summer': return '夏';
			case 'library.timeline.season.short.autumn': return '秋';
			case 'library.timeline.sort.title': return '排序方式';
			case 'library.timeline.sort.byHeat': return '按热度排序';
			case 'library.timeline.sort.byRating': return '按评分排序';
			case 'library.timeline.sort.byTime': return '按时间排序';
			case 'library.search.sort.label': return '搜索排序';
			case 'library.search.sort.byHeat': return '按热度排序';
			case 'library.search.sort.byRating': return '按评分排序';
			case 'library.search.sort.byRelevance': return '按相关度排序';
			case 'library.search.noHistory': return '暂无搜索记录';
			case 'library.history.title': return '历史记录';
			case 'library.history.empty': return '没有找到历史记录';
			case 'library.history.chips.source': return '来源';
			case 'library.history.chips.progress': return '已看到';
			case 'library.history.chips.episodeNumber': return '第{number}话';
			case 'library.history.toast.sourceMissing': return '未找到关联视频源';
			case 'library.history.manage.title': return '记录管理';
			case 'library.history.manage.confirmClear': return '确认要清除所有历史记录吗？';
			case 'library.history.manage.cancel': return '取消';
			case 'library.history.manage.confirm': return '确认';
			case 'library.info.summary.title': return '简介';
			case 'library.info.summary.expand': return '加载更多';
			case 'library.info.summary.collapse': return '加载更少';
			case 'library.info.tags.title': return '标签';
			case 'library.info.tags.more': return '更多 +';
			case 'library.info.metadata.refresh': return '刷新';
			case 'library.info.metadata.syncingTitle': return '正在同步元数据…';
			case 'library.info.metadata.syncingSubtitle': return '首次同步可能需要几秒钟。';
			case 'library.info.metadata.emptyTitle': return '尚未获取官方元数据';
			case 'library.info.metadata.emptySubtitle': return '稍后重试或检查设置中的元数据开关。';
			case 'library.info.metadata.source': return ({required Object source}) => '元数据来自 ${source}';
			case 'library.info.metadata.updated': return ({required Object timestamp, required Object language}) => '最后更新：${timestamp} · 语言：${language}';
			case 'library.info.metadata.languageSystem': return '系统默认';
			case 'library.info.metadata.multiSource': return '多源合并';
			case 'library.info.episodes.title': return '剧集';
			case 'library.info.episodes.collapse': return '收起';
			case 'library.info.episodes.expand': return ({required Object count}) => '展开全部 (${count})';
			case 'library.info.episodes.numberedEpisode': return ({required Object number}) => '第${number}话';
			case 'library.info.episodes.dateUnknown': return '日期待定';
			case 'library.info.episodes.runtimeUnknown': return '时长未知';
			case 'library.info.episodes.runtimeMinutes': return ({required Object minutes}) => '${minutes} 分钟';
			case 'library.info.errors.fetchFailed': return '获取失败，请重试';
			case 'library.info.tabs.overview': return '概览';
			case 'library.info.tabs.comments': return '短评';
			case 'library.info.tabs.characters': return '角色';
			case 'library.info.tabs.reviews': return '评论';
			case 'library.info.tabs.staff': return '制作人员';
			case 'library.info.tabs.placeholder': return '施工中';
			case 'library.info.actions.startWatching': return '开始观看';
			case 'library.info.toast.characterSortFailed': return '角色排序失败：{details}';
			case 'library.info.sourceSheet.title': return '选择播放源 ({name})';
			case 'library.info.sourceSheet.alias.deleteTooltip': return '删除别名';
			case 'library.info.sourceSheet.alias.deleteTitle': return '删除别名';
			case 'library.info.sourceSheet.alias.deleteMessage': return '删除后无法恢复，确认要永久删除这个别名吗？';
			case 'library.info.sourceSheet.toast.aliasEmpty': return '暂无可用别名，请先手动添加后再检索。';
			case 'library.info.sourceSheet.toast.loadFailed': return '获取视频播放列表失败。';
			case 'library.info.sourceSheet.toast.removed': return '已删除源 {plugin}。';
			case 'library.info.sourceSheet.sort.title': return '排序方式';
			case 'library.info.sourceSheet.sort.tooltip': return '排序：{label}';
			case 'library.info.sourceSheet.sort.options.original': return '默认顺序';
			case 'library.info.sourceSheet.sort.options.nameAsc': return '名称升序';
			case 'library.info.sourceSheet.sort.options.nameDesc': return '名称降序';
			case 'library.info.sourceSheet.sort.options.failureAsc': return '失败次数升序';
			case 'library.info.sourceSheet.sort.options.failureDesc': return '失败次数降序';
			case 'library.info.sourceSheet.card.title': return '源 · {plugin}';
			case 'library.info.sourceSheet.card.play': return '播放';
			case 'library.info.sourceSheet.actions.searchAgain': return '重新检索';
			case 'library.info.sourceSheet.actions.aliasSearch': return '别名检索';
			case 'library.info.sourceSheet.actions.removeSource': return '删除源';
			case 'library.info.sourceSheet.status.searching': return '{plugin} 检索中…';
			case 'library.info.sourceSheet.status.failed': return '{plugin} 检索失败';
			case 'library.info.sourceSheet.status.empty': return '{plugin} 无检索结果';
			case 'library.info.sourceSheet.empty.searching': return '检索中，请稍候…';
			case 'library.info.sourceSheet.empty.noResults': return '暂无可用视频源，请尝试重新检索或使用别名检索。';
			case 'library.info.sourceSheet.dialog.removeTitle': return '删除源';
			case 'library.info.sourceSheet.dialog.removeMessage': return '确定要删除源 {plugin} 吗？';
			case 'library.my.title': return '我的';
			case 'library.my.sections.video': return '视频';
			case 'library.my.favorites.title': return '收藏';
			case 'library.my.favorites.description': return '查看在看、想看、看过';
			case 'library.my.favorites.empty': return '暂无收藏记录。';
			case 'library.my.favorites.tabs.watching': return '在看';
			case 'library.my.favorites.tabs.planned': return '想看';
			case 'library.my.favorites.tabs.completed': return '看过';
			case 'library.my.favorites.tabs.empty': return '暂无记录。';
			case 'library.my.favorites.sync.disabled': return '未启用 WebDAV，同步功能不可用。';
			case 'library.my.favorites.sync.editing': return '编辑模式下无法执行同步。';
			case 'library.my.history.title': return '播放历史记录';
			case 'library.my.history.description': return '查看播放过的视频';
			case 'playback.toast.screenshotProcessing': return '截图中...';
			case 'playback.toast.screenshotSaved': return '截图保存到相簿成功';
			case 'playback.toast.screenshotSaveFailed': return '截图保存失败：{error}';
			case 'playback.toast.screenshotError': return '截图失败：{error}';
			case 'playback.toast.playlistEmpty': return '播放列表为空';
			case 'playback.toast.episodeLatest': return '已经是最新一集';
			case 'playback.toast.loadingEpisode': return '正在加载{identifier}';
			case 'playback.toast.danmakuUnsupported': return '当前剧集暂不支持发送弹幕';
			case 'playback.toast.danmakuEmpty': return '弹幕内容为空';
			case 'playback.toast.danmakuTooLong': return '弹幕内容过长';
			case 'playback.toast.waitForVideo': return '请等待视频加载完成';
			case 'playback.toast.enableDanmakuFirst': return '请先开启弹幕';
			case 'playback.toast.danmakuSearchError': return '弹幕检索错误: {error}';
			case 'playback.toast.danmakuSearchEmpty': return '未找到匹配结果';
			case 'playback.toast.danmakuSwitching': return '弹幕切换中';
			case 'playback.toast.clipboardCopied': return '已复制到剪贴板';
			case 'playback.toast.internalError': return '播放器内部错误：{details}';
			case 'playback.danmaku.inputHint': return '发个友善的弹幕见证当下';
			case 'playback.danmaku.inputDisabled': return '已关闭弹幕';
			case 'playback.danmaku.send': return '发送';
			case 'playback.danmaku.mobileButton': return '点我发弹幕';
			case 'playback.danmaku.mobileButtonDisabled': return '已关闭弹幕';
			case 'playback.externalPlayer.launching': return '尝试唤起外部播放器';
			case 'playback.externalPlayer.launchFailed': return '唤起外部播放器失败';
			case 'playback.externalPlayer.unavailable': return '无法使用外部播放器';
			case 'playback.externalPlayer.unsupportedDevice': return '暂不支持该设备';
			case 'playback.externalPlayer.unsupportedPlugin': return '暂不支持该规则';
			case 'playback.controls.speed.title': return '播放速度';
			case 'playback.controls.speed.reset': return '默认速度';
			case 'playback.controls.skip.title': return '跳过秒数';
			case 'playback.controls.skip.tooltip': return '长按修改时间';
			case 'playback.controls.status.fastForward': return '快进 {seconds} 秒';
			case 'playback.controls.status.rewind': return '快退 {seconds} 秒';
			case 'playback.controls.status.speed': return '倍速播放';
			case 'playback.controls.superResolution.label': return '超分辨率';
			case 'playback.controls.superResolution.off': return '关闭';
			case 'playback.controls.superResolution.balanced': return '效率档';
			case 'playback.controls.superResolution.quality': return '质量档';
			case 'playback.controls.speedMenu.label': return '倍速';
			case 'playback.controls.aspectRatio.label': return '视频比例';
			case 'playback.controls.aspectRatio.options.auto': return '自动';
			case 'playback.controls.aspectRatio.options.crop': return '裁切填充';
			case 'playback.controls.aspectRatio.options.stretch': return '拉伸填充';
			case 'playback.controls.tooltips.danmakuOn': return '关闭弹幕(d)';
			case 'playback.controls.tooltips.danmakuOff': return '打开弹幕(d)';
			case 'playback.controls.menu.danmakuToggle': return '弹幕切换';
			case 'playback.controls.menu.videoInfo': return '视频详情';
			case 'playback.controls.menu.cast': return '远程投屏';
			case 'playback.controls.menu.external': return '外部播放';
			case 'playback.controls.syncplay.label': return '一起看';
			case 'playback.controls.syncplay.room': return '当前房间：{name}';
			case 'playback.controls.syncplay.roomEmpty': return '未加入';
			case 'playback.controls.syncplay.latency': return '网络延时：{ms}ms';
			case 'playback.controls.syncplay.join': return '加入房间';
			case 'playback.controls.syncplay.switchServer': return '切换服务器';
			case 'playback.controls.syncplay.disconnect': return '断开连接';
			case 'playback.loading.parsing': return '视频资源解析中';
			case 'playback.loading.parseFailed': return '视频资源解析失败';
			case 'playback.loading.player': return '视频资源解析成功，播放器加载中';
			case 'playback.loading.danmakuSearch': return '弹幕检索中...';
			case 'playback.danmakuSearch.title': return '弹幕检索';
			case 'playback.danmakuSearch.hint': return '视频名';
			case 'playback.danmakuSearch.submit': return '提交';
			case 'playback.remote.title': return '远程投屏';
			case 'playback.remote.toast.searching': return '开始搜索';
			case 'playback.remote.toast.casting': return '尝试投屏至 {device}';
			case 'playback.remote.toast.error': return 'DLNA 异常: {details}\n尝试重新进入 DLNA 投屏或切换设备';
			case 'playback.debug.title': return '调试信息';
			case 'playback.debug.closeTooltip': return '关闭调试信息';
			case 'playback.debug.tabs.status': return '状态';
			case 'playback.debug.tabs.logs': return '日志';
			case 'playback.debug.sections.source': return '播放源';
			case 'playback.debug.sections.playback': return '播放器状态';
			case 'playback.debug.sections.timing': return '时间与参数';
			case 'playback.debug.sections.media': return '媒体轨道';
			case 'playback.debug.labels.series': return '视频';
			case 'playback.debug.labels.plugin': return '插件';
			case 'playback.debug.labels.route': return '线路';
			case 'playback.debug.labels.episode': return '集数';
			case 'playback.debug.labels.routeCount': return '线路数量';
			case 'playback.debug.labels.sourceTitle': return '源标题';
			case 'playback.debug.labels.parsedUrl': return '解析地址';
			case 'playback.debug.labels.playUrl': return '播放地址';
			case 'playback.debug.labels.danmakuId': return 'DanDan ID';
			case 'playback.debug.labels.syncRoom': return 'SyncPlay 房间';
			case 'playback.debug.labels.syncLatency': return 'SyncPlay RTT';
			case 'playback.debug.labels.nativePlayer': return '原生播放器';
			case 'playback.debug.labels.parsing': return '解析中';
			case 'playback.debug.labels.playerLoading': return '播放器加载';
			case 'playback.debug.labels.playerInitializing': return '播放器初始化';
			case 'playback.debug.labels.playing': return '播放中';
			case 'playback.debug.labels.buffering': return '缓冲中';
			case 'playback.debug.labels.completed': return '播放完成';
			case 'playback.debug.labels.bufferFlag': return '缓冲标志';
			case 'playback.debug.labels.currentPosition': return '当前位置';
			case 'playback.debug.labels.bufferProgress': return '缓冲进度';
			case 'playback.debug.labels.duration': return '总时长';
			case 'playback.debug.labels.speed': return '播放速度';
			case 'playback.debug.labels.volume': return '音量';
			case 'playback.debug.labels.brightness': return '亮度';
			case 'playback.debug.labels.resolution': return '分辨率';
			case 'playback.debug.labels.aspectRatio': return '视频比例';
			case 'playback.debug.labels.superResolution': return '超分辨率';
			case 'playback.debug.labels.videoParams': return '视频参数';
			case 'playback.debug.labels.audioParams': return '音频参数';
			case 'playback.debug.labels.playlist': return '播放列表';
			case 'playback.debug.labels.audioTracks': return '音频轨';
			case 'playback.debug.labels.videoTracks': return '视频轨';
			case 'playback.debug.labels.audioBitrate': return '音频码率';
			case 'playback.debug.values.yes': return '是';
			case 'playback.debug.values.no': return '否';
			case 'playback.debug.logs.playerEmpty': return '播放器日志（0）';
			case 'playback.debug.logs.playerSummary': return '播放器日志（{count} 条，展示 {displayed} 条）';
			case 'playback.debug.logs.webviewEmpty': return 'WebView 日志（0）';
			case 'playback.debug.logs.webviewSummary': return 'WebView 日志（{count} 条，展示 {displayed} 条）';
			case 'playback.syncplay.invalidEndpoint': return 'SyncPlay：服务器地址不合法 {endpoint}';
			case 'playback.syncplay.disconnected': return 'SyncPlay：同步中断 {reason}';
			case 'playback.syncplay.actionReconnect': return '重新连接';
			case 'playback.syncplay.alone': return 'SyncPlay：您是当前房间中的唯一用户';
			case 'playback.syncplay.followUser': return 'SyncPlay：当前以用户 {username} 的进度为准';
			case 'playback.syncplay.userLeft': return 'SyncPlay：{username} 离开了房间';
			case 'playback.syncplay.userJoined': return 'SyncPlay：{username} 加入了房间';
			case 'playback.syncplay.switchEpisode': return 'SyncPlay：{username} 切换到第 {episode} 话';
			case 'playback.syncplay.chat': return 'SyncPlay：{username} 说：{message}';
			case 'playback.syncplay.paused': return 'SyncPlay：{username} 暂停了播放';
			case 'playback.syncplay.resumed': return 'SyncPlay：{username} 开始了播放';
			case 'playback.syncplay.unknownUser': return '未知用户';
			case 'playback.syncplay.switchServerBlocked': return 'SyncPlay：请先退出当前房间再切换服务器';
			case 'playback.syncplay.defaultCustomEndpoint': return '自定义服务器';
			case 'playback.syncplay.selectServer.title': return '选择服务器';
			case 'playback.syncplay.selectServer.customTitle': return '自定义服务器';
			case 'playback.syncplay.selectServer.customHint': return '请输入服务器地址';
			case 'playback.syncplay.selectServer.duplicateOrEmpty': return '服务器地址不能重复或为空';
			case 'playback.syncplay.join.title': return '加入房间';
			case 'playback.syncplay.join.roomLabel': return '房间号';
			case 'playback.syncplay.join.roomEmpty': return '请输入房间号';
			case 'playback.syncplay.join.roomInvalid': return '房间号需要6到10位数字';
			case 'playback.syncplay.join.usernameLabel': return '用户名';
			case 'playback.syncplay.join.usernameEmpty': return '请输入用户名';
			case 'playback.syncplay.join.usernameInvalid': return '用户名必须为4到12位英文字符';
			case 'playback.playlist.collection': return '合集';
			case 'playback.playlist.list': return '播放列表{index}';
			case 'playback.tabs.episodes': return '选集';
			case 'playback.tabs.comments': return '评论';
			case 'playback.comments.sectionTitle': return '本集标题';
			case 'playback.comments.manualSwitch': return '手动切换';
			case 'playback.comments.dialogTitle': return '输入集数';
			case 'playback.comments.dialogEmpty': return '请输入集数';
			case 'playback.comments.dialogConfirm': return '刷新';
			case 'playback.superResolution.warning.title': return '性能提示';
			case 'playback.superResolution.warning.message': return '启用超分辨率（质量档）可能会造成设备卡顿，是否继续？';
			case 'playback.superResolution.warning.dontAskAgain': return '下次不再询问';
			case 'network.error.badCertificate': return '证书有误！';
			case 'network.error.badResponse': return '服务器异常，请稍后重试！';
			case 'network.error.cancel': return '请求已被取消，请重新请求';
			case 'network.error.connection': return '连接错误，请检查网络设置';
			case 'network.error.connectionTimeout': return '网络连接超时，请检查网络设置';
			case 'network.error.receiveTimeout': return '响应超时，请稍后重试！';
			case 'network.error.sendTimeout': return '发送请求超时，请检查网络设置';
			case 'network.error.unknown': return '{status} 网络异常';
			case 'network.status.mobile': return '正在使用移动流量';
			case 'network.status.wifi': return '正在使用 Wi-Fi';
			case 'network.status.ethernet': return '正在使用局域网';
			case 'network.status.vpn': return '正在使用代理网络';
			case 'network.status.other': return '正在使用其他网络';
			case 'network.status.none': return '未连接到任何网络';
			default: return null;
		}
	}
}

extension on _TranslationsZhTw {
	dynamic _flatMapFunction(String path) {
		switch (path) {
			case 'app.title': return 'Haipee';
			case 'app.loading': return '載入中…';
			case 'app.retry': return '重試';
			case 'app.confirm': return '確認';
			case 'app.cancel': return '取消';
			case 'app.delete': return '刪除';
			case 'metadata.sectionTitle': return '媒體資訊';
			case 'metadata.refresh': return '重新整理中繼資料';
			case 'metadata.source.bangumi': return 'Bangumi';
			case 'metadata.source.tmdb': return 'TMDb';
			case 'metadata.lastSynced': return '最後同步：{timestamp}';
			case 'downloads.sectionTitle': return '下載佇列';
			case 'downloads.downloadOffline': return '下載引擎未連線';
			case 'downloads.queued': return '排隊中';
			case 'downloads.running': return '下載中';
			case 'downloads.completed': return '已完成';
			case 'torrent.consent.title': return 'BitTorrent 使用通知';
			case 'torrent.consent.description': return '啟用 BT 下載前，請確認遵守所在地法律並了解使用風險。';
			case 'torrent.consent.agree': return '我已知悉，繼續';
			case 'torrent.consent.decline': return '暫不開啟';
			case 'torrent.error.submit': return '無法提交磁力連結，稍後重試';
			case 'settings.title': return '設定';
			case 'settings.downloads': return '下載設定';
			case 'settings.playback': return '播放偏好';
			case 'settings.general.title': return '一般';
			case 'settings.general.appearance': return '外觀';
			case 'settings.general.appearanceDesc': return '設定應用程式主題和刷新率';
			case 'settings.general.language': return '應用程式語言';
			case 'settings.general.languageDesc': return '選擇應用程式介面的顯示語言';
			case 'settings.general.followSystem': return '系統';
			case 'settings.general.exitBehavior': return '關閉時';
			case 'settings.general.exitApp': return '結束 Haipee';
			case 'settings.general.minimizeToTray': return '最小化至系統匣';
			case 'settings.general.askEveryTime': return '每次詢問';
			case 'settings.appearancePage.title': return '外觀';
			case 'settings.appearancePage.mode.title': return '主題模式';
			case 'settings.appearancePage.mode.system': return '系統';
			case 'settings.appearancePage.mode.light': return '淺色';
			case 'settings.appearancePage.mode.dark': return '深色';
			case 'settings.appearancePage.colorScheme.title': return '強調色';
			case 'settings.appearancePage.colorScheme.dialogTitle': return '選擇強調色';
			case 'settings.appearancePage.colorScheme.dynamicColor': return '使用動態色彩';
			case 'settings.appearancePage.colorScheme.dynamicColorInfo': return '在支援的裝置上根據您的桌布生成調色板（Android 12+ / Windows 11）。';
			case 'settings.appearancePage.colorScheme.labels.defaultLabel': return '預設';
			case 'settings.appearancePage.colorScheme.labels.teal': return '青色';
			case 'settings.appearancePage.colorScheme.labels.blue': return '藍色';
			case 'settings.appearancePage.colorScheme.labels.indigo': return '靛藍';
			case 'settings.appearancePage.colorScheme.labels.violet': return '紫羅蘭';
			case 'settings.appearancePage.colorScheme.labels.pink': return '粉色';
			case 'settings.appearancePage.colorScheme.labels.yellow': return '黃色';
			case 'settings.appearancePage.colorScheme.labels.orange': return '橙色';
			case 'settings.appearancePage.colorScheme.labels.deepOrange': return '深橙色';
			case 'settings.appearancePage.oled.title': return 'OLED 對比';
			case 'settings.appearancePage.oled.description': return '使用針對 OLED 顯示器最佳化的更深黑色。';
			case 'settings.appearancePage.window.title': return '視窗按鈕';
			case 'settings.appearancePage.window.description': return '在標題欄顯示視窗控制按鈕。';
			case 'settings.appearancePage.refreshRate.title': return '刷新率';
			case 'settings.source.title': return '來源';
			case 'settings.source.ruleManagement': return '規則管理';
			case 'settings.source.ruleManagementDesc': return '管理動畫資源規則';
			case 'settings.source.githubProxy': return 'GitHub 代理';
			case 'settings.source.githubProxyDesc': return '使用代理存取規則儲存庫';
			case 'settings.plugins.title': return '規則管理';
			case 'settings.plugins.empty': return '沒有可用的規則';
			case 'settings.plugins.tooltip.updateAll': return '全部更新';
			case 'settings.plugins.tooltip.addRule': return '新增規則';
			case 'settings.plugins.sort.title': return '排序方式';
			case 'settings.plugins.sort.tooltip': return '排序';
			case 'settings.plugins.sort.options.original': return '原始順序';
			case 'settings.plugins.sort.options.nameAsc': return '名稱（Ａ → ３）';
			case 'settings.plugins.sort.options.nameDesc': return '名稱（３ → Ａ）';
			case 'settings.plugins.sort.options.failureAsc': return '失敗次數（低 → 高）';
			case 'settings.plugins.sort.options.failureDesc': return '失敗次數（高 → 低）';
			case 'settings.plugins.multiSelect.selectedCount': return '已選擇 {count} 項';
			case 'settings.plugins.loading.updating': return '正在更新規則…';
			case 'settings.plugins.loading.updatingSingle': return '更新中…';
			case 'settings.plugins.loading.importing': return '導入中…';
			case 'settings.plugins.labels.version': return '版本：{version}';
			case 'settings.plugins.labels.statusUpdatable': return '可更新';
			case 'settings.plugins.labels.statusSearchValid': return '搜尋有效';
			case 'settings.plugins.actions.newRule': return '建立規則';
			case 'settings.plugins.actions.importFromRepo': return '從儲存庫匯入';
			case 'settings.plugins.actions.importFromClipboard': return '從剪貼簿匯入';
			case 'settings.plugins.actions.cancel': return '取消';
			case 'settings.plugins.actions.import': return '匯入';
			case 'settings.plugins.actions.update': return '更新';
			case 'settings.plugins.actions.edit': return '編輯';
			case 'settings.plugins.actions.copyToClipboard': return '複製到剪貼簿';
			case 'settings.plugins.actions.share': return '分享';
			case 'settings.plugins.actions.delete': return '刪除';
			case 'settings.plugins.dialogs.deleteTitle': return '刪除規則';
			case 'settings.plugins.dialogs.deleteMessage': return '確定要刪除選定的 {count} 個規則嗎？';
			case 'settings.plugins.dialogs.importTitle': return '匯入規則';
			case 'settings.plugins.dialogs.shareTitle': return '規則連結';
			case 'settings.plugins.toast.allUpToDate': return '所有規則都是最新的。';
			case 'settings.plugins.toast.updateCount': return '已更新 {count} 個規則。';
			case 'settings.plugins.toast.importSuccess': return '匯入成功。';
			case 'settings.plugins.toast.importFailed': return '匯入失敗：{error}';
			case 'settings.plugins.toast.repoMissing': return '儲存庫中沒有此規則。';
			case 'settings.plugins.toast.alreadyLatest': return '規則已經是最新的。';
			case 'settings.plugins.toast.updateSuccess': return '更新成功。';
			case 'settings.plugins.toast.updateIncompatible': return 'Haipee 版本過舊；此規則不相容。';
			case 'settings.plugins.toast.updateFailed': return '規則更新失敗。';
			case 'settings.plugins.toast.copySuccess': return '已複製到剪貼簿。';
			case 'settings.plugins.editor.title': return '編輯規則';
			case 'settings.plugins.editor.fields.name': return '規則名稱';
			case 'settings.plugins.editor.fields.version': return '版本';
			case 'settings.plugins.editor.fields.baseUrl': return '基礎 URL';
			case 'settings.plugins.editor.fields.searchUrl': return '搜尋 URL';
			case 'settings.plugins.editor.fields.searchList': return '搜尋列表 XPath';
			case 'settings.plugins.editor.fields.searchName': return '搜尋標題 XPath';
			case 'settings.plugins.editor.fields.searchResult': return '搜尋結果 XPath';
			case 'settings.plugins.editor.fields.chapterRoads': return '播放清單 XPath';
			case 'settings.plugins.editor.fields.chapterResult': return '播放清單結果 XPath';
			case 'settings.plugins.editor.fields.userAgent': return 'User-Agent';
			case 'settings.plugins.editor.fields.referer': return 'Referer';
			case 'settings.plugins.editor.advanced.title': return '進階選項';
			case 'settings.plugins.editor.advanced.legacyParser.title': return '啟用舊版解析器';
			case 'settings.plugins.editor.advanced.legacyParser.subtitle': return '使用舊版 XPath 解析器以保持相容性。';
			case 'settings.plugins.editor.advanced.httpPost.title': return '透過 POST 發送搜尋';
			case 'settings.plugins.editor.advanced.httpPost.subtitle': return '使用 HTTP POST 提交搜尋要求。';
			case 'settings.plugins.editor.advanced.nativePlayer.title': return '強制原生播放器';
			case 'settings.plugins.editor.advanced.nativePlayer.subtitle': return '啟動播放時優先使用內建播放器。';
			case 'settings.plugins.shop.title': return '規則儲存庫';
			case 'settings.plugins.shop.tooltip.sortByName': return '按名稱排序';
			case 'settings.plugins.shop.tooltip.sortByUpdate': return '按最後更新排序';
			case 'settings.plugins.shop.tooltip.refresh': return '重新整理規則列表';
			case 'settings.plugins.shop.labels.playerType.native': return '原生';
			case 'settings.plugins.shop.labels.playerType.webview': return '網頁檢視';
			case 'settings.plugins.shop.labels.lastUpdated': return '最後更新：{timestamp}';
			case 'settings.plugins.shop.buttons.install': return '新增';
			case 'settings.plugins.shop.buttons.installed': return '已新增';
			case 'settings.plugins.shop.buttons.update': return '更新';
			case 'settings.plugins.shop.buttons.toggleMirrorEnable': return '啟用鏡像';
			case 'settings.plugins.shop.buttons.toggleMirrorDisable': return '停用鏡像';
			case 'settings.plugins.shop.buttons.refresh': return '重新整理';
			case 'settings.plugins.shop.toast.importFailed': return '規則匯入失敗。';
			case 'settings.plugins.shop.error.unreachable': return '無法連線到儲存庫\n{status}';
			case 'settings.plugins.shop.error.mirrorEnabled': return '鏡像已啟用';
			case 'settings.plugins.shop.error.mirrorDisabled': return '鏡像已停用';
			case 'settings.metadata.title': return '資訊來源';
			case 'settings.metadata.enableBangumi': return '啟用 Bangumi 資訊來源';
			case 'settings.metadata.enableBangumiDesc': return '從 Bangumi 獲取動畫資訊';
			case 'settings.metadata.enableTmdb': return '啟用 TMDb 資訊來源';
			case 'settings.metadata.enableTmdbDesc': return '從 TMDb 補充多語言資料';
			case 'settings.metadata.preferredLanguage': return '偏好語言';
			case 'settings.metadata.preferredLanguageDesc': return '設定中繼資料同步的語言';
			case 'settings.metadata.followSystemLanguage': return '跟隨系統語言';
			case 'settings.metadata.simplifiedChinese': return '簡體中文（zh-CN）';
			case 'settings.metadata.traditionalChinese': return '繁體中文（zh-TW）';
			case 'settings.metadata.japanese': return '日語（ja-JP）';
			case 'settings.metadata.english': return '英語（en-US）';
			case 'settings.metadata.custom': return '自訂';
			case 'settings.player.title': return '播放器設定';
			case 'settings.player.playerSettings': return '播放器設定';
			case 'settings.player.playerSettingsDesc': return '設定播放器參數';
			case 'settings.player.hardwareDecoding': return '硬體解碼';
			case 'settings.player.hardwareDecoder': return '硬體解碼器';
			case 'settings.player.hardwareDecoderDesc': return '僅在硬體解碼啟用時生效';
			case 'settings.player.lowMemoryMode': return '低記憶體模式';
			case 'settings.player.lowMemoryModeDesc': return '停用進階快取以減少記憶體使用量';
			case 'settings.player.lowLatencyAudio': return '低延遲音訊';
			case 'settings.player.lowLatencyAudioDesc': return '啟用 OpenSLES 音訊輸出以降低延遲';
			case 'settings.player.superResolution': return '超解析度';
			case 'settings.player.autoJump': return '自動跳轉';
			case 'settings.player.autoJumpDesc': return '跳轉到上次播放位置';
			case 'settings.player.disableAnimations': return '停用過渡動畫';
			case 'settings.player.disableAnimationsDesc': return '停用播放器內的過渡動畫';
			case 'settings.player.errorPrompt': return '錯誤提示';
			case 'settings.player.errorPromptDesc': return '顯示播放器內部錯誤提示';
			case 'settings.player.debugMode': return '除錯模式';
			case 'settings.player.debugModeDesc': return '記錄播放器內部日誌';
			case 'settings.player.privateMode': return '私密模式';
			case 'settings.player.privateModeDesc': return '不保留觀看歷史';
			case 'settings.player.defaultPlaySpeed': return '預設播放速度';
			case 'settings.player.defaultVideoAspectRatio': return '預設影片比例';
			case 'settings.player.aspectRatio.auto': return '自動';
			case 'settings.player.aspectRatio.crop': return '裁切填充';
			case 'settings.player.aspectRatio.stretch': return '拉伸填充';
			case 'settings.player.danmakuSettings': return '彈幕設定';
			case 'settings.player.danmakuSettingsDesc': return '設定彈幕參數';
			case 'settings.player.danmaku': return '彈幕';
			case 'settings.player.danmakuDefaultOn': return '預設開啟';
			case 'settings.player.danmakuDefaultOnDesc': return '是否預設與影片一起播放彈幕';
			case 'settings.player.danmakuSource': return '彈幕來源';
			case 'settings.player.danmakuSources.bilibili': return 'Bilibili';
			case 'settings.player.danmakuSources.gamer': return 'Gamer';
			case 'settings.player.danmakuSources.dandan': return 'DanDan';
			case 'settings.player.danmakuCredentials': return '憑證';
			case 'settings.player.danmakuDanDanCredentials': return 'DanDan API 憑證';
			case 'settings.player.danmakuDanDanCredentialsDesc': return '自訂 DanDan 憑證';
			case 'settings.player.danmakuCredentialModeBuiltIn': return '內建';
			case 'settings.player.danmakuCredentialModeCustom': return '自訂';
			case 'settings.player.danmakuCredentialHint': return '留空使用內建憑證';
			case 'settings.player.danmakuCredentialNotConfigured': return '未設定';
			case 'settings.player.danmakuCredentialsSummary': return 'App ID: {appId}\nAPI Key: {apiKey}';
			case 'settings.player.danmakuShield': return '彈幕遮罩';
			case 'settings.player.danmakuKeywordShield': return '關鍵字遮罩';
			case 'settings.player.danmakuShieldInputHint': return '輸入關鍵字或正規表示式';
			case 'settings.player.danmakuShieldDescription': return '以「/」開頭和結尾的文字將視為正規表示式，例如「/\\d+/」遮罩所有數字';
			case 'settings.player.danmakuShieldCount': return '已新增 {count} 個關鍵字';
			case 'settings.player.danmakuStyle': return '彈幕樣式';
			case 'settings.player.danmakuDisplay': return '彈幕顯示';
			case 'settings.player.danmakuArea': return '彈幕區域';
			case 'settings.player.danmakuTopDisplay': return '頂部彈幕';
			case 'settings.player.danmakuBottomDisplay': return '底部彈幕';
			case 'settings.player.danmakuScrollDisplay': return '滾動彈幕';
			case 'settings.player.danmakuMassiveDisplay': return '大量彈幕';
			case 'settings.player.danmakuMassiveDescription': return '當螢幕擁擠時以重疊方式渲染';
			case 'settings.player.danmakuOutline': return '彈幕描邊';
			case 'settings.player.danmakuColor': return '彈幕顏色';
			case 'settings.player.danmakuFontSize': return '字體大小';
			case 'settings.player.danmakuFontWeight': return '字體粗細';
			case 'settings.player.danmakuOpacity': return '彈幕透明度';
			case 'settings.player.add': return '新增';
			case 'settings.player.save': return '儲存';
			case 'settings.player.restoreDefault': return '恢復預設';
			case 'settings.player.superResolutionTitle': return '超解析度';
			case 'settings.player.superResolutionHint': return '選擇預設的升級配置';
			case 'settings.player.superResolutionOptions.off.label': return '關閉';
			case 'settings.player.superResolutionOptions.off.description': return '停用所有升級增強功能。';
			case 'settings.player.superResolutionOptions.efficiency.label': return '平衡';
			case 'settings.player.superResolutionOptions.efficiency.description': return '平衡效能使用與畫質。';
			case 'settings.player.superResolutionOptions.quality.label': return '品質優先';
			case 'settings.player.superResolutionOptions.quality.description': return '最大化視覺品質，消耗更多資源。';
			case 'settings.player.superResolutionDefaultBehavior': return '預設行為';
			case 'settings.player.superResolutionClosePrompt': return '關閉提示';
			case 'settings.player.superResolutionClosePromptDesc': return '啟用超解析度時關閉提示';
			case 'settings.player.toast.danmakuKeywordEmpty': return '請輸入關鍵字。';
			case 'settings.player.toast.danmakuKeywordTooLong': return '關鍵字太長。';
			case 'settings.player.toast.danmakuKeywordExists': return '關鍵字已存在。';
			case 'settings.player.toast.danmakuCredentialsRestored': return '已恢復內建憑證。';
			case 'settings.player.toast.danmakuCredentialsUpdated': return '憑證已更新。';
			case 'settings.webdav.title': return 'WebDAV';
			case 'settings.webdav.desc': return '設定同步參數';
			case 'settings.webdav.pageTitle': return '同步設定';
			case 'settings.webdav.editor.title': return 'WebDAV 設定';
			case 'settings.webdav.editor.url': return '網址';
			case 'settings.webdav.editor.username': return '使用者名稱';
			case 'settings.webdav.editor.password': return '密碼';
			case 'settings.webdav.editor.toast.saveSuccess': return '設定已儲存。開始測試…';
			case 'settings.webdav.editor.toast.saveFailed': return '儲存設定失敗：{error}';
			case 'settings.webdav.editor.toast.testSuccess': return '測試成功。';
			case 'settings.webdav.editor.toast.testFailed': return '測試失敗：{error}';
			case 'settings.webdav.section.webdav': return 'WebDAV';
			case 'settings.webdav.tile.webdavToggle': return 'WebDAV 同步';
			case 'settings.webdav.tile.historyToggle': return '觀看歷史同步';
			case 'settings.webdav.tile.historyDescription': return '允許自動同步觀看歷史';
			case 'settings.webdav.tile.config': return 'WebDAV 設定';
			case 'settings.webdav.tile.manualUpload': return '手動上傳';
			case 'settings.webdav.tile.manualDownload': return '手動下載';
			case 'settings.webdav.info.upload': return '立即將您的觀看歷史上傳至 WebDAV。';
			case 'settings.webdav.info.download': return '立即將您的觀看歷史同步到此裝置。';
			case 'settings.webdav.toast.uploading': return '嘗試上傳至 WebDAV…';
			case 'settings.webdav.toast.downloading': return '嘗試從 WebDAV 同步…';
			case 'settings.webdav.toast.notConfigured': return 'WebDAV 同步已停用或設定無效。';
			case 'settings.webdav.toast.connectionFailed': return '連線到 WebDAV 失敗：{error}';
			case 'settings.webdav.toast.syncFailed': return 'WebDAV 同步失敗：{error}';
			case 'settings.webdav.result.initFailed': return 'WebDAV 初始化失敗：{error}';
			case 'settings.webdav.result.requireEnable': return '請先啟用 WebDAV 同步。';
			case 'settings.webdav.result.disabled': return 'WebDAV 同步已停用或設定無效。';
			case 'settings.webdav.result.connectionFailed': return '連線到 WebDAV 失敗。';
			case 'settings.webdav.result.syncSuccess': return '同步成功。';
			case 'settings.webdav.result.syncFailed': return '同步失敗：{error}';
			case 'settings.update.fallbackDescription': return '未提供發行說明。';
			case 'settings.update.error.invalidResponse': return '無效的更新回應。';
			case 'settings.update.dialog.title': return '有新的版本 {version} 可用';
			case 'settings.update.dialog.publishedAt': return '發布於 {date}';
			case 'settings.update.dialog.installationTypeLabel': return '選擇安裝套件';
			case 'settings.update.dialog.actions.disableAutoUpdate': return '停用自動更新';
			case 'settings.update.dialog.actions.remindLater': return '稍後提醒';
			case 'settings.update.dialog.actions.viewDetails': return '檢視詳情';
			case 'settings.update.dialog.actions.updateNow': return '立即更新';
			case 'settings.update.installationType.windowsMsix': return 'Windows 安裝程式 (MSIX)';
			case 'settings.update.installationType.windowsPortable': return 'Windows 攜帶版 (ZIP)';
			case 'settings.update.installationType.linuxDeb': return 'Linux 套件 (DEB)';
			case 'settings.update.installationType.linuxTar': return 'Linux 封存檔 (TAR.GZ)';
			case 'settings.update.installationType.macosDmg': return 'macOS 安裝程式 (DMG)';
			case 'settings.update.installationType.androidApk': return 'Android 套件 (APK)';
			case 'settings.update.installationType.ios': return 'iOS 應用程式（開啟 GitHub）';
			case 'settings.update.installationType.unknown': return '其他平台';
			case 'settings.update.toast.alreadyLatest': return '您已是最新版本。';
			case 'settings.update.toast.checkFailed': return '檢查更新失敗。請稍後再試。';
			case 'settings.update.toast.autoUpdateDisabled': return '自動更新已停用。';
			case 'settings.update.toast.downloadLinkMissing': return '沒有 {type} 的下載連結。';
			case 'settings.update.toast.downloadFailed': return '下載失敗：{error}';
			case 'settings.update.toast.noCompatibleLink': return '找不到相容的下載連結。';
			case 'settings.update.toast.prepareToInstall': return '正在準備安裝更新。應用程式將離開…';
			case 'settings.update.toast.openInstallerFailed': return '無法開啟安裝程式：{error}';
			case 'settings.update.toast.launchInstallerFailed': return '啟動安裝程式失敗：{error}';
			case 'settings.update.toast.revealFailed': return '無法開啟檔案管理器。';
			case 'settings.update.toast.unknownReason': return '未知原因';
			case 'settings.update.download.progressTitle': return '正在下載更新';
			case 'settings.update.download.cancel': return '取消';
			case 'settings.update.download.error.title': return '下載失敗';
			case 'settings.update.download.error.general': return '無法下載更新。';
			case 'settings.update.download.error.permission': return '權限不足，無法寫入檔案。';
			case 'settings.update.download.error.diskFull': return '磁碟空間不足。';
			case 'settings.update.download.error.network': return '網路連線失敗。';
			case 'settings.update.download.error.integrity': return '檔案完整性檢查失敗。請重試。';
			case 'settings.update.download.error.details': return '技術詳情：{error}';
			case 'settings.update.download.error.confirm': return '確定';
			case 'settings.update.download.error.retry': return '重試';
			case 'settings.update.download.complete.title': return '下載完成';
			case 'settings.update.download.complete.message': return '已下載 Haipee {version}。';
			case 'settings.update.download.complete.quitNotice': return '應用程式將在安裝期間離開。';
			case 'settings.update.download.complete.fileLocation': return '檔案儲存至';
			case 'settings.update.download.complete.buttons.later': return '稍後';
			case 'settings.update.download.complete.buttons.openFolder': return '開啟資料夾';
			case 'settings.update.download.complete.buttons.installNow': return '立即安裝';
			case 'settings.other.title': return '其他';
			case 'settings.other.about': return '關於';
			case 'settings.about.title': return '關於';
			case 'settings.about.sections.licenses.title': return '開源許可證';
			case 'settings.about.sections.licenses.description': return '查看所有開源許可證';
			case 'settings.about.sections.links.title': return '外部連結';
			case 'settings.about.sections.links.project': return '專案首頁';
			case 'settings.about.sections.links.repository': return '原始碼儲存庫';
			case 'settings.about.sections.links.icon': return '圖標設計';
			case 'settings.about.sections.links.index': return '動畫索引';
			case 'settings.about.sections.links.danmaku': return '彈幕提供者';
			case 'settings.about.sections.links.danmakuId': return 'ID：{id}';
			case 'settings.about.sections.cache.clearAction': return '清除快取';
			case 'settings.about.sections.cache.sizePending': return '計算中…';
			case 'settings.about.sections.cache.sizeLabel': return '{size} MB';
			case 'settings.about.sections.updates.title': return '應用程式更新';
			case 'settings.about.sections.updates.autoUpdate': return '自動更新';
			case 'settings.about.sections.updates.check': return '檢查更新';
			case 'settings.about.sections.updates.currentVersion': return '目前版本 {version}';
			case 'settings.about.logs.title': return '應用程式日誌';
			case 'settings.about.logs.empty': return '沒有可用的日誌條目。';
			case 'settings.about.logs.toast.cleared': return '日誌已清除。';
			case 'settings.about.logs.toast.clearFailed': return '清除日誌失敗。';
			case 'exitDialog.title': return '結束確認';
			case 'exitDialog.message': return '您想要結束 Haipee 嗎？';
			case 'exitDialog.dontAskAgain': return '下次不要再詢問';
			case 'exitDialog.exit': return '結束 Haipee';
			case 'exitDialog.minimize': return '最小化至系統匣';
			case 'exitDialog.cancel': return '取消';
			case 'tray.showWindow': return '顯示視窗';
			case 'tray.exit': return '結束 Haipee';
			case 'navigation.tabs.popular': return '熱門';
			case 'navigation.tabs.catalog': return '資源分類';
			case 'navigation.tabs.media': return '視頻直播';
			case 'navigation.tabs.resource': return '全網資源';
			case 'navigation.tabs.timeline': return '時間表';
			case 'navigation.tabs.my': return '媒體庫';
			case 'navigation.tabs.download': return '任務與下載';
			case 'navigation.tabs.settings': return '設定';
			case 'navigation.actions.search': return '搜尋';
			case 'navigation.actions.history': return '歷史紀錄';
			case 'navigation.actions.close': return '關閉';
			case 'dialogs.disclaimer.title': return '免責聲明';
			case 'dialogs.disclaimer.agree': return '已閱讀並同意';
			case 'dialogs.disclaimer.exit': return '結束';
			case 'dialogs.updateMirror.title': return '更新鏡像';
			case 'dialogs.updateMirror.question': return '您希望從哪裡取得應用程式更新？';
			case 'dialogs.updateMirror.description': return 'GitHub 鏡像適用於大多數情況。如果您使用 F-Droid 應用程式商店，請選擇 F-Droid 鏡像。';
			case 'dialogs.updateMirror.options.github': return 'GitHub';
			case 'dialogs.updateMirror.options.fdroid': return 'F-Droid';
			case 'dialogs.pluginUpdates.toast': return '偵測到 {count} 個規則可以更新';
			case 'dialogs.webdav.syncFailed': return '同步觀看紀錄失敗 {error}';
			case 'dialogs.about.licenseLegalese': return '開放原始碼授權';
			case 'dialogs.cache.title': return '快取管理';
			case 'dialogs.cache.message': return '快取包含番劇封面，清除後載入時需要重新下載，確認要清除快取嗎？';
			case 'library.common.emptyState': return '找不到內容';
			case 'library.common.retry': return '點擊重試';
			case 'library.common.backHint': return '再按一次以結束 Haipee';
			case 'library.common.toast.editMode': return '編輯模式已啟用。';
			case 'library.popular.title': return '熱門番組';
			case 'library.popular.allTag': return '全部';
			case 'library.popular.toast.backPress': return '再按一次以結束 Haipee';
			case 'library.timeline.weekdays.mon': return '一';
			case 'library.timeline.weekdays.tue': return '二';
			case 'library.timeline.weekdays.wed': return '三';
			case 'library.timeline.weekdays.thu': return '四';
			case 'library.timeline.weekdays.fri': return '五';
			case 'library.timeline.weekdays.sat': return '六';
			case 'library.timeline.weekdays.sun': return '日';
			case 'library.timeline.seasonPicker.title': return '時光機';
			case 'library.timeline.seasonPicker.yearLabel': return '{year}';
			case 'library.timeline.season.title': return '{season} {year}';
			case 'library.timeline.season.loading': return '載入中…';
			case 'library.timeline.season.names.winter': return '冬';
			case 'library.timeline.season.names.spring': return '春';
			case 'library.timeline.season.names.summer': return '夏';
			case 'library.timeline.season.names.autumn': return '秋';
			case 'library.timeline.season.short.winter': return '冬';
			case 'library.timeline.season.short.spring': return '春';
			case 'library.timeline.season.short.summer': return '夏';
			case 'library.timeline.season.short.autumn': return '秋';
			case 'library.timeline.sort.title': return '排序方式';
			case 'library.timeline.sort.byHeat': return '依人氣排序';
			case 'library.timeline.sort.byRating': return '依評分排序';
			case 'library.timeline.sort.byTime': return '依播出時間排序';
			case 'library.search.sort.label': return '搜尋排序';
			case 'library.search.sort.byHeat': return '依熱門度排序';
			case 'library.search.sort.byRating': return '依評分排序';
			case 'library.search.sort.byRelevance': return '依相關度排序';
			case 'library.search.noHistory': return '尚無搜尋紀錄';
			case 'library.history.title': return '觀看紀錄';
			case 'library.history.empty': return '尚無觀看紀錄';
			case 'library.history.chips.source': return '來源';
			case 'library.history.chips.progress': return '進度';
			case 'library.history.chips.episodeNumber': return '第 {number} 集';
			case 'library.history.toast.sourceMissing': return '找不到關聯的來源。';
			case 'library.history.manage.title': return '紀錄管理';
			case 'library.history.manage.confirmClear': return '要清除所有觀看紀錄嗎？';
			case 'library.history.manage.cancel': return '取消';
			case 'library.history.manage.confirm': return '確認';
			case 'library.info.summary.title': return '劇情簡介';
			case 'library.info.summary.expand': return '顯示更多';
			case 'library.info.summary.collapse': return '顯示較少';
			case 'library.info.tags.title': return '標籤';
			case 'library.info.tags.more': return '更多 +';
			case 'library.info.metadata.refresh': return '重新整理';
			case 'library.info.metadata.syncingTitle': return '同步中繼資料中…';
			case 'library.info.metadata.syncingSubtitle': return '首次同步可能需要幾秒鐘。';
			case 'library.info.metadata.emptyTitle': return '尚無官方中繼資料';
			case 'library.info.metadata.emptySubtitle': return '請稍後重試或檢查中繼資料設定。';
			case 'library.info.metadata.source': return ({required Object source}) => '中繼資料來源：${source}';
			case 'library.info.metadata.updated': return ({required Object timestamp, required Object language}) => '最後更新：${timestamp} · 語言：${language}';
			case 'library.info.metadata.languageSystem': return '系統預設';
			case 'library.info.metadata.multiSource': return '合併來源';
			case 'library.info.episodes.title': return '分集';
			case 'library.info.episodes.collapse': return '摺疊';
			case 'library.info.episodes.expand': return ({required Object count}) => '顯示全部（${count}）';
			case 'library.info.episodes.numberedEpisode': return ({required Object number}) => '第 ${number} 集';
			case 'library.info.episodes.dateUnknown': return '播出日期待定';
			case 'library.info.episodes.runtimeUnknown': return '片長未知';
			case 'library.info.episodes.runtimeMinutes': return ({required Object minutes}) => '${minutes} 分鐘';
			case 'library.info.errors.fetchFailed': return '載入失敗，請重試。';
			case 'library.info.tabs.overview': return '總覽';
			case 'library.info.tabs.comments': return '評論';
			case 'library.info.tabs.characters': return '角色';
			case 'library.info.tabs.reviews': return '心得';
			case 'library.info.tabs.staff': return '製作人員';
			case 'library.info.tabs.placeholder': return '即將推出';
			case 'library.info.actions.startWatching': return '開始觀看';
			case 'library.info.toast.characterSortFailed': return '排序角色失敗：{details}';
			case 'library.info.sourceSheet.title': return '選擇播放來源 ({name})';
			case 'library.info.sourceSheet.alias.deleteTooltip': return '刪除別名';
			case 'library.info.sourceSheet.alias.deleteTitle': return '刪除別名';
			case 'library.info.sourceSheet.alias.deleteMessage': return '此操作無法撤銷。確定要刪除此別名嗎？';
			case 'library.info.sourceSheet.toast.aliasEmpty': return '沒有可用的別名。請先手動新增後再搜尋。';
			case 'library.info.sourceSheet.toast.loadFailed': return '載入播放路線失敗。';
			case 'library.info.sourceSheet.toast.removed': return '已移除來源 {plugin}。';
			case 'library.info.sourceSheet.sort.title': return '排序方式';
			case 'library.info.sourceSheet.sort.tooltip': return '排序：{label}';
			case 'library.info.sourceSheet.sort.options.original': return '原始順序';
			case 'library.info.sourceSheet.sort.options.nameAsc': return '名稱（Ａ → ３）';
			case 'library.info.sourceSheet.sort.options.nameDesc': return '名稱（３ → Ａ）';
			case 'library.info.sourceSheet.sort.options.failureAsc': return '失敗次數（低 → 高）';
			case 'library.info.sourceSheet.sort.options.failureDesc': return '失敗次數（高 → 低）';
			case 'library.info.sourceSheet.card.title': return '來源 · {plugin}';
			case 'library.info.sourceSheet.card.play': return '播放';
			case 'library.info.sourceSheet.actions.searchAgain': return '重新搜尋';
			case 'library.info.sourceSheet.actions.aliasSearch': return '別名搜尋';
			case 'library.info.sourceSheet.actions.removeSource': return '移除來源';
			case 'library.info.sourceSheet.status.searching': return '{plugin} 搜尋中…';
			case 'library.info.sourceSheet.status.failed': return '{plugin} 搜尋失敗';
			case 'library.info.sourceSheet.status.empty': return '{plugin} 沒有回傳結果';
			case 'library.info.sourceSheet.empty.searching': return '搜尋中，請稍候…';
			case 'library.info.sourceSheet.empty.noResults': return '找不到播放來源。請嘗試重新搜尋或使用別名。';
			case 'library.info.sourceSheet.dialog.removeTitle': return '移除來源';
			case 'library.info.sourceSheet.dialog.removeMessage': return '移除來源 {plugin}？';
			case 'library.my.title': return '我的';
			case 'library.my.sections.video': return '影片';
			case 'library.my.favorites.title': return '收藏';
			case 'library.my.favorites.description': return '查看追看、計劃與已看完清單';
			case 'library.my.favorites.empty': return '尚無收藏項目。';
			case 'library.my.favorites.tabs.watching': return '觀看中';
			case 'library.my.favorites.tabs.planned': return '計劃觀看';
			case 'library.my.favorites.tabs.completed': return '已完成';
			case 'library.my.favorites.tabs.empty': return '尚無項目。';
			case 'library.my.favorites.sync.disabled': return 'WebDAV 同步已停用。';
			case 'library.my.favorites.sync.editing': return '編輯模式下無法同步。';
			case 'library.my.history.title': return '播放歷史';
			case 'library.my.history.description': return '查看您看過的節目';
			case 'playback.toast.screenshotProcessing': return '正在擷取螢幕截圖…';
			case 'playback.toast.screenshotSaved': return '螢幕截圖已儲存至相簿';
			case 'playback.toast.screenshotSaveFailed': return '儲存螢幕截圖失敗：{error}';
			case 'playback.toast.screenshotError': return '螢幕截圖失敗：{error}';
			case 'playback.toast.playlistEmpty': return '播放清單為空';
			case 'playback.toast.episodeLatest': return '已經是最新的集數';
			case 'playback.toast.loadingEpisode': return '正在載入 {identifier}';
			case 'playback.toast.danmakuUnsupported': return '此集數不支援發送彈幕';
			case 'playback.toast.danmakuEmpty': return '彈幕內容不能為空';
			case 'playback.toast.danmakuTooLong': return '彈幕內容過長';
			case 'playback.toast.waitForVideo': return '請等待影片載入完成';
			case 'playback.toast.enableDanmakuFirst': return '請先開啟彈幕';
			case 'playback.toast.danmakuSearchError': return '彈幕搜尋失敗：{error}';
			case 'playback.toast.danmakuSearchEmpty': return '找不到相符的結果';
			case 'playback.toast.danmakuSwitching': return '正在切換彈幕';
			case 'playback.toast.clipboardCopied': return '已複製到剪貼簿';
			case 'playback.toast.internalError': return '播放器內部錯誤：{details}';
			case 'playback.danmaku.inputHint': return '分享友善的彈幕';
			case 'playback.danmaku.inputDisabled': return '彈幕已關閉';
			case 'playback.danmaku.send': return '發送';
			case 'playback.danmaku.mobileButton': return '點擊發送彈幕';
			case 'playback.danmaku.mobileButtonDisabled': return '彈幕已停用';
			case 'playback.externalPlayer.launching': return '正在嘗試開啟外部播放器';
			case 'playback.externalPlayer.launchFailed': return '無法開啟外部播放器';
			case 'playback.externalPlayer.unavailable': return '外部播放器不可用';
			case 'playback.externalPlayer.unsupportedDevice': return '此裝置尚未支援';
			case 'playback.externalPlayer.unsupportedPlugin': return '此外掛程式尚未支援';
			case 'playback.controls.speed.title': return '播放速度';
			case 'playback.controls.speed.reset': return '預設速度';
			case 'playback.controls.skip.title': return '跳過時長';
			case 'playback.controls.skip.tooltip': return '長按變更時長';
			case 'playback.controls.status.fastForward': return '快進 {seconds} 秒';
			case 'playback.controls.status.rewind': return '快退 {seconds} 秒';
			case 'playback.controls.status.speed': return '倍速播放';
			case 'playback.controls.superResolution.label': return '超解析度';
			case 'playback.controls.superResolution.off': return '關閉';
			case 'playback.controls.superResolution.balanced': return '平衡';
			case 'playback.controls.superResolution.quality': return '品質';
			case 'playback.controls.speedMenu.label': return '速度';
			case 'playback.controls.aspectRatio.label': return '畫面比例';
			case 'playback.controls.aspectRatio.options.auto': return '自動';
			case 'playback.controls.aspectRatio.options.crop': return '裁切填充';
			case 'playback.controls.aspectRatio.options.stretch': return '拉伸填充';
			case 'playback.controls.tooltips.danmakuOn': return '關閉彈幕 (d)';
			case 'playback.controls.tooltips.danmakuOff': return '開啟彈幕 (d)';
			case 'playback.controls.menu.danmakuToggle': return '彈幕開關';
			case 'playback.controls.menu.videoInfo': return '影片資訊';
			case 'playback.controls.menu.cast': return '遠端投射';
			case 'playback.controls.menu.external': return '使用外部播放器開啟';
			case 'playback.controls.syncplay.label': return 'SyncPlay';
			case 'playback.controls.syncplay.room': return '目前房間：{name}';
			case 'playback.controls.syncplay.roomEmpty': return '未加入';
			case 'playback.controls.syncplay.latency': return '延遲：{ms} ms';
			case 'playback.controls.syncplay.join': return '加入房間';
			case 'playback.controls.syncplay.switchServer': return '切換伺服器';
			case 'playback.controls.syncplay.disconnect': return '中斷連線';
			case 'playback.loading.parsing': return '正在解析影片來源…';
			case 'playback.loading.parseFailed': return '影片來源解析失敗';
			case 'playback.loading.player': return '影片來源已解析，正在載入播放器';
			case 'playback.loading.danmakuSearch': return '搜尋彈幕中…';
			case 'playback.danmakuSearch.title': return '彈幕搜尋';
			case 'playback.danmakuSearch.hint': return '系列標題';
			case 'playback.danmakuSearch.submit': return '提交';
			case 'playback.remote.title': return '遠端投射';
			case 'playback.remote.toast.searching': return '搜尋中…';
			case 'playback.remote.toast.casting': return '嘗試投射到 {device}';
			case 'playback.remote.toast.error': return 'DLNA 錯誤：{details}\n嘗試重新開啟 DLNA 面板或選擇其他裝置。';
			case 'playback.debug.title': return '除錯資訊';
			case 'playback.debug.closeTooltip': return '關閉除錯資訊';
			case 'playback.debug.tabs.status': return '狀態';
			case 'playback.debug.tabs.logs': return '日誌';
			case 'playback.debug.sections.source': return '播放來源';
			case 'playback.debug.sections.playback': return '播放器狀態';
			case 'playback.debug.sections.timing': return '時間與指標';
			case 'playback.debug.sections.media': return '媒體軌';
			case 'playback.debug.labels.series': return '系列';
			case 'playback.debug.labels.plugin': return '外掛程式';
			case 'playback.debug.labels.route': return '路線';
			case 'playback.debug.labels.episode': return '集數';
			case 'playback.debug.labels.routeCount': return '路線數量';
			case 'playback.debug.labels.sourceTitle': return '來源標題';
			case 'playback.debug.labels.parsedUrl': return '解析的網址';
			case 'playback.debug.labels.playUrl': return '播放網址';
			case 'playback.debug.labels.danmakuId': return 'DanDan ID';
			case 'playback.debug.labels.syncRoom': return 'SyncPlay 房間';
			case 'playback.debug.labels.syncLatency': return 'SyncPlay RTT';
			case 'playback.debug.labels.nativePlayer': return '原生播放器';
			case 'playback.debug.labels.parsing': return '解析中';
			case 'playback.debug.labels.playerLoading': return '播放器載入中';
			case 'playback.debug.labels.playerInitializing': return '播放器初始化中';
			case 'playback.debug.labels.playing': return '播放中';
			case 'playback.debug.labels.buffering': return '緩衝中';
			case 'playback.debug.labels.completed': return '播放完成';
			case 'playback.debug.labels.bufferFlag': return '緩衝旗標';
			case 'playback.debug.labels.currentPosition': return '目前位置';
			case 'playback.debug.labels.bufferProgress': return '緩衝進度';
			case 'playback.debug.labels.duration': return '時長';
			case 'playback.debug.labels.speed': return '播放速度';
			case 'playback.debug.labels.volume': return '音量';
			case 'playback.debug.labels.brightness': return '亮度';
			case 'playback.debug.labels.resolution': return '解析度';
			case 'playback.debug.labels.aspectRatio': return '畫面比例';
			case 'playback.debug.labels.superResolution': return '超解析度';
			case 'playback.debug.labels.videoParams': return '影片參數';
			case 'playback.debug.labels.audioParams': return '音訊參數';
			case 'playback.debug.labels.playlist': return '播放清單';
			case 'playback.debug.labels.audioTracks': return '音訊軌';
			case 'playback.debug.labels.videoTracks': return '視訊軌';
			case 'playback.debug.labels.audioBitrate': return '音訊位元率';
			case 'playback.debug.values.yes': return '是';
			case 'playback.debug.values.no': return '否';
			case 'playback.debug.logs.playerEmpty': return '播放器日誌 (0)';
			case 'playback.debug.logs.playerSummary': return '播放器日誌（{count} 條，顯示 {displayed} 條）';
			case 'playback.debug.logs.webviewEmpty': return 'WebView 日誌 (0)';
			case 'playback.debug.logs.webviewSummary': return 'WebView 日誌（{count} 條，顯示 {displayed} 條）';
			case 'playback.syncplay.invalidEndpoint': return 'SyncPlay：無效的伺服器地址 {endpoint}';
			case 'playback.syncplay.disconnected': return 'SyncPlay：連線中斷 {reason}';
			case 'playback.syncplay.actionReconnect': return '重新連線';
			case 'playback.syncplay.alone': return 'SyncPlay：您是此房間的唯一使用者';
			case 'playback.syncplay.followUser': return 'SyncPlay：使用 {username} 的進度';
			case 'playback.syncplay.userLeft': return 'SyncPlay：{username} 離開了房間';
			case 'playback.syncplay.userJoined': return 'SyncPlay：{username} 加入了房間';
			case 'playback.syncplay.switchEpisode': return 'SyncPlay：{username} 切換到第 {episode} 集';
			case 'playback.syncplay.chat': return 'SyncPlay：{username} 說：{message}';
			case 'playback.syncplay.paused': return 'SyncPlay：{username} 暫停了播放';
			case 'playback.syncplay.resumed': return 'SyncPlay：{username} 恢復了播放';
			case 'playback.syncplay.unknownUser': return '未知';
			case 'playback.syncplay.switchServerBlocked': return 'SyncPlay：切換伺服器前請先離開目前房間';
			case 'playback.syncplay.defaultCustomEndpoint': return '自訂伺服器';
			case 'playback.syncplay.selectServer.title': return '選擇伺服器';
			case 'playback.syncplay.selectServer.customTitle': return '自訂伺服器';
			case 'playback.syncplay.selectServer.customHint': return '輸入伺服器網址';
			case 'playback.syncplay.selectServer.duplicateOrEmpty': return '伺服器網址必須是唯一的且不能為空';
			case 'playback.syncplay.join.title': return '加入房間';
			case 'playback.syncplay.join.roomLabel': return '房間 ID';
			case 'playback.syncplay.join.roomEmpty': return '輸入房間 ID';
			case 'playback.syncplay.join.roomInvalid': return '房間 ID 必須是 6 到 10 位數字';
			case 'playback.syncplay.join.usernameLabel': return '使用者名稱';
			case 'playback.syncplay.join.usernameEmpty': return '輸入使用者名稱';
			case 'playback.syncplay.join.usernameInvalid': return '使用者名稱必須是 4 到 12 個字母';
			case 'playback.playlist.collection': return '合集';
			case 'playback.playlist.list': return '播放清單 {index}';
			case 'playback.tabs.episodes': return '分集';
			case 'playback.tabs.comments': return '評論';
			case 'playback.comments.sectionTitle': return '集數標題';
			case 'playback.comments.manualSwitch': return '手動切換';
			case 'playback.comments.dialogTitle': return '輸入集數';
			case 'playback.comments.dialogEmpty': return '請輸入集數';
			case 'playback.comments.dialogConfirm': return '重新整理';
			case 'playback.superResolution.warning.title': return '效能警告';
			case 'playback.superResolution.warning.message': return '啟用超解析度（品質）可能會造成卡頓。是否繼續？';
			case 'playback.superResolution.warning.dontAskAgain': return '不要再詢問';
			case 'network.error.badCertificate': return '憑證錯誤。';
			case 'network.error.badResponse': return '伺服器錯誤，請稍後再試。';
			case 'network.error.cancel': return '請求已取消，請重試。';
			case 'network.error.connection': return '連線錯誤，請檢查網路設定。';
			case 'network.error.connectionTimeout': return '連線逾時，請檢查網路設定。';
			case 'network.error.receiveTimeout': return '接收回應逾時，請稍後再試。';
			case 'network.error.sendTimeout': return '傳送逾時，請檢查網路設定。';
			case 'network.error.unknown': return '{status} 網路問題。';
			case 'network.status.mobile': return '使用行動數據';
			case 'network.status.wifi': return '使用 Wi‑Fi';
			case 'network.status.ethernet': return '使用有線網路';
			case 'network.status.vpn': return '使用 VPN 連線';
			case 'network.status.other': return '使用其他網路';
			case 'network.status.none': return '無網路連線';
			default: return null;
		}
	}
}
