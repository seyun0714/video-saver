// lib/ui/screens/browser_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_saver/providers/settings_provider.dart';
import 'package:video_saver/services/settings_service.dart';
import 'package:video_saver/ui/widgets/browser_app_bar.dart';
import 'package:video_saver/ui/widgets/settings_sheet.dart';
import 'package:video_saver/utils/constants.dart';
import 'package:video_saver/providers/download_provider.dart';

class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key});

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  final TextEditingController _urlCtrl = TextEditingController(
    text: 'https://www.pexels.com/videos/',
  );
  InAppWebViewController? _webCtrl;
  double _progress = 0;

  PullToRefreshController? _pullToRefreshCtrl;
  DateTime? _backButtonPressTime;

  bool _isQualitySheetOpen = false;
  String? _lastSourcesSig; // 같은 소스 반복 방지용(선택)

  @override
  void initState() {
    super.initState();
    _pullToRefreshCtrl = PullToRefreshController(
      settings: PullToRefreshSettings(color: Colors.blue),
      onRefresh: () async {
        if (await _webCtrl?.getUrl() != null) {
          _webCtrl?.reload();
        }
      },
    );
  }

  bool _isValidUrl(String url) {
    // 간단한 URL 패턴 검사 (공백이 없고, '.'이 포함되며, http/https로 시작하거나 일반적인 도메인 형태)
    final urlPattern =
        r'(^https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$';
    final urlRegex = RegExp(urlPattern, caseSensitive: false);
    return urlRegex.hasMatch(url);
  }

  // --- 👇 다운로드 로직 섹션  ---
  Future<void> _go() async {
    String url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    // URL 유효성 검사
    if (_isValidUrl(url)) {
      // http/https스가 없으면 붙여줌
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }
    } else {
      // 유효한 URL이 아니면 검색어로 처리
      final searchQuery = Uri.encodeComponent(url);
      url = 'https://www.google.com/search?q=$searchQuery';
    }

    _webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    FocusScope.of(context).unfocus(); // 검색 시 포커스 해제
  }

  Future<void> _enqueueDownload(
    String url, {
    required SettingsService settings,
  }) async {
    final referer = await _webCtrl?.getUrl();
    final userAgent = (await _webCtrl?.getSettings())?.userAgent;
    final downloadService = ref.read(downloadServiceProvider);
    final task = await downloadService.createDownloadTask(
      url: url,
      referer: referer?.toString(),
      userAgent: userAgent,
    );
    // [중요] 수정된 프로바이더를 올바르게 호출합니다.
    await ref.read(asyncDownloadsProvider.notifier).enqueueDownload(task);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\'${task.filename}\' 다운로드를 시작합니다.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    await _webCtrl?.evaluateJavascript(
      source:
          "try{document.querySelectorAll('.video-saver-btn').forEach(b=>b.dataset.vsBusy='0')}catch(e){}",
    );
  }

  void _handleVideoFoundPayload(
    Map payload, {
    required SettingsService settings,
  }) {
    if (_isQualitySheetOpen) return; // ★ 이미 시트가 떠 있으면 무시
    final List sources = (payload['sources'] as List?) ?? const [];
    if (!mounted) return;
    if (sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다운로드 가능한 소스를 찾지 못했어요 (blob/DRM 제외).')),
      );
      return;
    }

    // (선택) 같은 소스 반복 방지 — sources의 URL만으로 시그니처 생성
    final sig = sources.map((e) => (e as Map)['url'] ?? '').join('|');
    if (_lastSourcesSig == sig) {
      // 직전과 동일 페이로드면 무시(필요 시 주석 처리)
      // return;
    }
    _lastSourcesSig = sig;

    _isQualitySheetOpen = true;
    _showQualitySheet(
      sources.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      settings: settings,
    ).whenComplete(() {
      _isQualitySheetOpen = false; // ★ 닫힐 때 플래그 해제
    });
  }

  Future<void> _showQualitySheet(
    List<Map<String, dynamic>> sources, {
    required SettingsService settings,
  }) async {
    // 👇 [수정] BottomSheet의 context를 사용하기 위해 builder 밖에서 선언
    final BuildContext currentContext = context;

    final selectedSource = await showModalBottomSheet<Map<String, dynamic>>(
      context: currentContext, // 미리 저장해둔 context 사용
      builder: (ctx) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: sources.length,
            itemBuilder: (c, i) {
              final s = sources[i];
              final label = s['label'] ?? 'video';
              final url = s['url'] ?? '';
              return ListTile(
                leading: const Icon(Icons.video_file_outlined),
                title: Text('화질: $label'),
                subtitle: Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // 👇 [수정] Navigator를 호출하기 전에 mounted를 확인합니다.
                onTap: () {
                  // c.mounted 대신 더 넓은 범위의 currentContext.mounted를 확인하는 것이 안전합니다.
                  if (!currentContext.mounted) return;
                  Navigator.of(c).pop(s);
                },
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
          ),
        );
      },
    );

    // 👇 [중요] await 이후의 로직에서도 mounted를 확인해줍니다.
    if (selectedSource != null) {
      final url = selectedSource['url'] as String?;
      if (url == null || url.isEmpty) return;

      if (url.toLowerCase().contains('.m3u8')) {
        // [수정] 여기에서도 mounted 확인
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('HLS(m3u8)는 현재 지원하지 않아요.')),
        );
        return;
      }
      _enqueueDownload(url, settings: settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsServiceAsyncValue = ref.watch(settingsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final canGoBack = await _webCtrl?.canGoBack() ?? false;
        if (canGoBack) {
          _webCtrl?.goBack();
        } else {
          final now = DateTime.now();
          final withinTwoSeconds =
              _backButtonPressTime != null &&
              now.difference(_backButtonPressTime!) <
                  const Duration(seconds: 2);
          if (withinTwoSeconds) {
            SystemNavigator.pop();
          } else {
            _backButtonPressTime = now;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('한 번 더 누르면 종료됩니다.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: SafeArea(
        top: true,
        bottom: false,
        child: Scaffold(
          appBar: BrowserAppBar(
            urlController: _urlCtrl,
            onGo: _go,
            onOpenSettings: () {
              settingsServiceAsyncValue.whenData((service) {
                showSettingsSheet(
                  context: context,
                  settingsService: service,
                  onSettingsSaved: () => ref.refresh(settingsProvider),
                );
              });
            },
            progress: _progress,
          ),
          body: InAppWebView(
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
            ),
            pullToRefreshController: _pullToRefreshCtrl,
            onWebViewCreated: (ctrl) {
              _webCtrl = ctrl;
              ctrl.addJavaScriptHandler(
                handlerName: 'onVideoFound',
                callback: (args) {
                  final settings = ref.read(settingsProvider);
                  // settingsProvider가 데이터를 성공적으로 가져온 경우에만 로직을 실행합니다.
                  settings.whenData((service) {
                    if (args.isEmpty) return;
                    final payload = jsonDecode(args.first as String);
                    if (payload is! Map) return;
                    // ★ 버튼을 눌러 발생한 이벤트만 허용
                    if (payload['reason'] != 'btn') return;
                    _handleVideoFoundPayload(payload, settings: service);
                  });
                },
              );
              ctrl.addJavaScriptHandler(
                handlerName: 'onWebViewTapped',
                callback: (args) {
                  // 키보드와 입력창 포커스를 모두 해제합니다.
                  FocusScope.of(context).unfocus();
                },
              );
            },
            onLoadStop: (ctrl, url) async {
              _pullToRefreshCtrl?.endRefreshing();
              await ctrl.evaluateJavascript(source: videoObserverJS);
            },
            onProgressChanged: (ctrl, p) {
              setState(() {
                _progress = p / 100.0;
              });
              if (p == 100) {
                _pullToRefreshCtrl?.endRefreshing();
              }
            },
            initialUrlRequest: URLRequest(url: WebUri(_urlCtrl.text)),
          ),
        ),
      ),
    );
  }
}
