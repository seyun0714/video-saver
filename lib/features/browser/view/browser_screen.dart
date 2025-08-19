// lib/features/browser/view/browser_screen.dart
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
              // 1. WebViewService의 메서드를 호출하여 controller를 전달합니다.
              ref.read(webViewServiceProvider).onWebViewCreated(controller);

              // 2. videoFinderServiceProvider를 import하고 핸들러를 등록합니다.
              final videoFinder = ref.read(videoFinderServiceProvider);
              controller.addJavaScriptHandler(
                handlerName: 'onVideoFound',
                callback: videoFinder.onVideoFoundCallback,
              );
            },
            // 3. WebViewService의 메서드를 호출합니다.
            onLoadStop: (controller, url) =>
                ref.read(webViewServiceProvider).onLoadStop(controller, url),
            // 4. WebViewService의 메서드를 호출합니다.
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
