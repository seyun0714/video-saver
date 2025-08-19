// lib/features/browser/services/video_finder_service.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_saver/utils/constants.dart';

final videoFinderServiceProvider = Provider((ref) => VideoFinderService());

class VideoFinderService {
  Function(List<Map<String, dynamic>>)? onVideoFound;

  String get javascriptToInject => videoObserverJS;

  void onVideoFoundCallback(List<dynamic> args) {
    if (args.isEmpty) return;
    final payload = jsonDecode(args.first as String);
    if (payload is! Map || payload['sources'] == null) return;

    final List sources = payload['sources'] as List;
    final sourcesList = sources
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    onVideoFound?.call(sourcesList);
  }
}
