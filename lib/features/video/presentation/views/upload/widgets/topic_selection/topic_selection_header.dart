import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Drag handle and top header bar with title, AI hub subtitle, refresh, and close controls.
class TopicSelectionTopHeader extends StatelessWidget {
  const TopicSelectionTopHeader({
    required this.isDark,
    required this.textColor,
    required this.subtextColor,
    required this.borderColor,
    required this.controller,
    super.key,
  });

  final bool isDark;
  final Color textColor;
  final Color subtextColor;
  final Color borderColor;
  final dynamic controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4.5,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.topic_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Save Video to Topic',
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'AI Topic Recommendation Hub',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  if (controller?.fetchAvailableTopics != null) {
                    controller.fetchAvailableTopics();
                  }
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                tooltip: 'Refresh recommendations',
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        Divider(height: 1, color: borderColor),
      ],
    );
  }
}

/// Integrated search field and "New Topic" creation button.
class TopicSelectionSearchBar extends StatelessWidget {
  const TopicSelectionSearchBar({
    required this.isDark,
    required this.textColor,
    required this.subtextColor,
    required this.borderColor,
    required this.controller,
    required this.onCreateNewTopicRequested,
    super.key,
  });

  final bool isDark;
  final Color textColor;
  final Color subtextColor;
  final Color borderColor;
  final dynamic controller;
  final Function(bool isDark) onCreateNewTopicRequested;

  @override
  Widget build(BuildContext context) {
    final query = controller?.topicSearchQuery?.value as String? ?? '';

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B26) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              onChanged: (val) {
                if (controller?.topicSearchQuery != null) {
                  controller.topicSearchQuery.value = val;
                }
              },
              style: AppTextStyles.bodyMedium.copyWith(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search topics by title, category, handle...',
                hintStyle: AppTextStyles.caption.copyWith(color: subtextColor, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.white, size: 18),
                        onPressed: () => controller.topicSearchQuery.value = '',
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            onCreateNewTopicRequested(isDark);
          },
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
          label: Text(
            'New Topic',
            style: AppTextStyles.buttonText.copyWith(color: Colors.white, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}
