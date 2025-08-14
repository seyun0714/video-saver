// lib/ui/screens/browser_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:video_saver/models/download_record.dart';
import 'package:video_saver/services/download_service.dart';
import 'package:video_saver/services/settings_service.dart';
import 'package:video_saver/ui/widgets/browser_app_bar.dart'; // <-- Import 추가
import 'package:video_saver/ui/widgets/downloads_bar.dart';
import 'package:video_saver/ui/widgets/settings_sheet.dart';
import 'package:video_saver/utils/constants.dart';
import 'package:video_saver/utils/permissions.dart';
import 'package:background_downloader/background_downloader.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final TextEditingController _urlCtrl = TextEditingController(
    text: 'https://example.org',
  );
  InAppWebViewController? _webCtrl;
  double _progress = 0;

  final downloads = <DownloadRecord>[];
  final downloadService = DownloadService();
  final settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    ensurePermissions();
    _loadAndApplySettings();

    // 다운로드 서비스 콜백 등록
    downloadService.registerCallbacks(
      onStatusUpdate: (update) {
        if (!mounted) return;
        setState(() {
          final rec = downloads.firstWhere(
            (r) => r.task.taskId == update.task.taskId,
          );
          rec.status = update.status;
        });
      },
      onProgressUpdate: (update) {
        if (!mounted) return;
        setState(() {
          final rec = downloads.firstWhere(
            (r) => r.task.taskId == update.task.taskId,
          );
          rec.progress = update.progress;
        });
      },
      // 👇 이 부분의 task 타입을 수정합니다.
      onDownloadComplete: (Task task, String filePath) {
        // <-- 수정: DownloadTask -> Task
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('다운로드 완료: ${task.filename}'),
            action: SnackBarAction(
              label: '공유',
              onPressed: () =>
                  downloadService.shareFile(filePath, task.filename),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadAndApplySettings() async {
    await settingsService.loadSettings();
    setState(() {});
  }

  Future<void> _go() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final uri = url.startsWith('http') ? url : 'https://$url';
    await _webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(uri)));
  }

  Future<void> _enqueueDownload(String url) async {
    final host = Uri.parse(url).host.toLowerCase();
    if (!settingsService.isAllowedDomain(host)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('허용되지 않은 도메인입니다: $host')));
      }
      return;
    }

    final referer = await _webCtrl?.getUrl();
    final userAgent = (await _webCtrl?.getSettings())?.userAgent;

    final task = await downloadService.createDownloadTask(
      url: url,
      referer: referer?.toString(),
      userAgent: userAgent,
    );

    setState(() {
      downloads.add(DownloadRecord(task: task));
    });

    await downloadService.enqueue(task);
  }

  void _showQualitySheet(List<Map<String, dynamic>> sources) {
    if (!mounted) return;
    final selected =
        showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          builder: (ctx) {
            return SafeArea(
              child: ListView.separated(
                shrinkWrap: true,
                itemBuilder: (c, i) {
                  final s = sources[i];
                  final label = s['label'] ?? 'video';
                  final url = s['url'] ?? '';
                  return ListTile(
                    leading: const Icon(Icons.video_file),
                    title: Text(label),
                    subtitle: Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(c).pop(s),
                  );
                },
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: sources.length,
              ),
            );
          },
        ).then((selected) {
          if (selected != null) {
            final u = selected['url'] as String;
            if (u.toLowerCase().contains('.m3u8')) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('HLS(m3u8)는 MVP에서 직접 MP4 저장을 지원하지 않아요.'),
                ),
              );
              return;
            }
            _enqueueDownload(selected['url'] as String);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: true,
      child: Scaffold(
        // AppBar를 BrowserAppBar 위젯으로 교체
        appBar: BrowserAppBar(
          urlController: _urlCtrl,
          onGo: _go,
          onOpenSettings: () => showSettingsSheet(
            context: context,
            settingsService: settingsService,
            onSettingsSaved: _loadAndApplySettings,
          ),
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
                      if (args.isEmpty) return;
                      final payload = jsonDecode(args.first as String);
                      final List sources = payload['sources'] ?? [];
                      if (sources.isEmpty) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '다운로드 가능한 소스를 찾지 못했어요 (blob/DRM 제외).',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      _showQualitySheet(
                        sources
                            .map((e) => Map<String, dynamic>.from(e))
                            .toList(),
                      );
                    },
                  );
                },
                onLoadStop: (ctrl, url) async {
                  await ctrl.evaluateJavascript(source: videoObserverJS);
                },
                onLoadResource: (ctrl, res) async {
                  await ctrl.evaluateJavascript(source: videoObserverJS);
                },
                onProgressChanged: (ctrl, p) =>
                    setState(() => _progress = p / 100.0),
                initialUrlRequest: URLRequest(url: WebUri(_urlCtrl.text)),
              ),
            ),
            DownloadsBar(records: downloads),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          label: const Text('테스트 MP4'),
          icon: const Icon(Icons.download),
          onPressed: () async {
            const testUrl =
                'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
            await _enqueueDownload(testUrl);
          },
        ),
      ),
    );
  }
}
