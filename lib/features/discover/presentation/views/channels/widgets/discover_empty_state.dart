import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_constants.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Empty state widget for channel discovery when no channels match active filters or search queries.
class DiscoverEmptyState extends StatelessWidget {
  const DiscoverEmptyState({
    required this.controller,
    super.key,
  });

  final DiscoverChannelsController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: buttonBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.explore_off_outlined,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Obx(() {
                final isCategorySelected =
                    controller.selectedCategory.value != 'All';
                final catName = controller.selectedCategory.value;

                return Column(
                  children: [
                    Text(
                      isCategorySelected
                          ? 'No $catName channels found'
                          : 'No channels found',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isCategorySelected
                          ? 'There are currently no active channels in $catName. Check back soon or explore other categories.'
                          : 'Try adjusting your search query to discover new creators.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: secondaryText),
                    ),
                    const SizedBox(height: 28),
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        controller.clearSearch();
                        controller.selectCategory('All');
                      },
                      icon: Icon(
                        isCategorySelected
                            ? Icons.explore_rounded
                            : Icons.refresh_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: Text(
                        isCategorySelected
                            ? 'Explore All Categories'
                            : 'Explore All Channels',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: primaryText,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: buttonBg,
                        side: BorderSide(
                          color: AppColors.textPrimary.withValues(alpha: 0.1),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
