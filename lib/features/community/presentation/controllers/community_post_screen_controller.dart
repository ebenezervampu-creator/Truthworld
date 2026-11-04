import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';

/// Controller coordinating the single Community Post viewer screen.
class CommunityPostScreenController extends BaseController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Rx<CommunityPostModel?> post = Rx<CommunityPostModel?>(null);

  String? postId;
  String? targetCommentId;
  String? targetReplyId;
  bool isFromNotification = false;

  @override
  void onInit() {
    super.onInit();
    setViewState(ViewState.loading);
    final args = Get.arguments is Map ? (Get.arguments as Map) : null;
    postId = (args?['postId'] as String?) ?? Get.parameters['postId'];
    targetCommentId = (args?['commentId'] as String?) ?? Get.parameters['commentId'];
    targetReplyId = (args?['replyId'] as String?) ?? Get.parameters['replyId'];
    isFromNotification = (args?['fromNotification'] == true) ||
        (args?['fromPush'] == true) ||
        (Get.parameters['fromNotification'] == 'true');

    if (postId != null && postId!.isNotEmpty) {
      loadPost(postId!);
    } else {
      setError('Post not found.');
    }
  }

  Future<void> loadPost(String id) async {
    setViewState(ViewState.loading);
    clearError();

    try {
      // 1. Try FirestoreCollections.community ('Community')
      var doc = await _firestore.collection(FirestoreCollections.community).doc(id).get();

      // 2. Fallback to lowercase 'community'
      if (!doc.exists || doc.data() == null) {
        doc = await _firestore.collection('community').doc(id).get();
      }

      // 3. Fallback to 'community_posts'
      if (!doc.exists || doc.data() == null) {
        doc = await _firestore.collection('community_posts').doc(id).get();
      }

      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        if (data['id'] == null || (data['id'] as String).isEmpty) {
          data['id'] = doc.id;
        }
        post.value = CommunityPostModel.fromMap(data);
        setViewState(ViewState.success);
      } else {
        setError('This post is no longer available.');
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'CommunityPostScreenController.loadPost');
      setError('Unable to load post. Please check your connection and try again.');
    }
  }
}
