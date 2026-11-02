import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:haipee/bean/widget/app_back_button.dart';
import 'package:haipee/bean/widget/desktop_window_controls_safe_area.dart';
import 'package:haipee/bean/widget/embedded_native_control_area.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/utils/utils.dart';
import 'package:window_manager/window_manager.dart';

class SysAppBar extends StatelessWidget implements PreferredSizeWidget {
  final double? toolbarHeight;

  final Widget? title;

  final Color? backgroundColor;

  final double? elevation;

  final ShapeBorder? shape;

  final List<Widget>? actions;

  final Widget? leading;

  final double? leadingWidth;

  final PreferredSizeWidget? bottom;

  final bool needTopOffset;

  const SysAppBar(
      {super.key,
      this.toolbarHeight,
      this.title,
      this.backgroundColor,
      this.elevation,
      this.shape,
      this.actions,
      this.leading,
      this.leadingWidth,
      this.bottom,
      this.needTopOffset = true});

  bool showWindowButton() {
    return GStorage.setting
        .get(SettingBoxKey.showWindowButton, defaultValue: false);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> acs = [];
    if (actions != null) {
      acs.addAll(actions!);
    }
    if ((Platform.isWindows || Platform.isLinux) && !showWindowButton()) {
      // acs.add(IconButton(onPressed: () => windowManager.minimize(), icon: const Icon(Icons.minimize)));
      acs.add(CloseButton(onPressed: () => windowManager.close()));
      acs.add(const SizedBox(width: 8));
    }
    Widget? effectiveLeading;
    if (leading != null) {
      effectiveLeading = leading;
    } else if (Navigator.canPop(context)) {
      effectiveLeading = const AppBackButton();
    }

    final bool requireLeadingOffset =
        needTopOffset || Navigator.canPop(context) || (effectiveLeading is AppBackButton);

    double? effectiveLeadingWidth = leadingWidth;
    if (effectiveLeading != null) {
      effectiveLeading = DesktopWindowControlsSafeArea.wrapLeading(
        effectiveLeading,
        requireOffset: requireLeadingOffset,
      );
      effectiveLeadingWidth = DesktopWindowControlsSafeArea.leadingWidth(
        leadingWidth,
        requireOffset: requireLeadingOffset,
      );
      effectiveLeading = EmbeddedNativeControlArea(
        requireOffset: needTopOffset,
        child: effectiveLeading!,
      );
    } else if (DesktopWindowControlsSafeArea.shouldAvoid(requireOffset: needTopOffset)) {
      // 当没有 leading 按钮（如一级页面且无左侧 NavigationRail 时）在 macOS 顶栏避让原生红黄绿三色视窗按钮
      effectiveLeading = const SizedBox(
        width: DesktopWindowControlsSafeArea.kMacOsTrafficLightsWidth,
      );
      effectiveLeadingWidth = DesktopWindowControlsSafeArea.leadingWidth(
        leadingWidth ?? 0.0,
        requireOffset: needTopOffset,
      );
    }

    Widget appBarWidget = GestureDetector(
      onPanStart: (_) =>
          (Utils.isDesktop()) ? windowManager.startDragging() : null,
      child: AppBar(
        toolbarHeight: preferredSize.height,
        scrolledUnderElevation: 0.0,
        title: title != null
            ? EmbeddedNativeControlArea(
                requireOffset: needTopOffset,
                child: title!,
              )
            : null,
        centerTitle: Platform.isIOS ? true : false,
        actions: acs.map((e) {
          return EmbeddedNativeControlArea(
            requireOffset: needTopOffset,
            child: e,
          );
        }).toList(),
        leading: effectiveLeading,
        leadingWidth: effectiveLeadingWidth,
        backgroundColor: backgroundColor,
        elevation: elevation,
        shape: shape,
        bottom: bottom,
        automaticallyImplyLeading: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              Theme.of(context).brightness == Brightness.light
                  ? Brightness.dark
                  : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      ),
    );

    if (Utils.isDesktop() && Navigator.canPop(context)) {
      appBarWidget = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            Navigator.maybePop(context);
          },
        },
        child: Focus(
          autofocus: true,
          child: appBarWidget,
        ),
      );
    }

    return appBarWidget;
  }

  @override
  Size get preferredSize {
    // Calculate base toolbar height
    double height;
    if (Platform.isMacOS && needTopOffset && showWindowButton()) {
      height = (toolbarHeight ?? kToolbarHeight) + 22;
    } else {
      height = toolbarHeight ?? kToolbarHeight;
    }

    // Add bottom widget height if present
    if (bottom != null) {
      height += bottom!.preferredSize.height;
    }

    return Size.fromHeight(height);
  }
}
