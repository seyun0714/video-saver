// lib/ui/widgets/download_list_item.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_saver/models/download_record.dart';
import 'package:logging/logging.dart';

final _log = Logger('DownloadListItem');

class DownloadListItem extends ConsumerWidget {
  final bool isMultiSelectMode;
  final bool isSelected;
  final VoidCallback onSelected;
  final VoidCallback onLongPress; // onLongPress 콜백 추가
  final DownloadRecord record;

  const DownloadListItem({
    super.key,
    required this.record,
    this.isMultiSelectMode = false,
    this.isSelected = false,
    required this.onSelected,
    required this.onLongPress, // 생성자에 추가
  });

  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.toString().length - 1) ~/ 3;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(decimals)} ${suffixes[i]}';
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
        return '취소됨';
      case TaskStatus.failed:
        return '실패';
      case TaskStatus.notFound:
        return '찾을 수 없음';
      default:
        return s.name;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<int>(
      future: record.task.expectedFileSize(),
      builder: (context, snapshot) {
        final totalBytes = snapshot.data ?? -1;
        final downloadedBytes = (totalBytes > 0)
            ? (record.progress * totalBytes).toInt()
            : 0;

        return GestureDetector(
          onLongPress: onLongPress, // 길게 누르기 이벤트 연결
          onTap: () {
            if (isMultiSelectMode) {
              onSelected(); // 선택 모드일 때는 선택/해제
            } else {
              // 일반 모드일 때는 파일 열기
              if (record.status == TaskStatus.complete) {
                final pathToOpen = record.finalPath;
                if (pathToOpen != null && pathToOpen.isNotEmpty) {
                  OpenFilex.open(pathToOpen);
                } else {
                  _log.warning('열 수 있는 파일 경로가 없습니다: ${record.task.taskId}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('파일을 찾을 수 없습니다. 다시 다운로드해주세요.'),
                    ),
                  );
                }
              }
            }
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isSelected ? Colors.blue.withOpacity(0.2) : null,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    height: 60,
                    child: Builder(
                      builder: (_) {
                        final tp = record.thumbPath;
                        if (tp != null && File(tp).existsSync()) {
                          return Image.file(File(tp), fit: BoxFit.cover);
                        }
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.video_library,
                            size: 40,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.task.filename,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        if (record.status == TaskStatus.running ||
                            record.status == TaskStatus.paused)
                          LinearProgressIndicator(value: record.progress),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              totalBytes == -1
                                  ? '계산 중...'
                                  : '${_formatBytes(downloadedBytes, 1)} / ${_formatBytes(totalBytes, 1)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              _statusLabel(record.status),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: record.status == TaskStatus.complete
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isMultiSelectMode)
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) => onSelected(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
