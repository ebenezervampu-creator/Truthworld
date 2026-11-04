import 'package:get/get.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/routes/modules/admin_routes.dart';
import 'package:truthworld/routes/modules/advertiser_routes.dart';
import 'package:truthworld/routes/modules/channel_routes.dart';
import 'package:truthworld/routes/modules/community_routes.dart';
import 'package:truthworld/routes/modules/core_routes.dart';
import 'package:truthworld/routes/modules/economy_routes.dart';
import 'package:truthworld/routes/modules/legal_routes.dart';
import 'package:truthworld/routes/modules/studio_routes.dart';
import 'package:truthworld/routes/modules/upload_routes.dart';
import 'package:truthworld/routes/modules/user_library_routes.dart';
import 'package:truthworld/routes/modules/video_routes.dart';

export 'app_routes.dart';
export 'app_transitions.dart';

/// Clean Architecture Composite Router for TruthWorld.
///
/// Decouples feature route tables into focused, single-responsibility modules:
/// - [CoreRoutes]: Dynamic root entry point, home feed, search, and platform overview.
/// - [VideoRoutes]: Streaming video player, shorts, clips, trending, and category feeds.
/// - [StudioRoutes]: Creator studio, drafts, trash, and deep analytics dashboards.
/// - [UploadRoutes]: Media pipeline ingestion, video, subtitles, dubbing, and community creation.
/// - [ChannelRoutes]: Creator profile screens, handles, wizard, plans, and subscriptions.
/// - [CommunityRoutes]: Posts, debates, topic breakdown, and saved interactions.
/// - [UserLibraryRoutes]: Watch history, bookmarks, offline library, and user preferences.
/// - [AdminRoutes]: Moderation portal, RBAC gates, and telemetry dashboards.
/// - [AdvertiserRoutes]: Ad campaign manager, portal, and placement auditing.
/// - [EconomyRoutes]: Monetization tiers, wallet balance, checkout, and payment handoff.
/// - [LegalRoutes]: Terms of service, privacy policy, guidelines, and copyright complaints.
class AppPages {
  AppPages._();

  /// Default landing route path.
  static const String initial = AppRoutes.root;

  /// Aggregated route table dynamically isolated by active platform and flavor.
  static List<GetPage> get routes {
    return [
      ...CoreRoutes.routes,
      ...VideoRoutes.routes,
      ...StudioRoutes.routes,
      ...UploadRoutes.routes,
      ...ChannelRoutes.routes,
      ...CommunityRoutes.routes,
      ...UserLibraryRoutes.routes,
      ...AdminRoutes.routes,
      ...AdvertiserRoutes.routes,
      ...EconomyRoutes.routes,
      ...LegalRoutes.routes,
      ChannelRoutes.handleRoute,
    ];
  }
}
