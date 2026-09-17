import 'package:flutter/material.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/player_controls.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Reusable top header for player settings sub-panels.
class PanelHeader extends StatelessWidget {
  const PanelHeader({
    required this.title,
    required this.onBack,
    required this.onClose,
    this.onContinue,
    this.continueLabel = 'Continue',
    this.actionIcon,
    this.onAction,
    super.key,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final VoidCallback? onContinue;
  final String continueLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          if (onBack != null)
            IconBtn(icon: Icons.arrow_back_ios_new, onTap: onBack, size: 18)
          else
            const SizedBox(width: 8),
          Expanded(child: Text(title, style: TS.title)),
          if (onAction != null && actionIcon != null) ...[
            IconBtn(icon: actionIcon!, onTap: onAction, size: 20),
            const SizedBox(width: 4),
          ],
          if (onContinue != null) ...[
            TextButton(
              onPressed: onContinue,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                continueLabel,
                style: const TextStyle(
                  color: PT.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (onClose != null)
            IconBtn(icon: Icons.close_rounded, onTap: onClose, size: 20),
        ],
      ),
    );
  }
}

/// Navigation tile with icon, title, current value, and chevron.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    super.key,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TS.body.copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: PT.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: PT.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(badge!, style: TS.badge.copyWith(fontSize: 11)),
                ),
                const SizedBox(width: 6),
              ],
              if (value.isNotEmpty)
                Flexible(
                  child: Text(
                    value,
                    style: TS.bodySm,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textDisabled,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toggle switch tile with title and icon.
class ToggleTile extends StatelessWidget {
  const ToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textPrimary, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TS.body.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: PT.primary,
            activeTrackColor: PT.primary.withValues(alpha: 0.4),
            inactiveThumbColor: AppColors.textTertiary,
            inactiveTrackColor: AppColors.bgDivider,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

/// Radio-style selection row with optional badge and checkmark indicator.
class SelectTile extends StatelessWidget {
  const SelectTile({
    required this.label,
    required this.selected,
    super.key,
    this.sublabel,
    this.badge,
    this.dimmed = false,
    this.onTap,
    this.trailing,
  });

  final String label;
  final String? sublabel;
  final String? badge;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Row(
            children: [
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 26),
                  decoration: BoxDecoration(
                    color: selected
                        ? PT.primary.withValues(alpha: 0.15)
                        : AppColors.textPrimary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: selected
                          ? PT.primary.withValues(alpha: 0.5)
                          : AppColors.textPrimary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      badge!,
                      style: TS.badge.copyWith(
                        color: selected ? PT.primary : AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TS.body.copyWith(
                        color: dimmed
                            ? AppColors.textDisabled
                            : selected
                            ? PT.primary
                            : AppColors.textPrimary,
                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sublabel != null)
                      Text(
                        sublabel!,
                        style: TS.bodySm.copyWith(
                          color: dimmed
                              ? AppColors.bgDivider
                              : AppColors.textTertiary,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (selected)
                const Icon(Icons.check_rounded, color: AppColors.textPrimary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtle divider between player settings sections.
class PlayerDivider extends StatelessWidget {
  const PlayerDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(
    color: AppColors.textPrimary.withValues(alpha: 0.08),
    height: 12,
    indent: 20,
    endIndent: 20,
  );
}

/// Action button leading to language preferences configuration dialog.
class ConfigureLanguagesButton extends StatelessWidget {
  const ConfigureLanguagesButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.settings_suggest_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preferred Languages',
                      style: TS.bold.copyWith(fontSize: 14),
                    ),
                    Text(
                      'Set primary, secondary & known languages',
                      style: TS.bodySm.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textDisabled,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
