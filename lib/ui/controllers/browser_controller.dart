// lib/ui/controllers/browser_controller.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_saver/providers/download_provider.dart';
import 'package:video_saver/providers/settings_provider.dart';
import 'package:video_saver/services/settings_service.dart';
import 'package:video_saver/utils/constants.dart';

final browserControllerProvider = ChangeNotifierProvider((ref) {
  return BrowserController(ref);
});

class BrowserController extends ChangeNotifier {
  final Ref _ref;
  BrowserController(this._ref);

  InAppWebViewController? webCtrl;
  PullToRefreshController? pullToRefreshCtrl;
  final TextEditingController urlCtrl = TextEditingController(
    text: 'https://www.pexels.com/videos/',
  );

  double _progress = 0;
  double get progress => _progress;

  // UI에 BottomSheet을 표시해야 함을 알리는 상태
  List<Map<String, dynamic>>? _sourcesToShow;
  List<Map<String, dynamic>>? get sourcesToShow => _sourcesToShow;

  bool _isQualitySheetOpen = false;
  String? _lastSourcesSig;

  void initPullToRefresh() {
    pullToRefreshCtrl = PullToRefreshController(
      settings: PullToRefreshSettings(color: Colors.blue),
      onRefresh: () async {
        if (await webCtrl?.getUrl() != null) {
          webCtrl?.reload();
        }
      },
    );
  }

  void onWebViewCreated(InAppWebViewController controller) {
    webCtrl = controller;
    _addJavaScriptHandlers();
  }

  void _addJavaScriptHandlers() {
    webCtrl?.addJavaScriptHandler(
      handlerName: 'onVideoFound',
      callback: (args) {
        final settings = _ref.read(settingsProvider);
        settings.whenData((service) {
          if (args.isEmpty) return;
          final payload = jsonDecode(args.first as String);
          if (payload is! Map) return;
          if (payload['reason'] != 'btn') return;
          _handleVideoFoundPayload(payload);
        });
      },
    );
  }

  Future<void> onLoadStop(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    pullToRefreshCtrl?.endRefreshing();
    await controller.evaluateJavascript(source: videoObserverJS);
  }

  void onProgressChanged(InAppWebViewController controller, int progress) {
    _progress = progress / 100.0;
    if (_progress == 1.0) {
      pullToRefreshCtrl?.endRefreshing();
    }
    notifyListeners();
  }

  bool _isValidUrl(String url) {
    final urlPattern =
        r'(^https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$';
    final urlRegex = RegExp(urlPattern, caseSensitive: false);
    return urlRegex.hasMatch(url);
  }

  Future<void> go(BuildContext context) async {
    String url = urlCtrl.text.trim();
    if (url.isEmpty) return;

    if (_isValidUrl(url)) {
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }
    } else {
      final searchQuery = Uri.encodeComponent(url);
      url = 'https://www.google.com/search?q=$searchQuery';
    }

    webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    FocusScope.of(context).unfocus();
  }

  Future<void> enqueueDownload({
    required BuildContext context,
    required String url,
    required SettingsService settings,
  }) async {
    final referer = await webCtrl?.getUrl();
    final userAgent = (await webCtrl?.getSettings())?.userAgent;
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
    await webCtrl?.evaluateJavascript(
      source:
          "try{document.querySelectorAll('.video-saver-btn').forEach(b=>b.dataset.vsBusy='0')}catch(e){}",
    );
  }

  void _handleVideoFoundPayload(Map payload) {
    if (_isQualitySheetOpen) return;
    final List sources = (payload['sources'] as List?) ?? const [];
    if (sources.isEmpty) return;

    final sig = sources.map((e) => (e as Map)['url'] ?? '').join('|');
    if (_lastSourcesSig == sig) {
      // return;
    }
    _lastSourcesSig = sig;

    // 상태를 업데이트하고 UI에 알림
    _sourcesToShow = sources
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    notifyListeners();
  }

  // UI가 BottomSheet을 띄운 후 호출하여 상태를 초기화
  void clearSourcesToShow() {
    _sourcesToShow = null;
    // notifyListeners() 호출은 필요 없음 (UI가 다시 반응할 필요 X)
  }

  // BottomSheet 열림/닫힘 상태를 UI로부터 전달받음
  void setQualitySheetOpen(bool isOpen) {
    _isQualitySheetOpen = isOpen;
  }

  @override
  void dispose() {
    urlCtrl.dispose();
    super.dispose();
  }
}
