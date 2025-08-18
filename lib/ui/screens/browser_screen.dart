// lib/ui/screens/browser_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_saver/providers/settings_provider.dart';
import 'package:video_saver/services/settings_service.dart';
import 'package:video_saver/ui/controllers/browser_controller.dart';
import 'package:video_saver/ui/widgets/browser_app_bar.dart';
import 'package:video_saver/ui/widgets/settings_sheet.dart';

class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key});

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  late final BrowserController _controller;
  DateTime? _backButtonPressTime;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(browserControllerProvider);
    _controller.initPullToRefresh();
  }

  Future<void> _showQualitySheet(
    List<Map<String, dynamic>> sources, {
    required SettingsService settings,
  }) async {
    _controller.setQualitySheetOpen(true);
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
          _controller.setQualitySheetOpen(false);
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
      _controller.enqueueDownload(
        context: context,
        url: url,
        settings: settings,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(browserControllerProvider);
    final settingsServiceAsyncValue = ref.watch(settingsProvider);

    // 컨트롤러의 상태 변화를 감지하여 UI 로직(BottomSheet)을 실행
    ref.listen(browserControllerProvider, (previous, next) {
      if (next.sourcesToShow != null) {
        final settings = ref.read(settingsProvider).value;
        if (settings != null) {
          _showQualitySheet(next.sourcesToShow!, settings: settings);
        }
        // 상태를 처리했으므로 컨트롤러의 상태를 초기화
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(browserControllerProvider.notifier).clearSourcesToShow();
        });
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final canGoBack = await controller.webCtrl?.canGoBack() ?? false;
        if (canGoBack) {
          controller.webCtrl?.goBack();
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
            urlController: controller.urlCtrl,
            onGo: () => controller.go(context),
            onOpenSettings: () {
              settingsServiceAsyncValue.whenData((service) {
                showSettingsSheet(
                  context: context,
                  settingsService: service,
                  onSettingsSaved: () => ref.refresh(settingsProvider),
                );
              });
            },
            progress: controller.progress,
          ),
          body: InAppWebView(
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
            ),
            pullToRefreshController: controller.pullToRefreshCtrl,
            onWebViewCreated: controller.onWebViewCreated,
            onLoadStop: controller.onLoadStop,
            onProgressChanged: controller.onProgressChanged,
            initialUrlRequest: URLRequest(url: WebUri(controller.urlCtrl.text)),
          ),
        ),
      ),
    );
  }
}
