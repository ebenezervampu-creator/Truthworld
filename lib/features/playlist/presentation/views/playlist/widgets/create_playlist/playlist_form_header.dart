import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Responsive header for the Create Playlist screen.
class PlaylistFormHeader extends StatelessWidget {
  const PlaylistFormHeader({
    required this.isDesktop,
    super.key,
  });

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: Get.back,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            Text(
              'Create Playlist',
              style: context.themeTypography.display.copyWith(
                fontSize: isDesktop ? 26 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Text(
            'Organize videos into a playlist and share with your audience.',
            style: context.themeTypography.body.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: isDesktop ? 14 : 12,
            ),
          ),
        ),
      ],
    );
  }
}
