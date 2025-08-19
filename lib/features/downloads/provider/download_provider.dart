// lib/providers/download_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_saver/core/models/download_record.dart';
import 'package:video_saver/core/services/download_service.dart';

final downloadServiceProvider = Provider((ref) => DownloadService());

class AsyncDownloads extends AsyncNotifier<List<DownloadRecord>> {
  List<DownloadRecord> _sorted(List<DownloadRecord> list) {
    final copy = List<DownloadRecord>.from(list);
    copy.sort((a, b) => b.task.creationTime.compareTo(a.task.creationTime));
    return copy;
  }

  @override
  Future<List<DownloadRecord>> build() async {
    _registerCallbacks();
    // 1. Provider가 빌드될 때 미처리 작업을 먼저 확인하고 재시도
    await ref.read(downloadServiceProvider).checkAndRetryPostProcessing();
    // 2. 재시도 후 최종 데이터를 로드
    final records = await _loadExistingTasks();
    return _sorted(records);
  }

  Future<List<DownloadRecord>> _loadExistingTasks() async {
    final recordsFromDb = await FileDownloader().database.allRecords();
    final sp = await SharedPreferences.getInstance();

    // DB에서 불러온 레코드에 SharedPreferences의 후처리 정보를 채워넣음
    final records = recordsFromDb.map((r) {
      final record = DownloadRecord(task: r.task as DownloadTask)
        ..status = r.status
        ..progress = r.progress;

      // 저장된 경로 정보가 있다면 불러와서 할당
      record.finalPath = sp.getString('finalPath:${r.task.taskId}');
      record.thumbPath = sp.getString('thumbPath:${r.task.taskId}');
      return record;
    }).toList();

    return records;
  }

  // _registerCallbacks, _onStatusUpdate, _onProgressUpdate, enqueueDownload, pauseDownload, resumeDownload, cancelDownload 메서드는 이전과 동일합니다.
  void _registerCallbacks() {
    FileDownloader().registerCallbacks(
      taskStatusCallback: _onStatusUpdate,
      taskProgressCallback: _onProgressUpdate,
    );
  }

  void _onStatusUpdate(TaskStatusUpdate update) async {
    if (!state.hasValue) return;
    final records = List<DownloadRecord>.from(state.value!);
    final index = records.indexWhere(
      (r) => r.task.taskId == update.task.taskId,
    );
    if (index != -1) {
      final current = records[index];
      current.status = update.status;
      if (update.status == TaskStatus.complete) {
        final updatedRecord = await ref
            .read(downloadServiceProvider)
            .processCompletedDownload(current);
        records[index] = updatedRecord;
      }
      state = AsyncData(_sorted(records));
    }
  }

  void _onProgressUpdate(TaskProgressUpdate update) {
    if (state.hasValue) {
      final records = state.value!;
      final newRecords = [
        for (final record in records)
          if (record.task.taskId == update.task.taskId)
            record..progress = update.progress
          else
            record,
      ];
      state = AsyncData(_sorted(newRecords));
    }
  }

  Future<void> enqueueDownload(DownloadTask task) async {
    if (state.value?.any((r) => r.task.taskId == task.taskId) ?? false) return;
    await ref.read(downloadServiceProvider).enqueue(task);
    final newRecord = DownloadRecord(task: task);
    state = AsyncData(_sorted([newRecord, ...state.value!]));
  }

  Future<void> pauseDownload(DownloadRecord record) async =>
      await ref.read(downloadServiceProvider).pause(record.task);
  Future<void> resumeDownload(DownloadRecord record) async =>
      await ref.read(downloadServiceProvider).resume(record.task);
  Future<void> cancelDownload(DownloadRecord record) async =>
      await ref.read(downloadServiceProvider).cancel(record.task);

  Future<void> deleteDownloads(Set<String> taskIdsToDelete) async {
    if (!state.hasValue || taskIdsToDelete.isEmpty) return;

    await ref.read(downloadServiceProvider).deleteDownloads(taskIdsToDelete);

    final currentRecords = List<DownloadRecord>.from(state.value!);
    currentRecords.removeWhere((r) => taskIdsToDelete.contains(r.task.taskId));
    state = AsyncData(_sorted(currentRecords));
  }
}

final asyncDownloadsProvider =
    AsyncNotifierProvider<AsyncDownloads, List<DownloadRecord>>(
      () => AsyncDownloads(),
    );
