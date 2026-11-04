
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/core/services/verification_cache_service.dart';
import 'package:truthworld/features/notifications/data/services/user_notification_service.dart';
import 'package:truthworld/features/video/data/repositories/storage_video_upload_repository.dart';
import 'package:truthworld/features/video/domain/repositories/video_upload_repository.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_mixins.dart';

// Re-export extracted models & repositories for 100% backward compatibility
export 'package:truthworld/features/video/data/models/topic_relevance_result.dart';
export 'package:truthworld/features/video/data/repositories/video_report_repository.dart';
export 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_mixins.dart';

class UploadController extends UploadControllerBase
    with
        UploadReactiveStorageMixin,
        UploadQuotaMixin,
        UploadAiFeaturesMixin,
        UploadMediaPickerMixin,
        UploadTopicsMixin,
        UploadPipelineMixin,
        UploadWizardMixin,
        UploadSubmissionMixin {
  UploadController({
    VideoUploadRepository? uploadRepository,
    FirebaseFirestore? firestore,
    FirebaseStorage? firebaseStorage,
  })  : _uploadRepository = uploadRepository ?? StorageVideoUploadRepository(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseStorage = firebaseStorage ?? FirebaseStorage.instance {
    bindLegacyPrimitiveSync();
  }

  // Core Services
  final VideoUploadRepository _uploadRepository;
  @override
  VideoUploadRepository get uploadRepository => _uploadRepository;

  final FirebaseFirestore _firestore;
  @override
  FirebaseFirestore get firestore => _firestore;

  final FirebaseStorage _firebaseStorage;
  @override
  FirebaseStorage get firebaseStorage => _firebaseStorage;

  final ImageVerificationService _imageVerificationService =
      ImageVerificationService();
  @override
  ImageVerificationService get imageVerificationService =>
      _imageVerificationService;

  final VerificationCacheService _cacheService = VerificationCacheService();
  @override
  VerificationCacheService get cacheService => _cacheService;

  final UserNotificationService _userNotificationService =
      UserNotificationService();
  @override
  UserNotificationService get userNotificationService =>
      _userNotificationService;

  @override
  void onInit() {
    super.onInit();
    initializeContentFilters();
    final initialCat = resolveChannelFirstCategory();
    if (initialCat.isNotEmpty && (selectedCategory.value.isEmpty || selectedCategory.value == 'Other')) {
      selectedCategory.value = initialCat;
    }
    fetchChannelsWithRetry();
    fetchAvailableTopics();

    // Typo-tolerant Typesense remote topic search worker
    addWorker(
      debounce(
        topicSearchQuery,
        searchTopicsRemote,
        time: const Duration(milliseconds: 350),
      ),
    );

    // Every video doesn't have video rating only when user enabled Factchecking
    addWorker(
      ever(aiFactCheckEnabled, (enabled) {
        allowRatings.value = enabled;
      }),
    );
  }

  @override
  void onClose() {
    videoPlayerController?.dispose();
    titleController.dispose();
    descriptionController.dispose();
    tagController.dispose();
    thumbnailModerationSubscription?.cancel();
    communityImageModerationSubscription?.cancel();
    channelsSubscription?.cancel();
    statusListener?.cancel();
    super.onClose();
  }
}
