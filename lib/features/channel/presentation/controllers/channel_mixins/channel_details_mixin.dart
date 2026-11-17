import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_mixins/channel_controller_base.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/home/data/datasources/edge_feed_remote_data_source.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

mixin ChannelDetailsMixin on ChannelControllerBase {
  void fetchChannel(String channelId) {
    final cleanId = channelId.trim();
    if (cleanId.isEmpty) {
      rxIsLoading.value = false;
      return;
    }
    subController.fetchSubscriberCount(cleanId);
    rxIsLoading.value = true;
    firestore
        .collection(ChannelControllerBase.channelsCol)
        .doc(cleanId)
        .getCacheFirst()
        .then((doc) {
          if (doc.exists) {
            selectedChannel.value = Channel.fromDocumentSnapshot(doc);
            final verifiedCount = subController.getSubscriberCount(
              cleanId,
              fallback: selectedChannel.value?.subscriberCount,
            );
            subscriberCount.value = verifiedCount;
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

  Future<void> shareChannel(String channelId, [Channel? fallbackChannel]) async {
    final channel = selectedChannel.value ?? fallbackChannel;
    if (channel == null) return;

    final rawBanner = channel.bannerImageUrl.isNotEmpty
        ? channel.bannerImageUrl
        : channel.bannerUrl;
    final banner = rawBanner.trim().replaceAll(' ', '%20');

    if (Get.isRegistered<MainController>()) {
      Get.find<MainController>().shareChannel(
        channelId,
        channel.channelName,
        avatarUrl: channel.avatarUrl.isNotEmpty ? channel.avatarUrl : null,
        bannerUrl: banner.isNotEmpty ? banner : null,
        handle: channel.handle,
        subscriberCount: channel.subscriberCount,
        videoCount: channel.videoCount,
        subtitle: channel.description.isNotEmpty ? channel.description : null,
      );
    } else {
      final url = DeepLinkService.channelUrl(channelId, handle: channel.handle);
      ShareBottomSheet.show(
        title: channel.channelName,
        url: url,
        avatarUrl: channel.avatarUrl.isNotEmpty ? channel.avatarUrl : null,
        bannerUrl: banner.isNotEmpty ? banner : null,
        thumbnailUrl: banner.isNotEmpty
            ? banner
            : (channel.avatarUrl.isNotEmpty ? channel.avatarUrl : null),
        handle: channel.handle,
        subscriberCount: channel.subscriberCount,
        videoCount: channel.videoCount,
        subtitle: channel.description.isNotEmpty ? channel.description : null,
        type: 'channel',
      );
    }
  }

  // Methods for Channel Details Page
  Future<void> loadChannelFromDeepLink(String channelIdOrHandle) async {
    final cleanInput = channelIdOrHandle.trim();
    if (cleanInput.isEmpty) return;

    // Safety guard: If accidentally called with a video watch query string, redirect to video screen
    if (cleanInput.contains('watch') || cleanInput.contains('v=')) {
      String? videoId;
      if (cleanInput.contains('v=')) {
        final parts = cleanInput.split('v=');
        if (parts.length > 1) {
          videoId = parts[1].split('&')[0];
        }
      }
      if (videoId != null && videoId.isNotEmpty) {
        unawaited(Get.offNamed<void>('/watch?v=$videoId'));
        return;
      }
    }

    final cached = DeepLinkService.instance.getChannelFromCache(cleanInput);
    if (cached != null) {
      debugPrint('[ChannelController] ⚡ 0ms instant cache hit for channel: $cleanInput');
      initForChannelDetails(cached);
      return;
    }

    try {
      debugPrint('[ChannelController] ⏳ Loading deep-linked channel from Firestore: $cleanInput');
      final channel = await DeepLinkService.instance.loadChannel(cleanInput);
      if (channel != null) {
        DeepLinkService.instance.cacheChannel(channel);
        initForChannelDetails(channel);
      } else {
        AppSnackbar.error(
          'This channel could not be found. It may have been removed or renamed.',
          title: 'Channel Unavailable',
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
      // Already initialized for this channel, just ensure listeners and content are attached
      _attachScrollListener();
      checkChannelContent(channel.channelId);
      return;
    }

    // Clear previous state first
    clearChannelDetailsState();

    selectedChannel.value = channel;
    final verifiedCount = subController.getSubscriberCount(
      channel.channelId,
      fallback: channel.subscriberCount,
    );
    subscriberCount.value = verifiedCount;
    ChannelSubscriptionController.channelSubscriberCounts[channel.channelId] = verifiedCount;
    subController.fetchSubscriberCount(channel.channelId);
    subController.hasChannelMemberships.value = channel.hasMemberships;
    hasVideos.value = channel.videoCount > 0;

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

  /// Whether current viewer is the owner of the selected channel.
  bool get isOwnerOfCurrentChannel {
    final currentUser = auth.currentUser;
    final ownerId = selectedChannel.value?.ownerId;
    return currentUser != null &&
        (ownerId == currentUser.uid ||
            (selectedChannel.value?.id != null &&
                selectedChannel.value!.id ==
                    AuthService.to.userChannel?.id));
  }

  Future<void> loadInitialVideos() async {
    if (selectedChannel.value == null) return;
    if (selectedChannel.value!.isOnHold) {
      videos.clear();
      hasVideos.value = false;
      channelVideoCount.value = 0;
      isLoadingVideos.value = false;
      return;
    }
    isLoadingVideos.value = true;
    try {
      // Step 0: Edge-first delivery for public channel uploads
      if (videoSortFilter.value == 'Latest' || videoSortFilter.value.isEmpty) {
        try {
          final edgeDataSource = EdgeFeedRemoteDataSource();
          final edgeResponse = await edgeDataSource.fetchChannelFeed(
            selectedChannel.value!.channelId,
            limit: 12,
          );
          if (edgeResponse.videos.isNotEmpty) {
            final isOwner = isOwnerOfCurrentChannel;
            final mapped = edgeResponse.videos
                .map(Video.fromEntity)
                .where((v) => VideoVisibilityPolicy.isVisibleForChannel(v, isChannelOwner: isOwner))
                .toList();
            if (mapped.isNotEmpty) {
              videos.value = mapped;
              lastVideoDocument.value = null;
              hasVideos.value = true;
              if (channelVideoCount.value == 0) {
                channelVideoCount.value = mapped.length;
              }
              return;
            }
          }
        } catch (edgeErr, edgeStack) {
          ErrorHandler.log(edgeErr, stackTrace: edgeStack, tag: 'ChannelDetailsMixin.loadInitialVideos.edge');
        }
      }

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

      final snapshot = await query.limit(12).getCacheFirst();

      if (snapshot.docs.isNotEmpty) {
        final isOwner = isOwnerOfCurrentChannel;
        videos.value = snapshot.docs
            .map(Video.fromDocumentSnapshot)
            .where((v) => VideoVisibilityPolicy.isVisibleForChannel(v, isChannelOwner: isOwner))
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
    if (selectedChannel.value?.isOnHold == true) return;
    if (lastVideoDocument.value == null ||
        isLoadingMore.value ||
        selectedChannel.value == null) {
      return;
    }
    isLoadingMore.value = true;
    try {
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
          .getCacheFirst();
      if (snapshot.docs.isNotEmpty) {
        final isOwner = isOwnerOfCurrentChannel;
        videos.addAll(
          snapshot.docs
              .map(Video.fromDocumentSnapshot)
              .where((v) => VideoVisibilityPolicy.isVisibleForChannel(v, isChannelOwner: isOwner))
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
    subController.hasChannelMemberships.value = false;
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
      try {
        final countSnap = await firestore
            .collection(FirestoreCollections.videos)
            .where('channelId', isEqualTo: channelId)
            .where('visibility', whereIn: const ['public', 'Public'])
            .count()
            .get();
        final c = countSnap.count ?? 0;
        channelVideoCount.value = c > 0
            ? c
            : videos.where(VideoVisibilityPolicy.isVisibleForChannel).length;
      } catch (_) {
        channelVideoCount.value =
            videos.where(VideoVisibilityPolicy.isVisibleForChannel).length;
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
      final isOwner = isOwnerOfCurrentChannel;
      final ownerId = selectedChannel.value?.ownerId;

      // Performance & Cost Optimization: Skip video query if already verified from channel.videoCount
      final needsVideoQuery = !hasVideos.value &&
          (selectedChannel.value == null || selectedChannel.value!.videoCount <= 0);

      await Future.wait([
        // 1. Check videos
        (() async {
          if (!needsVideoQuery) return;
          try {
            final snap = await firestore
                .collection(FirestoreCollections.videos)
                .where('channelId', isEqualTo: channelId)
                .limit(10)
                .getCacheFirst();
            final hasAnyVisibleVideo = snap.docs.any((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null) return false;
              final vis = (data['visibility'] as String?)?.toLowerCase() ?? 'public';
              if (isOwner && (vis == 'private' || vis == 'private_draft' || vis == 'unlisted')) {
                return true;
              }
              final isDiscoverable = vis == 'public' ||
                  vis.isEmpty ||
                  vis == 'members_only' ||
                  vis == 'members' ||
                  vis == 'subscribers_only' ||
                  vis == 'subscribers';
              return isDiscoverable && VideoVisibilityPolicy.isMapValid(data);
            });
            hasVideos.value = hasAnyVisibleVideo;
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'ChannelDetailsMixin.checkChannelContent.videos');
          }
        })(),

        // 2. Check playlists
        (() async {
          try {
            final snap = await firestore
                .collection('public_playlists')
                .where('channelId', isEqualTo: channelId)
                .limit(1)
                .getCacheFirst();
            final hasAnyPlaylist = snap.docs.any((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null) return false;
              final thumb = (data['thumbnailUrl'] as String?)?.trim() ?? '';
              final vCount = (data['videoCount'] as num?)?.toInt() ?? 0;
              final videoIds = data['videoIds'] as List?;
              return thumb.isNotEmpty || vCount > 0 || (videoIds != null && videoIds.isNotEmpty);
            });
            hasPlaylists.value = hasAnyPlaylist;
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'ChannelDetailsMixin.checkChannelContent.playlists');
          }
        })(),

        // 3. Check community posts
        (() async {
          try {
            // Check primary collection 'Community' by channelId
            var snap = await firestore
                .collection(FirestoreCollections.community)
                .where('channelId', isEqualTo: channelId)
                .limit(5)
                .getCacheFirst();

            // Fallback: check lowercase 'community' by channelId
            if (snap.docs.isEmpty) {
              snap = await firestore
                  .collection('community')
                  .where('channelId', isEqualTo: channelId)
                  .limit(5)
                  .getCacheFirst();
            }

            // Fallback: check by ownerId if different from channelId
            if (snap.docs.isEmpty && ownerId != null && ownerId.isNotEmpty && ownerId != channelId) {
              snap = await firestore
                  .collection(FirestoreCollections.community)
                  .where('ownerId', isEqualTo: ownerId)
                  .limit(5)
                  .getCacheFirst();
              if (snap.docs.isEmpty) {
                snap = await firestore
                    .collection('community')
                    .where('ownerId', isEqualTo: ownerId)
                    .limit(5)
                    .getCacheFirst();
              }
            }

            final hasAnyPost = snap.docs.any((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null) return false;
              final postId = (data['id'] as String?) ?? doc.id;
              final title = (data['title'] as String?)?.trim().toLowerCase() ?? '';
              final desc = (data['description'] as String?)?.trim().toLowerCase() ?? '';

              // Zero-mock policy filter
              if (postId == '8Zq2KuYIgm9m8kgogAE3' ||
                  title == 'our first video' ||
                  title.startsWith('our first video') ||
                  (title.contains('first video') && (desc.contains('hi every one') || desc.isEmpty))) {
                return false;
              }

              final status = (data['status'] as String?)?.toLowerCase();
              if (status == 'deleted' || status == 'trashed' || status == 'deletion_pending') {
                return false;
              }

              if (isOwner) return true;
              final vis = (data['visibility'] as String?)?.toLowerCase() ?? 'public';
              return vis == 'public' || vis == 'subscribers' || vis == 'members';
            });
            hasPosts.value = hasAnyPost;
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'ChannelDetailsMixin.checkChannelContent.posts');
          }
        })(),

        // 4. Check topics
        (() async {
          try {
            var snap = await firestore
                .collection(FirestoreCollections.topics)
                .where('channelId', isEqualTo: channelId)
                .limit(10)
                .getCacheFirst();

            if (snap.docs.isEmpty && ownerId != null && ownerId.isNotEmpty && ownerId != channelId) {
              snap = await firestore
                  .collection(FirestoreCollections.topics)
                  .where('creatorId', isEqualTo: ownerId)
                  .limit(10)
                  .getCacheFirst();
            }

            final hasAnyTopic = snap.docs.any((doc) {
              try {
                final topic = Topic.fromDocumentSnapshot(doc);
                if (topic.isArchivedOrDeleted) return false;
                if (topic.name.trim().isEmpty || topic.slug.trim().isEmpty) return false;
                final hasContent = topic.videoCount > 0 ||
                    topic.featuredVideoIds.isNotEmpty ||
                    topic.postCount > 0;
                if (!hasContent && !isOwner) return false;
                if (isOwner) return true;
                if (topic.visibilityType == TopicVisibilityType.public) return true;
                if (topic.visibilityType == TopicVisibilityType.channelOnly && isSubscribed.value) return true;
                return false;
              } catch (_) {
                return false;
              }
            });
            hasTopics.value = hasAnyTopic;
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: 'ChannelDetailsMixin.checkChannelContent.topics');
          }
        })(),
      ]);
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
