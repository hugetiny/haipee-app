import 'package:flutter/material.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// 商业级多端自适应模态弹窗 / 底部抽屉 (Haipee Adaptive Modal Sheet)
///
/// 基于 WoltModalSheet 打造：
/// - 移动端 (<600px)：优雅丝滑的底部抽屉 (Bottom Sheet)，支持手势拖拽关闭与吸顶标题栏
/// - 桌面端 / 平板 (>=600px)：居中自适应浮层弹窗 (Floating Centered Modal Dialog)
/// - 具备多步骤分页流转、粘性操作栏 (Sticky Action Bar) 与系统级无缝动效
class HaipeeModalSheet {
  HaipeeModalSheet._();

  /// 呼出自适应模态弹窗
  static Future<T?> show<T>({
    required BuildContext context,
    required List<WoltModalSheetPage> Function(BuildContext modalSheetContext)
        pageListBuilder,
    bool barrierDismissible = true,
    bool enableDrag = true,
    VoidCallback? onModalDismissedWithDrag,
  }) {
    return WoltModalSheet.show<T>(
      context: context,
      pageListBuilder: pageListBuilder,
      modalTypeBuilder: (ctx) {
        final width = MediaQuery.of(ctx).size.width;
        if (width < 600) {
          return WoltModalType.bottomSheet();
        } else {
          return WoltModalType.dialog();
        }
      },
      barrierDismissible: barrierDismissible,
      enableDrag: enableDrag,
      onModalDismissedWithDrag: onModalDismissedWithDrag,
    );
  }

  /// 构建统一质感的分页页面
  static WoltModalSheetPage buildPage({
    required BuildContext context,
    required Widget child,
    String? title,
    Widget? titleWidget,
    Widget? stickyActionBar,
    Widget? leadingNavBarWidget,
    Widget? trailingNavBarWidget,
    bool isTopBarLayerAlwaysVisible = true,
    Color? backgroundColor,
  }) {
    final theme = Theme.of(context);
    final topTitle = titleWidget ??
        (title != null
            ? Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              )
            : null);

    return WoltModalSheetPage(
      backgroundColor: backgroundColor ?? theme.colorScheme.surface,
      topBarTitle: topTitle,
      isTopBarLayerAlwaysVisible: isTopBarLayerAlwaysVisible,
      leadingNavBarWidget: leadingNavBarWidget,
      trailingNavBarWidget: trailingNavBarWidget ??
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
      stickyActionBar: stickyActionBar,
      child: child,
    );
  }

  /// 快捷呼出高质感单页弹窗
  static Future<T?> showSinglePage<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    Widget? stickyActionBar,
    bool barrierDismissible = true,
  }) {
    return show<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      pageListBuilder: (modalContext) => [
        buildPage(
          context: modalContext,
          title: title,
          stickyActionBar: stickyActionBar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: content,
          ),
        ),
      ],
    );
  }

  /// 商业级操作确认弹窗 (替代简陋原生 AlertDialog)
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = '确定',
    String cancelText = '取消',
    bool isDestructive = false,
    IconData? icon,
  }) {
    return show<bool>(
      context: context,
      pageListBuilder: (modalContext) {
        final theme = Theme.of(modalContext);
        final colorScheme = theme.colorScheme;
        final primaryActionColor =
            isDestructive ? colorScheme.error : colorScheme.primary;

        return [
          WoltModalSheetPage(
            backgroundColor: colorScheme.surface,
            topBarTitle: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            isTopBarLayerAlwaysVisible: true,
            trailingNavBarWidget: IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.of(modalContext).pop(false),
            ),
            stickyActionBar: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(modalContext).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(cancelText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(modalContext).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryActionColor,
                        foregroundColor: isDestructive
                            ? colorScheme.onError
                            : colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(confirmText),
                    ),
                  ),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isDestructive
                                ? colorScheme.error
                                : colorScheme.primary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: primaryActionColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      },
    );
  }
}
