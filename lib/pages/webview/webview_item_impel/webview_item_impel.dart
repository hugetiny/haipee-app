import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/providers/riverpod_compat.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:haipee/pages/webview/webview_controller.dart';

/// Provider for webview initialization state
final webviewInitializedProvider = StateProvider.autoDispose<int>((ref) => 0);

class WebviewItemImpel extends ConsumerStatefulWidget {
  const WebviewItemImpel({
    super.key,
    required this.webviewController,
  });

  final WebviewItemController webviewController;

  @override
  ConsumerState<WebviewItemImpel> createState() => _WebviewItemImpelState();
}

class _WebviewItemImpelState extends ConsumerState<WebviewItemImpel> {
  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    widget.webviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider to trigger rebuild when webview is initialized
    ref.watch(webviewInitializedProvider);
    return compositeView;
  }

  Future<void> initPlatformState() async {
    // 初始化Webview
    if (widget.webviewController.webviewController == null) {
      await widget.webviewController.init();
    }
    if (!mounted) return;
    ref.read(webviewInitializedProvider.notifier).state++;
  }

  Widget get compositeView {
    if (widget.webviewController.webviewController == null) {
      return const Text(
        'Not Initialized',
        style: TextStyle(
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return WebViewWidget(
          controller: widget.webviewController.webviewController);
    }
  }
}
