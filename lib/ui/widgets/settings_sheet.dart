// lib/ui/widgets/settings_sheet.dart
import 'package:flutter/material.dart';
import 'package:video_saver/services/settings_service.dart';

Future<void> showSettingsSheet({
  required BuildContext context,
  required SettingsService settingsService,
  required VoidCallback onSettingsSaved,
}) async {
  // --- 👇 [수정] whitelist 관련 controller 삭제 ---
  // final controller = TextEditingController(text: settingsService.whitelist.join('\n'));
  bool wifiOnly = settingsService.wifiOnly;
  // --- 👆 [수정] ---

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) {
      return StatefulBuilder(
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
                  // --- 👇 [수정] 허용 도메인 UI 부분 전체 삭제 ---
                  // const Text('허용 도메인...'),
                  // const SizedBox(height: 8),
                  // TextField(...),
                  // const SizedBox(height: 12),
                  // --- 👆 [수정] ---
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
    // --- 👇 [수정] whitelist 관련 로직 삭제 ---
    // final newWhitelist = controller.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    await settingsService.saveSettings(newWifiOnly: wifiOnly);
    // --- 👆 [수정] ---
    onSettingsSaved();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('설정을 저장했어요.')));
    }
  }
}
