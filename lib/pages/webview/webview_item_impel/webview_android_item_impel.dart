import 'package:flutter/material.dart';
import 'package:haipee/pages/webview/webview_controller_impel/webview_android_controller_impel.dart';

class WebviewAndroidItemImpel extends StatefulWidget {
  const WebviewAndroidItemImpel({
    super.key,
    required this.webviewController,
  });

  final WebviewAndroidItemControllerImpel webviewController;

  @override
  State<WebviewAndroidItemImpel> createState() =>
      _WebviewAndroidItemImpelState();
}

class _WebviewAndroidItemImpelState extends State<WebviewAndroidItemImpel> {
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
        child: const Center(
            child: Text('此平台不支持Webview规则',
                style: TextStyle(color: Colors.white))));
  }
}
