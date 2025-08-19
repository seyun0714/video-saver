// lib/ui/widgets/browser_app_bar.dart
import 'package:flutter/material.dart';

class BrowserAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController urlController;
  final VoidCallback onGo;
  final VoidCallback onOpenSettings;
  final double progress;

  const BrowserAppBar({
    super.key,
    required this.urlController,
    required this.onGo,
    required this.onOpenSettings,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      // leading (뒤로가기 버튼) 제거
      title: TextField(
        // 👈 TextField를 Row 바깥으로 빼서 전체 너비 사용
        controller: urlController,
        decoration: InputDecoration(
          hintText: 'URL 입력',
          // 검색(이동) 버튼을 TextField 안에 아이콘으로 배치
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            onPressed: onGo,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        onSubmitted: (_) => onGo(),
      ),
      actions: [
        // 설정 버튼만 남김
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: onOpenSettings,
        ),
      ],
      bottom: progress < 1.0
          ? PreferredSize(
              preferredSize: const Size.fromHeight(3.0),
              child: LinearProgressIndicator(
                value: progress == 0 ? null : progress,
                minHeight: 3.0,
              ),
            )
          : null,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (progress < 1.0 ? 3.0 : 0.0));
}
