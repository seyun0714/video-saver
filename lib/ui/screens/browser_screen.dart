// lib/ui/screens/browser_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_saver/services/settings_service.dart';
import 'package:video_saver/ui/widgets/browser_app_bar.dart';
import 'package:video_saver/ui/widgets/settings_sheet.dart';
import 'package:video_saver/utils/constants.dart';
import 'package:video_saver/providers/download_provider.dart';
import 'package:video_saver/providers/settings_provider.dart';

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

  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    // initState에서는 ref.read를 사용하여 Provider의 초기 로직을 실행합니다.
    final downloadsNotifier = ref.read(asyncDownloadsProvider.notifier);
    // Provider가 초기화될 때 콜백이 등록되므로, 여기서 별도로 호출할 필요는 없습니다.
  }

  // 로직들을 State 클래스의 private 메소드로 분리
  void _go() {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final uri = url.startsWith('http') ? url : 'https://$url';
    _webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(uri)));
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

    await ref.read(asyncDownloadsProvider.notifier).enqueueDownload(task);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\'${task.filename}\' 다운로드를 시작합니다.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleVideoFound(
    List<dynamic> args, {
    required SettingsService settings,
  }) {
    if (args.isEmpty) return;
    final payload = jsonDecode(args.first as String);
    final List sources = payload['sources'] ?? [];

    if (!mounted) return;

    if (sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다운로드 가능한 소스를 찾지 못했어요 (blob/DRM 제외).')),
      );
      return;
    }
    _showQualitySheet(
      sources.map((e) => Map<String, dynamic>.from(e)).toList(),
      settings: settings,
    );
  }

  Future<void> _showQualitySheet(
    List<Map<String, dynamic>> sources, {
    required SettingsService settings,
  }) async {
    final selectedSource = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
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
                onTap: () => Navigator.of(c).pop(s),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
          ),
        );
      },
    );

    if (selectedSource != null) {
      final url = selectedSource['url'] as String?;
      if (url == null || url.isEmpty) return;

      if (url.toLowerCase().contains('.m3u8')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('HLS(m3u8)는 현재 지원하지 않아요.')),
          );
        }
        return;
      }
      _enqueueDownload(url, settings: settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    // build 메소드에서는 ref.watch를 사용하여 상태 변화를 감지하고 UI를 다시 빌드합니다.
    final downloads = ref.watch(asyncDownloadsProvider);
    final settingsServiceAsyncValue = ref.watch(settingsProvider);

    return SafeArea(
      top: false,
      bottom: true,
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
          onBack: () => _webCtrl?.goBack(),
          onForward: () => _webCtrl?.goForward(),
          onReload: () => _webCtrl?.reload(),
          canGoBack: _canGoBack,
          canGoForward: _canGoForward,
        ),
        body: Column(
          children: [
            Expanded(
              child: InAppWebView(
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                ),
                onPermissionRequest: (controller, request) async {
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                },
                onWebViewCreated: (ctrl) {
                  _webCtrl = ctrl;
                  ctrl.addJavaScriptHandler(
                    handlerName: 'onVideoFound',
                    callback: (args) {
                      // 👇 [수정] 콜백 함수가 호출될 때 provider의 최신 상태를 읽어옵니다.
                      final settings = ref.read(settingsProvider);
                      // settingsProvider가 데이터를 성공적으로 가져온 경우에만 로직을 실행합니다.
                      settings.whenData((service) {
                        _handleVideoFound(args, settings: service);
                      });
                    },
                  );
                },
                //...
                onLoadStop: (ctrl, url) async {
                  // --- 👇 [3단계] 페이지 로드 완료 시 버튼 상태 업데이트 ---
                  final back = await ctrl.canGoBack();
                  final forward = await ctrl.canGoForward();
                  setState(() {
                    _canGoBack = back;
                    _canGoForward = forward;
                  });
                  // --- 👆 [3단계] 페이지 로드 완료 시 버튼 상태 업데이트 ---
                  await ctrl.evaluateJavascript(source: videoObserverJS);
                },
                onLoadResource: (ctrl, res) {
                  // 이 콜백은 매우 자주 호출되므로 무거운 작업을 하지 않습니다.
                },
                onProgressChanged: (ctrl, p) {
                  setState(() {
                    _progress = p / 100.0;
                  });
                },
                initialUrlRequest: URLRequest(url: WebUri(_urlCtrl.text)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
