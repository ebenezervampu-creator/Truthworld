import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/search/presentation/widgets/voice_search_dialog.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';

/// GetX controller managing search bar focus and hover reactivity without setState.
class FollowingTopicsSearchBarController extends GetxController {
  final FocusNode focusNode = FocusNode();
  final RxBool isFocused = false.obs;
  final RxBool isHovered = false.obs;

  @override
  void onInit() {
    super.onInit();
    focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    isFocused.value = focusNode.hasFocus;
  }

  @override
  void onClose() {
    focusNode.removeListener(_handleFocusChange);
    focusNode.dispose();
    super.onClose();
  }
}

/// Top header bar for Following Topics page with professional interactive search textfield:
/// - Ergonomic back navigation button with subtle hover styling
/// - Fully interactive animated pill search bar with luminous focus glow and hover state
/// - Polished typography, high-contrast white cursor, and crisp hint styling
/// - Integrated reactive clear button & voice search microphone with haptic feedback
/// - Responsive alignment for mobile, tablet, and desktop viewports
class FollowingTopicsHeader extends StatelessWidget {
  const FollowingTopicsHeader({
    required this.controller,
    required this.isMobile,
    required this.isDashboard,
    this.isTablet = false,
    this.isDesktop = false,
    super.key,
  });

  final FollowingTopicsController controller;
  final bool isMobile;
  final bool isDashboard;
  final bool isTablet;
  final bool isDesktop;

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
      useSafeArea: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchController = controller.searchController;
    final canPop = Navigator.of(context).canPop();
    final showBackButton = !isDashboard || canPop;

    final searchBarController = Get.isRegistered<FollowingTopicsSearchBarController>(
      tag: controller.hashCode.toString(),
    )
        ? Get.find<FollowingTopicsSearchBarController>(tag: controller.hashCode.toString())
        : Get.put(
            FollowingTopicsSearchBarController(),
            tag: controller.hashCode.toString(),
          );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 20,
            vertical: 10,
          ),
          child: Row(
            children: [
              // Back Button (shown if standalone route or can pop)
              if (showBackButton) ...[
                Tooltip(
                  message: 'Back',
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: _handleBack,
                      child: Container(
                        width: isMobile ? 40 : 42,
                        height: isMobile ? 40 : 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // Professional Interactive Pill Search Bar
              Expanded(
                child: MouseRegion(
                  onEnter: (_) => searchBarController.isHovered.value = true,
                  onExit: (_) => searchBarController.isHovered.value = false,
                  cursor: SystemMouseCursors.text,
                  child: Obx(() {
                    final isFocused = searchBarController.isFocused.value;
                    final isHovered = searchBarController.isHovered.value;

                    final borderColor = isFocused
                        ? Colors.white.withValues(alpha: 0.85)
                        : (isHovered
                            ? Colors.white.withValues(alpha: 0.28)
                            : Colors.white.withValues(alpha: 0.12));

                    final fieldBgColor = isFocused
                        ? const Color(0xFF1B1B20)
                        : (isHovered
                            ? const Color(0xFF17171C)
                            : const Color(0xFF141418));

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      height: isMobile ? 44 : 46,
                      decoration: BoxDecoration(
                        color: fieldBgColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: borderColor,
                          width: isFocused ? 1.5 : 1.0,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.07),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 14, right: 10),
                            child: Icon(
                              Icons.search_rounded,
                              color: isFocused
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.65),
                              size: 20,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              focusNode: searchBarController.focusNode,
                              maxLength: ContentValidator.defaultMaxSearchLength,
                              buildCounter: (
                                context, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) =>
                                  null,
                              inputFormatters:
                                  TruthworldTextInputFormatters.withLimit(
                                ContentValidator.defaultMaxSearchLength,
                              ),
                              textInputAction: TextInputAction.search,
                              onSubmitted: controller.updateSearchQuery,
                              onChanged: controller.updateSearchQuery,
                              cursorColor: Colors.white,
                              cursorWidth: 1.8,
                              cursorRadius: const Radius.circular(2),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.1,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search followed topics...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.42),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.1,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: isMobile ? 11 : 12,
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                          Obx(() {
                            final hasText =
                                controller.searchQuery.value.isNotEmpty ||
                                    searchController.text.isNotEmpty;

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasText)
                                  Tooltip(
                                    message: 'Clear search',
                                    child: Material(
                                      type: MaterialType.transparency,
                                      child: InkWell(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          controller.clearSearch();
                                          searchBarController.focusNode
                                              .requestFocus();
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(7),
                                          child: Icon(
                                            Icons.close_rounded,
                                            color: Colors.white
                                                .withValues(alpha: 0.75),
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Tooltip(
                                  message: 'Voice search',
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: InkWell(
                                      borderRadius:
                                          BorderRadius.circular(18),
                                      onTap: () =>
                                          _handleVoiceSearch(context),
                                      child: Padding(
                                        padding: const EdgeInsets.all(7),
                                        child: Icon(
                                          Icons.mic_rounded,
                                          color: isFocused
                                              ? Colors.white
                                              : Colors.white
                                                  .withValues(alpha: 0.85),
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
