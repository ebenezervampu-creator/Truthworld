import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';

/// Columns available for sorting the desktop copyright data table.
enum CopyrightSortColumn { videoTitle, claimant, date, impact }

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

  // Filter & Search observables
  final RxString searchQuery = ''.obs;
  final RxString selectedFilter = 'all'.obs;
  final Rx<CopyrightSortColumn> sortColumn = CopyrightSortColumn.date.obs;
  final RxBool sortAscending = false.obs;
  final RxBool isSubmittingAction = false.obs;

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

  void setSort(CopyrightSortColumn column) {
    if (sortColumn.value == column) {
      sortAscending.value = !sortAscending.value;
    } else {
      sortColumn.value = column;
      sortAscending.value = false;
    }
  }

  void setSearchQuery(String query) {
    searchQuery.value = query.trim().toLowerCase();
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
  }

  /// Stream of copyright claims and notices against the channel.
  Stream<QuerySnapshot> noticesStream(String targetChannelId) {
    if (targetChannelId.isEmpty) return const Stream.empty();
    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      return _firestore
          .collection('copyright_claims')
          .where('uploaderId', isEqualTo: uid)
          .snapshots();
    }
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
    String? channelName,
    bool isScheduled7Day = false,
  }) async {
    isSubmittingAction.value = true;
    try {
      await _firestore.collection('copyright_claims').add({
        'videoId': videoId,
        'videoTitle': title,
        'targetChannel': channelName ?? 'Unknown Channel',
        'channelId': activeChannelId,
        'claimant': 'Original Creator',
        'noticeType': 'DMCA Takedown Request',
        'status': isScheduled7Day ? 'SCHEDULED_7_DAY_NOTICE' : 'PENDING_TAKEDOWN',
        'isScheduled7Day': isScheduled7Day,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: '$_tag.submitRemovalRequest',
      );
      return false;
    } finally {
      isSubmittingAction.value = false;
    }
  }

  /// Submits a formal dispute against a Content ID or copyright claim.
  Future<bool> submitClaimDispute({
    required String claimId,
    required String reason,
    required String explanation,
  }) async {
    isSubmittingAction.value = true;
    try {
      await _firestore.collection('copyright_disputes').add({
        'claimId': claimId,
        'channelId': activeChannelId,
        'disputeReason': reason,
        'explanation': explanation,
        'status': 'UNDER_REVIEW',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: '$_tag.submitClaimDispute',
      );
      return false;
    } finally {
      isSubmittingAction.value = false;
    }
  }

  /// Archives or dismisses a re-upload match so it no longer clutters active matches.
  Future<bool> archiveMatch(String videoId) async {
    try {
      await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .update({'isCopyrightArchived': true});
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: '$_tag.archiveMatch',
      );
      return false;
    }
  }

  /// Increments retry trigger to force stream rebuilds on error recovery.
  void retry() {
    retryTrigger.value++;
  }
}
