// =============================
// lib/main.dart
// =============================
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FileDownloader().configure();
  runApp(const VideoSaverApp());
}

class VideoSaverApp extends StatelessWidget {
  const VideoSaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Saver',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const BrowserScreen(),
      debugShowCheckedModeBanner: false, // ← 추가
    );
  }
}

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

  List<String> _whitelist = ['example.org'];
  bool _wifiOnly = false;

  Future<void> _loadSettings() async {
    final sp = await SharedPreferences.getInstance();
    _whitelist = sp.getStringList('whitelist') ?? ['example.org'];
    _wifiOnly = sp.getBool('wifiOnly') ?? false;
    if (mounted) setState(() {});
  }

  Future<void> _saveSettings() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList('whitelist', _whitelist);
    await sp.setBool('wifiOnly', _wifiOnly);
  }

  @override
  void initState() {
    super.initState();
    _ensurePermissions();
    _loadSettings();
  }

  Future<void> _ensurePermissions() async {
    if (Platform.isAndroid) {
      // Android 10 미만에서만 저장소 권한 요청 (MVP: 앱 전용 디렉토리 저장)
      final sdkInt = await _androidSdkInt();
      if (sdkInt < 29) {
        await Permission.storage.request();
      }
    }
  }

  Future<int> _androidSdkInt() async {
    // device_info_plus 없이 보수적으로 최신으로 가정 (필요 시 패키지로 대체)
    return Platform.isAndroid ? 34 : 0;
  }

  // JS: <video> 감지 + 우하단 버튼 삽입
  final String videoObserverJS = '''
    document.querySelectorAll('iframe').forEach(function(frame){
      try {
        const doc = frame.contentDocument || frame.contentWindow.document;
        if (!doc) return;
        doc.querySelectorAll('video').forEach(function(video){
          if (!video.__vs_hasButton) {
            const btn = document.createElement('button');
            btn.innerText = '⬇';
            btn.style.position = 'absolute';
            btn.style.right = '8px';
            btn.style.bottom = '8px';
            btn.style.zIndex = 999999;
            btn.onclick = function(){
              const src = video.currentSrc || video.src;
              if (src && !src.startsWith('blob:')) {
                window.flutter_inappwebview.callHandler('onVideoFound', JSON.stringify({page: location.href, sources:[{url: src, label: 'video'}]}));
              }
            };
            video.parentElement.style.position = 'relative';
            video.parentElement.appendChild(btn);
            video.__vs_hasButton = true;
          }
        });
      } catch(e){}
    });
  ''';

  @override
  Widget build(BuildContext context) {
    // build 메서드의 return 부분 수정 - 상단바와 하단바 모두 SafeArea로 제외
    return SafeArea(
      top: false, // 상단 상태바 영역 제외
      bottom: true, // 하단 네비게이션바 영역 제외
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Enter URL and press Go',
                  ),
                  onSubmitted: (v) => _go(),
                ),
              ),
              IconButton(onPressed: _go, icon: const Icon(Icons.arrow_forward)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _openSettingsSheet, // ← 새로 추가한 함수
            ),
          ],
          bottom: _progress < 1.0
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(4.0),
                  child: LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress,
                  ),
                )
              : null,
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
                    callback: (args) async {
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
            _DownloadsBar(records: downloads, progress: _progress),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          label: const Text('테스트 MP4'),
          icon: const Icon(Icons.download),
          onPressed: () => _downloadTestMp4(),
        ),
      ),
    );
  }

  Future<void> _openSettingsSheet() async {
    final controller = TextEditingController(text: _whitelist.join('\n'));
    final result = await showModalBottomSheet<bool>(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '허용 도메인 (줄바꿈으로 구분)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'example.org.mysite.com',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('와이파이에서만 다운로드'),
                  value: _wifiOnly,
                  onChanged: (v) => setState(() => _wifiOnly = v),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('저장'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result == true) {
      _whitelist = controller.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      await _saveSettings();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('설정을 저장했어요.')));
      }
    }
  }

  Future<void> _go() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final uri = url.startsWith('http') ? url : 'https://$url';
    await _webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(uri)));
  }

  Future<void> _showQualitySheet(List<Map<String, dynamic>> sources) async {
    if (!mounted) return;
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
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
    );
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
      await _enqueueDownload(selected['url'] as String);
    }
  }

  Future<void> _enqueueDownload(String url) async {
    final host = Uri.parse(url).host.toLowerCase();
    final allowed = _whitelist.any(
      (w) => host == w.toLowerCase() || host.endsWith('.' + w.toLowerCase()),
    );
    if (!allowed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('허용되지 않은 도메인입니다: $host')));
      return;
    }

    if (_wifiOnly /* && 정확한 체크를 원하면 connectivity_plus 사용 */ ) {
      // 간단 안내만 (실제 네트워크 타입 체크는 connectivity_plus 권장)
      // if (!await _isOnWifi()) { ... }
    }

    final referer = await _webCtrl?.getUrl();
    final settings = await _webCtrl?.getSettings();
    final headers = <String, String>{
      if (referer != null) 'Referer': referer.toString(),
      if (settings?.userAgent != null) 'User-Agent': settings!.userAgent!,
      'Accept': '*/*',
    };

    final dir = await getApplicationDocumentsDirectory();
    final filename = _suggestFileNameFromUrl(url);

    final task = DownloadTask(
      url: url,
      filename: filename,
      directory: dir.path,
      updates: Updates.statusAndProgress,
      allowPause: true,
      retries: 2,
      displayName: 'Video',
      metaData: 'mp4',
      headers: headers,
    );

    downloads.add(DownloadRecord(task: task));
    setState(() {});

    FileDownloader().registerCallbacks(
      taskNotificationTapCallback: (notificationType, task) {
        // notificationType: NotificationType
        // task: DownloadTask
      },
      taskStatusCallback: (update) async {
        final task = update.task;
        final status = update.status;
        final rec = downloads.firstWhere((r) => r.task.taskId == task.taskId);
        rec.status = status;
        setState(() {});

        if (status == TaskStatus.complete) {
          // filePath() 메서드 대신 task.savedDir + filename 조합으로 실제 경로 생성
          final dirPath = task.directory;
          final filePath = dirPath != null ? '$dirPath/${task.filename}' : null;
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('다운로드 완료: ${task.filename}'),
              action: SnackBarAction(
                label: '공유',
                onPressed: () {
                  if (filePath != null) {
                    Share.shareXFiles([XFile(filePath)], text: task.filename);
                  }
                },
              ),
            ),
          );
        }
      },
      taskProgressCallback: (update) {
        final task = update.task;
        final progress = update.progress;
        final rec = downloads.firstWhere((r) => r.task.taskId == task.taskId);
        rec.progress = progress;
        setState(() {});
      },
    );

    await FileDownloader().enqueue(task);
  }

  Future<void> _downloadTestMp4() async {
    const testUrl =
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
    await _enqueueDownload(testUrl);
  }

  String _suggestFileNameFromUrl(String url) {
    final u = Uri.parse(url);
    var name = (u.pathSegments.isNotEmpty ? u.pathSegments.last : 'video.mp4');
    if (!name.toLowerCase().endsWith('.mp4')) name = '$name.mp4';
    return name;
  }
}

class _DownloadsBar extends StatelessWidget {
  const _DownloadsBar({required this.records, required this.progress});
  final List<DownloadRecord> records;
  final double progress;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 상단 페이지 로딩 진행률 표시 (본문과 동일 값)
        if (progress > 0 && progress < 1)
          const LinearProgressIndicator(minHeight: 2),
        if (records.isEmpty) const SizedBox.shrink() else _list(context),
      ],
    );
  }

  Widget _list(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        itemBuilder: (c, i) {
          final r = records[i];
          return Container(
            width: 220,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.task.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: r.status == TaskStatus.running ? r.progress : null,
                ),
                const SizedBox(height: 6),
                Text(_statusLabel(r.status)),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: records.length,
      ),
    );
  }

  static String _statusLabel(TaskStatus s) {
    switch (s) {
      case TaskStatus.enqueued:
        return '대기 중';
      case TaskStatus.running:
        return '다운로드 중';
      case TaskStatus.paused:
        return '일시정지';
      case TaskStatus.complete:
        return '완료';
      case TaskStatus.canceled:
        return '취소';
      case TaskStatus.failed:
        return '실패';
      case TaskStatus.notFound:
        return '404';
      default:
        return s.name;
    }
  }
}

class DownloadRecord {
  DownloadRecord({required this.task});
  final DownloadTask task;
  TaskStatus status = TaskStatus.enqueued;
  double progress = 0.0; // 0~1
}
