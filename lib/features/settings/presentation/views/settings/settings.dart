import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/settings/presentation/views/settings/sections/sections.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_theme.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_unauthenticated_view.dart';
import 'package:truthworld/theme/app_theme.dart';

// Re-export extracted views, widgets, and sections for 100% backward compatibility
export 'package:truthworld/features/settings/presentation/views/settings/sections/sections.dart';
export 'package:truthworld/features/settings/presentation/views/settings/watch_history_settings_view.dart';
export 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_section_card.dart';
export 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_theme.dart';
export 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_unauthenticated_view.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isAuth = Get.isRegistered<AuthService>() &&
          AuthService.to.isAuthenticated.value;

      if (!isAuth) {
        return SettingsUnauthenticatedView(isDashboard: isDashboard);
      }

      UserSettingsController.to;

      return Theme(
        data: getSettingsTheme(context),
        child: Builder(
          builder: (context) {
            return ResponsiveBuilder(
              builder: (context, deviceType) {
                return Scaffold(
                  backgroundColor: context.colors.background,
                  appBar: _buildAppBar(context),
                  body: SafeArea(child: _buildBody(context)),
                );
              },
            );
          },
        ),
      );
    });
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        'Settings',
        style: context.typography.headline.copyWith(
          color: context.colors.textPrimary,
        ),
      ),
      backgroundColor: context.colors.background,
      elevation: 0,
      centerTitle: context.isMobile,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: context.colors.textPrimary,
          size: context.isMobileSmall ? 20 : 24,
        ),
        onPressed: () {
          if (isDashboard) {
            Get.find<HomeController>().sideNavSelectedIndex.value =
                HomeController.indexLibrary;
          } else {
            Get.back();
          }
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ResponsiveContainer(
      child: ListView(
        padding: EdgeInsets.symmetric(vertical: context.layoutSpacing),
        children: [
          const GeneralAccountSection(),
          SizedBox(height: context.layoutSpacing),
          const WellbeingSection(),
          SizedBox(height: context.layoutSpacing),
          const PlaybackSection(),
          SizedBox(height: context.layoutSpacing),
          const DownloadsStorageSection(),
          SizedBox(height: context.layoutSpacing),
          const NotificationsSection(),
          SizedBox(height: context.layoutSpacing),
          const PrivacyHistorySection(),
          SizedBox(height: context.layoutSpacing),
          const AccessibilitySection(),
          SizedBox(height: context.layoutSpacing),
          const AdvancedDiagnosticsSection(),
          SizedBox(height: context.layoutSpacing),
          const LegalAboutSection(),
        ],
      ),
    );
  }
}

