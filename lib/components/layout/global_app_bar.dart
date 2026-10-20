import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/components/ui/auth/auth_bottom_sheet.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/navigation/app_navigator.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/get_instance_extensions.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/notifications/presentation/controllers/user_notification_controller.dart';
import 'package:truthworld/features/notifications/presentation/controllers/video_feed_notification_controller.dart';
import 'package:truthworld/theme/app_colors.dart';

const Color darkSurface = AppColors.bgInput;
const Color darkSurfaceVariant = Color(0xFF1E1E1E);
const Color darkOnSurface = Color(0xFFE8E8E8);
const Color darkOnSurfaceVariant = Color(0xFFB8B8B8);
const Color primaryAccent = Color(0xFF1976D2);

/// Global shared AppBar used consistently across HomeScreen, VideoScreen, etc.
class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlobalAppBar({
    super.key,
    this.isDesktop,
    this.isTablet,
    this.isMobile,
  });

  final bool? isDesktop;
  final bool? isTablet;
  final bool? isMobile;

  @override
  Size get preferredSize {
    if (isDesktop == true) {
      return const Size.fromHeight(kToolbarHeight + 10);
    }
    return const Size.fromHeight(kToolbarHeight + 10);
  }

  @override
  Widget build(BuildContext context) {
    return buildGlobalAppBar(
      context,
      isMobile: isMobile,
      isTablet: isTablet,
      isDesktop: isDesktop,
    );
  }
}

PreferredSizeWidget buildGlobalAppBar(
  BuildContext context, {
  bool? isMobile,
  bool? isTablet,
  bool? isDesktop,
}) {
  final width = MediaQuery.of(context).size.width;
  final desktop = isDesktop ?? (width >= 1000);
  final tablet = isTablet ?? (width >= 600 && width < 1000);
  final mobile = isMobile ?? (width < 600);

  if (desktop) {
    return _buildDesktopAppBar(context);
  }

  if (mobile || tablet) {
    return _buildMobileAppBar(context);
  }

  return _buildDesktopAppBar(context);
}

PreferredSizeWidget _buildDesktopAppBar(BuildContext context) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight + 10),
    child: AppBar(
      backgroundColor: darkSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: _buildDesktopHeader(context),
      actions: _buildAppBarActions(context, false),
    ),
  );
}

PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
  return AppBar(
    title: _buildMobileHeader(context),
    titleSpacing: 0,
    actions: _buildAppBarActions(context, true),
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: darkSurface,
    surfaceTintColor: Colors.transparent,
    automaticallyImplyLeading: false,
  );
}

Widget _buildDesktopHeader(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Row(
      children: [
        InkWell(
          onTap: RouteStackObserver.navigateToHome,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const AppLogo(
                  size: 34,
                  borderRadius: 8,
                ),
                const SizedBox(width: 12),
                Obx(() {
                  final isPremium = Get.isRegistered<AuthService>() &&
                      AuthService.to.isPremiumUser.value;
                  return Text(
                    isPremium ? 'Truthworld Premium' : 'Truthworld',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: GoogleFonts.roboto(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: darkOnSurface,
                      letterSpacing: 0.15,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(width: 40),
        Expanded(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 650),
              height: 44,
              child: Material(
                borderRadius: BorderRadius.circular(22),
                color: darkSurfaceVariant.withValues(alpha: 0.3),
                child: InkWell(
                  onTap: AppNavigator.toSearch,
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Search videos...',
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: darkOnSurfaceVariant,
                              letterSpacing: 0.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildMobileHeader(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.only(left: 16),
    child: InkWell(
      onTap: RouteStackObserver.navigateToHome,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(
              size: 28,
              borderRadius: 6,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Obx(() {
                final isPremium = Get.isRegistered<AuthService>() &&
                    AuthService.to.isPremiumUser.value;
                return Text(
                  isPremium ? 'Truthworld Premium' : 'Truthworld',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: darkOnSurface,
                    letterSpacing: 0.15,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    ),
  );
}

List<Widget> buildGlobalAppBarActions(BuildContext context, bool isMobile) {
  return _buildAppBarActions(context, isMobile);
}

List<Widget> _buildAppBarActions(BuildContext context, bool isMobile) {
  if (isMobile) {
    return [
      Container(
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: darkSurfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const IconButton(
          icon: Icon(
            Icons.search_rounded,
            color: Colors.white,
          ),
          tooltip: 'Search',
          onPressed: AppNavigator.toSearch,
        ),
      ),
      _buildNotificationLogo(context, isMobile: true),
    ];
  }

  return [
    _buildNotificationLogo(context),
    Obx(() {
      final isAuth = Get.isRegistered<AuthService>() &&
          AuthService.to.isAuthenticated.value;
      return !isAuth ? _buildSignInButton(context) : _buildUserMenu(context);
    }),
  ];
}

Widget _buildNotificationLogo(BuildContext context, {bool isMobile = false}) {
  return Obx(() {
    if (!Get.isRegistered<AuthService>()) {
      return const SizedBox.shrink();
    }
    final user = AuthService.to.currentUser.value;
    if (user == null || user.isAnonymous) {
      return const SizedBox.shrink();
    }

    final feedController =
        Get.findIfInstantiated<VideoFeedNotificationController>();
    final userController =
        Get.findIfInstantiated<UserNotificationController>();

    final totalCount =
        (feedController?.unseenCount ?? 0) + (userController?.unreadCount ?? 0);

    final countText = isMobile
        ? (totalCount > 9 ? '9+' : '$totalCount')
        : (totalCount > 99 ? '99+' : '$totalCount');

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          const IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              size: 24,
              color: Colors.white,
            ),
            onPressed: AppNavigator.toNotifications,
            tooltip: 'Notifications',
          ),
          if (totalCount > 0)
            Positioned(
              top: 6,
              right: 6,
              child: IgnorePointer(
                child: Container(
                  padding: totalCount > 9
                      ? const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1.5,
                        )
                      : const EdgeInsets.all(2),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCC0000), // Signature red
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0F0F0F),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    countText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  });
}

Future<void> _handleSignIn(BuildContext context) async {
  try {
    await AuthBottomSheet.show(context);
  } catch (e, stackTrace) {
    ErrorHandler.log(
      e,
      stackTrace: stackTrace,
      tag: 'GlobalAppBar.handleSignIn',
    );
  }
}

Widget _buildSignInButton(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Obx(() {
      final isAuth = Get.isRegistered<AuthService>() &&
          AuthService.to.isAuthenticated.value;
      final isLoading = Get.isRegistered<HomeController>() &&
          Get.find<HomeController>().isLoadingAuth.value;
      if (isAuth) return const SizedBox.shrink();

      return ElevatedButton(
        onPressed: isLoading ? null : () => _handleSignIn(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : const Text(
                'Sign In',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
      );
    }),
  );
}

Widget _buildUserMenu(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.only(right: 12, left: 4),
    child: PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      color: darkSurface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      onSelected: (value) {
        switch (value) {
          case 'studio':
            StudioLauncher.openStudio();
        }
      },
      itemBuilder: (context) => [
        _buildUserInfoMenuItem(context),
        const PopupMenuDivider(height: 1),
        _buildPopupMenuItem(
          context,
          Icons.analytics_outlined,
          'Studio',
          'studio',
        ),
      ],
      child: Obx(() => _buildUserAvatar(context)),
    ),
  );
}

PopupMenuItem<String> _buildUserInfoMenuItem(BuildContext context) {
  return PopupMenuItem(
    value: 'user_info',
    enabled: false,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Obx(() => _buildUserAvatar(context, radius: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(
                () => Text(
                  AuthService.to.activeDisplayName,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: darkOnSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Obx(
                () => Text(
                  AuthService.to.hasChannel.value &&
                          AuthService.to.userChannel != null
                      ? AuthService.to.activeHandle
                      : (AuthService.to.user?.email ?? ''),
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: darkOnSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

PopupMenuItem<String> _buildPopupMenuItem(
  BuildContext context,
  IconData icon,
  String title,
  String value,
) {
  return PopupMenuItem(
    value: value,
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.white,
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.roboto(
            fontSize: 14,
            color: darkOnSurface,
          ),
        ),
      ],
    ),
  );
}

Widget _buildUserAvatar(BuildContext context, {double radius = 18}) {
  final imageUrl = AuthService.to.activePhotoUrl;
  final displayName = AuthService.to.activeDisplayName;
  final email = AuthService.to.user?.email ?? '';
  final String initial;
  if (displayName.isNotEmpty && displayName != 'User') {
    initial = displayName.substring(0, 1).toUpperCase();
  } else if (email.isNotEmpty) {
    initial = email.substring(0, 1).toUpperCase();
  } else {
    initial = '';
  }

  final hasImage = imageUrl.isNotEmpty;

  Widget buildPlaceholder() {
    if (initial.isNotEmpty) {
      return Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: radius * 0.9,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    return Center(
      child: Icon(
        Icons.person_rounded,
        size: radius * 1.1,
        color: Colors.white,
      ),
    );
  }

  return Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: primaryAccent.withValues(alpha: 0.2),
      ),
    ),
    child: CircleAvatar(
      radius: radius,
      backgroundColor: darkSurfaceVariant,
      child: ClipOval(
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                memCacheWidth:
                    (radius * 2 * MediaQuery.of(context).devicePixelRatio).toInt(),
                placeholder: (context, url) => buildPlaceholder(),
                errorWidget: (context, url, error) => buildPlaceholder(),
              )
            : buildPlaceholder(),
      ),
    ),
  );
}
