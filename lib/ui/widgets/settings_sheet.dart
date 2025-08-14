// lib/ui/widgets/settings_sheet.dart
import 'package:flutter/material.dart';
import 'package:video_saver/services/settings_service.dart';

Future<void> showSettingsSheet({
  required BuildContext context,
  required SettingsService settingsService,
  required VoidCallback onSettingsSaved,
}) async {
  final controller = TextEditingController(
    text: settingsService.whitelist.join('\n'),
  );
  bool wifiOnly = settingsService.wifiOnly;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true, // 키보드가 올라올 때 UI가 가려지지 않도록 함
    builder: (_) {
      return StatefulBuilder(
        // BottomSheet 내부에서 상태 변경을 위해 사용
        builder: (BuildContext context, StateSetter setState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '허용 도메인 (줄바꿈으로 구분)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'example.org\nmysite.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('와이파이에서만 다운로드'),
                    value: wifiOnly,
                    onChanged: (v) => setState(() => wifiOnly = v),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('저장'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (result == true) {
    final newWhitelist = controller.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await settingsService.saveSettings(
      newWhitelist: newWhitelist,
      newWifiOnly: wifiOnly,
    );
    onSettingsSaved();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('설정을 저장했어요.')));
    }
  }
}
