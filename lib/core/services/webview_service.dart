// lib/core/services/webview_service.dart
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final webViewServiceProvider = Provider((ref) => WebViewService());

class WebViewService {
  InAppWebViewController? webViewController;
  PullToRefreshController? pullToRefreshController;

  Function(double)? onProgressChanged;
  String _javascriptToInject = '';

  void init(String javascriptToInject) {
    _javascriptToInject = javascriptToInject;
    pullToRefreshController = PullToRefreshController(
      onRefresh: () async {
        await webViewController?.reload();
      },
    );
  }

  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
  }

  Future<void> onLoadStop(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    pullToRefreshController?.endRefreshing();
    await controller.evaluateJavascript(source: _javascriptToInject);
  }

  void onProgress(InAppWebViewController controller, int progress) {
    final newProgress = progress / 100.0;
    onProgressChanged?.call(newProgress);
    if (newProgress == 1.0) {
      pullToRefreshController?.endRefreshing();
    }
  }

  Future<void> loadUrl(String url) async {
    await webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }
}
