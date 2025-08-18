// lib/models/download_record.dart
import 'package:background_downloader/background_downloader.dart';

class DownloadRecord {
  DownloadRecord({required this.task});
  DownloadTask task;
  TaskStatus status = TaskStatus.enqueued;
  double progress = 0.0; // 0~1
  String? finalPath;
}
