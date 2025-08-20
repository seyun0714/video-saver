// lib/features/browser/viewmodel/browser_viewmodel.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_saver/core/services/webview_service.dart';
import 'package:video_saver/features/browser/services/video_finder_service.dart';
import 'package:video_saver/features/downloads/provider/download_provider.dart';

final browserViewModelProvider = ChangeNotifierProvider.autoDispose(
  (ref) => BrowserViewModel(ref),
);

class BrowserViewModel extends ChangeNotifier {
  final Ref _ref;
  final TextEditingController urlController = TextEditingController(
    text: 'https://www.pexels.com/videos/',
  );
  late final WebViewService _webViewService;
  late final VideoFinderService _videoFinderService;

  double _progress = 0;
  double get progress => _progress;

  List<Map<String, dynamic>>? _sourcesToShow;
  List<Map<String, dynamic>>? get sourcesToShow => _sourcesToShow;

  bool _isQualitySheetOpen = false;

  InAppWebViewController? get webViewController =>
      _webViewService.webViewController;
  PullToRefreshController? get pullToRefreshController =>
      _webViewService.pullToRefreshController;

  BrowserViewModel(this._ref) {
    _videoFinderService = _ref.read(videoFinderServiceProvider);
    _webViewService = _ref.read(webViewServiceProvider);

    _webViewService.onProgressChanged = (progress) {
      _progress = progress;
      notifyListeners();
    };

    _videoFinderService.onVideoFound = (sources) {
      if (_isQualitySheetOpen || sources.isEmpty) return;
      _sourcesToShow = sources;
      notifyListeners();
    };

    _webViewService.init(_videoFinderService.javascriptToInject);
  }

  void go(BuildContext context) {
    String url = urlController.text.trim();
    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);

    if (uri != null && uri.hasScheme && uri.hasAuthority) {
      _webViewService.loadUrl(url);
    } else {
      final searchQuery = Uri.encodeComponent(url);
      _webViewService.loadUrl('https://www.google.com/search?q=$searchQuery');
    }
    FocusScope.of(context).unfocus();
  }

  Future<void> enqueueDownload(BuildContext context, String url) async {
    final referer = await webViewController?.getUrl();
    final userAgent = (await webViewController?.getSettings())?.userAgent;
    final downloadService = _ref.read(downloadServiceProvider);

    final task = await downloadService.createDownloadTask(
      url: url,
      referer: referer?.toString(),
      userAgent: userAgent,
    );

    await _ref.read(asyncDownloadsProvider.notifier).enqueueDownload(task);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\'${task.filename}\' 다운로드를 시작합니다.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void clearSourcesToShow() {
    _sourcesToShow = null;
  }

  void setQualitySheetOpen(bool isOpen) {
    _isQualitySheetOpen = isOpen;
  }

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }
}
