// lib/main.dart
import 'package:flutter/material.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // <--- Import 추가
import 'package:video_saver/ui/screens/browser_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FileDownloader().configure();
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
      home: const BrowserScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
