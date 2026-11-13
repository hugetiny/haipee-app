import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GeneralErrorWidget extends StatelessWidget {
  const GeneralErrorWidget({
    required this.errMsg,
    this.actions,
    super.key,
  });

  final String errMsg;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    ThemeData? theme;
    try {
      theme = Theme.of(context);
    } catch (_) {
      theme = null;
    }
    final textStyle = theme?.textTheme.titleSmall ??
        const TextStyle(
          fontSize: 14,
          color: Colors.redAccent,
        );

    return Center(
      child: SingleChildScrollView(
        physics: const ScrollPhysics.clamping(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: FractionallySizedBox(
                  widthFactor: 0.85,
                  child: SelectableText(
                    errMsg,
                    textAlign: TextAlign.center,
                    style: textStyle,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (actions != null) ...actions!,
                  GeneralErrorButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: errMsg));
                    },
                    text: '复制报错信息',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GeneralErrorButton extends StatelessWidget {
  const GeneralErrorButton({
    super.key,
    required this.onPressed,
    required this.text,
  });

  final Function() onPressed;
  final String text;

  @override
  Widget build(BuildContext context) {
    ThemeData? theme;
    try {
      theme = Theme.of(context);
    } catch (_) {
      theme = null;
    }
    final primary = theme?.colorScheme.primary ?? Colors.blue;

    return FilledButton.tonal(
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((_) {
          return primary.withAlpha(20);
        }),
      ),
      child: Text(
        text,
        style: TextStyle(color: primary),
      ),
    );
  }
}
