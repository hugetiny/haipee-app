import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/pages/setting/providers.dart';

/// Exposes the active [AppTranslations] instance for Riverpod listeners that
/// operate outside of widget build contexts.
final translationsProvider = Provider<AppTranslations>((ref) {
  final localeState = ref.watch(localeSettingsProvider);
  return localeState.appLocale.translations;
});
