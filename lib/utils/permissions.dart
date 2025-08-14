// lib/utils/permissions.dart
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

Future<void> ensurePermissions() async {
  if (Platform.isAndroid) {
    // Android 10 미만에서만 저장소 권한 요청 (MVP: 앱 전용 디렉토리 저장)
    // 실제로는 device_info_plus 패키지로 정확한 SDK 버전을 가져오는 것이 좋습니다.
    if (!await Permission.storage.isGranted) {
      await Permission.storage.request();
    }
  }
  // iOS의 경우 Info.plist에 권한 설명이 추가되어 있어야 합니다.
}
