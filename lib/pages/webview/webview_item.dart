import 'dart:io';
import 'package:flutter/material.dart';
import 'package:haipee/pages/video/video_controller.dart';
import 'package:haipee/pages/webview/webview_controller.dart';
import 'package:haipee/pages/webview/webview_controller_impel/webview_android_controller_impel.dart';
import 'package:haipee/pages/webview/webview_item_impel/webview_android_item_impel.dart';
import 'package:haipee/pages/webview/webview_item_impel/webview_item_impel.dart';
import 'package:haipee/pages/webview/webview_item_impel/webview_linux_item_impel.dart';
import 'package:haipee/pages/webview/webview_item_impel/webview_apple_item_impel.dart';
import 'package:haipee/utils/utils.dart';

class WebviewItem extends StatefulWidget {
  const WebviewItem({
    super.key,
    required this.videoPageController,
    required this.webviewController,
  });

  final VideoPageController videoPageController;
  final WebviewItemController webviewController;

  @override
  State<WebviewItem> createState() => _WebviewItemState();
}

class _WebviewItemState extends State<WebviewItem> {
  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows) {
      return const SizedBox.shrink();
    }
    if (Platform.isLinux) {
      return WebviewLinuxItemImpel(
        webviewController: widget.webviewController,
      );
    }
    if (Platform.isMacOS || Platform.isIOS) {
      return WebviewAppleItemImpel(
        webviewController: widget.webviewController,
      );
    }
    if (Platform.isAndroid && Utils.isDocumentStartScriptSupported) {
      return WebviewAndroidItemImpel(
        webviewController:
            widget.webviewController as WebviewAndroidItemControllerImpel,
      );
    }
    return WebviewItemImpel(
      webviewController: widget.webviewController,
    );
  }
}
