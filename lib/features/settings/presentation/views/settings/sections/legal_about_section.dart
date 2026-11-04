import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/web_platform_utils.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_section_card.dart';
import 'package:truthworld/theme/app_theme.dart';

class LegalAboutSection extends StatelessWidget {
  const LegalAboutSection({super.key, this.isDashboard = false});

  final bool isDashboard;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Legal & About',
      children: [
        _buildLegalTile(
          context,
          title: 'About TruthWorld',
          icon: Icons.info_outline,
          index: HomeController.indexAbout,
          route: '/about',
        ),
        _buildLegalTile(
          context,
          title: 'Privacy Policy',
          icon: Icons.privacy_tip_outlined,
          index: HomeController.indexPrivacy,
          route: '/privacy',
        ),
        _buildLegalTile(
          context,
          title: 'Terms & Conditions',
          icon: Icons.article_outlined,
          index: HomeController.indexTerms,
          route: '/terms',
        ),
        _buildLegalTile(
          context,
          title: 'Community Guidelines',
          icon: Icons.gavel_outlined,
          index: HomeController.indexCommunityGuidelines,
          route: '/community-guidelines',
        ),
        _buildVersionTile(context),
        _buildFeedbackTile(context),
      ],
    );
  }

  Widget _buildVersionTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info, color: AppColors.textPrimary),
      title: const Text(
        'Version',
        style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      ),
      subtitle: Text(
        '1.0.0 (Truthworld Production Release)',
        style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
      ),
    );
  }

  Widget _buildFeedbackTile(BuildContext context) {
    return ListTile(
      leading: const Icon(
        Icons.chat_bubble_outline,
        color: AppColors.textPrimary,
      ),
      title: const Text(
        'Feedback',
        style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
      onTap: () {
        if (isDashboard && Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().onSideNavItemSelect(
            HomeController.indexFeedback,
          );
          if (kIsWeb) {
            WebPlatformUtils.pushUrlHistory('/feedback');
          }
        } else {
          Get.toNamed('/feedback');
        }
      },
    );
  }

  Widget _buildLegalTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required int index,
    required String route,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
      onTap: () {
        if (isDashboard && Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().onSideNavItemSelect(index);
          if (kIsWeb) {
            WebPlatformUtils.pushUrlHistory(route);
          }
        } else {
          Get.toNamed(route);
        }
      },
    );
  }


}
