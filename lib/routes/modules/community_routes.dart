import 'package:get/get.dart';
import 'package:truthworld/core/utils/route_guards.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/features/community/presentation/bindings/community_post_screen_binding.dart';
import 'package:truthworld/features/community/presentation/bindings/saved_comments_binding.dart';
import 'package:truthworld/features/community/presentation/bindings/saved_community_posts_binding.dart';
import 'package:truthworld/features/community/presentation/views/community_post_screen.dart';
import 'package:truthworld/features/community/presentation/views/saved_comments_screen.dart';
import 'package:truthworld/features/community/presentation/views/saved_community_posts_screen.dart';
import 'package:truthworld/features/topics/presentation/bindings/topics_binding.dart';
import 'package:truthworld/features/topics/presentation/pages/explore_topics_page.dart'
    deferred as explore_topics;
import 'package:truthworld/features/topics/presentation/pages/following_topics_page.dart'
    deferred as following_topics;
import 'package:truthworld/features/topics/presentation/pages/topic_page.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/routes/app_transitions.dart';

/// Community posts, debates, discussion topics, and saved content routes.
class CommunityRoutes {
  CommunityRoutes._();

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.postWithId,
      page: CommunityPostScreen.new,
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: CommunityPostScreenBinding(),
    ),
    GetPage(
      name: AppRoutes.communityWithId,
      page: CommunityPostScreen.new,
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: CommunityPostScreenBinding(),
    ),
    GetPage(
      name: AppRoutes.followingTopics,
      page: () => DeferredWidget(
        loader: following_topics.loadLibrary,
        builder: () => following_topics.FollowingTopicsPage(),
      ),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [ConsumerRouteGuard(), AuthGuard()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: AppRoutes.exploreTopics,
      page: () => DeferredWidget(
        loader: explore_topics.loadLibrary,
        builder: () => explore_topics.ExploreTopicsPage(),
      ),
      transition: AppTransitions.peer,
      transitionDuration: AppTransitions.peerDuration,
      curve: AppTransitions.peerCurve,
      middlewares: [ConsumerRouteGuard()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: AppRoutes.topicSlug,
      page: () => const TopicPage(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [TopicRedirectMiddleware()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: AppRoutes.topicsSlug,
      page: () => const TopicPage(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [TopicRedirectMiddleware()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: AppRoutes.topicSlugCapT,
      page: () => const TopicPage(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [TopicRedirectMiddleware()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: AppRoutes.topicSlugLowerT,
      page: () => const TopicPage(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      middlewares: [TopicRedirectMiddleware()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: AppRoutes.savedPosts,
      page: () => const SavedCommunityPostsScreen(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: SavedCommunityPostsBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.savedComments,
      page: () => const SavedCommentsScreen(),
      transition: AppTransitions.hierarchical,
      transitionDuration: AppTransitions.hierarchicalDuration,
      curve: AppTransitions.hierarchicalCurve,
      binding: SavedCommentsBinding(),
      middlewares: [AuthGuard()],
    ),
  ];
}
