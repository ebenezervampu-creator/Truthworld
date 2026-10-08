import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/search/presentation/widgets/voice_search_dialog.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';

/// Top header bar for Following Topics page matching the sleek, modern dark UI:
/// - Back button (white arrow icon)
/// - Fully rounded pill search bar with prefix search icon
/// - Subtle dark fill (`#1E1E22`), grey placeholder text
/// - Integrated voice search microphone button & clear action
/// - Responsive max-width alignment for desktop and tablet screens
class FollowingTopicsHeader extends StatelessWidget {
  const FollowingTopicsHeader({
    required this.controller,
    required this.isMobile,
    required this.isDashboard,
    super.key,
  });

  final FollowingTopicsController controller;
  final bool isMobile;
  final bool isDashboard;

  void _handleBack() {
    if (isDashboard) {
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().sideNavSelectedIndex.value =
            HomeController.indexLibrary;
      } else {
        Get.back<void>();
      }
    } else {
      Get.back<void>();
    }
  }

  void _handleVoiceSearch(BuildContext context) {
    HapticFeedback.lightImpact();
    Get.dialog<void>(
      VoiceSearchDialog(
        onSearch: (query) {
          controller.searchController.text = query;
          controller.updateSearchQuery(query);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchController = controller.searchController;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 20,
            vertical: 10,
          ),
          child: Row(
            children: [
              // Back Button
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: 'Back',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                onPressed: _handleBack,
              ),
              const SizedBox(width: 8),

              // Rounded Search Pill with Mic Action
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E22),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 14, right: 10),
                        child: Icon(
                          Icons.search_rounded,
                          color: Color(0xFF8E8E93),
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search followed topics...',
                            hintStyle: TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 11),
                            isDense: true,
                          ),
                        ),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: searchController,
                        builder: (context, value, _) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (value.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFF8E8E93),
                                    size: 18,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  onPressed: controller.clearSearch,
                                ),
                              IconButton(
                                icon: const Icon(
                                  Icons.mic_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                tooltip: 'Voice search',
                                padding: const EdgeInsets.only(right: 8, left: 4),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed: () => _handleVoiceSearch(context),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
