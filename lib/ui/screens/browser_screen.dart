// lib/ui/screens/browser_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:background_downloader/background_downloader.dart'; // Task 타입을 위해 import
import 'package:video_saver/models/download_record.dart';
import 'package:video_saver/services/download_service.dart';
import 'package:video_saver/services/settings_service.dart';
import 'package:video_saver/ui/widgets/browser_app_bar.dart';
import 'package:video_saver/ui/widgets/downloads_bar.dart';
import 'package:video_saver/ui/widgets/settings_sheet.dart';
import 'package:video_saver/utils/constants.dart';
import 'package:video_saver/utils/permissions.dart';

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

    downloadService.registerCallbacks(
      onStatusUpdate: (update) {
        if (!mounted) return;
        // orElse를 사용하지 않고, 해당 task가 리스트에 반드시 존재한다고 가정합니다.
        try {
          final rec = downloads.firstWhere(
            (r) => r.task.taskId == update.task.taskId,
          );
          setState(() => rec.status = update.status);
        } catch (e) {
          // print('Status update for unknown task: ${update.task.taskId}');
        }
      },
      onProgressUpdate: (update) {
        if (!mounted) return;
        try {
          final rec = downloads.firstWhere(
            (r) => r.task.taskId == update.task.taskId,
          );
          setState(() => rec.progress = update.progress);
        } catch (e) {
          // print('Progress update for unknown task: ${update.task.taskId}');
        }
      },
      // 👇 이전 지적해주신 대로 `DownloadTask`가 아닌 `Task` 타입을 받도록 수정했습니다.
      onDownloadComplete: (Task task, String filePath) {
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
    if (mounted) setState(() {});
  }

  Future<void> _go() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final uri = url.startsWith('http') ? url : 'https://$url';
    await _webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(uri)));
  }

  /// JavaScript에서 동영상 정보를 받았을 때 호출되는 함수
  void _handleVideoFound(List<dynamic> args) {
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

    // 화질 선택 UI 표시
    _showQualitySheet(
      sources.map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  /// 사용자에게 화질을 선택할 수 있는 UI (바텀 시트)를 보여주는 함수
  Future<void> _showQualitySheet(List<Map<String, dynamic>> sources) async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('HLS(m3u8)는 현재 지원하지 않아요.')),
        );
        return;
      }
      _enqueueDownload(url);
    }
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: true,
      child: Scaffold(
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
                    callback: _handleVideoFound,
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
