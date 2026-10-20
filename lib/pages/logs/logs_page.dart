import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/widget/app_back_button.dart';
import 'package:kazumi/bean/widget/desktop_window_controls_safe_area.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Full-featured interactive log screen powered by [TalkerScreen].
class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String title;
    try {
      title = context.t.settings.about.logs.title;
    } catch (_) {
      title = t.settings.about.logs.title;
    }
    final effectiveLeadingWidth =
        DesktopWindowControlsSafeArea.leadingWidth(48.0);
    return Theme(
      data: theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          leadingWidth: effectiveLeadingWidth,
        ),
      ),
      child: TalkerScreen(
        talker: KazumiLogger().talker,
        appBarTitle: title,
        appBarLeading: DesktopWindowControlsSafeArea.wrapLeading(
          AppBackButton(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                context.go(Routes.settings);
              }
            },
          ),
        ),
        theme: TalkerScreenTheme(
          backgroundColor: theme.scaffoldBackgroundColor,
          textColor: theme.colorScheme.onSurface,
          cardColor: theme.colorScheme.surfaceContainerHigh,
        ),
      ),
    );
  }
}
