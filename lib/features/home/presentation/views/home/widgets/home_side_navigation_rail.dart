import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/models/home_sidebar_visibility.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/navigation_rail/nav_rail_barrel.dart';
import 'package:truthworld/theme/dark_professional_theme.dart';

export 'package:truthworld/features/home/presentation/views/home/widgets/navigation_rail/nav_rail_barrel.dart';

/// Modernized side navigation rail widget coordinating modular explore, personal,
/// subscriptions, support, and policy sections across desktop and tablet views.
class ModernSideNavigationRail extends StatelessWidget {
  const ModernSideNavigationRail({
    required this.selectedIndex,
    required this.onSelectItem,
    required this.onShowSignInSnackbar,
    required this.currentUser,
    required this.homeController,
    super.key,
    this.isCompact = false,
  });

  final int selectedIndex;
  final Function(int) onSelectItem;
  final VoidCallback onShowSignInSnackbar;
  final User? currentUser;
  final bool isCompact;
  final HomeController homeController;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isCompact ? kCompactSideNavWidth : kSideNavWidth,
      decoration: BoxDecoration(
        color: modernDarkProfessionalTheme.navigationRailTheme.backgroundColor,
        border: Border(
          right: BorderSide(
            color: modernDarkProfessionalTheme.dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Obx(() {
        final isAuthenticated = AuthService.to.isAuthenticated.value;
        final visibleEntries = HomeSidebarVisibility.getVisibleEntries(
          isAuthenticated: isAuthenticated,
        );
        final shouldShowPersonalSection =
            visibleEntries.contains('Your channel') ||
                visibleEntries.contains('History');

        return ListView(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          children: [
            const SizedBox(height: 8),
            NavRailExploreSection(
              selectedIndex: selectedIndex,
              isCompact: isCompact,
              currentUser: currentUser,
              onSelectItem: onSelectItem,
              onShowSignInSnackbar: onShowSignInSnackbar,
            ),
            if (shouldShowPersonalSection)
              NavRailPersonalSection(
                selectedIndex: selectedIndex,
                isCompact: isCompact,
                currentUser: currentUser,
                homeController: homeController,
                onSelectItem: onSelectItem,
                onShowSignInSnackbar: onShowSignInSnackbar,
              ),
            if (shouldShowPersonalSection)
              NavRailSubscriptionsSection(
                currentUser: currentUser,
                isCompact: isCompact,
                homeController: homeController,
              ),
            NavRailSupportSection(
              selectedIndex: selectedIndex,
              isCompact: isCompact,
              currentUser: currentUser,
              onSelectItem: onSelectItem,
              onShowSignInSnackbar: onShowSignInSnackbar,
            ),
            NavRailPoliciesSection(
              selectedIndex: selectedIndex,
              isCompact: isCompact,
              currentUser: currentUser,
              onSelectItem: onSelectItem,
              onShowSignInSnackbar: onShowSignInSnackbar,
            ),
            NavRailFooter(isCompact: isCompact),
            const SizedBox(height: 16),
          ],
        );
      }),
    );
  }
}

// Backward-compatibility aliases
typedef HomeSideNavigationRail = ModernSideNavigationRail;
