import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_mode_switcher.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_options_state.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Displays an interactive bottom sheet to select Voice Gender ('auto', 'male', 'female').
void showVoiceGenderPicker(BuildContext context, DubbingOptionsState state) {
  final colors = context.colors;
  final typography = context.twTypography;

  const options = <({String id, String label, String subtitle, IconData icon})>[
    (
      id: 'auto',
      label: 'Auto',
      subtitle: "Automatically match the original speaker's vocal profile.",
      icon: Icons.auto_awesome_rounded,
    ),
    (
      id: 'male',
      label: 'Male',
      subtitle: 'Synthesize audio using a natural male voice profile.',
      icon: Icons.male_rounded,
    ),
    (
      id: 'female',
      label: 'Female',
      subtitle: 'Synthesize audio using a natural female voice profile.',
      icon: Icons.female_rounded,
    ),
  ];

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
        ),
        child: Material(
          color: colors.appBarSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Voice Gender',
                  style: typography.headline.copyWith(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: 18,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose the voice gender used for dubbed audio tracks.',
                  style: typography.bodySmall.copyWith(
                    fontSize: 12.5,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Obx(() {
                  final current = state.selectedVoiceGender.value;
                  return Column(
                    children: [
                      for (var i = 0; i < options.length; i++) ...[
                        _GenderOptionTile(
                          label: options[i].label,
                          subtitle: options[i].subtitle,
                          icon: options[i].icon,
                          isSelected: current == options[i].id,
                          onTap: () {
                            state.selectedVoiceGender.value = options[i].id;
                            Navigator.pop(sheetContext);
                          },
                        ),
                        if (i < options.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  );
                }),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _GenderOptionTile extends StatelessWidget {
  const _GenderOptionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.twTypography;
    const radius = BorderRadius.all(Radius.circular(12));

    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.brand.withValues(alpha: 0.08)
              : colors.surfaceInput,
          borderRadius: radius,
          border: Border.all(
            color: isSelected
                ? colors.brand.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.textPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: typography.title.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: typography.bodySmall.copyWith(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? colors.brand : Colors.transparent,
                border: Border.all(
                  color: isSelected ? colors.brand : colors.textTertiary,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.black,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Clean standalone settings cards matching the redesigned UI:
/// 1. Voice Cloning toggle card
/// 2. Speaker Diarization toggle card
/// 3. Voice Gender selector card
class DubbingSettingsCard extends StatelessWidget {
  const DubbingSettingsCard({
    required this.state,
    super.key,
  });

  final DubbingOptionsState state;

  String _formatVoiceGenderLabel(String gender) {
    switch (gender) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      default:
        return 'Auto';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.twTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Voice Cloning Card
        Obx(() {
          final isCloned = state.voiceType.value == 'cloned';
          return _ToggleOptionCard(
            icon: Icons.mic_none_rounded,
            title: 'Voice Cloning',
            subtitle: "Use the original speaker's voice.",
            value: isCloned,
            onChanged: (val) =>
                state.voiceType.value = val ? 'cloned' : 'standard',
          );
        }),

        const SizedBox(height: 12),

        // 2. Speaker Diarization Card
        Obx(() {
          final enabled = state.enableDiarization.value;
          return _ToggleOptionCard(
            icon: Icons.groups_rounded,
            title: 'Speaker Diarization',
            subtitle: 'Detect and separate multiple speakers.',
            value: enabled,
            onChanged: (val) => state.enableDiarization.value = val,
          );
        }),

        const SizedBox(height: 12),

        // 3. Voice Gender Card
        DubbingOptionCard(
          onTap: () => showVoiceGenderPicker(context, state),
          child: Row(
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                size: 22,
                color: colors.textPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Voice Gender',
                  style: typography.title.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Obx(() {
                final label = _formatVoiceGenderLabel(
                  state.selectedVoiceGender.value,
                );
                return Text(
                  label,
                  style: typography.body.copyWith(
                    fontSize: 14.5,
                    color: colors.textSecondary,
                  ),
                );
              }),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToggleOptionCard extends StatelessWidget {
  const _ToggleOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.twTypography;

    return DubbingOptionCard(
      onTap: () => onChanged(!value),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: colors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: typography.title.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: typography.bodySmall.copyWith(
                    fontSize: 12.5,
                    color: colors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? Colors.black
                  : Colors.white;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? Colors.white
                  : const Color(0xFF3A3A3D);
            }),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}
