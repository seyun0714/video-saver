// lib/services/download_service.dart
import 'package:background_downloader/background_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DownloadService {
  Future<bool> pause(Task task) => FileDownloader().pause(task as DownloadTask);

  Future<bool> resume(Task task) =>
      FileDownloader().resume(task as DownloadTask);

  // 👇 [수정] 잘못된 'cancel' 메소드를 'cancelTasksWithIds'로 변경
  Future<bool> cancel(Task task) =>
      FileDownloader().cancelTasksWithIds([task.taskId]);
  // 👆 [수정]

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

  Future<void> enqueue(DownloadTask task) async {
    await FileDownloader().enqueue(task);
  }

  void registerCallbacks({
    required Function(TaskStatusUpdate) onStatusUpdate,
    required Function(TaskProgressUpdate) onProgressUpdate,
    required Function(Task, String) onDownloadComplete,
  }) {
    FileDownloader().registerCallbacks(
      taskStatusCallback: (update) {
        onStatusUpdate(update);
        if (update.status == TaskStatus.complete) {
          final filePath = '${update.task.directory}/${update.task.filename}';
          onDownloadComplete(update.task, filePath);
        }
      },
      taskProgressCallback: onProgressUpdate,
    );
  }

  Future<void> shareFile(String filePath, String text) async {
    final shareText = '$text\n\n파일 위치: $filePath';

    // SharePlus.instance.share를 사용하여 텍스트를 공유합니다.
    await SharePlus.instance.share(ShareParams(text: shareText));
  }

  String _suggestFileNameFromUrl(String url) {
    final u = Uri.parse(url);
    var name = (u.pathSegments.isNotEmpty ? u.pathSegments.last : 'video.mp4');
    if (!name.toLowerCase().endsWith('.mp4')) name = '$name.mp4';
    return name;
  }
}
