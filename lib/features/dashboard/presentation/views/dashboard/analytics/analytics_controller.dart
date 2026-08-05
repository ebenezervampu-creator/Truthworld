import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class AnalyticsController extends BaseController {
  AnalyticsController({required this.channelId});
  final String channelId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RxList<Video> topVideos = <Video>[].obs;
  RxBool rxIsLoading = true.obs;
  RxString rxErrorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    if (channelId.isNotEmpty) {
      fetchTopVideos();
    } else {
      rxIsLoading.value = false;
      rxErrorMessage.value = 'No channel ID provided.';
    }
  }

  void fetchTopVideos() {
    rxIsLoading.value = true;
    try {
      final videosRef = _firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: channelId)
          .limit(5);

      trackSubscription(videosRef.snapshots().listen(
        (snapshot) {
          topVideos.value = snapshot.docs
              .map(Video.fromDocumentSnapshot)
              .toList();
          rxIsLoading.value = false;
        },
        onError: (error) {
          rxIsLoading.value = false;
          rxErrorMessage.value = 'Failed to load top videos: $error';
        },
      ));
    } catch (e) {
      rxIsLoading.value = false;
      rxErrorMessage.value = 'An unexpected error occurred: $e';
    }
  }
}
