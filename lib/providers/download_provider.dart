// lib/providers/download_provider.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_saver/models/download_record.dart';
import 'package:video_saver/services/download_service.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

final _log = Logger('DownloadProvider');

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
    final records = await _loadExistingTasks();
    return _sorted(records);
  }

  Future<List<DownloadRecord>> _loadExistingTasks() async {
    final recordsFromDb = await FileDownloader().database.allRecords();
    return recordsFromDb.map((r) {
      return DownloadRecord(task: r.task as DownloadTask)
        ..status = r.status
        ..progress = r.progress;
    }).toList();
  }

  void _registerCallbacks() {
    FileDownloader().registerCallbacks(
      taskStatusCallback: _onStatusUpdate,
      taskProgressCallback: _onProgressUpdate,
    );
  }

  /// 다운로드가 끝난 직후(갤러리 이동 전)에, 원본 저장 위치의 실제 파일 경로를 복원
  Future<String?> _buildOriginalPath(DownloadTask task) async {
    String? basePath;
    switch (task.baseDirectory) {
      case BaseDirectory.applicationDocuments:
        basePath = (await getApplicationDocumentsDirectory()).path;
        break;
      case BaseDirectory.applicationSupport:
        basePath = (await getApplicationSupportDirectory()).path;
        break;
      case BaseDirectory.temporary:
        basePath = (await getTemporaryDirectory()).path;
        break;
      // downloads/movies/music 등 외부 공유 디렉터리에 바로 저장한다면
      // 여기서 별도 분기 처리가 필요할 수 있지만, 일반적으로 앱전용 디렉터리에 저장 후 이동을 권장
      default:
        basePath = null;
    }
    if (basePath == null) return null;

    final subdir = (task.directory ?? '').replaceAll(RegExp(r'^/+|/+$'), '');
    final fullPath = [
      basePath,
      if (subdir.isNotEmpty) subdir,
      task.filename,
    ].join('/');

    final f = File(fullPath);
    if (await f.exists()) return fullPath;

    _log.warning('원본 파일 경로를 찾지 못했습니다: $fullPath');
    return null;
  }

  /// 썸네일을 앱 캐시에 파일로 저장하고, 그 경로를 반환
  Future<String?> _makeThumbToCache(String srcPath, String taskId) async {
    try {
      final tmp = await getTemporaryDirectory();
      final thumbPath = '${tmp.path}/thumb_$taskId.jpg';

      final bytes = await VideoThumbnail.thumbnailData(
        video: srcPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 128,
        quality: 50,
      );
      if (bytes == null || bytes.isEmpty) {
        _log.warning('썸네일 생성 결과가 비어 있습니다: $srcPath');
        return null;
      }
      final f = File(thumbPath);
      await f.writeAsBytes(bytes, flush: true);
      return f.path;
    } catch (e) {
      _log.warning('썸네일 생성 실패($srcPath): $e');
      return null;
    }
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
      return result;
    } catch (e) {
      _log.warning('갤러리 이동 실패: $e');
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
      final current = records[index];
      current.status = update.status;

      if (update.status == TaskStatus.complete) {
        _log.info('Task ${update.task.filename} 완료: 썸네일 생성 후 갤러리 이동');

        // 1) 이동 전에 원본 경로로부터 썸네일을 캐시에 생성
        final originalPath = await _buildOriginalPath(
          update.task as DownloadTask,
        );
        if (originalPath != null) {
          final thumbPath = await _makeThumbToCache(
            originalPath,
            update.task.taskId,
          );
          if (thumbPath != null) {
            current.thumbPath = thumbPath; // ★ 썸네일 캐시 경로 저장
            _log.info('썸네일 캐시 저장 성공: $thumbPath');
          }
        }

        // 2) 갤러리(공유 저장소)로 이동
        final movedPath = await _saveToGallery(update.task);
        if (movedPath != null) {
          current.finalPath = movedPath; // ★ 이동 후 최종 경로 저장(content:// 또는 파일 경로)
          _log.info('갤러리 저장 성공. 최종 경로: $movedPath');
        } else {
          _log.warning('갤러리 저장 실패 또는 최종 경로 수신 실패');
        }
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
    state = AsyncData([newRecord, ...state.value!]); // 최신이 위로
  }

  Future<void> pauseDownload(DownloadRecord record) async {
    await ref.read(downloadServiceProvider).pause(record.task);
  }

  Future<void> resumeDownload(DownloadRecord record) async {
    await ref.read(downloadServiceProvider).resume(record.task);
  }

  Future<void> cancelDownload(DownloadRecord record) async {
    await ref.read(downloadServiceProvider).cancel(record.task);
  }

  Future<void> deleteDownloads(Set<String> taskIdsToDelete) async {
    final ids = Set<String>.from(taskIdsToDelete);
    if (!state.hasValue || ids.isEmpty) return;

    final currentRecords = List<DownloadRecord>.from(state.value!);

    await FileDownloader().database.deleteRecordsWithIds(ids.toList());
    _log.info('데이터베이스에서 ${ids.length}개의 기록을 삭제했습니다.');

    currentRecords.removeWhere((r) => ids.contains(r.task.taskId));
    state = AsyncData(_sorted(currentRecords));
    _log.info('${ids.length}개의 항목이 영구적으로 삭제되었습니다.');
  }
}

final asyncDownloadsProvider =
    AsyncNotifierProvider<AsyncDownloads, List<DownloadRecord>>(
      () => AsyncDownloads(),
    );
