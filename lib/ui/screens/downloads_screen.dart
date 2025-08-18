// lib/ui/screens/downloads_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_saver/providers/download_provider.dart';
import 'package:video_saver/ui/controllers/downloads_controller.dart';
import 'package:video_saver/ui/widgets/download_list_item.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  // AppBar를 빌드하는 함수
  AppBar _buildAppBar(BuildContext context, WidgetRef ref, int totalItemCount) {
    // UI 상태는 컨트롤러로부터 가져옴
    final controller = ref.watch(downloadsControllerProvider);
    final notifier = ref.read(downloadsControllerProvider.notifier);

    if (controller.isMultiSelectMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: notifier.disableMultiSelectMode, // 컨트롤러 메서드 호출
        ),
        title: Text('${controller.selectedTaskIds.length}개 선택됨'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: notifier.toggleSelectAll, // 컨트롤러 메서드 호출
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: controller.selectedTaskIds.isEmpty
                ? null
                : () => _confirmDelete(context, ref), // 삭제 확인 함수 호출
          ),
        ],
      );
    } else {
      return AppBar(
        title: const Text('다운로드 목록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: totalItemCount == 0
                ? null
                : notifier.startMultiSelectMode,
          ),
        ],
      );
    }
  }

  // 삭제 확인 대화상자를 띄우는 함수
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(downloadsControllerProvider);
    if (controller.selectedTaskIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text(
          '선택한 ${controller.selectedTaskIds.length}개의 항목을 정말 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final count = controller.selectedTaskIds.length;
      // 실제 삭제 로직은 컨트롤러에 위임
      await ref.read(downloadsControllerProvider.notifier).deleteSelected();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 완료 ($count개)')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsyncValue = ref.watch(asyncDownloadsProvider);
    // UI 상태와 로직을 담당하는 컨트롤러
    final controller = ref.watch(downloadsControllerProvider);
    final notifier = ref.read(downloadsControllerProvider.notifier);

    return downloadsAsyncValue.when(
      data: (downloads) {
        return Scaffold(
          appBar: _buildAppBar(context, ref, downloads.length),
          body: downloads.isEmpty
              ? const Center(child: Text('다운로드 기록이 없습니다.'))
              : ListView.builder(
                  itemCount: downloads.length,
                  itemBuilder: (context, index) {
                    final record = downloads[index];
                    return DownloadListItem(
                      record: record,
                      isMultiSelectMode: controller.isMultiSelectMode,
                      isSelected: controller.selectedTaskIds.contains(
                        record.task.taskId,
                      ),
                      onSelected: () =>
                          notifier.toggleSelection(record.task.taskId),
                      onLongPress: () =>
                          notifier.enableMultiSelectMode(record.task.taskId),
                    );
                  },
                ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('다운로드 목록')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(title: const Text('다운로드 목록')),
        body: Center(child: Text('오류가 발생했습니다: $err')),
      ),
    );
  }
}
