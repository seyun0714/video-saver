import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_saver/models/download_record.dart';
import 'package:video_saver/services/download_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('DownloadProvider'); // 2. 로거 생성

final downloadServiceProvider = Provider((ref) => DownloadService());

// 👇 StateNotifierProvider -> AsyncNotifierProvider로 변경
class AsyncDownloads extends AsyncNotifier<List<DownloadRecord>> {
  // build 메소드에서 초기 데이터를 비동기적으로 로드합니다.
  @override
  Future<List<DownloadRecord>> build() async {
    _registerCallbacks();
    final records = await _loadExistingTasks(); // 초기 데이터 로드

    // 1. [수정] 초기 데이터를 시간순으로 정렬합니다. (최신 항목이 위로)
    records.sort((a, b) => b.task.creationTime.compareTo(a.task.creationTime));
    return records;
  }

  // 데이터베이스에서 모든 기록을 불러오는 로직
  Future<List<DownloadRecord>> _loadExistingTasks() async {
    final recordsFromDb = await FileDownloader().database.allRecords();
    return recordsFromDb.map((recordFromDb) {
      return DownloadRecord(task: recordFromDb.task as DownloadTask)
        ..status = recordFromDb.status
        ..progress = recordFromDb.progress;
    }).toList();
  }

  // 다운로더 콜백 등록
  void _registerCallbacks() {
    FileDownloader().registerCallbacks(
      taskStatusCallback: _onStatusUpdate,
      taskProgressCallback: _onProgressUpdate,
    );
  }

  Future<String?> _saveToGallery(Task task) async {
    try {
      final result = await FileDownloader().moveToSharedStorage(
        task as DownloadTask,
        SharedStorage.video,
        directory: 'VideoSaver',
      );
      if (result != null) {
        final sp = await SharedPreferences.getInstance();
        await sp.setString('finalPath:${task.taskId}', result);
      }
      return result; // 이동 성공 시 새로운 경로 반환, 실패 시 null 반환
    } catch (e) {
      return null;
    }
  }

  void _onStatusUpdate(TaskStatusUpdate update) async {
    if (!state.hasValue) return;

    final records = List<DownloadRecord>.from(state.value!);
    final index = records.indexWhere(
      (r) => r.task.taskId == update.task.taskId,
    );

    if (index != -1) {
      final currentRecord = records[index];
      currentRecord.status = update.status; // 상태는 항상 먼저 업데이트

      // [핵심] 사용자님께서 요청하신 로직입니다.
      if (update.status == TaskStatus.complete) {
        _log.info('Task ${update.task.filename} 완료. 갤러리로 이동 시작.');
        // _saveToGallery 함수는 성공 시 최종 경로(String)를 반환합니다.
        final finalPath = await _saveToGallery(update.task);

        if (finalPath != null) {
          _log.info('갤러리 저장 성공. 최종 경로: $finalPath');
          // 상태에 있는 DownloadRecord의 finalPath를 최종 경로로 업데이트합니다.
          currentRecord.finalPath = finalPath;
        } else {
          _log.warning('갤러리 저장에 실패했거나 경로를 받지 못했습니다.');
        }
      }

      // 최종 경로가 포함된 업데이트된 리스트로 상태를 갱신합니다.
      state = AsyncData(records);
    }
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

  Future<void> deleteDownloads(Set<String> taskIdsToDelete) async {
    // ★ 호출자가 같은 Set을 clear해도 안전하도록 복사
    final ids = Set<String>.from(taskIdsToDelete);
    if (!state.hasValue || ids.isEmpty) return;

    final currentRecords = List<DownloadRecord>.from(state.value!);

    await FileDownloader().database.deleteRecordsWithIds(ids.toList());
    _log.info('데이터베이스에서 ${ids.length}개의 기록을 삭제했습니다.');

    // 3) UI 상태 갱신
    currentRecords.removeWhere((record) => ids.contains(record.task.taskId));
    state = AsyncData(currentRecords);
    _log.info('${ids.length}개의 항목이 영구적으로 삭제되었습니다.');
  }
}

final asyncDownloadsProvider =
    AsyncNotifierProvider<AsyncDownloads, List<DownloadRecord>>(() {
      return AsyncDownloads();
    });
