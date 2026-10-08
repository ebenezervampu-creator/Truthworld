import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/navigation_rail/nav_rail_action_handler.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/navigation_rail/nav_rail_item.dart';

/// Support section with Settings, Feedback, and About.
class NavRailSupportSection extends StatelessWidget {
  const NavRailSupportSection({
    required this.selectedIndex,
    required this.isCompact,
    required this.currentUser,
    required this.onSelectItem,
    required this.onShowSignInSnackbar,
    super.key,
  });

  final int selectedIndex;
  final bool isCompact;
  final User? currentUser;
  final Function(int) onSelectItem;
  final VoidCallback onShowSignInSnackbar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NavRailDivider(),
          NavRailSectionHeader(title: 'SUPPORT', isCompact: isCompact),
          if (currentUser != null)
            _item(
              context,
              Icons.settings_rounded,
              Icons.settings_outlined,
              'Settings',
              HomeController.indexSettings,
              route: '/settings',
              requiresAuth: true,
            ),
          _item(
            context,
            Icons.chat_bubble_rounded,
            Icons.chat_bubble_outline,
            'Feedback',
            HomeController.indexFeedback,
            route: '/feedback',
            requiresAuth: true,
          ),
          _item(
            context,
            Icons.info_rounded,
            Icons.info_outline,
            'About Truthworld',
            HomeController.indexAbout,
            route: '/about',
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData selected,
    IconData unselected,
    String title,
    int index, {
    String? route,
    bool requiresAuth = false,
  }) {
    return NavRailItem(
      selectedIcon: selected,
      unselectedIcon: unselected,
      title: title,
      index: index,
      isSelected: selectedIndex == index,
      isCompact: isCompact,
      requiresAuth: requiresAuth,
      onTap: () => NavRailActionHandler.handleNavItemTap(
        context: context,
        index: index,
        route: route,
        requiresAuth: requiresAuth,
        currentUser: currentUser,
        onSelectItem: onSelectItem,
        onShowSignInSnackbar: onShowSignInSnackbar,
      ),
    );
  }
}

/// Policies and Portal links section.
class NavRailPoliciesSection extends StatelessWidget {
  const NavRailPoliciesSection({
    required this.selectedIndex,
    required this.isCompact,
    required this.currentUser,
    required this.onSelectItem,
    required this.onShowSignInSnackbar,
    super.key,
  });

  final int selectedIndex;
  final bool isCompact;
  final User? currentUser;
  final Function(int) onSelectItem;
  final VoidCallback onShowSignInSnackbar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NavRailDivider(),
          NavRailSectionHeader(title: 'POLICIES', isCompact: isCompact),
          _item(
            context,
            Icons.privacy_tip_rounded,
            Icons.privacy_tip_outlined,
            'Privacy Policy',
            HomeController.indexPrivacy,
            route: '/privacy',
          ),
          _item(
            context,
            Icons.article_rounded,
            Icons.article_outlined,
            'Terms & Conditions',
            HomeController.indexTerms,
            route: '/terms',
          ),
          _item(
            context,
            Icons.gavel_rounded,
            Icons.gavel_outlined,
            'Community Guidelines',
            HomeController.indexCommunityGuidelines,
            route: '/community-guidelines',
          ),
          NavRailItem(
            selectedIcon: Icons.dashboard_rounded,
            unselectedIcon: Icons.dashboard_outlined,
            title: 'Truthworld Studio',
            index: 998,
            isSelected: selectedIndex == 998,
            isCompact: isCompact,
            onTap: StudioLauncher.openStudio,
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData selected,
    IconData unselected,
    String title,
    int index, {
    String? route,
  }) {
    return NavRailItem(
      selectedIcon: selected,
      unselectedIcon: unselected,
      title: title,
      index: index,
      isSelected: selectedIndex == index,
      isCompact: isCompact,
      onTap: () => NavRailActionHandler.handleNavItemTap(
        context: context,
        index: index,
        route: route,
        requiresAuth: false,
        currentUser: currentUser,
        onSelectItem: onSelectItem,
        onShowSignInSnackbar: onShowSignInSnackbar,
      ),
    );
  }
}

/// Copyright and branding footer for the navigation rail.
class NavRailFooter extends StatelessWidget {
  const NavRailFooter({
    required this.isCompact,
    super.key,
  });

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (isCompact) return const SizedBox.shrink();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          children: [
            Text(
              '© 2026 Truthworld',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: isDarkMode ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Made with ',
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    color: isDarkMode ? Colors.white24 : const Color(0xFFCBD5E1),
                  ),
                ),
                const Icon(
                  Icons.favorite,
                  size: 11,
                  color: Colors.white,
                ),
                Text(
                  ' for creators',
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    color: isDarkMode ? Colors.white24 : const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
