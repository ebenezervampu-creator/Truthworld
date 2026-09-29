import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    this.icon,
    this.child,
    super.key,
    this.onTap,
    this.size = 26,
    this.buttonDiameter,
    this.isPrimary = false,
    this.tooltip,
  }) : assert(icon != null || child != null, 'Either icon or child must be provided');
  final IconData? icon;
  final Widget? child;
  final VoidCallback? onTap;
  final double size;
  final double? buttonDiameter;
  final bool isPrimary;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final diameter = buttonDiameter ?? (isPrimary ? 72.0 : 52.0);
    final isHovered = false.obs;

    final Widget btn = MouseRegion(
      onEnter: (_) => isHovered.value = true,
      onExit: (_) => isHovered.value = false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          splashColor: Colors.white.withValues(alpha: 0.18),
          highlightColor: Colors.white.withValues(alpha: 0.10),
          child: Obx(
            () => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: diameter,
              height: diameter,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // Permanent high-contrast frosted glass backing disc
                // Guarantees maximum contrast even against pure white video scenes
                color: isHovered.value
                    ? (isPrimary
                        ? const Color(0xD90A0A0E)
                        : const Color(0xBF0A0A0E))
                    : (isPrimary
                        ? const Color(0x990A0A0E)
                        : const Color(0x800A0A0E)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isHovered.value
                      ? Colors.white.withValues(alpha: isPrimary ? 0.45 : 0.32)
                      : Colors.white.withValues(alpha: isPrimary ? 0.22 : 0.16),
                  width: isPrimary ? 1.5 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isHovered.value ? 0.65 : 0.45,
                    ),
                    blurRadius: isHovered.value
                        ? (isPrimary ? 22 : 16)
                        : (isPrimary ? 16 : 10),
                    spreadRadius: isHovered.value ? 2 : 1,
                    offset: Offset(0, isHovered.value ? 3 : 2),
                  ),
                ],
              ),
              child: Center(
                child: child ??
                    Icon(
                      icon,
                      size: size,
                      color: AppColors.textPrimary,
                      shadows: const [
                        Shadow(
                          color: Color(0xCC000000),
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
              ),
            ),
          ),
        ),
      ),
    );

    final tip = tooltip;
    if (tip != null && tip.isNotEmpty) {
      return Tooltip(
        message: tip,
        waitDuration: const Duration(milliseconds: 400),
        child: btn,
      );
    }

    return btn;
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
