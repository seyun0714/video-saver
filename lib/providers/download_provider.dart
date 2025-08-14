// lib/providers/downloads_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:video_saver/models/download_record.dart';
import 'package:video_saver/services/download_service.dart';

final downloadServiceProvider = Provider((ref) => DownloadService());

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
          onDownloadComplete: (task, filePath) {
            // 완료 시 로직
          },
        );
  }

  Future<void> enqueueDownload(DownloadTask task) async {
    await ref.read(downloadServiceProvider).enqueue(task);
    state = [...state, DownloadRecord(task: task)];
  }

  // --- 👇 [3단계] Notifier에 관리 메소드 추가 ---
  Future<void> pauseDownload(DownloadRecord record) async {
    await ref.read(downloadServiceProvider).pause(record.task);
  }

  Future<void> resumeDownload(DownloadRecord record) async {
    await ref.read(downloadServiceProvider).resume(record.task);
  }

  Future<void> cancelDownload(DownloadRecord record) async {
    await ref.read(downloadServiceProvider).cancel(record.task);
    // 상태 리스트에서 즉시 제거하여 UI에 반영
    state = state.where((r) => r.task.taskId != record.task.taskId).toList();
  }

  // --- 👆 [3단계] Notifier에 관리 메소드 추가 ---
}

final downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, List<DownloadRecord>>((ref) {
      return DownloadsNotifier(ref);
    });
