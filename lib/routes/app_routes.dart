/// Centralized strongly-typed route definitions for TruthWorld.
///
/// Follows Clean Architecture principles by providing a single source of truth
/// for route paths, eliminating magic strings and enabling type-safe navigation.
abstract class AppRoutes {
  AppRoutes._();

  // --- Core & Shell ---
  static const root = '/';
  static const home = '/home';
  static const about = '/about';
  static const search = '/search';

  // --- Video Streaming & Discovery ---
  static const watch = '/watch';
  static const watchWithId = '/watch/:videoId';
  static const videoscreen = '/videoscreen';
  static const videoAlias = '/video/:videoId';
  static const videoShortLink = '/v/:videoId';
  static const shorts = '/shorts/:videoId';
  static const clips = '/clips';
  static const trending = '/trending';
  static const category = '/category';
  static const browse = '/browse';
  static const downloads = '/downloads';
  static const videoAnalysis = '/video-analysis';
  static const videoDescription = '/video-description';
  static const analysis = '/analysis';
  static const askAi = '/ask-ai';
  static const aiChat = '/ai-chat';
  static const claimDetail = '/claim-detail';
  static const claim = '/claim';
  static const claimDetailScreen = '/ClaimDetailScreen';

  // --- Creator Studio ---
  static const studio = '/studio';
  static const dashboard = '/dashboard';
  static const studioNotifications = '/studio/notifications';
  static const studioChapters = '/studio/chapters';
  static const studioDrafts = '/studio/drafts';
  static const studioCommunity = '/studio/community';
  static const studioTrash = '/studio/trash';
  static const studioCreateMembershipTier = '/studio/memberships/create';
  static const analytics = '/analytics';
  static const watchtime = '/watchtime';
  static const watchtimePage = '/WatchTimePage';
  static const watchtimeDetails = '/watchtimedetails';
  static const views = '/views';
  static const subscribers = '/subscribers';

  // --- Content Creation & Upload ---
  static const upload = '/upload';
  static const uploadVideo = '/upload/video';
  static const uploadSubtitles = '/upload/subtitles';
  static const uploadDubbing = '/upload/dubbing';
  static const uploadSubtitlesAndDubbing = '/upload/subtitles-and-dubbing';
  static const uploadCommunity = '/upload/community';
  static const createPost = '/create-post';
  static const createPlaylist = '/create-playlist';
  static const uploadPlaylist = '/upload/playlist';
  static const createTopic = '/create-topic';
  static const uploadTopic = '/upload/topic';
  static const uploadscreen = '/uploadscreen';

  // --- Channels & Social ---
  static const channelDetails = '/channel-details';
  static const channelWithId = '/channel/:channelId';
  static const channelHandle = '/@:handle';
  static const channelWizard = '/channelscreen';
  static const channelPlanComparison = '/channel-plan-comparison';
  static const channelDescription = '/channel-description';
  static const subscriptions = '/subscriptions';
  static const discover = '/discover';
  static const myvideos = '/myvideos';

  // --- Community & Discussions ---
  static const postWithId = '/post/:postId';
  static const communityWithId = '/community/:postId';
  static const topicSlug = '/topic/:slug';
  static const topicsSlug = '/topics/:slug';
  static const topicSlugCapT = '/T/:slug';
  static const topicSlugLowerT = '/t/:slug';
  static const followingTopics = '/following-topics';
  static const exploreTopics = '/explore-topics';
  static const savedPosts = '/saved-community-posts';
  static const savedComments = '/saved-comments';

  // --- User Library & Settings ---
  static const library = '/library';
  static const history = '/history';
  static const likedVideos = '/likedvideos';
  static const watchLater = '/watchlater';
  static const playlistScreen = '/playlistscreen';
  static const playlistWithId = '/playlist/:playlistId';
  static const playlistDetail = '/playlist-detail';
  static const settings = '/settings';
  static const editProfile = '/settings/edit-profile';
  static const trash = '/trash';
  static const onboarding = '/onboarding';
  static const notifications = '/notifications';

  // --- Admin & Moderation ---
  static const adminRoot = '/admin';
  static const adminLogin = '/admin/login';
  static const adminDashboard = '/admin/dashboard';

  // --- Advertiser Portal ---
  static const advertiser = '/advertiser';
  static const advertisements = '/advertisements';
  static const ads = '/ads';

  // --- Monetization & Economy ---
  static const premium = '/premium';
  static const checkout = '/checkout';
  static const paymentResult = '/payment-result';

  // --- Legal, Support & Policies ---
  static const feedback = '/feedback';
  static const terms = '/terms';
  static const privacy = '/privacy';
  static const communityGuidelines = '/community-guidelines';
  static const copyrightComplaint = '/copyright-complaint';
  static const dmca = '/dmca';

  // --- Catch-All Handle Route ---
  static const handle = '/:handle';
}
