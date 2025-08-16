// lib/ui/screens/downloads_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_saver/providers/download_provider.dart';
import 'package:video_saver/ui/widgets/download_list_item.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsyncValue = ref.watch(asyncDownloadsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('다운로드 목록')),
      body: downloadsAsyncValue.when(
        data: (downloads) {
          if (downloads.isEmpty) {
            return const Center(child: Text('다운로드 기록이 없습니다.'));
          }
          return ListView.builder(
            itemCount: downloads.length,
            itemBuilder: (context, index) {
              final record = downloads[index];
              return DownloadListItem(record: record);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('오류가 발생했습니다: $err')),
      ),
    );
  }
}
