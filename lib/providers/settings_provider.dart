// lib/providers/settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_saver/services/settings_service.dart';

final settingsServiceProvider = Provider((ref) => SettingsService());

// 설정 데이터를 비동기적으로 로드하고 관리
final settingsProvider = FutureProvider((ref) async {
  final service = ref.watch(settingsServiceProvider);
  await service.loadSettings();
  return service;
});
