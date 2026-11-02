import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/pages/webview/webview_controller.dart';

final webviewItemControllerProvider = Provider<WebviewItemController>((ref) {
  final controller = WebviewItemControllerFactory.getController();
  ref.onDispose(controller.dispose);
  return controller;
});
