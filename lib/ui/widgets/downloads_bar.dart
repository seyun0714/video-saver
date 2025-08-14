// lib/ui/widgets/downloads_bar.dart
import 'package:flutter/material.dart';
import 'package:video_saver/models/download_record.dart';
import 'package:background_downloader/background_downloader.dart';

class DownloadsBar extends StatelessWidget {
  const DownloadsBar({super.key, required this.records});
  final List<DownloadRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }
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
