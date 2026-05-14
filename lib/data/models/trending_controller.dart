import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/core/services/logger_service.dart';

// Controller using GetX
class TrendingController extends GetxController {
  var trendingVideos = <Video>[].obs;
  var isLoading = true.obs;

  @override
  void onInit() {
    fetchTrendingVideos();
    super.onInit();
  }

  void fetchTrendingVideos() async {
    try {
      isLoading.value = true;
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('videos')
          .where('visibility', isEqualTo: 'Public')
          .orderBy('views', descending: true)
          .limit(20)
          .get();

      trendingVideos.value = snapshot.docs
          .map((doc) => Video.fromDocumentSnapshot(doc))
          .toList();
    } catch (e) {
      logger.error('Error fetching trending videos: $e', tag: 'TRENDING');
    } finally {
      isLoading.value = false;
    }
  }
}

// Main UI widget
class TrendingPage extends StatelessWidget {
  TrendingPage({super.key});

  final TrendingController controller = Get.put(TrendingController());

  String formatViews(int views) {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return views.toString();
  }

  String formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat.yMMMd().format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trending Videos')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: controller.trendingVideos.length,
          itemBuilder: (context, index) {
            final video = controller.trendingVideos[index];
            return Card(
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                contentPadding: EdgeInsets.all(12),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    video.thumbnailUrl,
                    width: 100,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  '${formatViews(video.views)} views • ${formatTimestamp(video.uploadedAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                trailing: const Icon(
                  Icons.trending_up,
                  color: Colors.redAccent,
                ),
                onTap: () {
                  Get.toNamed('/videoscreen', arguments: {"video": video});
                },
              ),
            );
          },
        );
      }),
    );
  }
}





