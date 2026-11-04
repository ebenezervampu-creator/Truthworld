import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audience/audience_components.dart';
import 'package:truthworld/theme/app_theme.dart';

class AudiencePage extends StatelessWidget {
  const AudiencePage({
    required this.channelId,
    required this.isDarkMode,
    super.key,
  });
  final String channelId;
  final bool isDarkMode;

  AudienceController get controller {
    final ctrl = Get.isRegistered<AudienceController>()
        ? Get.find<AudienceController>()
        : Get.put(AudienceController(initialChannelId: channelId));
    if (channelId.isNotEmpty && ctrl.channelId != channelId) {
      ctrl.setChannelContext(channelId);
    }
    return ctrl;
  }

  @override
  Widget build(BuildContext context) {
    const surfaceColor = AppColors.bgSurface;
    const backgroundColor = AppColors.bgPage;
    const textColor = AppColors.textPrimary;
    const subtitleColor = AppColors.textSecondary;
    const borderColor = AppColors.bgDivider;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Obx(() {
        if (controller.state == ViewState.loading && controller.allCountryItems.isEmpty) {
          return const StudioLoadingIndicator(
            message: 'Loading audience insights...',
          );
        }

        if (controller.state == ViewState.error) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => controller.fetchAudienceData(),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final countryItems = controller.filteredCountryItems;

        return CustomScrollView(
          slivers: [
            // Module Title Header Banner
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurfaceHover,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: const Icon(
                            Icons.public_rounded,
                            color: AppColors.textPrimary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Audience Geography & Insights',
                                style: TextStyle(
                                  fontFamily: TWTypography.brandFamily,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Track global audience reach and localized subscriber conversions by country.',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontSize: 14,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh Metrics',
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () => controller.fetchAudienceData(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Realtime Live Subscribers of channel Banner
                    buildAudienceLiveSubscriberBanner(
                      context: context,
                      channelId: channelId,
                      isDarkMode: isDarkMode,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      subtitleColor: subtitleColor,
                    ),
                    const SizedBox(height: 24),
                    // Summary Analytic Dashboard Cards Block
                    buildAudienceSummaryCardsMatrix(
                      controller: controller,
                      isDarkMode: isDarkMode,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      subtitleColor: subtitleColor,
                    ),
                    const SizedBox(height: 24),
                    // Demographics Breakdown Sections
                    buildAudienceDemographicsMatrix(
                      controller: controller,
                      isDarkMode: isDarkMode,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      subtitleColor: subtitleColor,
                    ),
                    const SizedBox(height: 24),
                    // Live Local Search Bar Filter
                    buildAudienceSearchBar(
                      controller: controller,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      subtitleColor: subtitleColor,
                    ),
                    const SizedBox(height: 20),
                    // Table Subtitles
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Global Performance Matrix (Countries)',
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          countryItems.length == 1
                              ? 'Showing 1 country'
                              : 'Showing ${countryItems.length} countries',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 13,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Dynamic Country Audience Breakdown Matrix List
            if (countryItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.public_off_rounded,
                        size: 48,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        controller.searchQuery.value.trim().isNotEmpty
                            ? 'No matching countries found.'
                            : 'No country viewer data recorded yet.',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: subtitleColor,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = countryItems[index];
                      return buildAudienceCountryCard(
                        item: item,
                        isDarkMode: isDarkMode,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                      );
                    },
                    childCount: countryItems.length,
                  ),
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        );
      }),
    );
  }
}
