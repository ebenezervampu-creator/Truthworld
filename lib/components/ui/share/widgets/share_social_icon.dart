import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

class ShareSocialIcon extends StatelessWidget {
  const ShareSocialIcon({
    required this.label,
    required this.onTap,
    super.key,
    this.imageAsset,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final String? imageAsset;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E22),
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: Center(
                child: imageAsset != null
                    ? Image.asset(
                        imageAsset!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          icon ?? Icons.share_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      )
                    : Icon(
                        icon ?? Icons.share_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShareClipAppIcon extends StatelessWidget {
  const ShareClipAppIcon({
    required this.label,
    required this.gradient,
    required this.child,
    required this.onTap,
    super.key,
  });

  final String label;
  final Gradient gradient;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: Center(child: child),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShareTikTokActionButton extends StatelessWidget {
  const ShareTikTokActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A30),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white12,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
