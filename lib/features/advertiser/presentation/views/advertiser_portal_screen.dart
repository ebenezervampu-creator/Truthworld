import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/advertiser_audio_dubs_tab.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/advertiser_campaigns_tab_view.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/advertiser_dashboard_tab_view.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/advertiser_reports_tab.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/advertiser_subtitles_tab.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/audience_tab_view.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/billing_tab_view.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/brand_settings_tab_view.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/creative_assets_tab_view.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/sponsorships_tab_view.dart';
import 'package:truthworld/features/advertiser/presentation/views/widgets/advertiser_header.dart';
import 'package:truthworld/features/advertiser/presentation/views/widgets/advertiser_landing_view.dart';
import 'package:truthworld/features/advertiser/presentation/views/widgets/advertiser_sidebar.dart';
import 'package:truthworld/theme/app_theme.dart';

// Re-exports for 100% backward compatibility
export 'package:truthworld/features/advertiser/data/models/advertiser_chart_data.dart';
export 'package:truthworld/features/advertiser/presentation/views/tabs/advertiser_audio_dubs_tab.dart';
export 'package:truthworld/features/advertiser/presentation/views/tabs/advertiser_campaigns_tab_view.dart';
export 'package:truthworld/features/advertiser/presentation/views/tabs/advertiser_dashboard_tab_view.dart';
export 'package:truthworld/features/advertiser/presentation/views/tabs/advertiser_reports_tab.dart';
export 'package:truthworld/features/advertiser/presentation/views/tabs/advertiser_subtitles_tab.dart';
export 'package:truthworld/features/advertiser/presentation/views/tabs/audience_tab_view.dart';
export 'package:truthworld/features/advertiser/presentation/views/tabs/billing_tab_view.dart';
export 'package:truthworld/features/advertiser/presentation/views/tabs/brand_settings_tab_view.dart';
export 'package:truthworld/features/advertiser/presentation/views/tabs/creative_assets_tab_view.dart';
export 'package:truthworld/features/advertiser/presentation/views/tabs/sponsorships_tab_view.dart';
export 'package:truthworld/features/advertiser/presentation/views/widgets/advertiser_add_money_dialog.dart';
export 'package:truthworld/features/advertiser/presentation/views/widgets/advertiser_campaign_card.dart';
export 'package:truthworld/features/advertiser/presentation/views/widgets/advertiser_header.dart';
export 'package:truthworld/features/advertiser/presentation/views/widgets/advertiser_input_field.dart';
export 'package:truthworld/features/advertiser/presentation/views/widgets/advertiser_landing_view.dart';
export 'package:truthworld/features/advertiser/presentation/views/widgets/advertiser_sidebar.dart';
export 'package:truthworld/features/advertiser/presentation/views/wizard/create_campaign_wizard_dialog.dart';

/// Main portal screen for advertisers on Truthworld.
class AdvertiserPortalScreen extends StatelessWidget {
  const AdvertiserPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<AdvertiserPortalController>()
        ? Get.find<AdvertiserPortalController>()
        : Get.put(AdvertiserPortalController());
    controller.applyRouteTargetIfPresent();

    return Obx(() {
      final isLoggedIn = AuthService.to.isAuthenticated.value;
      if (!isLoggedIn) {
        return AdvertiserLandingView(controller: controller);
      }

      final isDesktop = MediaQuery.of(context).size.width >= 900;

      return Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: isDesktop
            ? null
            : AppBar(
                backgroundColor: AppColors.bgPage,
                elevation: 0,
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(1),
                  child: Divider(color: AppColors.bgSurface, height: 1),
                ),
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                title: Text(
                  controller.tabTitles[controller.selectedIndex.value],
                  style: const TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _buildUserAvatar(context),
                  ),
                ],
              ),
        drawer: isDesktop ? null : AdvertiserDrawer(controller: controller),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop) AdvertiserSidebar(controller: controller),
              Expanded(
                child: Column(
                  children: [
                    if (isDesktop) AdvertiserHeader(controller: controller),
                    Expanded(
                      child: _buildSelectedTabContent(context, controller),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSelectedTabContent(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
    return Obx(() {
      switch (controller.selectedIndex.value) {
        case 0:
          return AdvertiserDashboardTabView(controller: controller);
        case 1:
          return AdvertiserCampaignsTabView(controller: controller);
        case 2:
          return AdvertiserReportsTab(controller: controller);
        case 3:
          return AdvertiserSubtitlesTab(controller: controller);
        case 4:
          return AdvertiserAudioDubsTab(controller: controller);
        case 5:
          return BillingTabView(controller: controller);
        case 6:
          return AudienceTabView(controller: controller);
        case 7:
          return SponsorshipsTabView(controller: controller);
        case 8:
          return CreativeAssetsTabView(controller: controller);
        case 9:
          return BrandSettingsTabView(controller: controller);
        default:
          return AdvertiserDashboardTabView(controller: controller);
      }
    });
  }

  Widget _buildUserAvatar(BuildContext context, {double radius = 16}) {
    return Obx(() {
      final user = AuthService.to.currentUser.value;
      if (user == null) return const SizedBox.shrink();

      final imageUrl = AuthService.to.activePhotoUrl.isNotEmpty
          ? AuthService.to.activePhotoUrl
          : null;
      final displayName = AuthService.to.activeDisplayName.isNotEmpty
          ? AuthService.to.activeDisplayName
          : (user.displayName ?? 'U');

      final hasImage = imageUrl != null && imageUrl.isNotEmpty;
      final initials = displayName.trim().isNotEmpty
          ? displayName.trim().substring(0, 1).toUpperCase()
          : 'U';

      return Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(BorderSide(color: AppColors.bgSurface)),
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.bgPage,
          child: ClipOval(
            child: hasImage
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        _buildAvatarPlaceholder(initials, radius),
                    errorWidget: (context, url, error) =>
                        _buildAvatarPlaceholder(initials, radius),
                  )
                : _buildAvatarPlaceholder(initials, radius),
          ),
        ),
      );
    });
  }

  Widget _buildAvatarPlaceholder(String initials, double radius) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: TWTypography.brandFamily,
          color: Colors.white,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
