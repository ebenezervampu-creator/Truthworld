import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_preferences.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Styling extension providing luxury theme accent palettes.
extension AudioPlayerThemeStyling on AudioPlayerTheme {
  Color get accentColor {
    switch (this) {
      case AudioPlayerTheme.fluidAura:
        return const Color(0xFF6366F1); // Indigo Fluid Aura
      case AudioPlayerTheme.kineticSyllable:
        return const Color(0xFFA78BFA); // Soft Lavender Transcript
      case AudioPlayerTheme.audiophileSpectral:
        return const Color(0xFF10B981); // Emerald Precision Spectrum
      case AudioPlayerTheme.obsidianMinimalist:
        return const Color(0xFFFFFFFF); // Pure White Minimalist Accent
      case AudioPlayerTheme.truthPulseHologram:
        return const Color(0xFF38BDF8); // Cyan Hologram Pulse
    }
  }
}

/// Modal bottom sheet for displaying and switching audio visualizer themes.
/// Follows the exact bottom-sheet popup architecture used in VideoChaptersBottomSheet.
class AudioThemesBottomSheet extends StatelessWidget {
  const AudioThemesBottomSheet({
    super.key,
    this.ctrl,
    this.videoTag,
  });

  final TowerPlayerController? ctrl;
  final String? videoTag;

  static void show(
    BuildContext context, {
    TowerPlayerController? ctrl,
    String? videoTag,
  }) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (context) => AudioThemesBottomSheet(
          ctrl: ctrl,
          videoTag: videoTag,
        ),
      ),
    );
  }

  TowerPlayerController? _getPlayerController() {
    try {
      if (ctrl != null) return ctrl;
      if (videoTag != null &&
          Get.isRegistered<TowerPlayerController>(tag: videoTag)) {
        return Get.find<TowerPlayerController>(tag: videoTag);
      }
      if (Get.isRegistered<TowerPlayerController>()) {
        return Get.find<TowerPlayerController>();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'AudioThemesBottomSheet.getPlayerController',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final playerCtrl = _getPlayerController();

    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              // Drag Indicator Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.palette_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Audio Themes',
                          style: context.twTypography.headline.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Subtitle
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select visual styling for audio-only mode',
                    style: context.twTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

              const Divider(height: 1, color: AppColors.bgDivider),

              // Theme List
              Expanded(
                child: Obx(() {
                  final activeTheme =
                      TowerPlayerPreferences.globalAudioTheme.value;

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: AudioPlayerTheme.values.length,
                    itemBuilder: (context, index) {
                      final theme = AudioPlayerTheme.values[index];
                      final isSelected = activeTheme == theme;

                      return AudioThemeTile(
                        theme: theme,
                        isSelected: isSelected,
                        onTap: () {
                          TowerPlayerPreferences.globalAudioThemeValue = theme;
                          playerCtrl?.showToast(
                            'Theme set: ${theme.displayName}',
                          );
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Interactive Audio Theme selection card adhering to high visual contrast and TruthWorld design guidelines.
class AudioThemeTile extends StatelessWidget {
  const AudioThemeTile({
    required this.theme,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final AudioPlayerTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = theme.accentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.bgSurfaceHover
                  : Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? accent.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.06),
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Visual Preview Box with Theme Icon & Accent Tint
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accent.withValues(alpha: isSelected ? 0.4 : 0.2),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      theme.icon,
                      size: 24,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Theme Display Name & Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              theme.displayName,
                              style: context.twTypography.title.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        theme.description,
                        style: context.twTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Trailing Selection Indicator (High Contrast: Black on White Circle when selected)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.white : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textTertiary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Center(
                          child: Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.black, // WCAG AA Compliant black-on-white
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
