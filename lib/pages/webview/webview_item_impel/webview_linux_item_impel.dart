import 'package:flutter/material.dart';
import 'package:haipee/pages/webview/webview_controller.dart';

class WebviewLinuxItemImpel extends StatefulWidget {
  const WebviewLinuxItemImpel({
    super.key,
    required this.webviewController,
  });

  final WebviewItemController webviewController;

  @override
  State<WebviewLinuxItemImpel> createState() => _WebviewLinuxItemImpelState();
}

class _WebviewLinuxItemImpelState extends State<WebviewLinuxItemImpel> {
  @override
  void initState() {
    super.initState();
    widget.webviewController.init();
  }

  @override
  void dispose() {
    widget.webviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        height: MediaQuery.of(context).size.width * 9.0 / (16.0),
        width: MediaQuery.of(context).size.width,
        color: Colors.black,
        child: const Center(child: Text('此平台不支持Webview规则')));
  }
}
