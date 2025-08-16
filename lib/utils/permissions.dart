// lib/utils/permissions.dart
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

Future<void> ensurePermissions() async {
  // 안드로이드일 경우에만 저장소 권한을 직접 요청합니다.
  if (Platform.isAndroid) {
    // 안드로이드 13 (API 33) 이상에서는 개별 권한을 요청해야 합니다.
    // background_downloader가 내부적으로 처리할 수 있지만, 명시적으로 요청하는 것이 안전합니다.
    var videosStatus = await Permission.videos.status;
    if (videosStatus.isDenied) {
      await Permission.videos.request();
    }

    // 알림 권한도 요청하는 것이 좋습니다.
    var notificationStatus = await Permission.notification.status;
    if (notificationStatus.isDenied) {
      await Permission.notification.request();
    }

    // 영구적으로 거부되었다면 앱 설정 화면을 열도록 안내
    if (await Permission.videos.isPermanentlyDenied ||
        await Permission.notification.isPermanentlyDenied) {
      openAppSettings();
    }
  }
  // iOS는 Info.plist로 권한을 관리하므로 Dart 코드에서 별도로 요청할 필요가 없습니다.
}
