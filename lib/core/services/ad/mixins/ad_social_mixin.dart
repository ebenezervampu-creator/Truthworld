import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/ad/mixins/ad_campaign_mixin.dart';
import 'package:truthworld/core/services/ad/models/ad_comment.dart';
import 'package:truthworld/core/services/ad/models/ad_item.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/home/presentation/controllers/home_feed_controller.dart';

mixin AdSocialMixin on AdCampaignMixin {
  final RxSet<String> likedAdIds = <String>{}.obs;
  final RxSet<String> savedAdIds = <String>{}.obs;
  StreamSubscription? _likesSubscription;
  StreamSubscription? _savesSubscription;

  void listenToUserInteractions() {
    _likesSubscription?.cancel();
    _savesSubscription?.cancel();
    likedAdIds.clear();
    savedAdIds.clear();

    final uid = AuthService.to.uid;
    if (uid.isEmpty) return;

    _likesSubscription = FirebaseFirestore.instance
        .collection('ad_likes')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) {
            likedAdIds.assignAll(
              snapshot.docs.map((doc) => doc.data()['adId'] as String),
            );
          },
          onError: (err) {
            if (err.toString().contains('permission-denied')) {
              debugPrint(
                '[AdService] ad_likes stream restricted by Firestore security rules. Local memory state active.',
              );
            } else {
              debugPrint('[AdService] ad_likes stream error: $err');
            }
          },
        );

    _savesSubscription = FirebaseFirestore.instance
        .collection('ad_saves')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) {
            savedAdIds.assignAll(
              snapshot.docs.map((doc) => doc.data()['adId'] as String),
            );
          },
          onError: (err) {
            if (err.toString().contains('permission-denied')) {
              debugPrint(
                '[AdService] ad_saves stream restricted by Firestore security rules. Local memory state active.',
              );
            } else {
              debugPrint('[AdService] ad_saves stream error: $err');
            }
          },
        );
  }

  Future<void> toggleLikeAd(String adId) async {
    final uid = AuthService.to.uid;
    if (uid.isEmpty) {
      AppSnackbar.show('Sign In Required', 'Please sign in to like ads.');
      return;
    }

    final isLiked = likedAdIds.contains(adId);
    if (isLiked) {
      likedAdIds.remove(adId);
    } else {
      likedAdIds.add(adId);
    }

    try {
      final docId = '${uid}_$adId';
      final ref = FirebaseFirestore.instance.collection('ad_likes').doc(docId);
      if (isLiked) {
        await ref.delete();
      } else {
        await ref.set({
          'userId': uid,
          'adId': adId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.toggleLikeAd');
    }
  }

  Future<void> toggleSaveAd(String adId) async {
    final uid = AuthService.to.uid;
    if (uid.isEmpty) {
      AppSnackbar.show('Sign In Required', 'Please sign in to save ads.');
      return;
    }

    final isSaved = savedAdIds.contains(adId);
    if (isSaved) {
      savedAdIds.remove(adId);
    } else {
      savedAdIds.add(adId);
    }

    try {
      final docId = '${uid}_$adId';
      final ref = FirebaseFirestore.instance.collection('ad_saves').doc(docId);
      if (isSaved) {
        await ref.delete();
      } else {
        await ref.set({
          'userId': uid,
          'adId': adId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.toggleSaveAd');
    }
  }

  Future<void> reportAd({
    required AdItem ad,
    required String reason,
    String details = '',
  }) async {
    final uid = AuthService.to.uid;
    final userName = AuthService.to.activeDisplayName.isNotEmpty
        ? AuthService.to.activeDisplayName
        : 'Anonymous User';
    final userEmail = AuthService.to.user?.email ?? '';

    // Hide ad locally for this user session & persist permanently
    hiddenAdIds.add(ad.id);
    try {
      storage?.write('hidden_ad_ids', hiddenAdIds.toList());
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.reportAd.storage');
    }


    customCampaigns.refresh();
    if (Get.isRegistered<HomeFeedController>()) {
      Get.find<HomeFeedController>().mixHomeFeed();
    }

    try {
      final docRef = FirebaseFirestore.instance.collection('ad_reports').doc();
      await docRef.set({
        'id': docRef.id,
        'adId': ad.id,
        'advertiser': ad.advertiser,
        'campaignTitle': ad.title,
        'userId': uid,
        'userName': userName,
        'userEmail': userEmail,
        'reason': reason,
        'details': details,
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      // Increment report count on ad_campaigns doc
      await FirebaseFirestore.instance
          .collection('ad_campaigns')
          .doc(ad.id)
          .update({
        'reportCount': FieldValue.increment(1),
        'lastReportedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.reportAd.firestore');
    }

    AppSnackbar.show(
      'Ad Reported',
      'Thank you for your feedback. We have hidden this ad.',
    );
  }


  Future<void> addAdComment(String adId, String text) async {
    final uid = AuthService.to.uid;
    if (uid.isEmpty) {
      AppSnackbar.show('Sign In Required', 'Please sign in to comment.');
      return;
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final validation = ContentValidator.validate(trimmed, fieldName: 'Comment');
    if (!validation.isValid) {
      AppSnackbar.warning(validation.message);
      return;
    }

    final userName = AuthService.to.activeDisplayName.isNotEmpty
        ? AuthService.to.activeDisplayName
        : 'Anonymous';
    final userProfilePicUrl = AuthService.to.activePhotoUrl;

    final ref = FirebaseFirestore.instance.collection('ad_comments').doc();
    await ref.set({
      'id': ref.id,
      'adId': adId,
      'userId': uid,
      'userName': userName,
      'userProfilePicUrl': userProfilePicUrl,
      'text': trimmed,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> replyToAdComment(
    String commentId,
    String replyText,
    String advertiserName,
  ) async {
    final uid = AuthService.to.uid;
    if (uid.isEmpty) return;

    final trimmed = replyText.trim();
    if (trimmed.isEmpty) return;

    final validation = ContentValidator.validate(trimmed, fieldName: 'Reply');
    if (!validation.isValid) {
      AppSnackbar.warning(validation.message);
      return;
    }

    await FirebaseFirestore.instance
        .collection('ad_comments')
        .doc(commentId)
        .update({
          'replyText': trimmed,
          'repliedAt': DateTime.now().toIso8601String(),
          'repliedBy': advertiserName,
        });
  }

  Stream<List<AdComment>> getAdCommentsStream(String adId) {
    return FirebaseFirestore.instance
        .collection('ad_comments')
        .where('adId', isEqualTo: adId)
        .snapshots()
        .map((snapshot) {
          final comments = snapshot.docs
              .map((doc) => AdComment.fromMap(doc.data(), doc.id))
              .toList();
          comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return comments;
        })
        .handleError((err) {
          debugPrint('[AdService] ad_comments stream notice: $err');
          return <AdComment>[];
        });
  }

  Stream<int> getAdCommentsCountStream(String adId) {
    return FirebaseFirestore.instance
        .collection('ad_comments')
        .where('adId', isEqualTo: adId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((err) {
          debugPrint('[AdService] ad_comments count stream notice: $err');
          return 0;
        });
  }

  Stream<int> getAdLikesCountStream(String adId) {
    return FirebaseFirestore.instance
        .collection('ad_likes')
        .where('adId', isEqualTo: adId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((err) {
          debugPrint('[AdService] ad_likes count stream notice: $err');
          return 0;
        });
  }

}
