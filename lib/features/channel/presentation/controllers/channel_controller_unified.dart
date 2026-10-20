import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/data/models/channel_availability_status.dart';
import 'package:truthworld/features/channel/data/models/channel_image_data.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_mixins/channel_mixins.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:uuid/uuid.dart';

// Re-exports for 100% backward compatibility
export 'package:truthworld/features/channel/data/models/channel_availability_status.dart';
export 'package:truthworld/features/channel/data/models/channel_image_data.dart';
export 'package:truthworld/features/channel/data/models/channel_transaction_result.dart';
export 'package:truthworld/features/channel/presentation/controllers/channel_mixins/channel_mixins.dart';
export 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';

class ChannelController extends ChannelControllerBase
    with
        ChannelAvailabilityMixin,
        ChannelMediaMixin,
        ChannelCreationMixin,
        ChannelDraftMixin,
        ChannelManagementMixin,
        ChannelDetailsMixin,
        ChannelTopicsMixin {
  static final RxMap<String, int> globalSubscriberCounts = <String, int>{}.obs;

  bool _isDisposed = false;
  @override
  bool get isClosed => _isDisposed;

  // Dependencies
  @override
  final FirebaseStorage storage = FirebaseStorage.instance;
  @override
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  @override
  final FirebaseAuth auth = FirebaseAuth.instance;
  @override
  final Uuid uuid = const Uuid();
  @override
  final ImageVerificationService imageVerificationService = ImageVerificationService();

  late ChannelSubscriptionController _subController;
  @override
  ChannelSubscriptionController get subController => _subController;
  @override
  set subController(ChannelSubscriptionController s) => _subController = s;

  // Controllers
  @override
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  @override
  final TextEditingController channelName = TextEditingController();
  @override
  final TextEditingController description = TextEditingController();
  @override
  final TextEditingController customUrl = TextEditingController();
  @override
  final TextEditingController tags = TextEditingController();
  @override
  final TextEditingController contactEmail = TextEditingController();
  @override
  final TextEditingController websiteUrl = TextEditingController();

  // Plans & Channels
  @override
  final RxString selectedPlan = 'free'.obs;
  @override
  final RxString customPricingTier = 'basic'.obs;
  @override
  final RxBool customPlanAutoPay = true.obs;
  @override
  final RxBool planSelectionError = false.obs;
  @override
  final RxString country = 'US'.obs;
  @override
  final RxString channelTypeCategory = ''.obs;
  @override
  final RxList<Channel> channels = <Channel>[].obs;
  @override
  final Rx<Channel?> selectedChannel = Rx<Channel?>(null);
  @override
  final RxBool rxIsLoading = false.obs;
  @override
  final RxString rxErrorMessage = ''.obs;
  @override
  final RxDouble uploadProgress = 0.0.obs;
  @override
  final RxString channelNameMessage = ''.obs;
  @override
  final Rx<ChannelType> selectedChannelType = ChannelType.standard.obs;

  // Media
  @override
  final Rx<ImageData?> bannerImageData = Rx<ImageData?>(null);
  @override
  final Rx<ImageData?> avatarImageData = Rx<ImageData?>(null);
  @override
  final RxString bannerUrl = ''.obs;
  @override
  final RxString avatarUrl = ''.obs;
  @override
  final RxDouble bannerUploadProgress = 0.0.obs;
  @override
  final RxDouble avatarUploadProgress = 0.0.obs;
  @override
  final RxBool isUploadingBanner = false.obs;
  @override
  final RxBool isUploadingAvatar = false.obs;
  @override
  final RxString bannerStatus = ''.obs;
  @override
  final RxString avatarStatus = ''.obs;
  @override
  final RxString bannerStatusReason = ''.obs;
  @override
  final RxString avatarStatusReason = ''.obs;
  @override
  final RxString avatarFileId = ''.obs;
  @override
  final RxString bannerFileId = ''.obs;
  @override
  final List<String> uploadedDocIds = [];
  @override
  final Map<String, StreamSubscription> moderationListeners = {};
  @override
  final Map<String, Timer> moderationTimers = {};

  // Details screen verification
  @override
  final RxString detailsAvatarStatus = ''.obs;
  @override
  final RxString detailsBannerStatus = ''.obs;
  @override
  final RxString detailsAvatarReason = ''.obs;
  @override
  final RxString detailsBannerReason = ''.obs;
  @override
  StreamSubscription? detailsAvatarSub;
  @override
  StreamSubscription? detailsBannerSub;

  // Drafts
  @override
  final RxBool hasDraft = false.obs;
  @override
  final Rx<String?> draftId = Rx<String?>(null);
  @override
  final RxBool isSavingDraft = false.obs;
  @override
  final Rx<DateTime?> lastDraftSaveTime = Rx<DateTime?>(null);
  @override
  final RxBool isSubmitting = false.obs;

  // Settings
  @override
  final RxBool isPublic = true.obs;
  @override
  final RxString visibility = 'Public'.obs;
  @override
  void setVisibility(String val) {
    visibility.value = val;
    isPublic.value = (val == 'Public');
  }
  @override
  final RxString language = 'en'.obs;
  @override
  final Rx<String?> selectedCategory = Rx<String?>(null);
  @override
  final RxList<String> selectedCategories = <String>[].obs;
  @override
  final RxBool isAgreed = false.obs;
  @override
  final RxBool agreeTerms = false.obs;
  @override
  final RxBool agreeGuidelines = false.obs;
  @override
  final RxInt formChangeTrigger = 0.obs;
  @override
  final RxMap<String, String> socialLinks = {
    'twitter': '',
    'instagram': '',
    'facebook': '',
    'linkedin': '',
    'youtube': '',
    'website': '',
  }.obs;
  @override
  final RxList<Map<String, String>> customLinks = <Map<String, String>>[].obs;
  @override
  final RxMap<String, dynamic> advancedSettings = <String, dynamic>{
    'allowComments': true,
    'moderationLevel': 'standard',
    'showSubscriberCount': true,
    'showLikeCount': true,
    'showDislikeCount': true,
    'enableWatermark': false,
  }.obs;
  @override
  final RxBool notificationAll = true.obs;
  @override
  final RxBool notificationPersonalized = true.obs;
  @override
  final RxBool notificationNew = true.obs;
  @override
  final RxBool notificationLive = true.obs;
  @override
  final RxBool notificationPlaylist = false.obs;

  // Availability
  @override
  final RxList<String> handleSuggestions = <String>[].obs;
  @override
  final Rx<AvailabilityStatus> channelNameAvailability = Rx<AvailabilityStatus>(AvailabilityStatus.unknown);
  @override
  final Rx<AvailabilityStatus> customUrlAvailability = Rx<AvailabilityStatus>(AvailabilityStatus.unknown);
  @override
  final RxString channelNameAvailabilityMessage = ''.obs;
  @override
  final RxString customUrlAvailabilityMessage = ''.obs;
  @override
  String lastAutoSlug = '';

  // Details State
  @override
  final Rx<Channel?> activeChannel = Rx<Channel?>(null);
  @override
  final RxList<Video> videos = <Video>[].obs;
  @override
  final Rx<DocumentSnapshot?> lastVideoDocument = Rx<DocumentSnapshot?>(null);
  @override
  final RxBool isLoadingMore = false.obs;
  @override
  final RxString videoSortFilter = 'Latest'.obs;
  @override
  final RxBool hasVideos = false.obs;
  @override
  final RxBool hasPlaylists = false.obs;
  @override
  final RxBool hasPosts = false.obs;
  @override
  final RxBool hasTopics = false.obs;
  @override
  final RxInt channelVideoCount = 0.obs;
  @override
  RxInt get subscriberCount => _subController.subscriberCount;
  @override
  final RxBool isAppBarExpanded = false.obs;
  @override
  final RxBool isDescriptionExpanded = false.obs;
  @override
  final RxBool isLoadingVideos = false.obs;

  @override
  void onInit() {
    super.onInit();
    subController = Get.isRegistered<ChannelSubscriptionController>()
        ? Get.find<ChannelSubscriptionController>()
        : Get.put(ChannelSubscriptionController());

    // Init UI controllers immediately so they are never null
    scrollController = ScrollController();
    trackScrollController(scrollController);
    tabController = TabController(length: tabs.length, vsync: this);

    // Track text controllers
    trackTextController(channelName);
    trackTextController(description);
    trackTextController(customUrl);
    trackTextController(tags);
    trackTextController(contactEmail);
    trackTextController(websiteUrl);

    initializeContentFilters();
    _initializeAnimations();
    setupTextFieldListeners();
    setupFormValidationListeners();

    final user = auth.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isClosed) return;
        // Auto-populate channel name from user's display name if empty
        if (channelName.text.isEmpty) {
          final name = user.displayName ?? '';
          if (name.isNotEmpty) {
            channelName.text = name;
            checkChannelNameAvailability(name);
          }
        }

        loadDraft();
        startAnimations();

        // Keep channels RxList in sync with Firestore
        rxIsLoading.value = true;
        final sub = firestore
            .collection(ChannelControllerBase.channelsCol)
            .where('ownerId', isEqualTo: user.uid)
            .snapshots()
            .listen(
              (snapshot) {
                final results = snapshot.docs
                    .map(Channel.fromDocumentSnapshot)
                    .where((channel) => !channel.isArchived)
                    .toList();
                channels.assignAll(results);
                rxIsLoading.value = false;
              },
              onError: (error) {
                debugPrint('Error fetching channels: $error');
                rxIsLoading.value = false;
              },
            );
        trackSubscription(sub);
      });
    }
  }

  // In ChannelController


  Future<void> fetchUserChannels() async {
    final user = auth.currentUser;
    if (user == null) return;

    try {
      rxIsLoading.value = true;
      final snapshot = await firestore
          .collection(ChannelControllerBase.channelsCol)
          .where('ownerId', isEqualTo: user.uid)
          .getCacheFirst();

      final results = snapshot.docs
          .map(Channel.fromDocumentSnapshot)
          .where((channel) => !channel.isArchived)
          .toList();

      channels.assignAll(results);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelControllerUnified.fetchChannels',
      );
    } finally {
      rxIsLoading.value = false;
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
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelControllerUnified.startFormAnimations',
      );
    }
  }

  void startPageAnimations() {
    if (isClosed) return;
    try {
      pageFadeAnimationController.forward();
      pageSlideAnimationController.forward();
      pageScaleAnimationController.forward();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelControllerUnified.startPageAnimations',
      );
    }
  }

  @override
  void onClose() {
    _isDisposed = true;

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
    tabController.dispose();

    // Cancel moderation listeners & timers
    for (final timer in moderationTimers.values) {
      timer.cancel();
    }
    moderationTimers.clear();
    for (final sub in moderationListeners.values) {
      sub.cancel();
    }
    moderationListeners.clear();
    detailsAvatarSub?.cancel();
    detailsBannerSub?.cancel();

    disposeAvailabilityTimers();

    // Call clear state to ensure all listeners/subscriptions are removed
    clearChannelDetailsState();

    super.onClose();
  }


  @override
  void resetForm() {
    selectedChannelType.value = ChannelType.standard;
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
    bannerStatus.value = '';
    avatarStatus.value = '';
    bannerStatusReason.value = '';
    avatarStatusReason.value = '';
    isPublic.value = true;
    language.value = 'en';
    selectedPlan.value = 'standard';
    selectedCategory.value = null;
    selectedCategories.clear();
    isAgreed.value = false;
    for (final timer in moderationTimers.values) {
      timer.cancel();
    }
    moderationTimers.clear();
    for (final sub in moderationListeners.values) {
      sub.cancel();
    }
    moderationListeners.clear();
    resetAvailabilityStatus();
  }



  @override
  void showErrorSnackbar(String message) {
    AppSnackbar.error(message);
  }

  @override
  void showSuccessSnackbar(String message) {
    AppSnackbar.success(message);
  }
}
