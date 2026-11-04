import 'package:get/get.dart';
import 'package:truthworld/core/bindings/app_bindings.dart';
import 'package:truthworld/core/utils/route_guards.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channel_description_screen.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channel_details_screen.dart'
    deferred as channel_details;
import 'package:truthworld/features/channel/presentation/views/channel/channel_screen_wizard.dart';
import 'package:truthworld/features/channel/presentation/views/channel/plan_comparison/plan_comparison_barrel.dart';
import 'package:truthworld/features/discover/presentation/views/discover_channels.dart'
    deferred as discover;
import 'package:truthworld/features/myvideos/presentation/bindings/my_videos_binding.dart';
import 'package:truthworld/features/myvideos/presentation/views/myvideos/my_videos.dart'
    deferred as my_videos;
import 'package:truthworld/features/subscriptions/presentation/bindings/subscriptions_binding.dart';
import 'package:truthworld/features/subscriptions/presentation/views/subscriptions/subscriptions.dart'
    deferred as subscriptions;
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/routes/app_transitions.dart';

/// Channel profiles, creator onboarding wizard, handles, and subscriptions routes.
class ChannelRoutes {
  ChannelRoutes._();

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.channelWizard,
      page: ChannelScreen.new,
      transition: AppTransitions.modal,
      transitionDuration: AppTransitions.modalDuration,
      curve: AppTransitions.modalCurve,
      middlewares: [ChannelCreationGuard()],
      binding: ChannelBinding(),
    ),
    GetPage(
      name: AppRoutes.channelPlanComparison,
      page: ChannelPlanComparisonScreen.new,
      transition: AppTransitions.modal,
      transitionDuration: AppTransitions.modalDuration,
      curve: AppTransitions.modalCurve,
      binding: ChannelBinding(),
    ),
    GetPage(
      name: AppRoutes.channelDescription,
      page: ChannelDescriptionScreen.new,
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: ChannelBinding(),
    ),
    GetPage(
      name: AppRoutes.channelDetails,
      page: () => DeferredWidget(
        loader: channel_details.loadLibrary,
        builder: () => channel_details.ChannelDetailsPage(),
      ),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [ConsumerRouteGuard(), ChannelDetailsRedirectMiddleware()],
      binding: ChannelBinding(),
    ),
    GetPage(
      name: AppRoutes.channelWithId,
      page: () {
        final channel = Get.arguments?['channel'];
        return DeferredWidget(
          loader: channel_details.loadLibrary,
          builder: () => channel_details.ChannelDetailsPage(
            channel: channel as Channel?,
          ),
        );
      },
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: ChannelBinding(),
    ),
    GetPage(
      name: AppRoutes.channelHandle,
      page: () {
        final channel = Get.arguments?['channel'];
        return DeferredWidget(
          loader: channel_details.loadLibrary,
          builder: () => channel_details.ChannelDetailsPage(
            channel: channel as Channel?,
          ),
        );
      },
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: ChannelBinding(),
    ),
    GetPage(
      name: AppRoutes.subscriptions,
      page: () => DeferredWidget(
        loader: subscriptions.loadLibrary,
        builder: () => subscriptions.SubscriptionsPage(),
      ),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      middlewares: [ConsumerRouteGuard(), AuthGuard()],
      binding: SubscriptionsBinding(),
    ),
    GetPage(
      name: AppRoutes.discover,
      page: () => DeferredWidget(
        loader: discover.loadLibrary,
        builder: () => discover.DiscoverChannelsPage(),
      ),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      middlewares: [ConsumerRouteGuard()],
    ),
    GetPage(
      name: AppRoutes.myvideos,
      page: () => DeferredWidget(
        loader: my_videos.loadLibrary,
        builder: () => my_videos.MyVideos(),
      ),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [ConsumerRouteGuard(), AuthGuard()],
      binding: MyVideosBinding(),
    ),
  ];

  /// Catch-all creator handle route (`/:handle`). Must be mounted at the very end
  /// of [AppPages.routes] to prevent hijacking specific single-segment routes
  /// like `/onboarding`, `/library`, `/settings`, `/feedback`, etc.
  static final GetPage handleRoute = GetPage(
    name: AppRoutes.handle,
    page: () {
      final channel = Get.arguments?['channel'];
      return DeferredWidget(
        loader: channel_details.loadLibrary,
        builder: () => channel_details.ChannelDetailsPage(
          channel: channel as Channel?,
        ),
      );
    },
    transition: AppTransitions.hierarchical,
    transitionDuration: AppTransitions.hierarchicalDuration,
    curve: AppTransitions.hierarchicalCurve,
    middlewares: [HandleRouteGuardMiddleware()],
    binding: ChannelBinding(),
  );
}
