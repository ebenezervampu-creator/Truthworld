import 'package:flutter/material.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';

class IconBtn extends StatelessWidget {
  const IconBtn({required this.icon, super.key, this.onTap, this.size = 26});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: PT.primary.withValues(alpha: 0.2),
        highlightColor: PT.primary.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: AppColors.textPrimary, size: size),
        ),
      ),
    );
  }
}

class CenterBtn extends StatelessWidget {
  const CenterBtn({
    required this.icon,
    super.key,
    this.onTap,
    this.size = 44,
    this.isPrimary = false,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: AppColors.textPrimary.withValues(alpha: 0.2),
        child: Container(
          padding: EdgeInsets.all(isPrimary ? 14 : 10),
          decoration: BoxDecoration(
            color: AppColors.bgPage.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Icon(icon, size: size, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class PremiumButton extends StatelessWidget {
  const PremiumButton({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PT.primary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileAutoplaySwitch extends StatelessWidget {
  const MobileAutoplaySwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value ? AppColors.textPrimary : AppColors.textDisabled,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? const Color(0xFF1E1E1E) : AppColors.textSecondary,
            ),
            child: Icon(
              value ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 14,
              color: value ? AppColors.textPrimary : const Color(0xFF1E1E1E),
            ),
          ),
        ),
      ),
    );
  }
}
