import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/bindings/app_bindings.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/admin_dashboard_screen.dart'
    deferred as admin_dashboard;
import 'package:truthworld/features/admin/presentation/views/admin_login_screen.dart'
    deferred as admin_login;
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/routes/app_transitions.dart';

/// Admin portal and moderation feature routes.
class AdminRoutes {
  AdminRoutes._();

  /// Validates whether the active authenticated user has admin or owner privileges.
  static bool hasAdminAccess() {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.toLowerCase();
    final isOwner =
        email != null && AdminController.authorizedOwnerEmails.contains(email);
    return isOwner ||
        (Get.isRegistered<AdminController>() &&
            Get.find<AdminController>().isAdmin.value);
  }

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.adminRoot,
      binding: AdminBinding(),
      transition: AppTransitions.modal,
      transitionDuration: AppTransitions.modalDuration,
      curve: AppTransitions.modalCurve,
      middlewares: [AdminRedirectMiddleware()],
      page: () => DeferredWidget(
        loader: admin_login.loadLibrary,
        builder: () => admin_login.AdminLoginScreen(),
      ),
    ),
    GetPage(
      name: AppRoutes.adminLogin,
      binding: AdminBinding(),
      transition: AppTransitions.modal,
      transitionDuration: AppTransitions.modalDuration,
      curve: AppTransitions.modalCurve,
      middlewares: [AdminRedirectMiddleware()],
      page: () => DeferredWidget(
        loader: admin_login.loadLibrary,
        builder: () => admin_login.AdminLoginScreen(),
      ),
    ),
    GetPage(
      name: AppRoutes.adminDashboard,
      binding: AdminBinding(),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      middlewares: [AdminAuthGuardMiddleware()],
      page: () => DeferredWidget(
        loader: admin_dashboard.loadLibrary,
        builder: () => admin_dashboard.AdminDashboardScreen(),
      ),
    ),
  ];
}
