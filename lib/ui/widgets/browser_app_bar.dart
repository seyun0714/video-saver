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
      title: Row(
        children: [
          Expanded(
            child: TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: 'Enter URL and press Go',
              ),
              onSubmitted: (_) => onGo(),
            ),
          ),
          IconButton(onPressed: onGo, icon: const Icon(Icons.arrow_forward)),
        ],
      ),
      actions: [
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
