import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';

class CommentsController extends BaseController {
  final Video video;

  CommentsController({required this.video});

  final RxInt retryKey = 0.obs;
  final RxList<Comment> comments = <Comment>[].obs;
  final RxString error = ''.obs;
  final RxString sortOrder = 'newest'.obs;

  @override
  void onInit() {
    super.onInit();
    _setupCommentsStream();
  }

  void _setupCommentsStream() {
    setState(ViewState.loading);
    FirebaseFirestore.instance
        .collection("videos")
        .doc(video.id)
        .collection('comments')
        .orderBy('createdAt', descending: sortOrder.value == 'newest')
        .snapshots()
        .listen((snapshot) {
      comments.assignAll(snapshot.docs
          .map((doc) => Comment.fromDocumentSnapshot(doc))
          .toList());
      setState(ViewState.success);
    }, onError: (e) {
      error.value = e.toString();
      setState(ViewState.error);
    });
  }

  void retry() {
    retryKey.value++;
    _setupCommentsStream();
  }

  void updateSortOrder(String newOrder) {
    if (sortOrder.value != newOrder) {
      sortOrder.value = newOrder;
      _setupCommentsStream();
    }
  }

  // Expansion state for replies (mapped by comment ID)
  final RxMap<String, bool> expandedReplies = <String, bool>{}.obs;

  void toggleReplies(String commentId) {
    bool current = expandedReplies[commentId] ?? false;
    expandedReplies[commentId] = !current;
  }
  
  bool isRepliesExpanded(String commentId) => expandedReplies[commentId] ?? false;
}





