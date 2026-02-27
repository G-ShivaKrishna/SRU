import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HtmlPreviewScreen extends StatefulWidget {
  final String htmlContent;

  const HtmlPreviewScreen({super.key, required this.htmlContent});

  @override
  State<HtmlPreviewScreen> createState() => _HtmlPreviewScreenState();
}

class _HtmlPreviewScreenState extends State<HtmlPreviewScreen> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(widget.htmlContent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Result Preview"),
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
