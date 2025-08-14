// lib/main.dart
import 'package:flutter/material.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:video_saver/ui/screens/browser_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // FileDownloader 초기 설정은 앱 시작 시 한 번만 수행
  await FileDownloader().configure();
  runApp(const VideoSaverApp());
}

class VideoSaverApp extends StatelessWidget {
  const VideoSaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Saver',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const BrowserScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
