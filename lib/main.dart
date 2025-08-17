// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_saver/ui/screens/main_screen.dart';
import 'package:video_saver/utils/permissions.dart';
import 'package:background_downloader/background_downloader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensurePermissions();

  await FileDownloader().configureNotification(
    // 1. 진행 중 알림 설정
    running: const TaskNotification(
      '다운로드 중: {displayName}',
      '진행률: {progress}  ({networkSpeed})',
    ),
    // 2. 완료 알림 설정
    complete: const TaskNotification(
      '다운로드 완료: {displayName}',
      '탭하여 파일을 확인하세요.',
    ),
    // 3. 오류 알림 설정
    error: const TaskNotification('다운로드 실패', '{displayName}'),
    // 4. 일시정지 알림 설정
    paused: const TaskNotification('다운로드 일시정지됨', '{displayName}'),
    // 5. 알림 탭 동작
    // tapOpensFile: true로 설정하면, '완료' 알림을 탭했을 때
    // 다운로드된 파일을 OS의 기본 앱으로 열려고 시도합니다.
    tapOpensFile: true,
  );

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
