// lib/ui/widgets/download_list_item.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_saver/models/download_record.dart';
import 'package:video_saver/providers/download_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:logging/logging.dart';

final _log = Logger('DownloadListItem');

class DownloadListItem extends ConsumerWidget {
  // 1. 다중 선택 모드 관리를 위한 파라미터 추가
  final bool isMultiSelectMode;
  final bool isSelected;
  final VoidCallback onSelected;
  final DownloadRecord record;

  const DownloadListItem({
    super.key,
    required this.record,
    this.isMultiSelectMode = false, // 기본값 설정
    this.isSelected = false,
    required this.onSelected,
  });

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<int>(
      future: record.task.expectedFileSize(), // Future<int>를 반환하는 함수를 호출
      builder: (context, snapshot) {
        // Future가 완료되면 snapshot.data에 int 값이 담겨 옵니다.
        final totalBytes = snapshot.data ?? -1; // 데이터가 아직 없으면 -1로 초기화
        final downloadedBytes = (totalBytes > 0)
            ? (record.progress * totalBytes).toInt()
            : 0;

        return GestureDetector(
          onLongPress: () {
            if (!isMultiSelectMode) {
              onSelected(); // 길게 누르면 선택 모드로 진입하며 현재 항목 선택
            }
          },
          onTap: () {
            if (isMultiSelectMode) {
              onSelected(); // 선택 모드일 때는 선택/해제 콜백 호출
            } else {
              // 일반 모드일 때는 파일 열기
              if (record.status == TaskStatus.complete) {
                final path_to_open = record.finalPath;
                if (path_to_open != null && path_to_open.isNotEmpty) {
                  OpenFilex.open(path_to_open);
                }
              }
            }
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isSelected
                ? Colors.blue.withOpacity(0.2)
                : null, // 선택된 항목 배경색 변경
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
