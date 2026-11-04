import 'package:get/get.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/features/advertiser/presentation/bindings/advertiser_binding.dart';
import 'package:truthworld/features/advertiser/presentation/views/advertiser_portal_screen.dart'
    deferred as advertiser_portal;
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/routes/app_transitions.dart';

/// Advertiser portal and campaign management routes.
class AdvertiserRoutes {
  AdvertiserRoutes._();

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.advertiser,
      binding: AdvertiserBinding(),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      page: () => DeferredWidget(
        loader: advertiser_portal.loadLibrary,
        builder: () => advertiser_portal.AdvertiserPortalScreen(),
      ),
    ),
    GetPage(
      name: AppRoutes.advertisements,
      binding: AdvertiserBinding(),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      page: () => DeferredWidget(
        loader: advertiser_portal.loadLibrary,
        builder: () => advertiser_portal.AdvertiserPortalScreen(),
      ),
    ),
    GetPage(
      name: AppRoutes.ads,
      binding: AdvertiserBinding(),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      page: () => DeferredWidget(
        loader: advertiser_portal.loadLibrary,
        builder: () => advertiser_portal.AdvertiserPortalScreen(),
      ),
    ),
  ];
}
