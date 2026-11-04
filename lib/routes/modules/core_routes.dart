import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:truthworld/core/bindings/app_bindings.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/utils/route_guards.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/features/about/presentation/views/About/about.dart';
import 'package:truthworld/features/admin/presentation/views/admin_dashboard_screen.dart'
    deferred as admin_dashboard;
import 'package:truthworld/features/admin/presentation/views/admin_login_screen.dart'
    deferred as admin_login;
import 'package:truthworld/features/advertiser/presentation/bindings/advertiser_binding.dart';
import 'package:truthworld/features/advertiser/presentation/views/advertiser_portal_screen.dart'
    deferred as advertiser_portal;
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart'
    deferred as dashboard;
import 'package:truthworld/features/home/presentation/views/home/home.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart'
    as app;
import 'package:truthworld/features/search/presentation/pages/search_page.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/routes/app_transitions.dart';
import 'package:truthworld/routes/modules/admin_routes.dart';

/// Core application routes handling dynamic entry points, home shell, search, and platform about.
class CoreRoutes {
  CoreRoutes._();

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.root,
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      page: () {
        if (AppFlavor.isStudio) {
          return DeferredWidget(
            loader: dashboard.loadLibrary,
            builder: () => dashboard.DashboardScreen(),
          );
        }
        if (AppFlavor.isAdmin) {
          if (AdminRoutes.hasAdminAccess()) {
            return DeferredWidget(
              loader: admin_dashboard.loadLibrary,
              builder: () => admin_dashboard.AdminDashboardScreen(),
            );
          }
          return DeferredWidget(
            loader: admin_login.loadLibrary,
            builder: () => admin_login.AdminLoginScreen(),
          );
        }
        if (AppFlavor.isAdvertiser) {
          return DeferredWidget(
            loader: advertiser_portal.loadLibrary,
            builder: () => advertiser_portal.AdvertiserPortalScreen(),
          );
        }
        if (kIsWeb) {
          final host = Uri.base.host.toLowerCase();
          if (host.startsWith('admin') || host.contains('admin.truthworld.in')) {
            if (AdminRoutes.hasAdminAccess()) {
              return DeferredWidget(
                loader: admin_dashboard.loadLibrary,
                builder: () => admin_dashboard.AdminDashboardScreen(),
              );
            }
            return DeferredWidget(
              loader: admin_login.loadLibrary,
              builder: () => admin_login.AdminLoginScreen(),
            );
          }
          if (host.startsWith('studio') ||
              host.contains('studio.truthworld.in')) {
            return DeferredWidget(
              loader: dashboard.loadLibrary,
              builder: () => dashboard.DashboardScreen(),
            );
          }
        }
        return const Home();
      },
      binding: BindingsBuilder(() {
        if (AppFlavor.isStudio) {
          DashboardBinding().dependencies();
          return;
        }
        if (AppFlavor.isAdmin) {
          AdminBinding().dependencies();
          return;
        }
        if (AppFlavor.isAdvertiser) {
          AdvertiserBinding().dependencies();
          return;
        }
        if (kIsWeb) {
          final host = Uri.base.host.toLowerCase();
          if (host.startsWith('admin') || host.contains('admin.truthworld.in')) {
            AdminBinding().dependencies();
            return;
          }
          if (host.startsWith('studio') ||
              host.contains('studio.truthworld.in')) {
            DashboardBinding().dependencies();
            return;
          }
        }
        HomeBinding().dependencies();
      }),
    ),
    GetPage(
      name: AppRoutes.home,
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      page: () {
        if (AppFlavor.isStudio) {
          return DeferredWidget(
            loader: dashboard.loadLibrary,
            builder: () => dashboard.DashboardScreen(),
          );
        }
        return const Home();
      },
      middlewares: [HomeRedirectMiddleware()],
      binding: BindingsBuilder(() {
        if (AppFlavor.isStudio) {
          DashboardBinding().dependencies();
          return;
        }
        HomeBinding().dependencies();
      }),
    ),
    GetPage(
      name: AppRoutes.about,
      page: () => const AboutPage(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
    ),
    GetPage(
      name: AppRoutes.search,
      page: () => const SearchPage(),
      middlewares: [ConsumerRouteGuard()],
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: BindingsBuilder(() {
        Get.lazyPut(app.SearchController.new);
      }),
    ),
  ];
}
