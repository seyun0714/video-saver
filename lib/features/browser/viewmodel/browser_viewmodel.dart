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
    text: 'https://www.instagram.com',
  );
  late final WebViewService _webViewService;
  late final VideoFinderService _videoFinderService;

  double _progress = 0;
  double get progress => _progress;

  List<Map<String, dynamic>>? _sourcesToShow;
  List<Map<String, dynamic>>? get sourcesToShow => _sourcesToShow;

  // 영상 길이를 저장할 상태 변수 추가
  double? _durationToShow;
  double? get durationToShow => _durationToShow;

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

    // JS에서 데이터가 오면 ViewModel의 상태를 업데이트
    _videoFinderService.onVideoFound = (payload) {
      if (_isQualitySheetOpen) return;

      final List sources = payload['sources'] as List;
      final sourcesList = sources
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final duration = (payload['duration'] as num?)?.toDouble();

      if (sourcesList.isNotEmpty) {
        _setSourcesToShow(sourcesList, duration);
      }
    };
  }

  // sources와 duration을 함께 받아 상태를 업데이트하는 내부 메서드
  void _setSourcesToShow(List<Map<String, dynamic>> sources, double? duration) {
    _sourcesToShow = sources;
    _durationToShow = duration;
    notifyListeners();
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
    _durationToShow = null;
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
