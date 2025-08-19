// lib/ui/controllers/downloads_controller.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_saver/features/downloads/provider/download_provider.dart';

// 1. 컨트롤러를 위한 Provider 생성
final downloadsViewModelProvider = ChangeNotifierProvider.autoDispose(
  (ref) => DownloadsViewModel(ref),
);

// 2. UI의 상태와 로직을 담당하는 컨트롤러
class DownloadsViewModel extends ChangeNotifier {
  final Ref _ref;
  DownloadsViewModel(this._ref);

  bool isMultiSelectMode = false;
  Set<String> selectedTaskIds = {};

  void startMultiSelectMode() {
    if (isMultiSelectMode) return;
    isMultiSelectMode = true;
    notifyListeners();
  }

  // 다중 선택 모드로 전환
  void enableMultiSelectMode(String initialTaskId) {
    if (isMultiSelectMode) return;
    isMultiSelectMode = true;
    selectedTaskIds.add(initialTaskId);
    notifyListeners();
  }

  // 다중 선택 모드 해제
  void disableMultiSelectMode() {
    isMultiSelectMode = false;
    selectedTaskIds.clear();
    notifyListeners();
  }

  // 개별 항목 선택/해제
  void toggleSelection(String taskId) {
    if (!isMultiSelectMode) return;

    if (selectedTaskIds.contains(taskId)) {
      selectedTaskIds.remove(taskId);
    } else {
      selectedTaskIds.add(taskId);
    }
    notifyListeners();
  }

  // 전체 선택/해제
  void toggleSelectAll() {
    final allTaskIds = _ref
        .read(asyncDownloadsProvider)
        .value!
        .map((r) => r.task.taskId)
        .toSet();

    if (selectedTaskIds.length == allTaskIds.length) {
      selectedTaskIds.clear(); // 모두 선택된 경우, 전체 선택 해제
    } else {
      selectedTaskIds = allTaskIds; // 전체 선택
    }
    notifyListeners();
  }

  // 선택된 항목 삭제
  Future<void> deleteSelected() async {
    if (selectedTaskIds.isEmpty) return;
    final idsToDelete = Set<String>.from(selectedTaskIds);
    await _ref
        .read(asyncDownloadsProvider.notifier)
        .deleteDownloads(idsToDelete);

    // 삭제 후 선택 모드 종료
    disableMultiSelectMode();
  }
}
