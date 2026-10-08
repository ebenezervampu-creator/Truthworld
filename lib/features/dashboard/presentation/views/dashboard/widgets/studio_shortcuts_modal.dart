import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog displaying all Creator Studio desktop hotkeys.
class StudioShortcutsModal extends StatelessWidget {
  const StudioShortcutsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const StudioShortcutsModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.keyboard_outlined,
                          color: AppColors.brand,
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Creator Studio Keyboard Shortcuts',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontFamily: TWTypography.brandFamily,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Navigation & Global Actions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              _buildShortcutRow(
                keys: ['/'],
                description: 'Focus Studio search',
              ),
              _buildShortcutRow(
                keys: ['Ctrl', 'S'],
                description: 'Save active draft or form metadata',
              ),
              _buildShortcutRow(
                keys: ['?'],
                description: 'Show this keyboard shortcuts guide',
              ),
              _buildShortcutRow(
                keys: ['Esc'],
                description: 'Close active dialog, sheet, or clear focus',
              ),
              const SizedBox(height: 18),
              const Text(
                'Video Player & Timeline Scrubbing (NLE Standard)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              _buildShortcutRow(
                keys: ['Space', 'or', 'K'],
                description: 'Play / Pause preview',
              ),
              _buildShortcutRow(
                keys: ['J'],
                description: 'Rewind 10 seconds (tap repeatedly to scrub backward)',
              ),
              _buildShortcutRow(
                keys: ['L'],
                description: 'Fast-forward 10 seconds (tap repeatedly to scrub forward)',
              ),
              _buildShortcutRow(
                keys: ['←', '→'],
                description: 'Seek backward / forward by 5 seconds',
              ),
              _buildShortcutRow(
                keys: ['M'],
                description: 'Toggle audio mute',
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutRow({
    required List<String> keys,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontFamily: TWTypography.uiFamily,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: keys.map((key) {
              if (key == 'or') {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    'or',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  ),
                );
              }
              return Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Text(
                  key,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
