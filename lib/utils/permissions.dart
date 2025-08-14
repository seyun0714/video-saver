// lib/utils/permissions.dart
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

Future<void> ensurePermissions() async {
  if (Platform.isAndroid) {
    var status = await Permission.storage.status;
    if (status.isDenied) {
      // 첫 권한 요청
      await Permission.storage.request();
    } else if (status.isPermanentlyDenied) {
      // 사용자가 권한을 영구적으로 거부한 경우
      // 앱 설정으로 이동하여 직접 권한을 켜도록 안내
      openAppSettings();
    }
  }
  // iOS는 Info.plist로 처리하므로 별도 코드는 불필요
}
