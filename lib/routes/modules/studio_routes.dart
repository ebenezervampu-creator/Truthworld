import 'package:get/get.dart';
import 'package:truthworld/core/bindings/app_bindings.dart';
import 'package:truthworld/core/utils/route_guards.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/features/analytics/presentation/bindings/analytics_binding.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics_dashboard.dart';
import 'package:truthworld/features/analytics/presentation/pages/subscribers_page.dart';
import 'package:truthworld/features/analytics/presentation/pages/views_page.dart';
import 'package:truthworld/features/analytics/presentation/pages/watch_time_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart'
    deferred as dashboard;
import 'package:truthworld/features/watchtime/presentation/pages/watchtime_details_page.dart';
import 'package:truthworld/routes/app_routes.dart';

/// Creator Studio and analytics dashboard routes.
class StudioRoutes {
  StudioRoutes._();

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.studio,
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        builder: () => dashboard.DashboardScreen(),
      ),
      middlewares: [StudioRedirectMiddleware(), StudioAccessGuard()],
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.dashboard,
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        builder: () => dashboard.DashboardScreen(),
      ),
      middlewares: [DashboardRedirectMiddleware(), StudioAccessGuard()],
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.studioChapters,
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        builder: () => dashboard.DashboardScreen(),
      ),
      middlewares: [StudioRedirectMiddleware(), StudioAccessGuard()],
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.studioTrash,
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        builder: () => dashboard.DashboardScreen(),
      ),
      middlewares: [StudioRedirectMiddleware(), StudioAccessGuard()],
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.studioDrafts,
      page: () => DeferredWidget(
        loader: dashboard.loadLibrary,
        builder: () => dashboard.DashboardScreen(),
      ),
      middlewares: [StudioRedirectMiddleware(), StudioAccessGuard()],
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.analytics,
      page: () => const CreatorAnalyticsDashboard(),
      binding: AnalyticsBinding(),
    ),
    GetPage(
      name: AppRoutes.watchtime,
      page: () => const WatchTimePage(),
      binding: AnalyticsBinding(),
    ),
    GetPage(
      name: AppRoutes.watchtimePage,
      page: () => const WatchTimePage(),
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
      binding: AnalyticsBinding(),
    ),
    GetPage(
      name: AppRoutes.views,
      page: () => const ViewsPage(),
      binding: AnalyticsBinding(),
    ),
    GetPage(
      name: AppRoutes.subscribers,
      page: () => const SubscribersPage(),
      binding: AnalyticsBinding(),
    ),
  ];
}
