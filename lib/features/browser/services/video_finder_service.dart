// lib/features/browser/services/video_finder_service.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final videoFinderServiceProvider = Provider((ref) => VideoFinderService());

class VideoFinderService {
  // JavaScript에서 전달된 전체 payload(Map)를 처리하는 콜백
  Function(Map<String, dynamic>)? onVideoFound;

  void onVideoFoundCallback(List<dynamic> args) {
    if (args.isEmpty) return;
    try {
      final payload = jsonDecode(args.first as String);
      if (payload is Map<String, dynamic> && payload['sources'] != null) {
        onVideoFound?.call(payload);
      }
    } catch (e) {
      // JSON 파싱 오류 처리
      // print('Error parsing video data: $e');
    }
  }
}
