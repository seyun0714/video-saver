// lib/ui/screens/downloads_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_saver/providers/download_provider.dart';
import 'package:video_saver/ui/widgets/download_list_item.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  // 2. 다중 선택 모드와 선택된 항목들을 관리하기 위한 상태 변수
  bool _isMultiSelectMode = false;
  Set<String> _selectedTaskIds = {}; // 선택된 taskId들을 저장

  // 3. AppBar를 동적으로 변경하는 함수
  AppBar _buildAppBar(int totalItemCount) {
    if (_isMultiSelectMode) {
      // 다중 선택 모드일 때의 AppBar
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // 선택 모드 종료
            setState(() {
              _isMultiSelectMode = false;
              _selectedTaskIds.clear();
            });
          },
        ),
        title: Text('${_selectedTaskIds.length}개 선택됨'),
        actions: [
          // 전체 선택 버튼
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: () {
              setState(() {
                final allTaskIds = ref
                    .read(asyncDownloadsProvider)
                    .value!
                    .map((r) => r.task.taskId)
                    .toSet();
                if (_selectedTaskIds.length == allTaskIds.length) {
                  _selectedTaskIds.clear(); // 모두 선택된 경우, 전체 선택 해제
                } else {
                  _selectedTaskIds = allTaskIds; // 전체 선택
                }
              });
            },
          ),
          // 선택 항목 삭제 버튼
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _selectedTaskIds.isEmpty
                ? null // 선택된 항목이 없으면 비활성화
                : () => _confirmDelete(),
          ),
        ],
      );
    } else {
      // 일반 모드일 때의 AppBar
      return AppBar(
        title: const Text('다운로드 목록'),
        actions: [
          // 삭제 모드로 진입하는 버튼
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: totalItemCount == 0
                ? null
                : () {
                    setState(() {
                      _isMultiSelectMode = true;
                    });
                  },
          ),
        ],
      );
    }
  }

  // 4. 삭제 확인 대화상자를 띄우는 함수
  Future<void> _confirmDelete() async {
    if (_selectedTaskIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text(
          '선택한 ${_selectedTaskIds.length}개의 항목을 정말 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.',
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
      final ids = Set<String>.from(_selectedTaskIds);
      await ref.read(asyncDownloadsProvider.notifier).deleteDownloads(ids);
      if (!mounted) return;
      setState(() {
        _isMultiSelectMode = false;
        _selectedTaskIds.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 완료 (${ids.length}개)')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadsAsyncValue = ref.watch(asyncDownloadsProvider);

    return downloadsAsyncValue.when(
      data: (downloads) {
        return Scaffold(
          appBar: _buildAppBar(downloads.length), // 동적 AppBar 사용
          body: downloads.isEmpty
              ? const Center(child: Text('다운로드 기록이 없습니다.'))
              : ListView.builder(
                  itemCount: downloads.length,
                  itemBuilder: (context, index) {
                    final record = downloads[index];
                    return DownloadListItem(
                      record: record,
                      isMultiSelectMode: _isMultiSelectMode,
                      isSelected: _selectedTaskIds.contains(record.task.taskId),
                      onSelected: () {
                        setState(() {
                          if (!_isMultiSelectMode) _isMultiSelectMode = true;
                          if (_selectedTaskIds.contains(record.task.taskId)) {
                            _selectedTaskIds.remove(record.task.taskId);
                          } else {
                            _selectedTaskIds.add(record.task.taskId);
                          }
                        });
                      },
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
