import 'package:flutter/material.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Post Content for Community Post Card
/// Renders clickable description text with automatic URL detection and styling.
class CommunityPostContent extends StatelessWidget {
  const CommunityPostContent({
    required this.description,
    super.key,
  });

  final String description;

  @override
  Widget build(BuildContext context) {
    if (description.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClickableUrlText(
        text: description,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
      ),
    );
  }
}
