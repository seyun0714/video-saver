// lib/ui/widgets/downloads_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_saver/models/download_record.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:video_saver/providers/download_provider.dart';

// ConsumerWidget으로 변경
class DownloadsBar extends ConsumerWidget {
  const DownloadsBar({super.key, required this.records});
  final List<DownloadRecord> records;

  void _showDownloadMenu(
    BuildContext context,
    WidgetRef ref,
    DownloadRecord record,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final notifier = ref.read(downloadsProvider.notifier);
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              if (record.status == TaskStatus.running)
                ListTile(
                  leading: const Icon(Icons.pause_circle_outline),
                  title: const Text('일시정지'),
                  onTap: () {
                    notifier.pauseDownload(record);
                    Navigator.pop(context);
                  },
                ),
              if (record.status == TaskStatus.paused)
                ListTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: const Text('재개'),
                  onTap: () {
                    notifier.resumeDownload(record);
                    Navigator.pop(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: const Text('취소', style: TextStyle(color: Colors.red)),
                onTap: () {
                  notifier.cancelDownload(record);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      // ... 기존 Container 스타일
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        itemCount: records.length,
        itemBuilder: (c, i) {
          final r = records[i];
          return GestureDetector(
            onTap: () => _showDownloadMenu(context, ref, r), // 탭하면 메뉴 표시
            child: Container(
              width: 220,
              // ... 기존 Container 스타일
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Column(
                // ... 기존 Column 내용
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
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
      ),
    );
  }

  static String _statusLabel(TaskStatus s) {
    // ... 기존 _statusLabel 함수
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
