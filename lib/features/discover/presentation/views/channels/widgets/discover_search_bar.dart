import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_constants.dart';
import 'package:truthworld/features/search/presentation/widgets/voice_search_dialog.dart';

/// Interactive AI & text search bar for channel discovery matching Image 1.
class DiscoverSearchBar extends StatelessWidget {
  const DiscoverSearchBar({
    required this.controller,
    super.key,
    this.isMobile = false,
  });

  final DiscoverChannelsController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161619),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kDiscoverCardBorder,
        ),
      ),
      child: TextField(
        controller: controller.searchController,
        inputFormatters: [TruthworldTextInputFormatters.englishOnly],
        onChanged: controller.onSearchChanged,
        style: const TextStyle(
          color: primaryText,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText:
              'Ask AI or search channels (e.g. "Top verified science educators", "Emerging AI & robotics creators")...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 20,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                tooltip: 'Voice Search',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Get.dialog(
                    VoiceSearchDialog(
                      onSearch: (query) {
                        controller.searchController.text = query;
                        controller.onSearchChanged(query);
                      },
                    ),
                  );
                },
              ),
              Obx(
                () => controller.searchQuery.value.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        tooltip: 'Clear',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          controller.clearSearch();
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
