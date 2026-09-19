import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';

/// Controller managing copyright claims, DMCA notices, and content re-upload matches.
class CopyrightController extends BaseController
    with GetSingleTickerProviderStateMixin {
  CopyrightController({
    String? initialChannelId,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance {
    if (initialChannelId != null && initialChannelId.isNotEmpty) {
      channelId.value = initialChannelId;
    }
  }

  static const String _tag = 'CopyrightController';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  late TabController tabController;
  final RxString channelId = ''.obs;
  final RxInt retryTrigger = 0.obs;

  String get activeChannelId {
    if (channelId.value.isNotEmpty) {
      return channelId.value;
    }
    return _auth.currentUser?.uid ?? '';
  }

  void setChannelContext(String id) {
    channelId.value = id;
  }

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 2, vsync: this);
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  /// Stream of copyright claims and notices against the channel.
  Stream<QuerySnapshot> noticesStream(String targetChannelId) {
    if (targetChannelId.isEmpty) return const Stream.empty();
    return _firestore
        .collection('copyright_claims')
        .where('channelId', isEqualTo: targetChannelId)
        .snapshots();
  }

  /// Stream of detected unauthorized re-uploads of the channel's videos.
  Stream<QuerySnapshot> matchedReuploadsStream(String targetChannelId) {
    if (targetChannelId.isEmpty) return const Stream.empty();
    return _firestore
        .collection(FirestoreCollections.videos)
        .where('originalChannelId', isEqualTo: targetChannelId)
        .snapshots();
  }

  /// Submits a DMCA removal request for an unauthorized re-upload.
  Future<bool> submitRemovalRequest({
    required String videoId,
    required String title,
  }) async {
    try {
      await _firestore.collection('copyright_claims').add({
        'videoId': videoId,
        'videoTitle': title,
        'channelId': activeChannelId,
        'claimant': 'Original Creator',
        'noticeType': 'DMCA Takedown Request',
        'status': 'PENDING_TAKEDOWN',
        'createdAt': Timestamp.now(),
      });
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: '$_tag.submitRemovalRequest',
      );
      return false;
    }
  }

  /// Increments retry trigger to force stream rebuilds on error recovery.
  void retry() {
    retryTrigger.value++;
  }
}
