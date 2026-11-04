import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/theme/dark_professional_theme.dart';

/// Bottom navigation bar for mobile and compact tablet devices.
class HomeBottomNavigation extends StatelessWidget {
  const HomeBottomNavigation({
    required this.homeController,
    super.key,
  });

  final HomeController homeController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: modernDarkProfessionalTheme.navigationBarTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: modernDarkProfessionalTheme.navigationBarTheme
              .copyWith(
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const IconThemeData(color: Colors.white, size: 24);
                  }
                  return const IconThemeData(
                    color: darkOnSurfaceVariant,
                    size: 24,
                  );
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final style = TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  );
                  if (states.contains(WidgetState.selected)) {
                    return style.copyWith(color: Colors.white);
                  }
                  return style.copyWith(color: darkOnSurfaceVariant);
                }),
              ),
        ),
        child: Obx(
          () => NavigationBar(
            selectedIndex: homeController.bottomNavSelectedIndex.value,
            onDestinationSelected: homeController.onBottomNavItemTapped,
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: kBottomNavBarHeight,
            indicatorColor: Colors.grey.withValues(alpha: 0.15),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              const NavigationDestination(
                icon: Icon(Icons.interests_outlined),
                selectedIcon: Icon(Icons.interests),
                label: 'Topics',
              ),
              const NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Channels',
              ),
              NavigationDestination(
                icon: (() {
                  final isAuth = Get.isRegistered<AuthService>() &&
                      AuthService.to.isAuthenticated.value;
                  if (!isAuth) {
                    return const Icon(Icons.account_circle_outlined);
                  }
                  return const UserAvatar(
                    radius: 12,
                    showBorder: false,
                  );
                })(),
                selectedIcon: (() {
                  final isAuth = Get.isRegistered<AuthService>() &&
                      AuthService.to.isAuthenticated.value;
                  if (!isAuth) {
                    return const Icon(Icons.account_circle_rounded);
                  }
                  return const UserAvatar(
                    radius: 12,
                    borderColor: Colors.white,
                  );
                })(),
                label: 'You',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
