import 'package:flutter/material.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Full-featured interactive log screen powered by [TalkerScreen].
class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TalkerScreen(
      talker: KazumiLogger().talker,
      appBarTitle: context.t.settings.about.logs.title,
      appBarLeading: Navigator.canPop(context)
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.maybePop(context),
            )
          : null,
      theme: TalkerScreenTheme(
        backgroundColor: theme.scaffoldBackgroundColor,
        textColor: theme.colorScheme.onSurface,
        cardColor: theme.colorScheme.surfaceContainerHigh,
      ),
    );
  }
}
