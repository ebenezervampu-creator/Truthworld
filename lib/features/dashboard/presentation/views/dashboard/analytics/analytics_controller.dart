import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class AnalyticsController extends GetxController {
  AnalyticsController({required this.channelId});
  final String channelId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RxList<Video> topVideos = <Video>[].obs;
  RxBool isLoading = true.obs;
  RxString errorMessage = ''.obs;

  StreamSubscription? _videosSubscription;

  @override
  void onInit() {
    super.onInit();
    if (channelId.isNotEmpty) {
      fetchTopVideos();
    } else {
      isLoading.value = false;
      errorMessage.value = 'No channel ID provided.';
    }
  }

  @override
  void onClose() {
    _videosSubscription?.cancel();
    super.onClose();
  }

  void fetchTopVideos() {
    isLoading.value = true;
    try {
      final videosRef = _firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: channelId)
          // .orderBy('views', descending: true)
          .limit(5);

      _videosSubscription = videosRef.snapshots().listen(
        (snapshot) {
          topVideos.value = snapshot.docs
              .map(Video.fromDocumentSnapshot)
              .toList();
          isLoading.value = false;
        },
        onError: (error) {
          isLoading.value = false;
          errorMessage.value = 'Failed to load top videos: $error';
        },
      );
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = 'An unexpected error occurred: $e';
    }
  }
}
