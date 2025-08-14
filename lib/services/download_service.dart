// lib/services/download_service.dart
import 'package:background_downloader/background_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DownloadService {
  // ... (createDownloadTask, enqueue, shareFile, _suggestFileNameFromUrl 함수는 동일)
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
      displayName: 'Video',
      metaData: 'mp4',
      headers: headers,
    );
  }

  Future<void> enqueue(DownloadTask task) async {
    await FileDownloader().enqueue(task);
  }

  void registerCallbacks({
    required Function(TaskStatusUpdate) onStatusUpdate,
    required Function(TaskProgressUpdate) onProgressUpdate,
    required Function(Task, String)
    onDownloadComplete, // <-- 수정: DownloadTask -> Task
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
    await Share.shareXFiles([XFile(filePath)], text: text);
  }

  String _suggestFileNameFromUrl(String url) {
    final u = Uri.parse(url);
    var name = (u.pathSegments.isNotEmpty ? u.pathSegments.last : 'video.mp4');
    if (!name.toLowerCase().endsWith('.mp4')) name = '$name.mp4';
    return name;
  }
}
