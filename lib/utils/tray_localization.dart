import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/providers/translations_provider.dart';

/// Immutable snapshot of tray labels for the current locale.
class TrayLabels {
  const TrayLabels({
    required this.showWindow,
    required this.exit,
    required this.tooltip,
  });

  final String showWindow;
  final String exit;
  final String tooltip;
}

/// Helper responsible for retrieving locale-aware tray strings without a BuildContext.
class HaipeeTrayLabels {
  const HaipeeTrayLabels._();

  /// Returns the tray labels for the active [LocaleSettings.currentLocale].
  static TrayLabels current() {
    final translations = LocaleSettings.currentLocale.translations;
    return _fromTranslations(translations);
  }

  /// Returns tray labels resolved through the shared [translationsProvider].
  static TrayLabels fromRef(WidgetRef ref) {
    final translations = ref.read(translationsProvider);
    return _fromTranslations(translations);
  }

  static TrayLabels _fromTranslations(AppTranslations translations) {
    return TrayLabels(
      showWindow: translations.tray.showWindow,
      exit: translations.tray.exit,
      tooltip: translations.app.title,
    );
  }
}
