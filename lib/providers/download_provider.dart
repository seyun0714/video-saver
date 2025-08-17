import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:video_saver/models/download_record.dart';
import 'package:video_saver/services/download_service.dart';

final downloadServiceProvider = Provider((ref) => DownloadService());

// 👇 StateNotifierProvider -> AsyncNotifierProvider로 변경
class AsyncDownloads extends AsyncNotifier<List<DownloadRecord>> {
  // build 메소드에서 초기 데이터를 비동기적으로 로드합니다.
  @override
  Future<List<DownloadRecord>> build() async {
    _registerCallbacks();
    return _loadExistingTasks(); // 초기 데이터 로드
  }

  // 데이터베이스에서 모든 기록을 불러오는 로직
  Future<List<DownloadRecord>> _loadExistingTasks() async {
    final recordsFromDb = await FileDownloader().database.allRecords();
    final records = <DownloadRecord>[];
    for (var recordFromDb in recordsFromDb) {
      records.add(
        DownloadRecord(task: recordFromDb.task as DownloadTask)
          ..status = recordFromDb.status
          ..progress = recordFromDb.progress,
      );
    }
    return records;
  }

  // 다운로더 콜백 등록
  void _registerCallbacks() {
    FileDownloader().registerCallbacks(
      taskStatusCallback: _onStatusUpdate,
      taskProgressCallback: _onProgressUpdate,
    );
  }

  Future<void> _saveToGallery(Task task) async {
    try {
      // 파일을 공용 'Movies' 폴더로 이동합니다.
      // 이 메소드는 자동으로 미디어 스캔을 트리거합니다.
      final result = await FileDownloader().moveToSharedStorage(
        task as DownloadTask,
        SharedStorage.video,
        directory: 'VideoSaver', // 'Movies' 폴더 아래에 'VideoSaver'라는 하위 폴더를 만듭니다.
      );

      if (result != null) {
        print('[VideoSaver] 파일이 갤러리에 저장되었습니다: $result');
      } else {
        print('[VideoSaver] 갤러리 저장에 실패했습니다.');
      }
    } catch (e) {
      print('[VideoSaver] 갤러리 저장 중 오류 발생: $e');
    }
  }

  void _onStatusUpdate(TaskStatusUpdate update) {
    if (!state.hasValue) return;
    final records = state.value!;
    print('[VideoSaver] 상태 업데이트: ${update.task.taskId} -> ${update.status}');

    if (update.status == TaskStatus.complete) {
      _saveToGallery(update.task as DownloadTask);
    }

    state = AsyncData([
      for (final record in records)
        if (record.task.taskId == update.task.taskId)
          record..status = update.status
        else
          record,
    ]);
  }

  // 진행률 업데이트 콜백
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
      state = AsyncData(newRecords);
    }
  }

  // 다운로드 추가
  Future<void> enqueueDownload(DownloadTask task) async {
    if (state.value?.any((r) => r.task.taskId == task.taskId) ?? false) return;

    await ref.read(downloadServiceProvider).enqueue(task);
    final newRecord = DownloadRecord(task: task);

    state = AsyncData([...state.value!, newRecord]);
  }

  // 다운로드 일시정지
  Future<void> pauseDownload(DownloadRecord record) async {
    await ref.read(downloadServiceProvider).pause(record.task);
  }

  // 다운로드 재개
  Future<void> resumeDownload(DownloadRecord record) async {
    await ref.read(downloadServiceProvider).resume(record.task);
  }

  // 다운로드 취소
  Future<void> cancelDownload(DownloadRecord record) async {
    await ref.read(downloadServiceProvider).cancel(record.task);
  }

  // 다운로드 삭제
  Future<void> deleteDownload(DownloadRecord record) async {
    // 👇 [수정] 데이터베이스 기록까지 삭제하는 올바른 메소드입니다.
    await FileDownloader().cancelTaskWithId(record.task.taskId);

    // cancelTaskWithId가 파일 삭제까지 처리해주는 경우가 많지만,
    // 만일을 대비해 파일이 남아있으면 직접 삭제하는 로직을 유지하는 것이 안전합니다.
    try {
      final filePath = '${record.task.directory}/${record.task.filename}';
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('파일 삭제 중 추가 오류 발생: $e');
    }

    // 상태 리스트에서 해당 항목 제거
    final newRecords = state.value
        ?.where((r) => r.task.taskId != record.task.taskId)
        .toList();
    state = AsyncData(newRecords ?? []);
  }
}

final asyncDownloadsProvider =
    AsyncNotifierProvider<AsyncDownloads, List<DownloadRecord>>(() {
      return AsyncDownloads();
    });
