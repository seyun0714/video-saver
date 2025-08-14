// lib/ui/widgets/browser_app_bar.dart
import 'package:flutter/material.dart';

class BrowserAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController urlController;
  final VoidCallback onGo;
  final VoidCallback onOpenSettings;
  final double progress;
  // --- 👇 [3단계] 웹뷰 제어 콜백 추가 ---
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;
  final bool canGoBack;
  final bool canGoForward;
  // --- 👆 [3단계] 웹뷰 제어 콜백 추가 ---

  const BrowserAppBar({
    super.key,
    required this.urlController,
    required this.onGo,
    required this.onOpenSettings,
    required this.progress,
    // --- 👇 [3단계] 생성자 파라미터 추가 ---
    required this.onBack,
    required this.onForward,
    required this.onReload,
    required this.canGoBack,
    required this.canGoForward,
    // --- 👆 [3단계] 생성자 파라미터 추가 ---
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      // --- 👇 [3단계] 뒤로가기 버튼 추가 ---
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: canGoBack ? onBack : null, // 비활성화 상태 제어
      ),
      // --- 👆 [3단계] 뒤로가기 버튼 추가 ---
      title: Row(
        children: [
          Expanded(
            child: TextField(
              controller: urlController,
              decoration: const InputDecoration(hintText: 'Enter URL'),
              onSubmitted: (_) => onGo(),
            ),
          ),
          IconButton(onPressed: onGo, icon: const Icon(Icons.arrow_forward)),
        ],
      ),
      actions: [
        // --- 👇 [3단계] 앞으로가기, 새로고침 버튼 추가 ---
        IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: canGoForward ? onForward : null, // 비활성화 상태 제어
        ),
        IconButton(icon: const Icon(Icons.refresh), onPressed: onReload),
        // --- 👆 [3단계] 앞으로가기, 새로고침 버튼 추가 ---
        IconButton(icon: const Icon(Icons.settings), onPressed: onOpenSettings),
      ],
      bottom: progress < 1.0
          ? PreferredSize(
              preferredSize: const Size.fromHeight(4.0),
              child: LinearProgressIndicator(
                value: progress == 0 ? null : progress,
              ),
            )
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4.0);
}
