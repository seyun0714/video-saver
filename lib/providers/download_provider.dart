// lib/providers/downloads_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:video_saver/models/download_record.dart';
import 'package:video_saver/services/download_service.dart';

// 다운로드 서비스 프로바이더
final downloadServiceProvider = Provider((ref) => DownloadService());

// 다운로드 목록 상태를 관리하는 Notifier
class DownloadsNotifier extends StateNotifier<List<DownloadRecord>> {
  DownloadsNotifier(this.ref) : super([]) {
    _registerCallbacks();
  }

  final Ref ref;

  void _registerCallbacks() {
    ref
        .read(downloadServiceProvider)
        .registerCallbacks(
          onStatusUpdate: (update) {
            if (!mounted) return;
            state = [
              for (final record in state)
                if (record.task.taskId == update.task.taskId)
                  record..status = update.status
                else
                  record,
            ];
          },
          onProgressUpdate: (update) {
            if (!mounted) return;
            state = [
              for (final record in state)
                if (record.task.taskId == update.task.taskId)
                  record..progress = update.progress
                else
                  record,
            ];
          },
          // 완료 시 UI 알림은 화면(View)에서 처리하는 것이 더 적합하므로 여기서는 목록 관리만 합니다.
          onDownloadComplete: (task, filePath) {
            // 완료된 항목을 처리하는 로직 (예: DB 저장)이 필요하다면 여기에 추가
          },
        );
  }

  Future<void> enqueueDownload(DownloadTask task) async {
    await ref.read(downloadServiceProvider).enqueue(task);
    state = [...state, DownloadRecord(task: task)];
  }
}

// 다운로드 Notifier 프로바이더
final downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, List<DownloadRecord>>((ref) {
      return DownloadsNotifier(ref);
    });
