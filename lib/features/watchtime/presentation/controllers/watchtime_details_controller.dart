import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';

/// Data model representing consolidated video watch time analytics.
class WatchtimeVideoItem {
  final String id;
  final String title;
  final int totalViews;
  final int uniqueUsers;
  final int totalWatchSeconds;
  final double avgWatchSeconds;
  final double completionRate;
  final int fullWatched;
  final int halfWatched;
  final int under20Sec;

  const WatchtimeVideoItem({
    required this.id,
    required this.title,
    this.totalViews = 0,
    this.uniqueUsers = 0,
    this.totalWatchSeconds = 0,
    this.avgWatchSeconds = 0.0,
    this.completionRate = 0.0,
    this.fullWatched = 0,
    this.halfWatched = 0,
    this.under20Sec = 0,
  });
}

/// Controller managing watch time details presentation state.
/// Decouples UI from direct database queries and adheres to GetX Clean Architecture.
class WatchtimeDetailsController extends BaseController {
  final String channelId;

  WatchtimeDetailsController({this.channelId = ''});

  final RxList<WatchtimeVideoItem> videoItems = <WatchtimeVideoItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchWatchtimeDetails();
  }

  Future<void> fetchWatchtimeDetails() async {
    await safeExecute(() async {
      final col = FirebaseFirestore.instance.collection(FirestoreCollections.videos);
      QuerySnapshot querySnapshot;

      if (channelId.isNotEmpty) {
        querySnapshot = await col.where('channelId', isEqualTo: channelId).get();
      } else {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          querySnapshot = await col.where('ownerId', isEqualTo: uid).get();
        } else {
          querySnapshot = await col.limit(20).get();
        }
      }

      final docs = querySnapshot.docs;
      if (docs.isEmpty) {
        videoItems.clear();
        return;
      }

      // Batch load stats for videos to eliminate N+1 query latency
      final statsFutures = docs.map((doc) async {
        final videoTitle = (doc.data() as Map<String, dynamic>?)?['title'] as String? ?? 'Untitled';
        try {
          final statsDoc = await FirebaseFirestore.instance
              .collection('video_stats')
              .doc(doc.id)
              .get();
          final stats = statsDoc.data();
          if (stats != null) {
            return WatchtimeVideoItem(
              id: doc.id,
              title: videoTitle,
              totalViews: (stats['totalViews'] as num?)?.toInt() ?? 0,
              uniqueUsers: (stats['uniqueUsers'] as num?)?.toInt() ?? 0,
              totalWatchSeconds: (stats['totalWatchSeconds'] as num?)?.toInt() ?? 0,
              avgWatchSeconds: (stats['avgWatchSeconds'] as num?)?.toDouble() ?? 0.0,
              completionRate: (stats['completionRate'] as num?)?.toDouble() ?? 0.0,
              fullWatched: (stats['fullWatched'] as num?)?.toInt() ?? 0,
              halfWatched: (stats['halfWatched'] as num?)?.toInt() ?? 0,
              under20Sec: (stats['under20Sec'] as num?)?.toInt() ?? 0,
            );
          }
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'WatchtimeDetailsController.stats');
        }

        final vData = doc.data() as Map<String, dynamic>? ?? {};
        final vViews = (vData['viewCount'] as num?)?.toInt() ?? (vData['views'] as num?)?.toInt() ?? 0;
        final vWatch = (vData['totalWatchTimeSeconds'] as num?)?.toInt() ?? 0;
        final vDur = (vData['durationSeconds'] as num?)?.toInt() ?? 0;
        return WatchtimeVideoItem(
          id: doc.id,
          title: videoTitle,
          totalViews: vViews,
          uniqueUsers: vViews,
          totalWatchSeconds: vWatch,
          avgWatchSeconds: vViews > 0 ? vWatch / vViews : 0.0,
          completionRate: (vDur > 0 && vViews > 0) ? ((vWatch / vViews) / vDur * 100).clamp(0.0, 100.0) : 0.0,
        );
      });

      final loadedItems = await Future.wait(statsFutures);
      videoItems.assignAll(loadedItems);
    });
  }
}
