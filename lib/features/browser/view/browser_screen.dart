// lib/features/browser/view/browser_screen.dart
import 'dart:io'; // 추가
import 'package:background_downloader/background_downloader.dart'; // 추가
import 'package:path_provider/path_provider.dart'; // 추가
import 'package:video_thumbnail/video_thumbnail.dart'; // 추가
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_saver/core/services/webview_service.dart';
import 'package:video_saver/features/browser/services/video_finder_service.dart';
import 'package:video_saver/features/browser/viewmodel/browser_viewmodel.dart';
import 'package:video_saver/features/browser/view/widgets/browser_app_bar.dart';
import 'package:video_saver/features/settings/provider/settings_provider.dart';
import 'package:video_saver/features/settings/view/widgets/settings_sheet.dart';

class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key});

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  DateTime? _backButtonPressTime;

  @override
  void initState() {
    super.initState();
  }

  // 파일 크기를 읽기 쉬운 형식으로 변환하는 함수
  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.toString().length - 1) ~/ 3;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  // 영상 URL로부터 썸네일과 파일 크기 정보를 가져오는 함수
  Future<Map<String, dynamic>> _getVideoInfo(String videoUrl) async {
    // 1. 썸네일 생성
    final thumbnailPath = await VideoThumbnail.thumbnailFile(
      video: videoUrl,
      thumbnailPath: (await getTemporaryDirectory()).path,
      imageFormat: ImageFormat.WEBP,
      quality: 25,
    );

    // 2. 예상 파일 크기 가져오기
    final task = DownloadTask(url: videoUrl);
    final size = await task.expectedFileSize();
    String fileSize;
    if (size != -1) {
      fileSize = _formatBytes(size, 1);
    } else {
      fileSize = '알 수 없음';
    }

    return {'thumbnailPath': thumbnailPath, 'fileSize': fileSize};
  }

  // 화질 선택 Bottom Sheet UI 수정
  Future<void> _showQualitySheet(List<Map<String, dynamic>> sources) async {
    final viewModel = ref.read(browserViewModelProvider);
    viewModel.setQualitySheetOpen(true);

    final selectedSource =
        await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          builder: (ctx) {
            return SafeArea(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sources.length,
                itemBuilder: (c, i) {
                  final s = sources[i];
                  final url = s['url'] ?? '';
                  final label = s['label'] ?? 'video';

                  return FutureBuilder<Map<String, dynamic>>(
                    future: _getVideoInfo(url),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return ListTile(
                          leading: SizedBox(
                            width: 56,
                            height: 100, // 16:9 ratio
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          title: Text('화질: $label'),
                          subtitle: const Text('정보를 불러오는 중...'),
                        );
                      }

                      final info = snapshot.data ?? {};
                      final thumbPath = info['thumbnailPath'];
                      final fileSize = info['fileSize'] ?? '크기 정보 없음';

                      return ListTile(
                        leading: SizedBox(
                          width: 56,
                          height: 100, // 16:9 ratio
                          child: thumbPath != null
                              ? Image.file(File(thumbPath), fit: BoxFit.cover)
                              : Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.videocam_off,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                        title: Text('화질: $label'),
                        subtitle: Text('예상 용량: $fileSize'),
                        onTap: () => Navigator.of(c).pop(s),
                      );
                    },
                  );
                },
                separatorBuilder: (_, __) => const Divider(height: 1),
              ),
            );
          },
        ).whenComplete(() {
          viewModel.setQualitySheetOpen(false);
        });

    if (selectedSource != null && context.mounted) {
      final url = selectedSource['url'] as String?;
      if (url == null || url.isEmpty) return;

      if (url.toLowerCase().contains('.m3u8')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('HLS(m3u8)는 현재 지원하지 않아요.')),
        );
        return;
      }
      viewModel.enqueueDownload(context, url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(browserViewModelProvider);
    final settingsServiceAsyncValue = ref.watch(settingsProvider);

    ref.listen(browserViewModelProvider, (previous, next) {
      if (next.sourcesToShow != null) {
        _showQualitySheet(next.sourcesToShow!);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          next.clearSourcesToShow();
        });
      }
    });

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final canGoBack =
            await viewModel.webViewController?.canGoBack() ?? false;
        if (canGoBack) {
          viewModel.webViewController?.goBack();
        } else {
          final now = DateTime.now();
          if (_backButtonPressTime != null &&
              now.difference(_backButtonPressTime!) <
                  const Duration(seconds: 2)) {
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
            urlController: viewModel.urlController,
            onGo: () => viewModel.go(context),
            onOpenSettings: () {
              settingsServiceAsyncValue.whenData((service) {
                showSettingsSheet(
                  context: context,
                  settingsService: service,
                  onSettingsSaved: () => ref.refresh(settingsProvider),
                );
              });
            },
            progress: viewModel.progress,
          ),
          body: InAppWebView(
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
            ),
            pullToRefreshController: viewModel.pullToRefreshController,
            onWebViewCreated: (controller) {
              ref.read(webViewServiceProvider).onWebViewCreated(controller);
              final videoFinder = ref.read(videoFinderServiceProvider);
              controller.addJavaScriptHandler(
                handlerName: 'onVideoFound',
                callback: videoFinder.onVideoFoundCallback,
              );
            },
            onLoadStop: (controller, url) =>
                ref.read(webViewServiceProvider).onLoadStop(controller, url),
            onProgressChanged: (controller, progress) => ref
                .read(webViewServiceProvider)
                .onProgress(controller, progress),
            initialUrlRequest: URLRequest(
              url: WebUri(viewModel.urlController.text),
            ),
          ),
        ),
      ),
    );
  }
}
