import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';

class VideoRatingController extends GetxController {

  VideoRatingController({required this.channelId});
  final String channelId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RxList<Video> ratedVideos = <Video>[].obs;
  RxBool isLoading = true.obs;
  RxString errorMessage = ''.obs;
  Rxn<Video> selectedVideo = Rxn<Video>();

  @override
  void onInit() {
    super.onInit();
    if (channelId.isNotEmpty) {
      loadRatedVideos();
    }
  }

  Future<void> loadRatedVideos() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      // Fetch all videos for this channel and filter locally to avoid needing a composite index
      final snapshot = await _firestore
          .collection('videos')
          .where('channelId', isEqualTo: channelId)
          .get();

      ratedVideos.value = snapshot.docs
          .map(Video.fromDocumentSnapshot)
          .where((video) => 
            video.trustScore > 0 || 
            video.videoRating > 0 || 
            video.uiReport != null || 
            video.factCheckStats != null ||
            video.trustLabel != null
          )
          .toList();

      // Sort by video rating primarily, then trust score
      ratedVideos.sort((a, b) {
        final scoreA = a.videoRating > 0 ? a.videoRating : a.trustScore;
        final scoreB = b.videoRating > 0 ? b.videoRating : b.trustScore;
        return scoreB.compareTo(scoreA);
      });

    } catch (e) {
      errorMessage.value = 'Failed to load rated videos: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> selectVideo(Video video) async {
    selectedVideo.value = video;
    await VideoMediaService().getCredibility(video.id);
    selectedVideo.refresh();
  }

  void clearSelection() {
    selectedVideo.value = null;
  }

  int getTrustColor(double score) {
    if (score >= 80) return 0xFF4CAF50; // Green
    if (score >= 60) return 0xFF8BC34A; // Light Green
    if (score >= 40) return 0xFFFFC107; // Amber
    if (score >= 20) return 0xFFFF9800; // Orange
    return 0xFFF44336; // Red
  }
}
