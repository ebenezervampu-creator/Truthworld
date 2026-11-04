import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_constants.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Empty state widget for channel discovery when no channels match active filters or search queries.
/// Features high-converting pioneer creator call-to-action for nascent categories while preserving backward compatibility.
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
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: buttonBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.explore_off_outlined,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                    const SizedBox(height: 10),
                    Text(
                      isCategorySelected
                          ? 'Be the first creator in $catName! Start your channel today and reach audiences on TruthWorld.'
                          : 'Try adjusting your search query or reset your filters to discover new creators.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: secondaryText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Primary Action: Pioneer Channel CTA
                    if (isCategorySelected) ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Get.toNamed('/channelscreen');
                        },
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 18,
                          color: Colors.black,
                        ),
                        label: Text(
                          'Create $catName Channel',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Secondary Action: Explore All Categories / Reset Filters
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
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        isCategorySelected
                            ? 'Explore All Categories'
                            : 'Explore All Channels',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: primaryText,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: buttonBg,
                        side: BorderSide(
                          color: AppColors.textPrimary.withValues(alpha: 0.12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
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
