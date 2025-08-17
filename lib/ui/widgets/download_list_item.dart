// lib/ui/widgets/download_list_item.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:video_saver/models/download_record.dart';
import 'package:video_saver/providers/download_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class DownloadListItem extends ConsumerWidget {
  final DownloadRecord record;

  const DownloadListItem({super.key, required this.record});

  Future<String?> _generateThumbnail(DownloadRecord record) async {
    // 다운로드가 완료된 파일만 썸네일 생성
    if (record.status != TaskStatus.complete) {
      return null;
    }
    final filePath = '${record.task.directory}/${record.task.filename}';
    // VideoThumbnail.thumbnailFile은 썸네일 이미지 파일의 경로를 반환합니다.
    final thumbnailPath = await VideoThumbnail.thumbnailFile(
      video: filePath,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 128, // 썸네일 이미지의 최대 너비
      quality: 25,
    );
    return thumbnailPath;
  }

  // 파일 크기를 읽기 쉽게 변환하는 함수
  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.toString().length - 1) ~/ 3;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  // 상태를 한글 텍스트로 변환하는 함수
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

  void _showPopupMenu(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(asyncDownloadsProvider.notifier);
    final items = <PopupMenuEntry>[];

    // 다운로드가 진행중이거나 일시정지 상태일 때만 '취소' 메뉴 표시
    if (record.status == TaskStatus.running ||
        record.status == TaskStatus.paused) {
      items.add(const PopupMenuItem(value: 'cancel', child: Text('취소')));
    }

    items.add(
      const PopupMenuItem(
        value: 'delete',
        child: Text('삭제', style: TextStyle(color: Colors.red)),
      ),
    );

    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 100, 100), // 위치는 임시
      items: items,
    ).then((selectedValue) {
      if (selectedValue == 'cancel') {
        notifier.cancelDownload(record);
      } else if (selectedValue == 'delete') {
        notifier.deleteDownload(record);
      }
    });
  }

  // lib/ui/widgets/download_list_item.dart
  // ... (다른 코드는 그대로 둡니다)

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 👇 [수정] FutureBuilder를 사용해서 비동기적으로 파일 크기를 가져옵니다.
    return FutureBuilder<int>(
      future: record.task.expectedFileSize(), // Future<int>를 반환하는 함수를 호출
      builder: (context, snapshot) {
        // Future가 완료되면 snapshot.data에 int 값이 담겨 옵니다.
        final totalBytes = snapshot.data ?? -1; // 데이터가 아직 없으면 -1로 초기화
        final downloadedBytes = (totalBytes > 0)
            ? (record.progress * totalBytes).toInt()
            : 0;

        return GestureDetector(
          onLongPress: () => _showPopupMenu(context, ref),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    height: 60,
                    child: FutureBuilder<String?>(
                      future: _generateThumbnail(record),
                      builder: (context, snapshot) {
                        // 썸네일이 성공적으로 생성되면 이미지 표시
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.hasData &&
                            snapshot.data != null) {
                          return Image.file(
                            File(snapshot.data!),
                            fit: BoxFit.cover,
                          );
                        }
                        // 썸네일 생성 전이나 실패 시, 기본 아이콘 표시
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
                        // 7.1. 비디오 제목
                        Text(
                          record.task.filename,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // 7.3. 다운로드 용량 및 진행률
                        if (record.status == TaskStatus.running ||
                            record.status == TaskStatus.paused)
                          LinearProgressIndicator(value: record.progress),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              // 로딩 중일 때는 "계산 중..." 표시
                              totalBytes == -1
                                  ? '계산 중...'
                                  : '${_formatBytes(downloadedBytes, 1)} / ${_formatBytes(totalBytes, 1)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            // 7.4. 상태 텍스트
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
