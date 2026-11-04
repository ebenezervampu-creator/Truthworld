import 'package:get/get.dart';
import 'package:truthworld/core/bindings/app_bindings.dart';
import 'package:truthworld/core/utils/route_guards.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/analytics/presentation/bindings/analytics_binding.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics_dashboard.dart';
import 'package:truthworld/features/analytics/presentation/pages/subscribers_page.dart';
import 'package:truthworld/features/analytics/presentation/pages/views_page.dart';
import 'package:truthworld/features/analytics/presentation/pages/watch_time_page.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/channel_notifications_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart'
    deferred as dashboard;
import 'package:truthworld/features/dashboard/presentation/views/dashboard/memberships/create_or_edit_tier_page.dart';
import 'package:truthworld/features/notifications/presentation/bindings/notifications_binding.dart';
import 'package:truthworld/features/watchtime/presentation/pages/watchtime_details_page.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/routes/app_transitions.dart';

/// Creator Studio and analytics dashboard routes.
class StudioRoutes {
  StudioRoutes._();

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.studio,
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        placeholder: const StudioLoadingIndicator(),
        builder: () => dashboard.DashboardScreen(),
      ),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      middlewares: [StudioRedirectMiddleware(), StudioAccessGuard()],
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.dashboard,
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        placeholder: const StudioLoadingIndicator(),
        builder: () => dashboard.DashboardScreen(),
      ),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      middlewares: [DashboardRedirectMiddleware(), StudioAccessGuard()],
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.studioChapters,
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        placeholder: const StudioLoadingIndicator(),
        builder: () => dashboard.DashboardScreen(),
      ),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      middlewares: [StudioRedirectMiddleware(), StudioAccessGuard()],
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.studioTrash,
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        placeholder: const StudioLoadingIndicator(),
        builder: () => dashboard.DashboardScreen(),
      ),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      middlewares: [StudioRedirectMiddleware(), StudioAccessGuard()],
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.studioDrafts,
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        placeholder: const StudioLoadingIndicator(),
        builder: () => dashboard.DashboardScreen(),
      ),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      middlewares: [StudioRedirectMiddleware(), StudioAccessGuard()],
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.studioCommunity,
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        placeholder: const StudioLoadingIndicator(),
        builder: () => dashboard.DashboardScreen(),
      ),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      middlewares: [StudioRedirectMiddleware(), StudioAccessGuard()],
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.analytics,
      page: () => const CreatorAnalyticsDashboard(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: AnalyticsBinding(),
    ),
    GetPage(
      name: AppRoutes.watchtime,
      page: () => const WatchTimePage(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: AnalyticsBinding(),
    ),
    GetPage(
      name: AppRoutes.watchtimePage,
      page: () => const WatchTimePage(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: AnalyticsBinding(),
    ),
    GetPage(
      name: AppRoutes.watchtimeDetails,
      page: () {
        final channelId = Get.parameters['channelId'] ??
            Get.parameters['id'] ??
            (Get.arguments is Map
                ? Get.arguments['channelId'] as String?
                : null) ??
            '';
        return WatchtimeDetailsPage(
          channelId: channelId,
          isDarkMode: Get.isDarkMode,
        );
      },
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: AnalyticsBinding(),
    ),
    GetPage(
      name: AppRoutes.views,
      page: () => const ViewsPage(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: AnalyticsBinding(),
    ),
    GetPage(
      name: AppRoutes.subscribers,
      page: () => const SubscribersPage(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: AnalyticsBinding(),
    ),
    GetPage(
      name: AppRoutes.studioCreateMembershipTier,
      page: () {
        final controller = Get.isRegistered<MembershipsController>()
            ? Get.find<MembershipsController>()
            : Get.put(MembershipsController());
        final tier = Get.arguments is ChannelMembershipTier
            ? Get.arguments as ChannelMembershipTier
            : null;
        return CreateOrEditTierPage(
          controller: controller,
          tier: tier,
          isDarkMode: Get.isDarkMode,
        );
      },
      transition: AppTransitions.modal,
      transitionDuration: AppTransitions.modalDuration,
      curve: AppTransitions.modalCurve,
      middlewares: [StudioRedirectMiddleware(), StudioAccessGuard()],
    ),
    GetPage(
      name: AppRoutes.studioNotifications,
      page: () => const ChannelNotificationsPage(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [StudioAccessGuard()],
      binding: NotificationsBinding(),
    ),
  ];
}
