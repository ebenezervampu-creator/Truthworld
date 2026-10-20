import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/user_clips_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class ClipsHeader extends StatelessWidget {
  const ClipsHeader({
    required this.controller,
    required this.isDashboard,
    super.key,
  });

  final UserClipsController controller;
  final bool isDashboard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, isDashboard ? 16 : 48, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Obx(
              () => controller.isSearchExpanded.value
                  ? Container(
                      height: 40,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.bgDivider.withValues(alpha: 0.5),
                        ),
                      ),
                      child: TextField(
                        maxLength: defaultMaxSearchLength,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        inputFormatters: TruthworldTextInputFormatters.withLimit(defaultMaxSearchLength),
                        onChanged: (value) =>
                            controller.searchQuery.value = value,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search clips...',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.textPrimary,
                              size: 18,
                            ),
                            onPressed: () {
                              controller.isSearchExpanded.value = false;
                              controller.searchQuery.value = '';
                            },
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () {
                            if (isDashboard) {
                              if (Get.isRegistered<HomeController>()) {
                                Get.find<HomeController>()
                                        .sideNavSelectedIndex
                                        .value =
                                    HomeController.indexLibrary;
                              }
                            } else {
                              Get.back<void>();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Your Clips',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Obx(
            () => !controller.isSearchExpanded.value
                ? IconButton(
                    icon: const Icon(
                      Icons.search,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () => controller.isSearchExpanded.value = true,
                  )
                : const SizedBox.shrink(),
          ),
          IconButton(
            icon: Obx(
              () => Icon(
                controller.isListView.value
                    ? Icons.grid_view_rounded
                    : Icons.view_list_rounded,
                color: AppColors.textPrimary,
              ),
            ),
            onPressed: controller.toggleView,
          ),
        ],
      ),
    );
  }
}

class ClipsCategoryChips extends StatelessWidget {
  const ClipsCategoryChips({
    required this.controller,
    super.key,
  });

  final UserClipsController controller;

  @override
  Widget build(BuildContext context) {
    const categories = ['All', 'Recent'];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Obx(() {
            final isSelected = controller.selectedCategory.value == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) controller.setCategory(category);
                },
                selectedColor: AppColors.textPrimary,
                backgroundColor: AppColors.bgSurfaceHover,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.bgPage : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                showCheckmark: false,
              ),
            );
          });
        },
      ),
    );
  }
}
