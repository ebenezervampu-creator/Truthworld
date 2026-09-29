import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/data/models/channel_availability_status.dart';
import 'package:truthworld/features/channel/data/models/channel_image_data.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/repositories/topic_repository.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:uuid/uuid.dart';

abstract class ChannelControllerBase extends BaseController
    with GetTickerProviderStateMixin, ContentValidationMixin {
  static const String channelsCol = 'channels';
  static const int minChannelNameLength = 3;
  static const int maxChannelNameLength = 30;
  static const int minCustomUrlLength = 3;
  static const int maxCustomUrlLength = 30;
  static const int debounceDurationMs = 500;
  static const int maxChannelsPerUser = 10;
  static const int maxDescriptionLength = 1000;
  static const int maxTags = 5;
  static const int maxBannerSize = 5 * 1024 * 1024; // 5MB
  static const int maxAvatarSize = 2 * 1024 * 1024; // 2MB
  static const double recommendedBannerRatio = 16 / 9;
  static const double recommendedAvatarRatio = 1;

  // Services
  FirebaseFirestore get firestore;
  FirebaseAuth get auth;
  FirebaseStorage get storage;
  Uuid get uuid;
  ImageVerificationService get imageVerificationService;
  TopicRepository get topicRepository;
  ChannelSubscriptionController get subController;
  set subController(ChannelSubscriptionController s);

  // Subscription state
  RxBool get isSubscribed;
  RxBool get notificationsEnabled;
  RxString get notificationOption;
  RxBool get isChannelMember;
  Rxn<ChannelMember> get currentMembership;

  // Form Key & Controllers
  GlobalKey<FormState> get formKey;
  TextEditingController get channelName;
  TextEditingController get description;
  TextEditingController get customUrl;
  TextEditingController get tags;
  TextEditingController get contactEmail;
  TextEditingController get websiteUrl;

  // Form Animations
  late AnimationController formFadeAnimationController;
  late AnimationController formSlideAnimationController;
  late AnimationController formScaleAnimationController;
  late AnimationController heroAnimationController;
  late AnimationController staggeredAnimationController;
  late AnimationController buttonAnimationController;
  late AnimationController successAnimationController;

  // Form Animation Values
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

  // Plans & Channels
  RxString get selectedPlan;
  RxString get customPricingTier;
  RxBool get customPlanAutoPay;
  RxBool get planSelectionError;
  RxString get country;
  RxString get channelTypeCategory;
  RxList<Channel> get channels;
  Rx<Channel?> get selectedChannel;
  RxBool get rxIsLoading;
  RxString get rxErrorMessage;
  RxDouble get uploadProgress;
  RxString get channelNameMessage;
  Rx<ChannelType> get selectedChannelType;

  // Media
  Rx<ImageData?> get bannerImageData;
  Rx<ImageData?> get avatarImageData;
  RxString get bannerUrl;
  RxString get avatarUrl;
  RxDouble get bannerUploadProgress;
  RxDouble get avatarUploadProgress;
  RxBool get isUploadingBanner;
  RxBool get isUploadingAvatar;
  RxString get bannerStatus;
  RxString get avatarStatus;
  RxString get bannerStatusReason;
  RxString get avatarStatusReason;
  RxString get bannerFileId;
  RxString get avatarFileId;
  List<String> get uploadedDocIds;
  Map<String, StreamSubscription> get moderationListeners;
  Map<String, Timer> get moderationTimers;

  // Details Media Status
  RxString get detailsAvatarStatus;
  RxString get detailsBannerStatus;
  RxString get detailsAvatarReason;
  RxString get detailsBannerReason;
  StreamSubscription? get detailsAvatarSub;
  set detailsAvatarSub(StreamSubscription? sub);
  StreamSubscription? get detailsBannerSub;
  set detailsBannerSub(StreamSubscription? sub);

  // Drafts & Submission
  RxBool get hasDraft;
  Rx<String?> get draftId;
  RxBool get isSavingDraft;
  Rx<DateTime?> get lastDraftSaveTime;
  RxBool get isSubmitting;

  // Settings & Preferences
  RxBool get isPublic;
  RxString get visibility;
  void setVisibility(String val);
  RxString get language;
  Rx<String?> get selectedCategory;
  RxList<String> get selectedCategories;
  RxBool get isAgreed;
  RxBool get agreeTerms;
  RxBool get agreeGuidelines;
  RxInt get formChangeTrigger;
  RxMap<String, String> get socialLinks;
  RxMap<String, dynamic> get advancedSettings;
  RxBool get notificationAll;
  RxBool get notificationPersonalized;
  RxBool get notificationNew;
  RxBool get notificationLive;
  RxBool get notificationPlaylist;

  // Availability
  RxList<String> get handleSuggestions;
  Rx<AvailabilityStatus> get channelNameAvailability;
  Rx<AvailabilityStatus> get customUrlAvailability;
  String get lastAutoSlug;
  set lastAutoSlug(String val);

  // Details state
  Rx<Channel?> get activeChannel;
  RxList<Video> get videos;
  Rx<DocumentSnapshot?> get lastVideoDocument;
  RxBool get isLoadingMore;
  RxString get videoSortFilter;
  RxBool get hasVideos;
  RxBool get hasPlaylists;
  RxBool get hasPosts;
  RxBool get hasTopics;
  RxInt get channelVideoCount;
  RxInt get subscriberCount;
  RxBool get isAppBarExpanded;
  RxBool get isDescriptionExpanded;
  RxBool get isLoadingVideos;

  // Topics state
  Rxn<Topic> get selectedChannelTopic;
  RxMap<String, List<Video>> get topicVideosMap;
  RxMap<String, bool> get isLoadingVideosMap;
  RxMap<String, List<CommunityPostModel>> get topicPostsMap;
  RxMap<String, bool> get isLoadingPostsMap;

  // UI Controllers for details page
  late ScrollController scrollController;
  late TabController tabController;

  // Cross-mixin listeners and callbacks with safe defaults
  void startAvatarModerationListener(String docId) {}
  void startBannerModerationListener(String docId) {}
  void listenSubscription(String channelId) {}
  void listenMembership(String channelId) {}
  void fetchSubscriberCount(String channelId) {}

  // Lifecycle listeners
  void setupTextFieldListeners();
  void setupFormValidationListeners();

  // Snackbars & Form Management
  void showErrorSnackbar(String message) {
    AppSnackbar.error(message);
  }

  void showSuccessSnackbar(String message) {
    AppSnackbar.success(message);
  }

  void resetForm();
  Future<void> loadDraft();

  List<String> get activeTabs {
    return const ['Home', 'Videos', 'Topics', 'Playlists', 'Posts'];
  }


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
    // Fact-checking / High-credibility categories first
    'Business',
    'History',
    'News',
    'Education',
    'Science',
    'Technology',
    'Finance',
    'Health',
    'Documentary',
    'Fitness',
    // General / Entertainment / Lifestyle categories
    'Music',
    'Entertainment',
    'Sports',
    'Lifestyle',
    'Travel',
    'Food',
    'Fashion',
    'Comedy',
    'Art',
    'Animation',
    'Automotive',
    'Pets & Animals',
    'DIY & How-to',
    'Nature',
    'Spirituality',
    'People & Blogs',
    'Kids & Family',
    'Movies',
    'TV Shows',
    'Vlogs',
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

  bool isCustomBusinessEmail(String email) {
    final trimmed = email.trim().toLowerCase();
    if (!trimmed.contains('@')) return false;
    final parts = trimmed.split('@');
    if (parts.length != 2) return false;
    final domain = parts[1].trim();
    if (domain.isEmpty || !domain.contains('.')) return false;
    const blockedDomains = [
      'gmail.com',
      'yahoo.com',
      'hotmail.com',
      'outlook.com',
      'icloud.com',
      'aol.com',
      'mail.com',
      'zoho.com',
      'protonmail.com',
      'proton.me',
      'yandex.com',
      'gmx.com',
    ];
    return !blockedDomains.contains(domain);
  }

}
