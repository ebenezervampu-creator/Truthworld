import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:uuid/uuid.dart';

// ==========================================================================
// MODELS AND ENUMS
// ==========================================================================

// ContentValidationResult is now provided by content_validation_mixin.dart

class TransactionResult {
  final bool success;
  final String? errorMessage;
  final bool alreadySubscribed;

  TransactionResult({
    this.success = false,
    this.errorMessage,
    this.alreadySubscribed = false,
  });
}

enum AvailabilityStatus { unknown, checking, available, taken, invalid, error }

extension AvailabilityStatusExtension on AvailabilityStatus {
  Color get color {
    switch (this) {
      case AvailabilityStatus.unknown:
        return AppColors.textSecondary;
      case AvailabilityStatus.checking:
        return Color(0xFFF59E0B);
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
  final Uint8List bytes;
  final String name;
  final int size;
  final double aspectRatio;

  ImageData({
    required this.bytes,
    required this.name,
    required this.size,
    required this.aspectRatio,
  });
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
  final Uuid _uuid = Uuid();
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
  static const double recommendedAvatarRatio = 1.0;

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
  var isSubscriptionLoading = true.obs;
  final RxBool notificationsEnabled = true.obs;
  final RxMap<String, RxBool> _subscribedMap = <String, RxBool>{}.obs;
  var subscriberCount = 0.obs;
  var isLoading = false.obs;
  // Track channels subscribed to during this app session for "new subscriber" analytics
  final Set<String> _sessionSubscribedChannels = {};
  var errorMessage = ''.obs;
  var uploadProgress = 0.0.obs;
  final RxString channelNameMessage = ''.obs;

  // State for Channel Details Page
  final isAppBarExpanded = false.obs;
  final isLoadingVideos = false.obs;
  final videos = <Video>[].obs;
  final lastVideoDocument = Rx<DocumentSnapshot?>(null);
  final isLoadingMore = false.obs;
  final videoSortFilter = 'Latest'.obs;

  // Reactive flags for channel content tabs availability
  final hasVideos = false.obs;
  final hasPlaylists = false.obs;
  final hasPosts = false.obs;

  List<String> get activeTabs {
    final list = <String>['Home'];
    if (hasVideos.value) list.add('Videos');
    if (hasPlaylists.value) list.add('Playlists');
    if (hasPosts.value) list.add('Posts');
    return list;
  }

  // Reactive State - Image Upload
  final bannerImageData = Rx<ImageData?>(null);
  final avatarImageData = Rx<ImageData?>(null);
  final bannerUrl = ''.obs;
  final avatarUrl = ''.obs;
  final bannerUploadProgress = 0.0.obs;
  final avatarUploadProgress = 0.0.obs;
  final isUploadingBanner = false.obs;
  final isUploadingAvatar = false.obs;

  // Moderation statuses
  final bannerStatus = "PENDING".obs;
  final avatarStatus = "PENDING".obs;
  final bannerStatusReason = "".obs;
  final avatarStatusReason = "".obs;

  // Verification File IDs
  final avatarFileId = ''.obs;
  final bannerFileId = ''.obs;

  // Details screen real-time verification statuses
  final detailsAvatarStatus = "".obs;
  final detailsBannerStatus = "".obs;
  final detailsAvatarReason = "".obs;
  final detailsBannerReason = "".obs;

  StreamSubscription? _detailsAvatarSub;
  StreamSubscription? _detailsBannerSub;

  // Draft management
  final hasDraft = false.obs;
  final draftId = Rx<String?>(null);
  final isSavingDraft = false.obs;
  final lastDraftSaveTime = Rx<DateTime?>(null);
  final isSubmitting = false.obs;

  // Other reactive state
  final isPublic = true.obs;
  final language = 'en'.obs;
  final selectedCategory = Rx<String?>(null);
  final selectedCategories = <String>[].obs;
  final isAgreed = false.obs;
  final formChangeTrigger = 0.obs;
  final socialLinks = {
    'twitter': '',
    'instagram': '',
    'youtube': '',
    'website': '',
  }.obs;
  final advancedSettings = <String, dynamic>{
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
  final handleSuggestions = <String>[].obs;
  var channelNameAvailability = Rx<AvailabilityStatus>(
    AvailabilityStatus.unknown,
  );
  var customUrlAvailability = Rx<AvailabilityStatus>(
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
      fetchUserChannels();
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
                  .map((doc) => Channel.fromDocumentSnapshot(doc))
                  .where((channel) => channel.isArchived != true)
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
          .map((doc) => Channel.fromDocumentSnapshot(doc))
          .where((channel) => channel.isArchived != true)
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
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    formSlideAnimationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    formScaleAnimationController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    heroAnimationController = AnimationController(
      duration: Duration(milliseconds: 1000),
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

    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: formFadeAnimationController,
        curve: Curves.easeIn,
      ),
    );
    slideAnimation = Tween<Offset>(begin: Offset(0, 0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: formSlideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
    scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: formScaleAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    heroAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: heroAnimationController, curve: Curves.easeInOut),
    );
    buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: buttonAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    successScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
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

    pageFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: pageFadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    pageSlideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: pageSlideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
    pageScaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
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
    subscriptionScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
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
      final slug = channelName.text.toLowerCase().trim()
          .replaceAll(RegExp(r'[^a-z0-9_-]'), '-')
          .replaceAll(RegExp(r'-+'), '-')
          .replaceAll(RegExp(r'_+'), '_');
      String cleanSlug = slug;
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
    for (var sub in _moderationListeners.values) {
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
      Duration(milliseconds: debounceDurationMs),
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
      Duration(milliseconds: debounceDurationMs),
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
        return _showErrorSnackbar("Unable to read image file.");
      }

      final maxSize = isBanner ? maxBannerSize : maxAvatarSize;
      if (file.size > maxSize) {
        return _showErrorSnackbar(
          "Image exceeds ${(maxSize / (1024 * 1024)).toStringAsFixed(1)}MB.",
        );
      }

      final extension = file.extension?.toLowerCase();
      if (extension == null ||
          !['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(extension)) {
        return _showErrorSnackbar(
          "Unsupported format. Use JPG, PNG, WebP, GIF.",
        );
      }

      dynamic image;
      try {
        image = await decodeImageFromList(file.bytes!);
      } catch (e) {
        return _showErrorSnackbar("Invalid image: $e");
      }
      if (image == null) return _showErrorSnackbar("Unable to decode image.");

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
      String? oldUrl = isBanner ? bannerUrl.value : avatarUrl.value;
      if (oldUrl.isNotEmpty) {
        try {
          await _storage.refFromURL(oldUrl).delete();
        } catch (_) {}
      }

      final user = _auth.currentUser;
      if (user == null) return _showErrorSnackbar("Login required.");

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
          bannerStatus.value = "ERROR";
        } else {
          isUploadingAvatar.value = false;
          avatarStatus.value = "ERROR";
        }
        return _showErrorSnackbar("Upload failed. Please try again.");
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
      _showErrorSnackbar("Failed to process local image.");
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
      bannerStatus.value = "PENDING";
    } else {
      avatarStatus.value = "PENDING";
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
                "Banner Rejected",
                result.reason,
                backgroundColor: AppColors.brand,
                colorText: Colors.white,
              );
            } else if (result.status == VerificationStatus.approved) {
              Get.snackbar(
                "Banner Approved",
                "Your banner has passed verification.",
                backgroundColor: AppColors.success,
                colorText: Colors.white,
              );
            }
          } else {
            avatarStatus.value = statusStr;
            avatarStatusReason.value = result.reason;

            if (result.status == VerificationStatus.rejected) {
              Get.snackbar(
                "Avatar Rejected",
                result.reason,
                backgroundColor: AppColors.brand,
                colorText: Colors.white,
              );
            } else if (result.status == VerificationStatus.approved) {
              Get.snackbar(
                "Avatar Approved",
                "Your avatar has passed verification.",
                backgroundColor: AppColors.success,
                colorText: Colors.white,
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
          "You can only create one channel per Google account.",
        );
        return;
      }

      // 1. Validation
      if (!formKey.currentState!.validate()) {
        _showErrorSnackbar("Please fill in all required fields correctly.");
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
        if (avatarStatus.value == "REJECTED" ||
            avatarStatus.value == "FLAGGED") {
          _showErrorSnackbar(
            "Your avatar was rejected or flagged: ${avatarStatusReason.value}",
          );
          return;
        }
      }

      if (bannerUrl.value.isNotEmpty) {
        if (bannerStatus.value == "REJECTED" ||
            bannerStatus.value == "FLAGGED") {
          _showErrorSnackbar(
            "Your banner was rejected or flagged: ${bannerStatusReason.value}",
          );
          return;
        }
      }

      if (avatarStatus.value == "ERROR" || bannerStatus.value == "ERROR") {
        _showErrorSnackbar(
          "Moderation service error. Please try uploading your branding images again.",
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

      const String defaultBanner =
          "https://images.unsplash.com/photo-1579546929518-9e396f3cc809?q=80&w=2670&auto=format&fit=crop";
      const String defaultAvatar =
          "https://ui-avatars.com/api/?background=6B46C1&color=fff&size=512&name=";

      final channelData = {
        // Core fields matching Channel model (V2)
        "name": channelNameText,
        "nameLowercase": channelNameText.toLowerCase(),
        "channelName": channelNameText,
        "channelNameLowercase": channelNameText.toLowerCase(),
        "description": description.text.trim(),
        "bannerUrl": bannerUrl.value.isEmpty ? defaultBanner : bannerUrl.value,
        "avatarUrl": avatarUrl.value.isEmpty
            ? "$defaultAvatar$channelNameText"
            : avatarUrl.value,
        "avatarFileId": avatarFileId.value.isEmpty ? null : avatarFileId.value,
        "bannerFileId": bannerFileId.value.isEmpty ? null : bannerFileId.value,
        "avatarStatus": avatarStatus.value,
        "bannerStatus": bannerStatus.value,
        "ownerId": uid,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),

        // Public settings
        "isPublic": isPublic.value,
        "isVerified": false,
        "subscriberCount": 0,
        "language": language.value,
        "tags": tagsList,

        // Custom URL mapped to handle
        "handle": customUrlText,
        "handleLowercase": customUrlText.toLowerCase(),
        "customUrl": customUrlText,
        "customUrlLowercase": customUrlText.toLowerCase(),

        // Moderation lists
        "moderatorIds": [],
        "blockedUserIds": [],

        // Optional fields
        "category": selectedCategories.isEmpty
            ? (selectedCategory.value ?? 'other')
            : selectedCategories.join(', '),
        "contactEmail": contactEmail.text.trim().isEmpty
            ? null
            : contactEmail.text.trim(),
        "websiteUrl": websiteUrl.text.trim().isEmpty
            ? null
            : websiteUrl.text.trim(),
        "socialLinks": Map<String, dynamic>.from(socialLinks),

        // Advanced settings from form
        "allowComments": advancedSettings['allowComments'] ?? true,
        "allowSubscriptions": advancedSettings['allowSubscriptions'] ?? true,
        "showSubscriberCount": advancedSettings['showSubscriberCount'] ?? true,

        // Branding
        "brandingSettings": {
          "primaryColor": "#6B46C1",
          "secondaryColor": "#9333EA",
          "bannerStyle": "gradient",
        },

        // Status & Metrics
        "status": "underReview",
        "videoCount": 0,
        "isLive": false,
        "metrics": {
          "totalViews": 0,
          "totalWatchTimeMinutes": 0,
          "averageRetention": 0.0,
        },
      };

      // Firestore transaction
      final String? newChannelId = await _firestore.runTransaction<String?>((
        transaction,
      ) async {
        final channelRef = _firestore.collection(_channelsCol).doc();
        transaction.set(channelRef, channelData);

        // Update user document with channelId (use set+merge in case user doc doesn't exist yet)
        final userRef = _firestore.collection('users').doc(uid);
        transaction.set(userRef, {'channelId': channelRef.id}, SetOptions(merge: true));

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

      // Navigate directly to Creator Studio with a smooth transition
      Get.offAllNamed(
        "/studio",
        arguments: {
          'channel': {
            'id': newChannelId,
            'name': channelNameText,
          }
        },
      );
    } catch (e) {
      debugPrint('âŒ Error creating channel: $e');
      _showErrorSnackbar("Failed to create channel: $e");
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
      _showErrorSnackbar('Failed to subscribe: ${e.toString()}');
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
              notificationsEnabled.value = data?['notificationsEnabled'] ?? true;
            }
            isSubscriptionLoading.value = false;
          },
          onError: (error) {
            isSubscribed.value = false;
            isSubscriptionLoading.value = false;
          },
        );
  }

  Future<void> updateNotificationPreference(String channelId, bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showErrorSnackbar('You must be logged in to update preferences.');
      return;
    }

    final subDocId = '${channelId}_${user.uid}';
    final subRef = _firestore.collection(_subsCol).doc(subDocId);

    try {
      await subRef.update({
        'notificationsEnabled': enabled,
      });
      notificationsEnabled.value = enabled;
      _showSuccessSnackbar(enabled ? 'All notifications turned on' : 'Notifications muted');
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
      _showErrorSnackbar("Failed to delete draft: $e");
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
      "Error",
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.brand,
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: Icon(Icons.star, color: AppColors.textPrimary),
    );
  }

  void _showSuccessSnackbar(String message) {
    Get.snackbar(
      "Success",
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: Icon(Icons.star, color: AppColors.textPrimary),
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
    detailsAvatarStatus.value = channel.avatarStatus ?? "";
    detailsBannerStatus.value = channel.bannerStatus ?? "";
    detailsAvatarReason.value = "";
    detailsBannerReason.value = "";

    _detailsAvatarSub?.cancel();
    _detailsBannerSub?.cancel();

    final currentUser = _auth.currentUser;
    if (currentUser != null && channel.ownerId == currentUser.uid) {
      if (channel.avatarFileId != null &&
          channel.avatarFileId!.isNotEmpty &&
          channel.avatarStatus != "APPROVED") {
        detailsAvatarStatus.value = channel.avatarStatus ?? "PENDING";
        _detailsAvatarSub = _imageVerificationService
            .streamVerificationStatus(channel.avatarFileId!)
            .listen((result) {
              detailsAvatarStatus.value = result.status.name.toUpperCase();
              detailsAvatarReason.value = result.reason;
              if (result.status == VerificationStatus.approved ||
                  result.status == VerificationStatus.rejected ||
                  result.status == VerificationStatus.flagged) {
                _firestore.collection(_channelsCol).doc(channel.id).update({
                  'avatarStatus': result.status.name.toUpperCase(),
                }).catchError((_) {});
              }
            });
      }

      if (channel.bannerFileId != null &&
          channel.bannerFileId!.isNotEmpty &&
          channel.bannerStatus != "APPROVED") {
        detailsBannerStatus.value = channel.bannerStatus ?? "PENDING";
        _detailsBannerSub = _imageVerificationService
            .streamVerificationStatus(channel.bannerFileId!)
            .listen((result) {
              detailsBannerStatus.value = result.status.name.toUpperCase();
              detailsBannerReason.value = result.reason;
              if (result.status == VerificationStatus.approved ||
                  result.status == VerificationStatus.rejected ||
                  result.status == VerificationStatus.flagged) {
                _firestore.collection(_channelsCol).doc(channel.id).update({
                  'bannerStatus': result.status.name.toUpperCase(),
                }).catchError((_) {});
              }
            });
      }
    }

    listenSubscription(channel.channelId);
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

    final double offset = scrollController.offset;
    final bool isExpanded = offset > 200;

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
      Query<Map<String, dynamic>> query = _firestore
          .collection('videos')
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
        videos.value = snapshot.docs
            .map((doc) => Video.fromDocumentSnapshot(doc))
            .toList();
        lastVideoDocument.value = snapshot.docs.last;
        hasVideos.value = true;
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
      Query<Map<String, dynamic>> query = _firestore
          .collection('videos')
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
          snapshot.docs.map((doc) => Video.fromDocumentSnapshot(doc)).toList(),
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
    detailsAvatarStatus.value = "";
    detailsBannerStatus.value = "";
    detailsAvatarReason.value = "";
    detailsBannerReason.value = "";
    hasVideos.value = false;
    hasPlaylists.value = false;
    hasPosts.value = false;
  }

  Future<void> checkChannelContent(String channelId) async {
    try {
      // Check if channel has videos
      final videoSnap = await _firestore
          .collection('videos')
          .where('channelId', isEqualTo: channelId)
          .limit(1)
          .get();
      hasVideos.value = videoSnap.docs.isNotEmpty;

      // Check if channel has playlists
      final playlistSnap = await _firestore
          .collection('public_playlists')
          .where('channelId', isEqualTo: channelId)
          .limit(1)
          .get();
      hasPlaylists.value = playlistSnap.docs.isNotEmpty;

      // Check if channel has posts (Community)
      final postSnap = await _firestore
          .collection('Community')
          .where('channelId', isEqualTo: channelId)
          .limit(1)
          .get();
      hasPosts.value = postSnap.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking channel content: $e');
    }
  }
}
