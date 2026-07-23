import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';

class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  static const _shortcuts = [
    {
      'keys': ['Space', 'K'],
      'action': 'Play / Pause',
    },
    {
      'keys': ['J'],
      'action': 'Seek backward 10 seconds',
    },
    {
      'keys': ['L'],
      'action': 'Seek forward 10 seconds',
    },
    {
      'keys': ['←'],
      'action': 'Seek backward 5 seconds',
    },
    {
      'keys': ['→'],
      'action': 'Seek forward 5 seconds',
    },
    {
      'keys': ['↑'],
      'action': 'Volume up 10%',
    },
    {
      'keys': ['↓'],
      'action': 'Volume down 10%',
    },
    {
      'keys': ['M'],
      'action': 'Mute / Unmute audio',
    },
    {
      'keys': ['F'],
      'action': 'Toggle fullscreen',
    },
    {
      'keys': ['I'],
      'action': 'Toggle Picture-in-Picture',
    },
    {
      'keys': [','],
      'action': 'Rewind 1 second',
    },
    {
      'keys': ['.'],
      'action': 'Advance 1 second',
    },
    {
      'keys': ['?'],
      'action': 'Show keyboard shortcuts',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 420,
          constraints: const BoxConstraints(maxHeight: 520),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.bgDivider),
            boxShadow: [
              BoxShadow(
                color: AppColors.bgPage.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Keyboard Shortcuts',
                      style: TS.title.copyWith(fontSize: 18),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: Get.back,
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.bgDivider, height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _shortcuts.length,
                  itemBuilder: (_, i) {
                    final item = _shortcuts[i];
                    final keys = item['keys']! as List<String>;
                    final action = item['action']! as String;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              action,
                              style: TS.bodySm.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                          Wrap(
                            spacing: 4,
                            children: keys
                                .map(
                                  (k) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.textPrimary.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.bgDivider),
                                    ),
                                    child: Text(
                                      k,
                                      style: TS.mono.copyWith(
                                        color: AppColors.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FULLSCREEN ACTIONS & POPUPS
// ─────────────────────────────────────────────────────────────────────────────
