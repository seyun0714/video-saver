// lib/services/download_service.dart
import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_saver/core/models/download_record.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:logging/logging.dart';

final _log = Logger('DownloadService');

class DownloadService {
  // pause, resume, cancel, enqueue, deleteDownloads, createDownloadTask, _suggestFileNameFromUrl 메서드는 이전과 동일합니다.
  Future<bool> pause(Task task) => FileDownloader().pause(task as DownloadTask);
  Future<bool> resume(Task task) =>
      FileDownloader().resume(task as DownloadTask);
  Future<bool> cancel(Task task) =>
      FileDownloader().cancelTasksWithIds([task.taskId]);
  Future<void> enqueue(DownloadTask task) async =>
      await FileDownloader().enqueue(task);
  Future<void> deleteDownloads(Set<String> taskIdsToDelete) async {
    final sp = await SharedPreferences.getInstance();
    for (final taskId in taskIdsToDelete) {
      sp.remove('finalPath:$taskId');
      sp.remove('thumbPath:$taskId');
    }
    await FileDownloader().database.deleteRecordsWithIds(
      taskIdsToDelete.toList(),
    );
    _log.info(
      '데이터베이스와 SharedPreferences에서 ${taskIdsToDelete.length}개의 기록을 삭제했습니다.',
    );
  }

  Future<DownloadTask> createDownloadTask({
    required String url,
    String? referer,
    String? userAgent,
  }) async {
    final headers = <String, String>{
      if (referer != null) 'Referer': referer,
      if (userAgent != null) 'User-Agent': userAgent,
      'Accept': '*/*',
    };
    final dir = await getApplicationDocumentsDirectory();
    final filename = _suggestFileNameFromUrl(url);
    return DownloadTask(
      url: url,
      filename: filename,
      directory: dir.path,
      updates: Updates.statusAndProgress,
      allowPause: true,
      retries: 2,
      displayName: filename,
      metaData: url,
      headers: headers,
    );
  }

  String _suggestFileNameFromUrl(String url) {
    final u = Uri.parse(url);
    var name = (u.pathSegments.isNotEmpty ? u.pathSegments.last : 'video.mp4');
    if (!name.toLowerCase().endsWith('.mp4')) name = '$name.mp4';
    return name;
  }

  /// 다운로드 완료 후 후처리 작업을 수행하고, 업데이트된 레코드를 반환합니다.
  Future<DownloadRecord> processCompletedDownload(DownloadRecord record) async {
    _log.info('Task ${record.task.filename} 완료: 썸네일 생성 후 갤러리 이동');
    final sp = await SharedPreferences.getInstance();

    final originalPath = await _buildOriginalPath(record.task);
    if (originalPath != null) {
      final thumbPath = await _makeThumbToCache(
        originalPath,
        record.task.taskId,
      );
      if (thumbPath != null) {
        record.thumbPath = thumbPath;
        // 썸네일 경로를 SharedPreferences에 저장
        await sp.setString('thumbPath:${record.task.taskId}', thumbPath);
        _log.info('썸네일 캐시 저장 성공: $thumbPath');
      }
    }

    final movedPath = await _saveToGallery(record.task);
    if (movedPath != null) {
      record.finalPath = movedPath; // finalPath는 _saveToGallery 내부에서 저장됨
      _log.info('갤러리 저장 성공. 최종 경로: $movedPath');
    } else {
      _log.warning('갤러리 저장 실패 또는 최종 경로 수신 실패');
    }

    return record;
  }

  /// 앱 시작 시 후처리가 완료되지 않은 작업을 찾아 재시도합니다.
  Future<void> checkAndRetryPostProcessing() async {
    _log.info('미처리된 다운로드 작업이 있는지 확인합니다...');
    final recordsFromDb = await FileDownloader().database.allRecords();
    final sp = await SharedPreferences.getInstance();

    for (final record in recordsFromDb) {
      if (record.status == TaskStatus.complete) {
        final finalPath = sp.getString('finalPath:${record.task.taskId}');
        if (finalPath == null) {
          _log.warning(
            '${record.task.filename} 작업이 완료되었지만 후처리가 되지 않았습니다. 재시도합니다.',
          );
          // DownloadRecord 객체를 만들어 전달
          final downloadRecord =
              DownloadRecord(task: record.task as DownloadTask)
                ..status = record.status
                ..progress = record.progress;
          await processCompletedDownload(downloadRecord);
        }
      }
    }
    _log.info('미처리 작업 확인 완료.');
  }

  // _buildOriginalPath, _makeThumbToCache, _saveToGallery 메서드는 이전과 동일합니다.
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

  Future<String?> _saveToGallery(DownloadTask task) async {
    try {
      final result = await FileDownloader().moveToSharedStorage(
        task,
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
}
