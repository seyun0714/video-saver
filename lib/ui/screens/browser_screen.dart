// lib/ui/screens/browser_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_downloader/background_downloader.dart'; // Task 타입을 위해 import
import 'package:video_saver/models/download_record.dart';
import 'package:video_saver/services/download_service.dart';
import 'package:video_saver/services/settings_service.dart';
import 'package:video_saver/ui/widgets/browser_app_bar.dart';
import 'package:video_saver/ui/widgets/downloads_bar.dart';
import 'package:video_saver/ui/widgets/settings_sheet.dart';
import 'package:video_saver/utils/constants.dart';
import 'package:video_saver/utils/permissions.dart';
import 'package:video_saver/providers/download_provider.dart';
import 'package:video_saver/providers/settings_provider.dart';

class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key});

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  final TextEditingController _urlCtrl = TextEditingController(
    text: 'https://example.org',
  );
  InAppWebViewController? _webCtrl;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    // initState에서는 ref.read를 사용하여 Provider의 초기 로직을 실행합니다.
    final downloadsNotifier = ref.read(downloadsProvider.notifier);
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
    final host = Uri.parse(url).host.toLowerCase();
    if (!settings.isAllowedDomain(host)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('허용되지 않은 도메인입니다: $host')));
      }
      return;
    }
    final referer = await _webCtrl?.getUrl();
    final userAgent = (await _webCtrl?.getSettings())?.userAgent;

    final downloadService = ref.read(downloadServiceProvider);
    final task = await downloadService.createDownloadTask(
      url: url,
      referer: referer?.toString(),
      userAgent: userAgent,
    );

    // downloadsProvider의 Notifier를 통해 상태 변경
    await ref.read(downloadsProvider.notifier).enqueueDownload(task);
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
    final downloads = ref.watch(downloadsProvider);
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
        ),
        body: Column(
          children: [
            Expanded(
              child: InAppWebView(
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  useOnLoadResource: true,
                ),
                onWebViewCreated: (ctrl) {
                  _webCtrl = ctrl;
                  ctrl.addJavaScriptHandler(
                    handlerName: 'onVideoFound',
                    callback: (args) {
                      // settingsProvider가 로드되었는지 확인 후 로직 실행
                      settingsServiceAsyncValue.whenData((settings) {
                        _handleVideoFound(args, settings: settings);
                      });
                    },
                  );
                },
                onLoadStop: (ctrl, url) async {
                  await ctrl.evaluateJavascript(source: videoObserverJS);
                },
                onLoadResource: (ctrl, res) async {
                  await ctrl.evaluateJavascript(source: videoObserverJS);
                },
                onProgressChanged: (ctrl, p) {
                  setState(() {
                    _progress = p / 100.0;
                  });
                },
                initialUrlRequest: URLRequest(url: WebUri(_urlCtrl.text)),
              ),
            ),
            DownloadsBar(records: downloads),
          ],
        ),
        floatingActionButton: settingsServiceAsyncValue.when(
          data: (settings) => FloatingActionButton.extended(
            label: const Text('테스트 MP4'),
            icon: const Icon(Icons.download),
            onPressed: () {
              const testUrl =
                  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
              _enqueueDownload(testUrl, settings: settings);
            },
          ),
          loading: () => const CircularProgressIndicator(),
          error: (e, s) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
