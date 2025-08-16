// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_saver/ui/screens/main_screen.dart';
import 'package:video_saver/utils/permissions.dart';
import 'package:background_downloader/background_downloader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensurePermissions();
  await FileDownloader().trackTasks();

  // ProviderScope로 앱의 최상단을 감싸줍니다.
  runApp(const ProviderScope(child: VideoSaverApp()));
}

class VideoSaverApp extends StatelessWidget {
  const VideoSaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Saver',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const MainScreen(), // 이렇게 수정합니다.
      debugShowCheckedModeBanner: false,
    );
  }
}
