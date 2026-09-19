import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Reusable section container card for the community upload workflow.
class CommunityUploadSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final String? subtitle;
  final Widget? titleAction;

  const CommunityUploadSectionCard({
    required this.title,
    required this.children,
    super.key,
    this.subtitle,
    this.titleAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.divider.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.twTypography.title.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              ?titleAction,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: context.twTypography.caption.copyWith(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}
