import 'package:flutter/material.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/topic_selection/topic_selection_host.dart';
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
  final TopicSelectionHost controller;

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
                      'Save Video to Topics',
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          'Select up to 3 topics',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                            color: subtextColor,
                          ),
                        ),
                        Builder(
                          builder: (context) {
                            final total = controller.selectedTopicIds != null
                                ? controller.selectedTopicIds!.length
                                : (controller.selectedTopicId.value.isNotEmpty ? 1 : 0);
                            final ownCount = controller.selectedOwnTopicsCount;
                            final publicCount = controller.selectedPublicTopicsCount;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: total > 0
                                    ? const Color(0xFF0284C7).withValues(alpha: 0.2)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: total > 0 ? const Color(0xFF38BDF8) : borderColor,
                                ),
                              ),
                              child: Text(
                                '$total/3 Selected ($ownCount own, $publicCount public)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: total > 0 ? const Color(0xFF38BDF8) : subtextColor,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
  final TopicSelectionHost controller;
  final Function(bool isDark) onCreateNewTopicRequested;

  @override
  Widget build(BuildContext context) {
    final query = controller.topicSearchQuery.value;

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
              maxLength: defaultMaxSearchLength,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: TruthworldTextInputFormatters.withLimit(defaultMaxSearchLength),
              onChanged: (val) {
                controller.topicSearchQuery.value = val;
              },
              style: AppTextStyles.bodyMedium.copyWith(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search topics or handles...',
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
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            onCreateNewTopicRequested(isDark);
          },
          icon: Icon(
            Icons.add_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            size: 18,
          ),
          label: Text(
            'New Topic',
            style: AppTextStyles.buttonText.copyWith(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 13,
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            side: BorderSide(color: borderColor),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
