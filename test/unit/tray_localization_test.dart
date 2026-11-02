import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/utils/tray_localization.dart';

void main() {
  setUp(() {
    LocaleSettings.setLocale(AppLocale.zhCn);
  });

  test('returns English tray labels when locale is enUs', () {
    LocaleSettings.setLocale(AppLocale.enUs);

    final labels = HaipeeTrayLabels.current();

    expect(labels.showWindow, 'Show Window');
    expect(labels.exit, 'Exit haipee');
  });

  test('returns Simplified Chinese tray labels when locale is zhCn', () {
    LocaleSettings.setLocale(AppLocale.zhCn);

    final labels = HaipeeTrayLabels.current();

    expect(labels.showWindow, '显示窗口');
    expect(labels.exit, '退出 haipee');
  });
}
