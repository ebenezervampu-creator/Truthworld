import 'package:get/get.dart';
import 'package:truthworld/core/bindings/app_bindings.dart';
import 'package:truthworld/core/utils/route_guards.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/features/community/presentation/bindings/saved_comments_binding.dart';
import 'package:truthworld/features/community/presentation/bindings/saved_community_posts_binding.dart';
import 'package:truthworld/features/community/presentation/views/saved_comments_screen.dart';
import 'package:truthworld/features/community/presentation/views/saved_community_posts_screen.dart';
import 'package:truthworld/features/home/presentation/views/home/home.dart';
import 'package:truthworld/features/topics/presentation/bindings/topics_binding.dart';
import 'package:truthworld/features/topics/presentation/pages/explore_topics_page.dart'
    deferred as explore_topics;
import 'package:truthworld/features/topics/presentation/pages/following_topics_page.dart'
    deferred as following_topics;
import 'package:truthworld/features/topics/presentation/pages/topic_page.dart';
import 'package:truthworld/routes/app_routes.dart';

/// Community posts, debates, discussion topics, and saved content routes.
class CommunityRoutes {
  CommunityRoutes._();

  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.postWithId,
      page: Home.new,
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.communityWithId,
      page: Home.new,
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.followingTopics,
      page: () => DeferredWidget(
        loader: following_topics.loadLibrary,
        builder: () => following_topics.FollowingTopicsPage(),
      ),
      middlewares: [ConsumerRouteGuard(), AuthGuard()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: AppRoutes.exploreTopics,
      page: () => DeferredWidget(
        loader: explore_topics.loadLibrary,
        builder: () => explore_topics.ExploreTopicsPage(),
      ),
      middlewares: [ConsumerRouteGuard()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: AppRoutes.topicSlug,
      page: () => const TopicPage(),
      middlewares: [TopicRedirectMiddleware()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: AppRoutes.topicsSlug,
      page: () => const TopicPage(),
      middlewares: [TopicRedirectMiddleware()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: AppRoutes.topicSlugCapT,
      page: () => const TopicPage(),
      middlewares: [TopicRedirectMiddleware()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: AppRoutes.topicSlugLowerT,
      page: () => const TopicPage(),
      middlewares: [TopicRedirectMiddleware()],
      binding: TopicsBinding(),
    ),
    GetPage(
      name: AppRoutes.savedPosts,
      page: () => const SavedCommunityPostsScreen(),
      binding: SavedCommunityPostsBinding(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.savedComments,
      page: () => const SavedCommentsScreen(),
      binding: SavedCommentsBinding(),
      middlewares: [AuthGuard()],
    ),
  ];
}
