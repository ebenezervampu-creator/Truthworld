import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Top desktop navigation bar matching playlist theme
Widget buildCreateTopicDesktopTopHeader(BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    decoration: BoxDecoration(
      color: context.colors.background,
      border: Border(
        bottom: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
    ),
    child: Row(
      children: [
        // Logo
        Row(
          children: [
            const AppLogo(
              size: 26,
              borderRadius: 6,
            ),
            const SizedBox(width: 8),
            Text(
              'TRUTHWORLD',
              style: context.themeTypography.logo.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(width: 48),

        // Search Bar
        Expanded(
          child: Container(
            height: 40,
            constraints: const BoxConstraints(maxWidth: 540),
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: TextField(
              inputFormatters: [TruthworldTextInputFormatters.englishOnly],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search videos, channels, topics...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white,
                  size: 18,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),

        // Right Action Controls
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
          onPressed: () {},
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF333333),
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white.withValues(alpha: 0.7),
              size: 18,
            ),
          ],
        ),
      ],
    ),
  );
}

/// Page header with back arrow, title, and descriptive subtitle
Widget buildCreateTopicPageHeader(BuildContext context, {required bool isDesktop}) {
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
            'Create Topic',
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
          'Build a topic to organize and curate videos around a theme.',
          style: context.themeTypography.body.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: isDesktop ? 14 : 12,
          ),
        ),
      ),
    ],
  );
}
