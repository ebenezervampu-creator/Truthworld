import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class AnalyticsController extends GetxController {
  final String channelId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AnalyticsController({required this.channelId});

  var topVideos = <Video>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;

  StreamSubscription? _videosSubscription;

  @override
  void onInit() {
    super.onInit();
    if (channelId.isNotEmpty) {
      fetchTopVideos();
    } else {
      isLoading.value = false;
      errorMessage.value = "No channel ID provided.";
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
          .collection('videos')
          .where('channelId', isEqualTo: channelId)
          // .orderBy('views', descending: true)
          .limit(5);

      _videosSubscription = videosRef.snapshots().listen(
        (snapshot) {
          topVideos.value = snapshot.docs
              .map((doc) => Video.fromDocumentSnapshot(doc))
              .toList();
          isLoading.value = false;
        },
        onError: (error) {
          isLoading.value = false;
          errorMessage.value = "Failed to load top videos: $error";
        },
      );
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = "An unexpected error occurred: $e";
    }
  }
}





