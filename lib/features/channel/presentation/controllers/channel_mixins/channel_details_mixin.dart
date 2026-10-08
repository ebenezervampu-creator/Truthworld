import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_mixins/channel_controller_base.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

mixin ChannelDetailsMixin on ChannelControllerBase {
  void fetchChannel(String channelId) {
    final cleanId = channelId.trim();
    if (cleanId.isEmpty) {
      rxIsLoading.value = false;
      return;
    }
    rxIsLoading.value = true;
    firestore
        .collection(ChannelControllerBase.channelsCol)
        .doc(cleanId)
        .get()
        .then((doc) {
          if (doc.exists) {
            selectedChannel.value = Channel.fromDocumentSnapshot(doc);
          }
          rxIsLoading.value = false;
        })
        .catchError((e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'ChannelDetailsMixin.fetchChannel',
          );
          rxErrorMessage.value = 'Unable to load channel details. Please try again.';
          rxIsLoading.value = false;
        });
  }

  Future<void> shareChannel(String channelId) async {
    final channel = selectedChannel.value;
    if (channel == null) return;

    Get.find<MainController>().shareChannel(
      channelId,
      channel.channelName,
      avatarUrl: channel.avatarUrl.isNotEmpty ? channel.avatarUrl : null,
      bannerUrl: channel.bannerUrl.isNotEmpty ? channel.bannerUrl : null,
      handle: channel.handle,
      subscriberCount: channel.subscriberCount,
      videoCount: channel.videoCount,
      subtitle: channel.description.isNotEmpty ? channel.description : null,
    );
  }

  // Methods for Channel Details Page
  Future<void> loadChannelFromDeepLink(String channelIdOrHandle) async {
    final cached = DeepLinkService.instance.getChannelFromCache(channelIdOrHandle);
    if (cached != null) {
      debugPrint('[ChannelController] ⚡ 0ms instant cache hit for channel: $channelIdOrHandle');
      initForChannelDetails(cached);
      return;
    }

    try {
      debugPrint('[ChannelController] ⏳ Loading deep-linked channel from Firestore: $channelIdOrHandle');
      final channel = await DeepLinkService.instance.loadChannel(channelIdOrHandle);
      if (channel != null) {
        DeepLinkService.instance.cacheChannel(channel);
        initForChannelDetails(channel);
      } else {
        AppSnackbar.show(
          'Channel Not Found',
          'No channel found for $channelIdOrHandle',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.bgSurface,
          colorText: AppColors.textPrimary,
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelDetailsMixin.loadChannelFromDeepLink',
      );
    }
  }

  void initForChannelDetails(Channel channel) {
    DeepLinkService.instance.cacheChannel(channel);
    if (selectedChannel.value?.channelId == channel.channelId) {
      // Already initialized for this channel, just ensure listeners are attached
      _attachScrollListener();
      return;
    }

    // Clear previous state first
    clearChannelDetailsState();

    selectedChannel.value = channel;
    subscriberCount.value = channel.subscriberCount;
    ChannelSubscriptionController.channelSubscriberCounts[channel.channelId] = channel.subscriberCount;

    // Set initial values from the channel document
    detailsAvatarStatus.value = channel.avatarStatus ?? '';
    detailsBannerStatus.value = channel.bannerStatus ?? '';
    detailsAvatarReason.value = '';
    detailsBannerReason.value = '';

    detailsAvatarSub?.cancel();
    detailsBannerSub?.cancel();

    final currentUser = auth.currentUser;
    if (currentUser != null && channel.ownerId == currentUser.uid) {
      if (channel.avatarFileId != null &&
          channel.avatarFileId!.isNotEmpty &&
          channel.avatarStatus != 'APPROVED') {
        detailsAvatarStatus.value = channel.avatarStatus ?? 'PENDING';
        detailsAvatarSub = imageVerificationService
            .streamVerificationStatus(channel.avatarFileId!)
            .listen(
              (result) {
                detailsAvatarStatus.value = result.status.name.toUpperCase();
                detailsAvatarReason.value = result.reason;
                if (result.status == VerificationStatus.approved ||
                    result.status == VerificationStatus.rejected ||
                    result.status == VerificationStatus.flagged) {
                  firestore
                      .collection(ChannelControllerBase.channelsCol)
                      .doc(channel.id)
                      .update({
                        'avatarStatus': result.status.name.toUpperCase(),
                      })
                      .catchError((e, s) {
                        ErrorHandler.log(
                          e,
                          stackTrace: s,
                          tag: 'ChannelDetailsMixin.updateAvatarStatus',
                        );
                      });
                }
              },
              onError: (e, s) {
                ErrorHandler.log(
                  e,
                  stackTrace: s,
                  tag: 'ChannelDetailsMixin.detailsAvatarSub',
                );
              },
            );
      }

      if (channel.bannerFileId != null &&
          channel.bannerFileId!.isNotEmpty &&
          channel.bannerStatus != 'APPROVED') {
        detailsBannerStatus.value = channel.bannerStatus ?? 'PENDING';
        detailsBannerSub = imageVerificationService
            .streamVerificationStatus(channel.bannerFileId!)
            .listen(
              (result) {
                detailsBannerStatus.value = result.status.name.toUpperCase();
                detailsBannerReason.value = result.reason;
                if (result.status == VerificationStatus.approved ||
                    result.status == VerificationStatus.rejected ||
                    result.status == VerificationStatus.flagged) {
                  firestore
                      .collection(ChannelControllerBase.channelsCol)
                      .doc(channel.id)
                      .update({
                        'bannerStatus': result.status.name.toUpperCase(),
                      })
                      .catchError((e, s) {
                        ErrorHandler.log(
                          e,
                          stackTrace: s,
                          tag: 'ChannelDetailsMixin.updateBannerStatus',
                        );
                      });
                }
              },
              onError: (e, s) {
                ErrorHandler.log(
                  e,
                  stackTrace: s,
                  tag: 'ChannelDetailsMixin.detailsBannerSub',
                );
              },
            );
      }
    }

    listenSubscription(channel.channelId);
    fetchSubscriberCount(channel.channelId);
    fetchChannelVideoCount(channel.channelId);
    _attachScrollListener();
    loadInitialVideos();
    checkChannelContent(channel.channelId);
  }

  Future<void> requestManualReview({
    required String channelId,
    required bool isBanner,
    String? reason,
  }) async {
    try {
      final statusField = isBanner ? 'bannerStatus' : 'avatarStatus';
      final reasonField =
          isBanner ? 'bannerStatusReason' : 'avatarStatusReason';
      final userReason = reason ?? 'Creator requested manual review.';

      await firestore.collection(ChannelControllerBase.channelsCol).doc(channelId).update({
        statusField: 'MANUAL_REVIEW',
        reasonField: userReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (isBanner) {
        detailsBannerStatus.value = 'MANUAL_REVIEW';
        detailsBannerReason.value = userReason;
      } else {
        detailsAvatarStatus.value = 'MANUAL_REVIEW';
        detailsAvatarReason.value = userReason;
      }

      AppSnackbar.success(
        'Your image has been queued for manual review.',
        title: 'Manual Review Requested',
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelDetailsMixin.requestManualReview',
      );
      AppSnackbar.error(
        'Unable to request manual review. Please check your connection and try again.',
        title: 'Manual Review',
      );
    }
  }

  void _attachScrollListener() {
    // Only add if not already attached
    scrollController.removeListener(_onScrollListener);
    scrollController.addListener(_onScrollListener);
  }

  void _onScrollListener() {
    if (!scrollController.hasClients) return;
    onScroll(scrollController);
  }

  void onScroll(ScrollController scrollController) {
    if (!scrollController.hasClients || scrollController.positions.length != 1) return;

    final offset = scrollController.offset;
    final isExpanded = offset > 200;

    if (isExpanded != isAppBarExpanded.value) {
      isAppBarExpanded.value = isExpanded;
    }

    if (scrollController.position.extentAfter < 200 && !isLoadingMore.value) {
      loadMoreVideos();
    }
  }

  Future<void> loadInitialVideos() async {
    if (selectedChannel.value == null) return;
    isLoadingVideos.value = true;
    try {
      var query = firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: selectedChannel.value!.channelId);

      // Apply Filters
      if (videoSortFilter.value == 'Short video') {
        query = query.where('isShort', isEqualTo: true);
      } else if (videoSortFilter.value == 'Long video') {
        query = query.where('isShort', isEqualTo: false);
      }

      // Apply Sorting
      if (videoSortFilter.value == 'Popular') {
        query = query.orderBy('views', descending: true);
      } else if (videoSortFilter.value == 'Oldest') {
        query = query.orderBy('uploadedAt', descending: false);
      } else if (videoSortFilter.value == 'Latest') {
        query = query.orderBy('uploadedAt', descending: true);
      } else {
        // Default sorting for other filters (Short/Long)
        query = query.orderBy('uploadedAt', descending: true);
      }

      final currentUser = auth.currentUser;
      final isChannelOwner = currentUser != null &&
          (selectedChannel.value?.ownerId == currentUser.uid ||
           (selectedChannel.value?.channelId != null &&
            selectedChannel.value!.channelId == AuthService.to.userChannel?.channelId));

      final snapshot = await query.limit(12).get();

      if (snapshot.docs.isNotEmpty) {
        videos.value = snapshot.docs
            .map(Video.fromDocumentSnapshot)
            .where(VideoVisibilityPolicy.isValidVideo)
            .where((v) => isChannelOwner || !v.isPrivate)
            .toList();
        lastVideoDocument.value = snapshot.docs.last;
        hasVideos.value = videos.isNotEmpty;
        if (channelVideoCount.value == 0) {
          channelVideoCount.value = videos.length;
        }
      } else {
        videos.clear();
        lastVideoDocument.value = null;
      }
    } catch (error, stackTrace) {
      ErrorHandler.log(
        error,
        stackTrace: stackTrace,
        tag: 'ChannelDetailsMixin.loadInitialVideos',
      );
      showErrorSnackbar('Unable to load videos. Please try again.');
    } finally {
      isLoadingVideos.value = false;
    }
  }

  void setVideoSortFilter(String filter) {
    if (videoSortFilter.value == filter) return;
    videoSortFilter.value = filter;
    loadInitialVideos();
  }

  Future<void> loadMoreVideos() async {
    if (lastVideoDocument.value == null ||
        isLoadingMore.value ||
        selectedChannel.value == null) {
      return;
    }
    isLoadingMore.value = true;
    try {
      final currentUser = auth.currentUser;
      final isChannelOwner = currentUser != null &&
          (selectedChannel.value?.ownerId == currentUser.uid ||
           (selectedChannel.value?.channelId != null &&
            selectedChannel.value!.channelId == AuthService.to.userChannel?.channelId));

      var query = firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: selectedChannel.value!.channelId);

      // Apply Filters Same as loadInitialVideos
      if (videoSortFilter.value == 'Short video') {
        query = query.where('isShort', isEqualTo: true);
      } else if (videoSortFilter.value == 'Long video') {
        query = query.where('isShort', isEqualTo: false);
      }

      // Apply Sorting Same as loadInitialVideos
      if (videoSortFilter.value == 'Popular') {
        query = query.orderBy('views', descending: true);
      } else if (videoSortFilter.value == 'Oldest') {
        query = query.orderBy('uploadedAt', descending: false);
      } else if (videoSortFilter.value == 'Latest') {
        query = query.orderBy('uploadedAt', descending: true);
      } else {
        query = query.orderBy('uploadedAt', descending: true);
      }

      final snapshot = await query
          .startAfterDocument(lastVideoDocument.value!)
          .limit(12)
          .get();
      if (snapshot.docs.isNotEmpty) {
        videos.addAll(
          snapshot.docs
              .map(Video.fromDocumentSnapshot)
              .where(VideoVisibilityPolicy.isValidVideo)
              .where((v) => isChannelOwner || !v.isPrivate)
              .toList(),
        );
        lastVideoDocument.value = snapshot.docs.last;
      }
    } catch (error, stackTrace) {
      ErrorHandler.log(
        error,
        stackTrace: stackTrace,
        tag: 'ChannelDetailsMixin.loadMoreVideos',
      );
      showErrorSnackbar('Unable to load more videos. Please try again.');
    } finally {
      isLoadingMore.value = false;
    }
  }

  void clearChannelDetailsState() {
    scrollController.removeListener(_onScrollListener);
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    isAppBarExpanded.value = false;
    isDescriptionExpanded.value = false;
    videos.clear();
    lastVideoDocument.value = null;
    isLoadingMore.value = false;
    isLoadingVideos.value = false;
    selectedChannel.value = null;
    videoSortFilter.value = 'Latest';
    detailsAvatarSub?.cancel();
    detailsBannerSub?.cancel();
    detailsAvatarStatus.value = '';
    detailsBannerStatus.value = '';
    detailsAvatarReason.value = '';
    detailsBannerReason.value = '';
    hasVideos.value = false;
    hasPlaylists.value = false;
    hasPosts.value = false;
    hasTopics.value = false;
    channelVideoCount.value = 0;
    subscriberCount.value = 0;
    selectedChannelTopic.value = null;
    topicVideosMap.clear();
    isLoadingVideosMap.clear();
    topicPostsMap.clear();
    isLoadingPostsMap.clear();
  }

  Future<void> fetchChannelVideoCount(String channelId) async {
    try {
      final currentUser = auth.currentUser;
      final isOwner = currentUser != null &&
          (selectedChannel.value?.ownerId == currentUser.uid ||
           (selectedChannel.value?.channelId != null &&
            selectedChannel.value!.channelId == AuthService.to.userChannel?.channelId));

      if (isOwner) {
        final countSnap = await firestore
            .collection(FirestoreCollections.videos)
            .where('channelId', isEqualTo: channelId)
            .count()
            .get();
        channelVideoCount.value = countSnap.count ?? 0;
      } else {
        try {
          final countSnap = await firestore
              .collection(FirestoreCollections.videos)
              .where('channelId', isEqualTo: channelId)
              .where('visibility', isEqualTo: 'Public')
              .count()
              .get();
          channelVideoCount.value = countSnap.count ?? 0;
        } catch (_) {
          channelVideoCount.value =
              videos.where((v) => !v.isPrivate).length;
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelDetailsMixin.fetchChannelVideoCount',
      );
    }
  }

  Future<void> checkChannelContent(String channelId) async {
    try {
      final currentUser = auth.currentUser;
      final isOwner = currentUser != null &&
          (selectedChannel.value?.ownerId == currentUser.uid ||
           (selectedChannel.value?.channelId != null &&
            selectedChannel.value!.channelId == AuthService.to.userChannel?.channelId));

      var postQuery = firestore
          .collection(FirestoreCollections.community)
          .where('channelId', isEqualTo: channelId);

      if (isOwner) {
        postQuery = postQuery.where('ownerId', isEqualTo: currentUser.uid);
      } else {
        postQuery = postQuery.where('visibility', isEqualTo: 'Public');
      }

      final results = await Future.wait([
        firestore
            .collection(FirestoreCollections.videos)
            .where('channelId', isEqualTo: channelId)
            .limit(10)
            .get(),
        firestore
            .collection('public_playlists')
            .where('channelId', isEqualTo: channelId)
            .limit(1)
            .get(),
        postQuery.limit(1).get(),
        firestore
            .collection(FirestoreCollections.topics)
            .where('channelId', isEqualTo: channelId)
            .where('status', isEqualTo: 'active')
            .limit(5)
            .get(),
      ]);

      final videoDocs = results[0].docs;
      final hasAnyVisibleVideo = videoDocs.any((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;
        final vis = (data['visibility'] as String?)?.toLowerCase() ?? 'public';
        return isOwner || (vis != 'private' && vis != 'draft');
      });
      hasVideos.value = hasAnyVisibleVideo;
      hasPlaylists.value = results[1].docs.isNotEmpty;
      hasPosts.value = results[2].docs.isNotEmpty;
      hasTopics.value = results[3].docs.any((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        final vCount = (data?['videoCount'] as num?)?.toInt() ?? 0;
        final featVids = data?['featuredVideoIds'] as List?;
        return vCount > 0 || (featVids != null && featVids.isNotEmpty);
      });
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelDetailsMixin.checkChannelContent',
      );
    }
  }

  Stream<QuerySnapshot>? _channelPlaylistsStream;
  String? _channelPlaylistsId;
  Stream<QuerySnapshot> getPlaylistsStream(String channelId) {
    if (_channelPlaylistsStream == null || _channelPlaylistsId != channelId) {
      _channelPlaylistsId = channelId;
      _channelPlaylistsStream = firestore
          .collection('public_playlists')
          .where('channelId', isEqualTo: channelId)
          .limit(50)
          .snapshots();
    }
    return _channelPlaylistsStream!;
  }

  Stream<QuerySnapshot>? _channelTopicsStream;
  String? _channelTopicsId;
  Stream<QuerySnapshot> getTopicsStream(String channelId) {
    if (_channelTopicsStream == null || _channelTopicsId != channelId) {
      _channelTopicsId = channelId;
      _channelTopicsStream = firestore
          .collection(FirestoreCollections.topics)
          .where('channelId', isEqualTo: channelId)
          .snapshots();
    }
    return _channelTopicsStream!;
  }

  Stream<QuerySnapshot>? _channelCommunityStream;
  String? _channelCommunityId;
  Stream<QuerySnapshot> getCommunityStream(String channelId) {
    if (_channelCommunityStream == null || _channelCommunityId != channelId) {
      _channelCommunityId = channelId;
      _channelCommunityStream = firestore
          .collection(FirestoreCollections.community)
          .where('channelId', isEqualTo: channelId)
          .snapshots();
    }
    return _channelCommunityStream!;
  }

}
