import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/repositories/topic_repository.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:uuid/uuid.dart';

// ==========================================================================
// MODELS AND ENUMS
// ==========================================================================

// ContentValidationResult is now provided by content_validation_mixin.dart

class TransactionResult {
  TransactionResult({
    this.success = false,
    this.errorMessage,
    this.alreadySubscribed = false,
  });
  final bool success;
  final String? errorMessage;
  final bool alreadySubscribed;
}

enum AvailabilityStatus { unknown, checking, available, taken, invalid, error }

extension AvailabilityStatusExtension on AvailabilityStatus {
  Color get color {
    switch (this) {
      case AvailabilityStatus.unknown:
        return AppColors.textSecondary;
      case AvailabilityStatus.checking:
        return const Color(0xFFF59E0B);
      case AvailabilityStatus.available:
        return AppColors.success;
      case AvailabilityStatus.taken:
      case AvailabilityStatus.invalid:
      case AvailabilityStatus.error:
        return AppColors.brand;
    }
  }

  IconData get icon {
    switch (this) {
      case AvailabilityStatus.unknown:
        return Icons.help_outline;
      case AvailabilityStatus.checking:
        return Icons.hourglass_empty;
      case AvailabilityStatus.available:
        return Icons.check_circle;
      case AvailabilityStatus.taken:
        return Icons.cancel;
      case AvailabilityStatus.invalid:
      case AvailabilityStatus.error:
        return Icons.error;
    }
  }

  String get message {
    switch (this) {
      case AvailabilityStatus.unknown:
        return '';
      case AvailabilityStatus.checking:
        return 'Checking availability...';
      case AvailabilityStatus.available:
        return 'Available!';
      case AvailabilityStatus.taken:
        return 'This name is already taken';
      case AvailabilityStatus.invalid:
        return 'Invalid format';
      case AvailabilityStatus.error:
        return 'Error checking availability';
    }
  }
}

class ImageData {
  ImageData({
    required this.bytes,
    required this.name,
    required this.size,
    required this.aspectRatio,
  });
  final Uint8List bytes;
  final String name;
  final int size;
  final double aspectRatio;
}

// ==========================================================================
// UNIFIED CHANNEL CONTROLLER
// ==========================================================================

class ChannelController extends GetxController
    with GetTickerProviderStateMixin, ContentValidationMixin {
  static final RxMap<String, int> globalSubscriberCounts = <String, int>{}.obs;
  // Flag to track disposal state and prevent ticker errors
  bool _isDisposed = false;
  @override
  bool get isClosed => _isDisposed;
  // Dependencies
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();
  final ImageVerificationService _imageVerificationService =
      ImageVerificationService();

  // Moderation filters are now provided by ContentValidationMixin

  // Form Keys
  final formKey = GlobalKey<FormState>();

  // Text Editing Controllers
  final channelName = TextEditingController();
  final description = TextEditingController();
  final customUrl = TextEditingController();
  final tags = TextEditingController();
  final contactEmail = TextEditingController();
  final websiteUrl = TextEditingController();

  // Constants
  static const String _channelsCol = 'channels';
  static const String _subsCol = 'subscriptions';
  static const int maxChannelsPerUser = 1;
  static const int debounceDurationMs = 500;
  static const int minChannelNameLength = 3;
  static const int maxChannelNameLength = 50;
  static const int minCustomUrlLength = 3;
  static const int maxCustomUrlLength = 30;
  static const int maxDescriptionLength = 1000;
  static const int maxTags = 10;
  static const int maxBannerSize = 5 * 1024 * 1024; // 5MB
  static const int maxAvatarSize = 2 * 1024 * 1024; // 2MB
  static const double recommendedBannerRatio = 16 / 9;
  static const double recommendedAvatarRatio = 1;

  // Animation Controllers
  late AnimationController formFadeAnimationController;
  late AnimationController formSlideAnimationController;
  late AnimationController formScaleAnimationController;
  late AnimationController heroAnimationController;
  late AnimationController staggeredAnimationController;
  late AnimationController buttonAnimationController;
  late AnimationController successAnimationController;

  // Animations
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;
  late Animation<double> scaleAnimation;
  late Animation<double> heroAnimation;
  late Animation<double> buttonScaleAnimation;
  late Animation<double> successScaleAnimation;

  // Channel Details Page Animations
  late AnimationController pageFadeAnimationController;
  late AnimationController pageSlideAnimationController;
  late AnimationController pageScaleAnimationController;
  late Animation<double> pageFadeAnimation;
  late Animation<Offset> pageSlideAnimation;
  late Animation<double> pageScaleAnimation;

  // Subscription Button Animations
  late AnimationController subscriptionAnimationController;
  late Animation<double> subscriptionScaleAnimation;

  // Reactive State - Channel List
  RxList<Channel> channels = RxList<Channel>();
  Rx<Channel?> selectedChannel = Rx<Channel?>(null);
  RxBool isSubscribed = false.obs;
  RxBool isSubscriptionLoading = true.obs;
  final RxBool notificationsEnabled = true.obs;
  final RxString notificationOption = 'all'.obs;
  final RxMap<String, RxBool> _subscribedMap = <String, RxBool>{}.obs;
  RxInt subscriberCount = 0.obs;
  RxBool isLoading = false.obs;
  // Track channels subscribed to during this app session for "new subscriber" analytics
  final Set<String> _sessionSubscribedChannels = {};
  RxString errorMessage = ''.obs;
  RxDouble uploadProgress = 0.0.obs;
  final RxString channelNameMessage = ''.obs;
  final Rx<ChannelType> selectedChannelType = ChannelType.standard.obs;

  // State for Channel Details Page
  final RxBool isAppBarExpanded = false.obs;
  final RxBool isLoadingVideos = false.obs;
  final RxList<Video> videos = <Video>[].obs;
  final lastVideoDocument = Rx<DocumentSnapshot?>(null);
  final RxBool isLoadingMore = false.obs;
  final RxString videoSortFilter = 'Latest'.obs;

  // Reactive flags for channel content tabs availability
  final RxBool hasVideos = false.obs;
  final RxBool hasPlaylists = false.obs;
  final RxBool hasPosts = false.obs;
  final RxBool hasTopics = false.obs;
  final RxInt channelVideoCount = 0.obs;

  List<String> get activeTabs {
    return const ['Home', 'Videos', 'Topics', 'Playlists', 'Posts'];
  }

  // Topic content maps matching Saved Topics (FollowingTopicsPage) architecture
  final TopicRepository _topicRepository = TopicRepository();
  final Rxn<Topic> selectedChannelTopic = Rxn<Topic>();
  final RxMap<String, List<Video>> topicVideosMap = <String, List<Video>>{}.obs;
  final RxMap<String, bool> isLoadingVideosMap = <String, bool>{}.obs;
  final RxMap<String, List<CommunityPostModel>> topicPostsMap =
      <String, List<CommunityPostModel>>{}.obs;
  final RxMap<String, bool> isLoadingPostsMap = <String, bool>{}.obs;

  Future<void> fetchVideosForChannelTopic(Topic topic) async {
    final key = topic.id;
    if (topicVideosMap.containsKey(key) && isLoadingVideosMap[key] != true) {
      return;
    }
    isLoadingVideosMap[key] = true;
    try {
      var vids = await _topicRepository.getVideosByTopic(topic.slug);
      if (vids.isEmpty && topic.id != topic.slug) {
        vids = await _topicRepository.getVideosByTopic(topic.id);
      }
      topicVideosMap[key] = vids;
    } catch (e) {
      debugPrint('Error fetching videos for channel topic ${topic.title}: $e');
      topicVideosMap[key] = [];
    } finally {
      isLoadingVideosMap[key] = false;
    }
  }

  Future<void> fetchPostsForChannelTopic(Topic topic) async {
    final key = topic.id;
    if (topicPostsMap.containsKey(key) && isLoadingPostsMap[key] != true) {
      return;
    }
    isLoadingPostsMap[key] = true;
    try {
      var posts = await _topicRepository.getCommunityPostsByTopic(topic.slug);
      if (posts.isEmpty && topic.id != topic.slug) {
        posts = await _topicRepository.getCommunityPostsByTopic(topic.id);
      }
      topicPostsMap[key] = posts;
    } catch (e) {
      debugPrint('Error fetching posts for channel topic ${topic.title}: $e');
      topicPostsMap[key] = [];
    } finally {
      isLoadingPostsMap[key] = false;
    }
  }

  void selectChannelTopic(Topic? topic) {
    selectedChannelTopic.value = topic;
    if (topic != null) {
      fetchVideosForChannelTopic(topic);
      fetchPostsForChannelTopic(topic);
    }
  }

  // Reactive State - Image Upload
  final bannerImageData = Rx<ImageData?>(null);
  final avatarImageData = Rx<ImageData?>(null);
  final RxString bannerUrl = ''.obs;
  final RxString avatarUrl = ''.obs;
  final RxDouble bannerUploadProgress = 0.0.obs;
  final RxDouble avatarUploadProgress = 0.0.obs;
  final RxBool isUploadingBanner = false.obs;
  final RxBool isUploadingAvatar = false.obs;

  // Moderation statuses
  final RxString bannerStatus = 'PENDING'.obs;
  final RxString avatarStatus = 'PENDING'.obs;
  final RxString bannerStatusReason = ''.obs;
  final RxString avatarStatusReason = ''.obs;

  // Verification File IDs
  final RxString avatarFileId = ''.obs;
  final RxString bannerFileId = ''.obs;

  // Details screen real-time verification statuses
  final RxString detailsAvatarStatus = ''.obs;
  final RxString detailsBannerStatus = ''.obs;
  final RxString detailsAvatarReason = ''.obs;
  final RxString detailsBannerReason = ''.obs;

  StreamSubscription? _detailsAvatarSub;
  StreamSubscription? _detailsBannerSub;

  // Draft management
  final RxBool hasDraft = false.obs;
  final draftId = Rx<String?>(null);
  final RxBool isSavingDraft = false.obs;
  final lastDraftSaveTime = Rx<DateTime?>(null);
  final RxBool isSubmitting = false.obs;

  // Other reactive state
  final RxBool isPublic = true.obs;
  final RxString language = 'en'.obs;
  final selectedCategory = Rx<String?>(null);
  final RxList<String> selectedCategories = <String>[].obs;
  final RxBool isAgreed = false.obs;
  final RxInt formChangeTrigger = 0.obs;
  final RxMap<String, String> socialLinks = {
    'twitter': '',
    'instagram': '',
    'youtube': '',
    'website': '',
  }.obs;
  final RxMap<String, dynamic> advancedSettings = <String, dynamic>{
    'allowComments': true,
    'allowSubscriptions': true,
    'showSubscriberCount': true,
  }.obs;

  // Notification preferences
  final RxBool notificationAll = true.obs;
  final RxBool notificationPersonalized = true.obs;
  final RxBool notificationNew = true.obs;
  final RxBool notificationLive = true.obs;
  final RxBool notificationPlaylist = false.obs;

  // Availability Checking
  final RxList<String> handleSuggestions = <String>[].obs;
  Rx<AvailabilityStatus> channelNameAvailability = Rx<AvailabilityStatus>(
    AvailabilityStatus.unknown,
  );
  Rx<AvailabilityStatus> customUrlAvailability = Rx<AvailabilityStatus>(
    AvailabilityStatus.unknown,
  );
  Timer? _channelNameDebounceTimer;
  Timer? _customUrlDebounceTimer;
  String _lastAutoSlug = '';

  // Subscriptions
  StreamSubscription? _subscriptionListener;
  StreamSubscription? _countListener;
  final Map<String, StreamSubscription> _moderationListeners = {};
  List<String> uploadedDocIds = [];

  // Lists
  final List<String> tabs = [
    'Home',
    'Videos',
    'Playlists',
    'Channels',
    'About',
  ];

  final List<String> languages = [
    'en',
    'es',
    'fr',
    'de',
    'zh',
    'ja',
    'ar',
    'hi',
    'pt',
    'ru',
  ];

  final List<String> categories = [
    'Gaming',
    'Music',
    'Entertainment',
    'Education',
    'Technology',
    'Sports',
    'News',
    'Lifestyle',
    'Travel',
    'Food',
    'Fashion',
    'Health',
    'Business',
    'Comedy',
    'Science',
    'Art',
    'Documentary',
    'Animation',
    'Automotive',
    'Pets & Animals',
    'DIY & How-to',
    'Fitness',
    'Beauty',
    'Finance',
    'History',
    'Nature',
    'Spirituality',
    'Kids & Family',
    'Other',
  ];

  // Computed Properties
  bool get canCreateMoreChannels => channels.length < maxChannelsPerUser;

  // Category Selection Helpers
  void toggleCategory(String category) {
    if (selectedCategories.contains(category)) {
      selectedCategories.remove(category);
    } else {
      selectedCategories.add(category);
    }
    selectedCategory.value = selectedCategories.isEmpty
        ? null
        : selectedCategories.first;
    formChangeTrigger.value++;
  }

  void selectAllCategories() {
    selectedCategories.assignAll(categories);
    selectedCategory.value = categories.isNotEmpty ? categories.first : 'Other';
    formChangeTrigger.value++;
  }

  void deselectAllCategories() {
    selectedCategories.clear();
    selectedCategory.value = null;
    formChangeTrigger.value++;
  }

  bool isCategorySelected(String category) {
    return selectedCategories.contains(category);
  }

  bool get isAllCategoriesSelected =>
      selectedCategories.length == categories.length && categories.isNotEmpty;

  // UI Controllers for details page
  late ScrollController scrollController;
  late TabController tabController;

  @override
  void onInit() {
    super.onInit();

    // Init UI controllers immediately so they are never null
    scrollController = ScrollController();
    tabController = TabController(length: tabs.length, vsync: this);

    initializeContentFilters();
    _initializeAnimations();

    final user = _auth.currentUser;
    if (user != null) {
      // Auto-populate channel name from user's display name if empty
      if (channelName.text.isEmpty) {
        final name = user.displayName ?? '';
        if (name.isNotEmpty) {
          channelName.text = name;
          checkChannelNameAvailability(name);
        }
      }

      _setupTextFieldListeners();
      _setupFormValidationListeners();
      _loadDraft();
      startAnimations();

      // Keep channels RxList in sync with Firestore
      isLoading.value = true;
      _firestore
          .collection(_channelsCol)
          .where('ownerId', isEqualTo: user.uid)
          .snapshots()
          .listen(
            (snapshot) {
              final results = snapshot.docs
                  .map(Channel.fromDocumentSnapshot)
                  .where((channel) => !channel.isArchived)
                  .toList();
              channels.assignAll(results);
              isLoading.value = false;
            },
            onError: (error) {
              debugPrint('Error fetching channels: $error');
              isLoading.value = false;
            },
          );
    }
  }

  // In ChannelController
  Future<void> fetchUserChannels() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      isLoading.value = true;
      final snapshot = await _firestore
          .collection(_channelsCol)
          .where('ownerId', isEqualTo: user.uid)
          .get();

      final results = snapshot.docs
          .map(Channel.fromDocumentSnapshot)
          .where((channel) => !channel.isArchived)
          .toList();

      channels.assignAll(results);
    } catch (e) {
      debugPrint('Error fetching channels: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // _initializeFilters removed in favor of initializeContentFilters from mixin

  void _initializeAnimations() {
    // Existing animations
    formFadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    formSlideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    formScaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    heroAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Creation wizard animations
    staggeredAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: formFadeAnimationController,
        curve: Curves.easeIn,
      ),
    );
    slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: formSlideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
    scaleAnimation = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(
        parent: formScaleAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    heroAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: heroAnimationController, curve: Curves.easeInOut),
    );
    buttonScaleAnimation = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(
        parent: buttonAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    successScaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: successAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    // Page animations
    pageFadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    pageSlideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    pageScaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    pageFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: pageFadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    pageSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: pageSlideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
    pageScaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(
        parent: pageScaleAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    // Subscription button animations
    subscriptionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    subscriptionScaleAnimation = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(
        parent: subscriptionAnimationController,
        curve: Curves.elasticOut,
      ),
    );
  }

  void _updateHandleSuggestions(String baseSlug) {
    if (baseSlug.trim().isEmpty) {
      handleSuggestions.clear();
      return;
    }
    final base = baseSlug.length > 25 ? baseSlug.substring(0, 25) : baseSlug;
    handleSuggestions.value = [
      base,
      '${base}123',
      '${base}_vsp',
      '${base}777',
    ];
  }

  void _setupTextFieldListeners() {
    channelName.addListener(() {
      checkChannelNameAvailability(channelName.text);
      // Auto-fill custom URL if it's empty or was previously auto-filled
      final slug = channelName.text
          .toLowerCase()
          .trim()
          .replaceAll(RegExp('[^a-z0-9_-]'), '-')
          .replaceAll(RegExp('-+'), '-')
          .replaceAll(RegExp('_+'), '_');
      var cleanSlug = slug;
      if (cleanSlug.startsWith('-') || cleanSlug.startsWith('_')) {
        cleanSlug = cleanSlug.substring(1);
      }
      if (cleanSlug.endsWith('-') || cleanSlug.endsWith('_')) {
        cleanSlug = cleanSlug.substring(0, cleanSlug.length - 1);
      }
      if (customUrl.text.isEmpty || customUrl.text == _lastAutoSlug) {
        customUrl.text = cleanSlug;
        _lastAutoSlug = cleanSlug;
        if (cleanSlug.isNotEmpty) {
          checkCustomUrlAvailability(cleanSlug);
        }
      }
      _updateHandleSuggestions(cleanSlug);
      formChangeTrigger.value++;
    });
    customUrl.addListener(() {
      if (customUrl.text.isNotEmpty) {
        checkCustomUrlAvailability(customUrl.text);
      } else {
        customUrlAvailability.value = AvailabilityStatus.unknown;
      }
    });
    description.addListener(() {
      formChangeTrigger.value++;
    });
  }

  void _setupFormValidationListeners() {
    // Already handled in _setupTextFieldListeners
  }

  void startAnimations() {
    if (isClosed) return;
    try {
      formFadeAnimationController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!isClosed) formSlideAnimationController.forward();
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!isClosed) formScaleAnimationController.forward();
      });
      if (!isClosed) staggeredAnimationController.forward();
    } catch (e) {
      debugPrint('Animation start error: $e');
    }
  }

  void startPageAnimations() {
    pageFadeAnimationController.forward();
    pageSlideAnimationController.forward();
    pageScaleAnimationController.forward();
  }

  @override
  void onClose() {
    _isDisposed = true;

    // Dispose text controllers
    channelName.dispose();
    description.dispose();
    customUrl.dispose();
    tags.dispose();
    contactEmail.dispose();
    websiteUrl.dispose();

    // Dispose animation controllers
    formFadeAnimationController.dispose();
    formSlideAnimationController.dispose();
    formScaleAnimationController.dispose();
    heroAnimationController.dispose();
    staggeredAnimationController.dispose();
    buttonAnimationController.dispose();
    successAnimationController.dispose();
    pageFadeAnimationController.dispose();
    pageSlideAnimationController.dispose();
    pageScaleAnimationController.dispose();
    subscriptionAnimationController.dispose();

    // Dispose UI controllers
    scrollController.dispose();
    tabController.dispose();

    // Cancel subscriptions
    _subscriptionListener?.cancel();
    _countListener?.cancel();
    _channelNameDebounceTimer?.cancel();
    _customUrlDebounceTimer?.cancel();

    // Cancel moderation listeners
    for (final sub in _moderationListeners.values) {
      sub.cancel();
    }
    _moderationListeners.clear();

    // Call clear state to ensure all listeners/subscriptions are removed
    clearChannelDetailsState();

    super.onClose();
  }

  // ==========================================================================
  // CONTENT VALIDATION
  // ==========================================================================

  // Deprecated validation logic replaced by ContentValidationMixin

  // validateTags is now provided by ContentValidationMixin

  // ==========================================================================
  // AVAILABILITY CHECKING
  // ==========================================================================

  void checkChannelNameAvailability(String channelName) {
    _channelNameDebounceTimer?.cancel();

    if (channelName.trim().isEmpty) {
      channelNameAvailability.value = AvailabilityStatus.unknown;
      return;
    }

    if (channelName.length < minChannelNameLength ||
        channelName.length > maxChannelNameLength) {
      channelNameAvailability.value = AvailabilityStatus.invalid;
      return;
    }

    channelNameAvailability.value = AvailabilityStatus.checking;

    _channelNameDebounceTimer = Timer(
      const Duration(milliseconds: debounceDurationMs),
      () => _performChannelNameAvailabilityCheck(channelName),
    );
  }

  Future<void> _performChannelNameAvailabilityCheck(String channelName) async {
    try {
      final snapshot = await _firestore
          .collection(_channelsCol)
          .where('nameLowercase', isEqualTo: channelName.trim().toLowerCase())
          .limit(1)
          .get();

      channelNameAvailability.value = snapshot.docs.isEmpty
          ? AvailabilityStatus.available
          : AvailabilityStatus.taken;
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        debugPrint(
          '📋 ChannelController: Permission denied checking channel name. Using error state.',
        );
      } else {
        debugPrint('❌ ChannelController: Error checking channel name: $e');
      }
      channelNameAvailability.value = AvailabilityStatus.error;
    }
  }

  void checkCustomUrlAvailability(String customUrl) {
    _customUrlDebounceTimer?.cancel();

    if (customUrl.trim().isEmpty) {
      customUrlAvailability.value = AvailabilityStatus.unknown;
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(customUrl) ||
        customUrl.length < minCustomUrlLength ||
        customUrl.length > maxCustomUrlLength) {
      customUrlAvailability.value = AvailabilityStatus.invalid;
      return;
    }

    customUrlAvailability.value = AvailabilityStatus.checking;

    _customUrlDebounceTimer = Timer(
      const Duration(milliseconds: debounceDurationMs),
      () => _performCustomUrlAvailabilityCheck(customUrl),
    );
  }

  Future<void> _performCustomUrlAvailabilityCheck(String customUrl) async {
    try {
      final snapshot = await _firestore
          .collection(_channelsCol)
          .where('handleLowercase', isEqualTo: customUrl.trim().toLowerCase())
          .limit(1)
          .get();

      customUrlAvailability.value = snapshot.docs.isEmpty
          ? AvailabilityStatus.available
          : AvailabilityStatus.taken;
    } catch (e) {
      debugPrint('Error checking custom URL: $e');
      customUrlAvailability.value = AvailabilityStatus.error;
    }
  }

  void resetAvailabilityStatus() {
    channelNameAvailability.value = AvailabilityStatus.unknown;
    customUrlAvailability.value = AvailabilityStatus.unknown;
  }

  // ==========================================================================
  // IMAGE UPLOAD
  // ==========================================================================

  Future<Map<String, String>?> uploadImage(
    PlatformFile file,
    String folder,
    String userId, {
    Function(double progress)? onProgress,
  }) async {
    try {
      final uniqueFileName = '${_uuid.v4()}.${file.extension}';
      final ref = _storage.ref().child(
        'channels/$folder/$userId/$uniqueFileName',
      );

      final metadata = SettableMetadata(contentType: 'image/${file.extension}');
      final uploadTask = ref.putData(file.bytes!, metadata);

      uploadTask.snapshotEvents.listen(
        (snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          if (onProgress != null) onProgress(progress);
        },
        onError: (e) {
          debugPrint('Upload stream error: $e');
        },
      );

      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      return {'url': url, 'fileName': uniqueFileName};
    } on FirebaseException catch (e) {
      debugPrint('ðŸ”¥ Firebase Storage Error: ${e.code}');
      debugPrint('ðŸ“ Message: ${e.message}');
      if (e.code == 'permission-denied') {
        debugPrint(
          'âš ï¸ Ensure Firebase Storage rules are configured correctly.',
        );
      }
      return null;
    } catch (e) {
      debugPrint('âŒ Upload error: $e');
      return null;
    }
  }

  Future<void> pickImage(bool isBanner) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        return _showErrorSnackbar('Unable to read image file.');
      }

      final maxSize = isBanner ? maxBannerSize : maxAvatarSize;
      if (file.size > maxSize) {
        return _showErrorSnackbar(
          'Image exceeds ${(maxSize / (1024 * 1024)).toStringAsFixed(1)}MB.',
        );
      }

      final extension = file.extension?.toLowerCase();
      if (extension == null ||
          !['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(extension)) {
        return _showErrorSnackbar(
          'Unsupported format. Use JPG, PNG, WebP, GIF.',
        );
      }

      dynamic image;
      try {
        image = await decodeImageFromList(file.bytes!);
      } catch (e) {
        return _showErrorSnackbar('Invalid image: $e');
      }
      if (image == null) return _showErrorSnackbar('Unable to decode image.');

      final imageData = ImageData(
        bytes: file.bytes!,
        name: file.name,
        size: file.size,
        aspectRatio: image.width / image.height,
      );

      if (isBanner) {
        bannerImageData.value = imageData;
        isUploadingBanner.value = true;
        bannerUploadProgress.value = 0.0;
      } else {
        avatarImageData.value = imageData;
        isUploadingAvatar.value = true;
        avatarUploadProgress.value = 0.0;
      }

      // Delete previous image
      final oldUrl = isBanner ? bannerUrl.value : avatarUrl.value;
      if (oldUrl.isNotEmpty) {
        try {
          await _storage.refFromURL(oldUrl).delete();
        } catch (_) {}
      }

      final user = _auth.currentUser;
      if (user == null) return _showErrorSnackbar('Login required.');

      final uploadData = await uploadImage(
        file,
        isBanner ? 'banners' : 'avatars',
        user.uid,
        onProgress: (progress) {
          if (isBanner) {
            bannerUploadProgress.value = progress;
          } else {
            avatarUploadProgress.value = progress;
          }
        },
      );

      if (uploadData == null) {
        if (isBanner) {
          isUploadingBanner.value = false;
          bannerStatus.value = 'ERROR';
        } else {
          isUploadingAvatar.value = false;
          avatarStatus.value = 'ERROR';
        }
        return _showErrorSnackbar('Upload failed. Please try again.');
      }

      final uploadedUrl = uploadData['url']!;
      final fileName = uploadData['fileName']!;

      if (isBanner) {
        bannerUrl.value = uploadedUrl;
        bannerFileId.value = fileName;
        isUploadingBanner.value = false;
        _startModerationListener(fileName, true);
      } else {
        avatarUrl.value = uploadedUrl;
        avatarFileId.value = fileName;
        isUploadingAvatar.value = false;
        _startModerationListener(fileName, false);
      }
    } catch (e) {
      debugPrint('Error in pickImage: $e');
      _showErrorSnackbar('Failed to process local image.');
    } finally {
      if (isBanner) {
        isUploadingBanner.value = false;
      } else {
        isUploadingAvatar.value = false;
      }
    }
  }

  void _startModerationListener(String docId, bool isBanner) {
    debugPrint(
      'ðŸ” Starting moderation listener for ${isBanner ? "banner" : "avatar"}: $docId',
    );

    // Cancel existing listener if any
    final key = isBanner ? 'banner' : 'avatar';
    _moderationListeners[key]?.cancel();

    if (isBanner) {
      bannerStatus.value = 'PENDING';
    } else {
      avatarStatus.value = 'PENDING';
    }

    _moderationListeners[key] = _imageVerificationService
        .streamVerificationStatus(docId)
        .listen((result) {
          debugPrint(
            'âœ… Received status for $key: ${result.status} - ${result.reason}',
          );

          final statusStr = result.status.name.toUpperCase();
          if (isBanner) {
            bannerStatus.value = statusStr;
            bannerStatusReason.value = result.reason;

            if (result.status == VerificationStatus.rejected) {
              Get.snackbar(
                'Banner Rejected',
                result.reason,
                backgroundColor: AppColors.brand,
                colorText: AppColors.textPrimary,
              );
            } else if (result.status == VerificationStatus.approved) {
              Get.snackbar(
                'Banner Approved',
                'Your banner has passed verification.',
                backgroundColor: AppColors.success,
                colorText: AppColors.textPrimary,
              );
            }
          } else {
            avatarStatus.value = statusStr;
            avatarStatusReason.value = result.reason;

            if (result.status == VerificationStatus.rejected) {
              Get.snackbar(
                'Avatar Rejected',
                result.reason,
                backgroundColor: AppColors.brand,
                colorText: AppColors.textPrimary,
              );
            } else if (result.status == VerificationStatus.approved) {
              Get.snackbar(
                'Avatar Approved',
                'Your avatar has passed verification.',
                backgroundColor: AppColors.success,
                colorText: AppColors.textPrimary,
              );
            }
          }
        });

    // Track for cleanup
    if (!uploadedDocIds.contains(docId)) {
      uploadedDocIds.add(docId);
    }
  }

  // ==========================================================================
  // CREATE CHANNEL
  // ==========================================================================

  Future<void> createChannel() async {
    if (isSubmitting.value) return;
    isSubmitting.value = true;

    try {
      // 0. Limit Check
      if (channels.length >= maxChannelsPerUser) {
        _showErrorSnackbar(
          'You can only create one channel per Google account.',
        );
        return;
      }

      // 1. Validation
      if (!formKey.currentState!.validate()) {
        _showErrorSnackbar('Please fill in all required fields correctly.');
        return;
      }

      /* Images are now optional for smoother creation
      if (bannerUrl.value.isEmpty) {
        _showErrorSnackbar("Please upload a banner image.");
        return;
      }

      if (avatarUrl.value.isEmpty) {
        _showErrorSnackbar("Please upload an avatar image.");
        return;
      }
      */

      // 2. Moderation checks (Background verification does not block creation if status is PENDING)
      if (avatarUrl.value.isNotEmpty) {
        if (avatarStatus.value == 'REJECTED' ||
            avatarStatus.value == 'FLAGGED') {
          _showErrorSnackbar(
            'Your avatar was rejected or flagged: ${avatarStatusReason.value}',
          );
          return;
        }
      }

      if (bannerUrl.value.isNotEmpty) {
        if (bannerStatus.value == 'REJECTED' ||
            bannerStatus.value == 'FLAGGED') {
          _showErrorSnackbar(
            'Your banner was rejected or flagged: ${bannerStatusReason.value}',
          );
          return;
        }
      }

      if (avatarStatus.value == 'ERROR' || bannerStatus.value == 'ERROR') {
        _showErrorSnackbar(
          'Moderation service error. Please try uploading your branding images again.',
        );
        return;
      }

      /* Auto-accepting terms for smoother creation
      if (!isAgreed.value) {
        _showErrorSnackbar("You must agree to the Terms and Conditions.");
        return;
      }
      */

      // Animation
      await buttonAnimationController.forward();
      await buttonAnimationController.reverse();

      // Prepare data
      final uid = _auth.currentUser!.uid;

      final tagsList = tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final channelNameText = channelName.text.trim();
      final customUrlText = customUrl.text.trim();

      const defaultBanner =
          'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?q=80&w=2670&auto=format&fit=crop';
      const defaultAvatar =
          'https://ui-avatars.com/api/?background=6B46C1&color=fff&size=512&name=';

      final channelData = {
        // Core fields matching Channel model (V2)
        'channelType': selectedChannelType.value.name,
        'name': channelNameText,
        'nameLowercase': channelNameText.toLowerCase(),
        'channelName': channelNameText,
        'channelNameLowercase': channelNameText.toLowerCase(),
        'description': description.text.trim(),
        'bannerUrl': bannerUrl.value.isEmpty ? defaultBanner : bannerUrl.value,
        'avatarUrl': avatarUrl.value.isEmpty
            ? '$defaultAvatar$channelNameText'
            : avatarUrl.value,
        'avatarFileId': avatarFileId.value.isEmpty ? null : avatarFileId.value,
        'bannerFileId': bannerFileId.value.isEmpty ? null : bannerFileId.value,
        'avatarStatus': avatarStatus.value,
        'bannerStatus': bannerStatus.value,
        'ownerId': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        // Public settings
        'isPublic': isPublic.value,
        'isVerified': false,
        'subscriberCount': 0,
        'language': language.value,
        'tags': tagsList,

        // Custom URL mapped to handle
        'handle': customUrlText,
        'handleLowercase': customUrlText.toLowerCase(),
        'customUrl': customUrlText,
        'customUrlLowercase': customUrlText.toLowerCase(),

        // Moderation lists
        'moderatorIds': [],
        'blockedUserIds': [],

        // Optional fields
        'category': selectedCategories.isEmpty
            ? (selectedCategory.value ?? 'other')
            : selectedCategories.join(', '),
        'categories': selectedCategories.isEmpty
            ? [(selectedCategory.value ?? 'other')]
            : selectedCategories.toList(),
        'contactEmail': contactEmail.text.trim().isEmpty
            ? null
            : contactEmail.text.trim(),
        'websiteUrl': websiteUrl.text.trim().isEmpty
            ? null
            : websiteUrl.text.trim(),
        'socialLinks': Map<String, dynamic>.from(socialLinks),

        // Advanced settings from form
        'allowComments': advancedSettings['allowComments'] ?? true,
        'allowSubscriptions': advancedSettings['allowSubscriptions'] ?? true,
        'showSubscriberCount': advancedSettings['showSubscriberCount'] ?? true,

        // Branding
        'brandingSettings': {
          'primaryColor': '#6B46C1',
          'secondaryColor': '#9333EA',
          'bannerStyle': 'gradient',
        },

        // Status & Metrics
        'status': 'underReview',
        'videoCount': 0,
        'isLive': false,
        'metrics': {
          'totalViews': 0,
          'totalWatchTimeMinutes': 0,
          'averageRetention': 0.0,
        },
      };

      // Firestore transaction
      final newChannelId = await _firestore.runTransaction<String?>((
        transaction,
      ) async {
        final channelRef = _firestore.collection(_channelsCol).doc();
        transaction.set(channelRef, channelData);

        // Update user document with channelId (use set+merge in case user doc doesn't exist yet)
        final userRef = _firestore
            .collection(FirestoreCollections.users)
            .doc(uid);
        transaction.set(userRef, {
          'channelId': channelRef.id,
        }, SetOptions(merge: true));

        // Delete draft if exists
        if (draftId.value != null) {
          final draftRef = _firestore
              .collection('channel_drafts')
              .doc(draftId.value);
          transaction.delete(draftRef);
        }

        return channelRef.id;
      });

      // Success
      hasDraft.value = false;
      draftId.value = null;

      _showSuccessSnackbar('Channel "$channelNameText" created successfully!');
      debugPrint('âœ… Channel created with ID: $newChannelId');
      debugPrint('ðŸ“ Channel name: $channelNameText');

      _resetForm();

      // Navigate back to Home and open Creator Studio app externally
      Get.offAllNamed('/home');
      StudioLauncher.openStudio(
        arguments: {
          'channel': {
            'id': newChannelId,
            'name': channelNameText,
          },
        },
      );
    } catch (e) {
      debugPrint('âŒ Error creating channel: $e');
      _showErrorSnackbar('Failed to create channel: $e');
    } finally {
      isSubmitting.value = false;
    }
  }

  // ==========================================================================
  // CHANNEL OPERATIONS
  // ==========================================================================

  Future<bool> archiveChannel(String channelId) async {
    try {
      await _firestore.collection(_channelsCol).doc(channelId).update({
        'status': 'deleted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showSuccessSnackbar('Channel archived successfully');
      return true;
    } catch (e) {
      _showErrorSnackbar('Failed to archive channel: $e');
      return false;
    }
  }

  Future<bool> updateChannel(
    String channelId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection(_channelsCol).doc(channelId).update(updates);
      _showSuccessSnackbar('Channel updated successfully');
      return true;
    } catch (e) {
      _showErrorSnackbar('Failed to update channel: $e');
      return false;
    }
  }

  // ==========================================================================
  // SUBSCRIPTIONS
  // ==========================================================================

  Future<bool> subscribeToChannel(String channelId) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showErrorSnackbar('You must be logged in to subscribe.');
      return false;
    }

    final subDocId = '${channelId}_${user.uid}';
    final subRef = _firestore.collection(_subsCol).doc(subDocId);
    final channelRef = _firestore.collection(_channelsCol).doc(channelId);

    try {
      // 1. Check local state first for instant feedback (Optimistic UI handled by caller)

      // 2. We use a transaction because we need to check if already subscribed
      // AND increment the counter atomically.
      // To scale for millions, we'd typically use a Cloud Function for the increment,
      // but for client-side, we can optimize by using deterministic IDs.
      await _firestore.runTransaction((tx) async {
        final txSubSnapshot = await tx.get(subRef);
        if (txSubSnapshot.exists) {
          throw Exception('already_subscribed');
        }

        // Create subscription document
        tx.set(subRef, {
          'userId': user.uid,
          'channelId': channelId,
          'subscribedAt': FieldValue.serverTimestamp(),
          'notificationsEnabled': true,
        });

        // Increment counter - FieldValue.increment is atomic and safe
        tx.update(channelRef, {
          'subscriberCount': FieldValue.increment(1),
          'lastActiveAt': FieldValue.serverTimestamp(),
        });
      }, maxAttempts: 3); // Faster fail for high contention

      isSubscribed.value = true;
      subscriberCount.value++;
      _showSuccessSnackbar('Subscribed successfully');
      return true;
    } catch (e) {
      if (e.toString().contains('already_subscribed')) {
        isSubscribed.value = true;
        return false;
      }
      _showErrorSnackbar('Failed to subscribe: $e');
      return false;
    }
  }

  Future<bool> unsubscribeFromChannel(String channelId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final subDocId = '${channelId}_${user.uid}';
    final subRef = _firestore.collection(_subsCol).doc(subDocId);
    final channelRef = _firestore.collection(_channelsCol).doc(channelId);

    try {
      await _firestore.runTransaction((tx) async {
        final subDoc = await tx.get(subRef);
        if (!subDoc.exists) return; // Already unsubscribed

        tx.delete(subRef);
        tx.update(channelRef, {'subscriberCount': FieldValue.increment(-1)});
      }, maxAttempts: 3);

      isSubscribed.value = false;
      subscriberCount.value = (subscriberCount.value - 1).clamp(0, 999999999);
      _showSuccessSnackbar('Unsubscribed successfully');
      return true;
    } catch (e) {
      _showErrorSnackbar('Failed to unsubscribe');
      return false;
    }
  }

  Future<void> toggleSubscription(String channelId) async {
    // â”€â”€ Optimistic update: toggle instantly â”€â”€
    final wasSubscribed = isSubscribed.value;
    isSubscribed.value = !wasSubscribed;
    subscriberCount.value += wasSubscribed ? -1 : 1;
    if (subscriberCount.value < 0) subscriberCount.value = 0;

    // Track as 'new subscriber' for session analytics if they just subscribed
    if (!wasSubscribed) {
      _sessionSubscribedChannels.add(channelId);
    } else {
      _sessionSubscribedChannels.remove(channelId);
    }

    // â”€â”€ Fire-and-forget API call â”€â”€
    try {
      if (wasSubscribed) {
        await unsubscribeFromChannel(channelId);
      } else {
        await subscribeToChannel(channelId);
      }
    } catch (_) {
      // Revert on error
      isSubscribed.value = wasSubscribed;
      subscriberCount.value += wasSubscribed ? 1 : -1;
      if (subscriberCount.value < 0) subscriberCount.value = 0;
      _sessionSubscribedChannels.remove(channelId);
    }
  }

  /// Returns true if the user subscribed to this channel during the current app session
  bool isNewSubscriber(String channelId) {
    return _sessionSubscribedChannels.contains(channelId);
  }

  void listenSubscription(String channelId) {
    final user = _auth.currentUser;
    if (user == null) {
      isSubscribed.value = false;
      isSubscriptionLoading.value = false;
      return;
    }

    isSubscriptionLoading.value = true;
    _subscriptionListener?.cancel();

    // COST-EFFECTIVE: Use doc lookup by deterministic ID instead of collection query
    final subDocId = '${channelId}_${user.uid}';
    _subscriptionListener = _firestore
        .collection(_subsCol)
        .doc(subDocId)
        .snapshots()
        .listen(
          (snapshot) {
            isSubscribed.value = snapshot.exists;
            if (snapshot.exists) {
              final data = snapshot.data();
              notificationsEnabled.value =
                  data?['notificationsEnabled'] ?? true;
              notificationOption.value =
                  data?['notificationOption'] as String? ??
                  (notificationsEnabled.value ? 'all' : 'none');
            }
            isSubscriptionLoading.value = false;
          },
          onError: (error) {
            isSubscribed.value = false;
            isSubscriptionLoading.value = false;
          },
        );
  }

  Future<void> updateNotificationPreference(
    String channelId,
    String option,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showErrorSnackbar('You must be logged in to update preferences.');
      return;
    }

    final subDocId = '${channelId}_${user.uid}';
    final subRef = _firestore.collection(_subsCol).doc(subDocId);
    final enabled = option != 'none';

    try {
      await subRef.set({
        'notificationsEnabled': enabled,
        'notificationOption': option,
      }, SetOptions(merge: true));
      notificationsEnabled.value = enabled;
      notificationOption.value = option;
      final msg = option == 'all'
          ? 'All notifications turned on'
          : (option == 'personalized'
                ? 'Personalized notifications set'
                : 'Notifications turned off');
      _showSuccessSnackbar(msg);
    } catch (e) {
      _showErrorSnackbar('Failed to update notification preferences');
    }
  }

  /// Check if current user is subscribed to a specific channel (reactive)
  RxBool isSubscribedTo(String channelId) {
    final user = _auth.currentUser;
    if (user == null) return false.obs;

    // Return cached if exists
    if (_subscribedMap.containsKey(channelId)) {
      return _subscribedMap[channelId]!;
    }

    final rx = false.obs;
    _subscribedMap[channelId] = rx;

    final subDocId = '${channelId}_${user.uid}';
    _firestore
        .collection(_subsCol)
        .doc(subDocId)
        .snapshots()
        .listen((snap) => rx.value = snap.exists);

    return rx;
  }

  void fetchSubscriberCount(String channelId) {
    _countListener?.cancel();
    _countListener = _firestore
        .collection(_channelsCol)
        .doc(channelId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final count = snapshot.data()?['subscriberCount'] ?? 0;
            subscriberCount.value = count is int
                ? count
                : (count as num).toInt();
            final updatedChannel = Channel.fromDocumentSnapshot(snapshot);
            selectedChannel.value = updatedChannel;
          }
        });
  }

  String get formattedSubscribers =>
      FormatUtils.formatCount(subscriberCount.value);

  // ==========================================================================
  // MODERATION
  // ==========================================================================

  Future<bool> addModerator(String channelId, String userId) async {
    try {
      await _firestore
          .collection(_channelsCol)
          .doc(channelId)
          .collection('moderators')
          .doc(userId)
          .set({
            'userId': userId,
            'addedAt': FieldValue.serverTimestamp(),
          });
      _showSuccessSnackbar('Moderator added successfully');
      return true;
    } catch (e) {
      _showErrorSnackbar('Failed to add moderator: $e');
      return false;
    }
  }

  Future<bool> removeModerator(String channelId, String userId) async {
    try {
      await _firestore
          .collection(_channelsCol)
          .doc(channelId)
          .collection('moderators')
          .doc(userId)
          .delete();
      _showSuccessSnackbar('Moderator removed successfully');
      return true;
    } catch (e) {
      _showErrorSnackbar('Failed to remove moderator: $e');
      return false;
    }
  }

  Future<bool> blockUser(String channelId, String userId) async {
    try {
      await _firestore
          .collection(_channelsCol)
          .doc(channelId)
          .collection('blocked_users')
          .doc(userId)
          .set({
            'userId': userId,
            'blockedAt': FieldValue.serverTimestamp(),
          });
      _showSuccessSnackbar('User blocked successfully');
      return true;
    } catch (e) {
      _showErrorSnackbar('Failed to block user: $e');
      return false;
    }
  }

  Future<bool> unblockUser(String channelId, String userId) async {
    try {
      await _firestore
          .collection(_channelsCol)
          .doc(channelId)
          .collection('blocked_users')
          .doc(userId)
          .delete();
      _showSuccessSnackbar('User unblocked successfully');
      return true;
    } catch (e) {
      _showErrorSnackbar('Failed to unblock user: $e');
      return false;
    }
  }

  // ==========================================================================
  // NOTIFICATION PREFERENCES
  // ==========================================================================

  Future<void> saveNotificationPreferences(String channelId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final prefsRef = _firestore
          .collection('notification_preferences')
          .doc('${channelId}_${user.uid}');

      await prefsRef.set({
        'userId': user.uid,
        'channelId': channelId,
        'notificationAll': notificationAll.value,
        'notificationPersonalized': notificationPersonalized.value,
        'notificationNew': notificationNew.value,
        'notificationLive': notificationLive.value,
        'notificationPlaylist': notificationPlaylist.value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('âœ… Notification preferences saved');
    } catch (e) {
      debugPrint('âŒ Error saving notification preferences: $e');
    }
  }

  Future<void> loadNotificationPreferences(String channelId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final prefsRef = _firestore
          .collection('notification_preferences')
          .doc('${channelId}_${user.uid}');

      final doc = await prefsRef.get();

      if (doc.exists) {
        final data = doc.data();
        notificationAll.value = data?['notificationAll'] ?? true;
        notificationPersonalized.value =
            data?['notificationPersonalized'] ?? true;
        notificationNew.value = data?['notificationNew'] ?? true;
        notificationLive.value = data?['notificationLive'] ?? true;
        notificationPlaylist.value = data?['notificationPlaylist'] ?? false;
        debugPrint('âœ… Notification preferences loaded');
      }
    } catch (e) {
      debugPrint('âŒ Error loading notification preferences: $e');
    }
  }

  // ==========================================================================
  // DRAFT MANAGEMENT
  // ==========================================================================

  Future<void> _loadDraft() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final draftSnapshot = await _firestore
          .collection('channel_drafts')
          .where('ownerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (draftSnapshot.docs.isNotEmpty) {
        final draftData = draftSnapshot.docs.first.data();
        draftId.value = draftSnapshot.docs.first.id;

        // Restore form data
        channelName.text = draftData['channelName'] ?? '';
        description.text = draftData['description'] ?? '';
        customUrl.text = draftData['customUrl'] ?? '';
        tags.text = draftData['tags'] ?? '';
        contactEmail.text = draftData['contactEmail'] ?? '';
        websiteUrl.text = draftData['websiteUrl'] ?? '';
        isPublic.value = draftData['isPublic'] ?? true;
        language.value = draftData['language'] ?? 'en';
        selectedCategories.value = List<String>.from(
          draftData['categories'] ?? [],
        );

        if (draftData['socialLinks'] != null) {
          socialLinks.value = Map<String, String>.from(
            draftData['socialLinks'],
          );
        }

        if (draftData['advancedSettings'] != null) {
          advancedSettings.value = Map<String, dynamic>.from(
            draftData['advancedSettings'],
          );
        }

        bannerUrl.value = draftData['bannerUrl'] ?? '';
        avatarUrl.value = draftData['avatarUrl'] ?? '';

        hasDraft.value = true;
        lastDraftSaveTime.value = (draftData['updatedAt'] as Timestamp?)
            ?.toDate();
      }
    } catch (e) {
      debugPrint('Error loading draft: $e');
    }
  }

  Future<void> saveDraft({int? currentStep}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('âŒ Cannot save draft: No user logged in');
        return;
      }

      debugPrint('ðŸ’¾ Saving draft for user: ${user.uid}');
      isSavingDraft.value = true;

      final draftData = {
        'ownerId': user.uid,
        'channelName': channelName.text.trim(),
        'description': description.text.trim(),
        'customUrl': customUrl.text.trim(),
        'tags': tags.text.trim(),
        'contactEmail': contactEmail.text.trim(),
        'websiteUrl': websiteUrl.text.trim(),
        'isPublic': isPublic.value,
        'language': language.value,
        'categories': selectedCategories.toList(),
        'socialLinks': Map<String, dynamic>.from(socialLinks),
        'advancedSettings': Map<String, dynamic>.from(advancedSettings),
        'bannerUrl': bannerUrl.value,
        'avatarUrl': avatarUrl.value,
        'currentStep': currentStep ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': draftId.value == null
            ? FieldValue.serverTimestamp()
            : null,
      };

      if (draftId.value != null) {
        draftData.remove('createdAt');
      }

      if (draftId.value == null) {
        debugPrint('ðŸ“ Creating new draft document...');
        final docRef = await _firestore
            .collection('channel_drafts')
            .add(draftData);
        draftId.value = docRef.id;
        debugPrint('âœ… Draft created with ID: ${docRef.id}');
      } else {
        debugPrint('ðŸ“ Updating draft: ${draftId.value}');
        await _firestore
            .collection('channel_drafts')
            .doc(draftId.value)
            .update(draftData);
        debugPrint('âœ… Draft updated successfully');
      }

      hasDraft.value = true;
      lastDraftSaveTime.value = DateTime.now();
      isSavingDraft.value = false;

      // Silent draft save - no snackbar
    } catch (e) {
      isSavingDraft.value = false;
      debugPrint('âŒ Error saving draft: $e');
      // Silent error - draft save is automatic
    }
  }

  Future<void> deleteDraft() async {
    try {
      final user = _auth.currentUser;
      if (user == null || draftId.value == null) return;

      // Delete uploaded images
      if (bannerUrl.value.isNotEmpty) {
        try {
          await _storage.refFromURL(bannerUrl.value).delete();
        } catch (e) {
          debugPrint('Error deleting banner: $e');
        }
      }

      if (avatarUrl.value.isNotEmpty) {
        try {
          await _storage.refFromURL(avatarUrl.value).delete();
        } catch (e) {
          debugPrint('Error deleting avatar: $e');
        }
      }

      // Delete draft document
      await _firestore.collection('channel_drafts').doc(draftId.value).delete();

      hasDraft.value = false;
      draftId.value = null;
      lastDraftSaveTime.value = null;
    } catch (e) {
      debugPrint('Error deleting draft: $e');
      _showErrorSnackbar('Failed to delete draft: $e');
    }
  }

  // ==========================================================================
  // UTILITY METHODS
  // ==========================================================================

  void _resetForm() {
    channelName.clear();
    description.clear();
    customUrl.clear();
    tags.clear();
    contactEmail.clear();
    websiteUrl.clear();
    bannerImageData.value = null;
    avatarImageData.value = null;
    bannerUrl.value = '';
    avatarUrl.value = '';
    bannerFileId.value = '';
    avatarFileId.value = '';
    bannerStatus.value = 'PENDING';
    avatarStatus.value = 'PENDING';
    bannerStatusReason.value = '';
    avatarStatusReason.value = '';
    isPublic.value = true;
    language.value = 'en';
    selectedCategory.value = null;
    selectedCategories.clear();
    isAgreed.value = false;
    resetAvailabilityStatus();
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.brand,
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.star, color: AppColors.textPrimary),
    );
  }

  void _showSuccessSnackbar(String message) {
    Get.snackbar(
      'Success',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.star, color: AppColors.textPrimary),
    );
  }

  void fetchChannel(String channelId) {
    isLoading.value = true;
    _firestore
        .collection(_channelsCol)
        .doc(channelId)
        .get()
        .then((doc) {
          if (doc.exists) {
            selectedChannel.value = Channel.fromDocumentSnapshot(doc);
          }
          isLoading.value = false;
        })
        .catchError((e) {
          errorMessage.value = e.toString();
          isLoading.value = false;
        });
  }

  Future<void> shareChannel(String channelId) async {
    final channel = selectedChannel.value;
    if (channel == null) return;

    Get.find<MainController>().shareChannel(
      channelId,
      channel.channelName,
      avatarUrl: channel.avatarUrl,
    );
  }

  // Methods for Channel Details Page
  void initForChannelDetails(Channel channel) {
    if (selectedChannel.value?.channelId == channel.channelId) {
      // Already initialized for this channel, just ensure listeners are attached
      _attachScrollListener();
      return;
    }

    // Clear previous state first
    clearChannelDetailsState();

    selectedChannel.value = channel;

    // Set initial values from the channel document
    detailsAvatarStatus.value = channel.avatarStatus ?? '';
    detailsBannerStatus.value = channel.bannerStatus ?? '';
    detailsAvatarReason.value = '';
    detailsBannerReason.value = '';

    _detailsAvatarSub?.cancel();
    _detailsBannerSub?.cancel();

    final currentUser = _auth.currentUser;
    if (currentUser != null && channel.ownerId == currentUser.uid) {
      if (channel.avatarFileId != null &&
          channel.avatarFileId!.isNotEmpty &&
          channel.avatarStatus != 'APPROVED') {
        detailsAvatarStatus.value = channel.avatarStatus ?? 'PENDING';
        _detailsAvatarSub = _imageVerificationService
            .streamVerificationStatus(channel.avatarFileId!)
            .listen((result) {
              detailsAvatarStatus.value = result.status.name.toUpperCase();
              detailsAvatarReason.value = result.reason;
              if (result.status == VerificationStatus.approved ||
                  result.status == VerificationStatus.rejected ||
                  result.status == VerificationStatus.flagged) {
                _firestore
                    .collection(_channelsCol)
                    .doc(channel.id)
                    .update({
                      'avatarStatus': result.status.name.toUpperCase(),
                    })
                    .catchError((_) {});
              }
            });
      }

      if (channel.bannerFileId != null &&
          channel.bannerFileId!.isNotEmpty &&
          channel.bannerStatus != 'APPROVED') {
        detailsBannerStatus.value = channel.bannerStatus ?? 'PENDING';
        _detailsBannerSub = _imageVerificationService
            .streamVerificationStatus(channel.bannerFileId!)
            .listen((result) {
              detailsBannerStatus.value = result.status.name.toUpperCase();
              detailsBannerReason.value = result.reason;
              if (result.status == VerificationStatus.approved ||
                  result.status == VerificationStatus.rejected ||
                  result.status == VerificationStatus.flagged) {
                _firestore
                    .collection(_channelsCol)
                    .doc(channel.id)
                    .update({
                      'bannerStatus': result.status.name.toUpperCase(),
                    })
                    .catchError((_) {});
              }
            });
      }
    }

    listenSubscription(channel.channelId);
    fetchSubscriberCount(channel.channelId);
    fetchChannelVideoCount(channel.channelId);
    _attachScrollListener();
    loadInitialVideos();
    checkChannelContent(channel.channelId);
  }

  void _attachScrollListener() {
    // Only add if not already attached
    scrollController.removeListener(_onScrollListener);
    scrollController.addListener(_onScrollListener);
  }

  void _onScrollListener() {
    if (!scrollController.hasClients) return;
    onScroll(scrollController);
  }

  void onScroll(ScrollController scrollController) {
    if (!scrollController.hasClients) return;

    final offset = scrollController.offset;
    final isExpanded = offset > 200;

    if (isExpanded != isAppBarExpanded.value) {
      isAppBarExpanded.value = isExpanded;
    }

    if (scrollController.position.extentAfter < 200 && !isLoadingMore.value) {
      loadMoreVideos();
    }
  }

  Future<void> loadInitialVideos() async {
    if (selectedChannel.value == null) return;
    isLoadingVideos.value = true;
    try {
      var query = _firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: selectedChannel.value!.channelId);

      // Apply Filters
      if (videoSortFilter.value == 'Short video') {
        query = query.where('isShort', isEqualTo: true);
      } else if (videoSortFilter.value == 'Long video') {
        query = query.where('isShort', isEqualTo: false);
      }

      // Apply Sorting
      if (videoSortFilter.value == 'Popular') {
        query = query.orderBy('views', descending: true);
      } else if (videoSortFilter.value == 'Oldest') {
        query = query.orderBy('uploadedAt', descending: false);
      } else if (videoSortFilter.value == 'Latest') {
        query = query.orderBy('uploadedAt', descending: true);
      } else {
        // Default sorting for other filters (Short/Long)
        query = query.orderBy('uploadedAt', descending: true);
      }

      final snapshot = await query.limit(12).get();

      if (snapshot.docs.isNotEmpty) {
        videos.value = snapshot.docs.map(Video.fromDocumentSnapshot).toList();
        lastVideoDocument.value = snapshot.docs.last;
        hasVideos.value = true;
        if (channelVideoCount.value == 0) {
          channelVideoCount.value = snapshot.docs.length;
        }
      } else {
        videos.clear();
        lastVideoDocument.value = null;
      }
    } catch (error) {
      debugPrint('Error loading videos: $error');
      _showErrorSnackbar('Failed to load videos: $error');
    } finally {
      isLoadingVideos.value = false;
    }
  }

  void setVideoSortFilter(String filter) {
    if (videoSortFilter.value == filter) return;
    videoSortFilter.value = filter;
    loadInitialVideos();
  }

  Future<void> loadMoreVideos() async {
    if (lastVideoDocument.value == null ||
        isLoadingMore.value ||
        selectedChannel.value == null) {
      return;
    }
    isLoadingMore.value = true;
    try {
      var query = _firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: selectedChannel.value!.channelId);

      // Apply Filters Same as loadInitialVideos
      if (videoSortFilter.value == 'Short video') {
        query = query.where('isShort', isEqualTo: true);
      } else if (videoSortFilter.value == 'Long video') {
        query = query.where('isShort', isEqualTo: false);
      }

      // Apply Sorting Same as loadInitialVideos
      if (videoSortFilter.value == 'Popular') {
        query = query.orderBy('views', descending: true);
      } else if (videoSortFilter.value == 'Oldest') {
        query = query.orderBy('uploadedAt', descending: false);
      } else if (videoSortFilter.value == 'Latest') {
        query = query.orderBy('uploadedAt', descending: true);
      } else {
        query = query.orderBy('uploadedAt', descending: true);
      }

      final snapshot = await query
          .startAfterDocument(lastVideoDocument.value!)
          .limit(12)
          .get();
      if (snapshot.docs.isNotEmpty) {
        videos.addAll(
          snapshot.docs.map(Video.fromDocumentSnapshot).toList(),
        );
        lastVideoDocument.value = snapshot.docs.last;
      }
    } catch (error) {
      _showErrorSnackbar('Failed to load more videos: $error');
    } finally {
      isLoadingMore.value = false;
    }
  }

  void clearChannelDetailsState() {
    scrollController.removeListener(_onScrollListener);
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    isAppBarExpanded.value = false;
    videos.clear();
    lastVideoDocument.value = null;
    isLoadingMore.value = false;
    isLoadingVideos.value = false;
    selectedChannel.value = null;
    videoSortFilter.value = 'Latest';
    _subscriptionListener?.cancel();
    _detailsAvatarSub?.cancel();
    _detailsBannerSub?.cancel();
    detailsAvatarStatus.value = '';
    detailsBannerStatus.value = '';
    detailsAvatarReason.value = '';
    detailsBannerReason.value = '';
    hasVideos.value = false;
    hasPlaylists.value = false;
    hasPosts.value = false;
    hasTopics.value = false;
    channelVideoCount.value = 0;
    selectedChannelTopic.value = null;
    topicVideosMap.clear();
    isLoadingVideosMap.clear();
    topicPostsMap.clear();
    isLoadingPostsMap.clear();
  }

  Future<void> fetchChannelVideoCount(String channelId) async {
    try {
      final countSnap = await _firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: channelId)
          .count()
          .get();
      channelVideoCount.value = countSnap.count ?? 0;
    } catch (e) {
      debugPrint('Error fetching channel video count: $e');
    }
  }

  Future<void> checkChannelContent(String channelId) async {
    try {
      final currentUser = _auth.currentUser;
      final isOwner =
          currentUser != null &&
          selectedChannel.value?.ownerId == currentUser.uid;

      var postQuery = _firestore
          .collection(FirestoreCollections.community)
          .where('channelId', isEqualTo: channelId);

      if (isOwner) {
        postQuery = postQuery.where('ownerId', isEqualTo: currentUser.uid);
      } else {
        postQuery = postQuery.where('visibility', isEqualTo: 'Public');
      }

      final results = await Future.wait([
        _firestore
            .collection(FirestoreCollections.videos)
            .where('channelId', isEqualTo: channelId)
            .limit(1)
            .get(),
        _firestore
            .collection('public_playlists')
            .where('channelId', isEqualTo: channelId)
            .limit(1)
            .get(),
        postQuery.limit(1).get(),
        _firestore
            .collection(FirestoreCollections.topics)
            .where('channelId', isEqualTo: channelId)
            .limit(1)
            .get(),
      ]);

      hasVideos.value = results[0].docs.isNotEmpty;
      hasPlaylists.value = results[1].docs.isNotEmpty;
      hasPosts.value = results[2].docs.isNotEmpty;
      hasTopics.value = results[3].docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking channel content: $e');
    }
  }

  /// Updates channel monetization tier / channel type (Standard vs Custom)
  Future<bool> updateChannelType(
    String channelId,
    ChannelType newType, {
    CustomChannelInfraConfig? config,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'channelType': newType.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newType == ChannelType.custom) {
        final infra =
            config ??
            CustomChannelInfraConfig(
              stripeConnectAccountId: 'acct_demo_${channelId.substring(0, 6)}',
              subscriptionId: 'sub_demo_${channelId.substring(0, 6)}',
              flatPlatformFee: 25.0,
            );
        updateData['infraConfig'] = infra.toMap();
      }

      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .update(updateData);

      if (selectedChannel.value?.id == channelId) {
        final updatedDoc = await _firestore
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .get();
        if (updatedDoc.exists) {
          selectedChannel.value = Channel.fromDocumentSnapshot(updatedDoc);
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error updating channel type: $e');
      return false;
    }
  }

  /// Schedules a channel type change to take effect on the 1st of next month (Next Billing Cycle)
  Future<bool> scheduleChannelTypeChange(
    String channelId,
    ChannelType targetType,
  ) async {
    try {
      final now = DateTime.now();
      // Calculate 1st of next month (e.g. July 10 -> August 1)
      final effectiveDate = DateTime(now.year, now.month + 1);
      final effectiveTimestamp = Timestamp.fromDate(effectiveDate);

      final updateData = <String, dynamic>{
        'pendingChannelType': targetType.name,
        'pendingTypeEffectiveDate': effectiveTimestamp,
        'nextBillingCycleDate': effectiveTimestamp,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .update(updateData);

      if (selectedChannel.value?.id == channelId) {
        final updatedDoc = await _firestore
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .get();
        if (updatedDoc.exists) {
          selectedChannel.value = Channel.fromDocumentSnapshot(updatedDoc);
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error scheduling channel type change: $e');
      return false;
    }
  }

  /// Cancels a pending scheduled channel type change
  Future<bool> cancelScheduledChannelTypeChange(String channelId) async {
    try {
      final updateData = <String, dynamic>{
        'pendingChannelType': FieldValue.delete(),
        'pendingTypeEffectiveDate': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .update(updateData);

      if (selectedChannel.value?.id == channelId) {
        final updatedDoc = await _firestore
            .collection(FirestoreCollections.channels)
            .doc(channelId)
            .get();
        if (updatedDoc.exists) {
          selectedChannel.value = Channel.fromDocumentSnapshot(updatedDoc);
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error canceling scheduled channel type change: $e');
      return false;
    }
  }
}
