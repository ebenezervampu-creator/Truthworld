import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/errors/error_handler.dart';

/// Mixin managing moderation modes (Direct Admin Approval vs Google Cloud Vision)
/// and bypass switches for TruthWorld Admin.
mixin AdminModerationModesMixin on GetxController {
  final RxBool rxBypassChannelBanners = false.obs;
  final RxBool rxBypassChannelAvatars = false.obs;
  final RxBool rxBypassVideoThumbnails = false.obs;
  final RxBool rxBypassCommunityPosts = false.obs;
  final RxBool rxBypassTopicThumbnails = false.obs;
  final RxBool rxBypassTopics = false.obs;
  final RxBool rxBypassPlaylistThumbnails = false.obs;
  final RxBool rxBypassVideos = false.obs;
  final RxBool rxBypassChannels = false.obs;
  final RxBool rxBypassAds = false.obs;
  final RxBool isLoadingModerationModes = false.obs;
  final RxBool isTogglingModerationMode = false.obs;

  void applyModerationModes(Map<String, dynamic> data) {
    if (data.containsKey('thumbnails') ||
        data.containsKey('videoThumbnails') ||
        data.containsKey('videos_thumbnails')) {
      rxBypassVideoThumbnails.value = data['thumbnails'] == true ||
          data['videos_thumbnails'] == true ||
          data['videoThumbnails'] == true;
    }
    if (data.containsKey('banner') ||
        data.containsKey('channelBanner') ||
        data.containsKey('channel_banner')) {
      rxBypassChannelBanners.value = data['banner'] == true ||
          data['channelBanner'] == true ||
          data['channel_banner'] == true;
    }
    if (data.containsKey('avatar') ||
        data.containsKey('channelAvatar') ||
        data.containsKey('channel_avatar')) {
      rxBypassChannelAvatars.value = data['avatar'] == true ||
          data['channelAvatar'] == true ||
          data['channel_avatar'] == true;
    }
    if (data.containsKey('community') ||
        data.containsKey('communityPosts') ||
        data.containsKey('community_posts')) {
      rxBypassCommunityPosts.value = data['community'] == true ||
          data['community_posts'] == true ||
          data['communityPosts'] == true;
    }
    if (data.containsKey('topics') ||
        data.containsKey('topicThumbnails') ||
        data.containsKey('topic_thumbnails')) {
      rxBypassTopicThumbnails.value = data['topics'] == true ||
          data['topic_thumbnails'] == true ||
          data['topicThumbnails'] == true;
      rxBypassTopics.value = rxBypassTopicThumbnails.value;
    }
    if (data.containsKey('playlists') ||
        data.containsKey('playlistThumbnails') ||
        data.containsKey('playlist_thumbnails')) {
      rxBypassPlaylistThumbnails.value = data['playlists'] == true ||
          data['playlist_thumbnails'] == true ||
          data['playlistThumbnails'] == true;
    }
    if (data.containsKey('videos')) {
      rxBypassVideos.value = data['videos'] == true;
    }
    if (data.containsKey('channels') || data.containsKey('channelDetails')) {
      rxBypassChannels.value =
          data['channels'] == true || data['channelDetails'] == true;
    }
    if (data.containsKey('ads') ||
        data.containsKey('campaigns') ||
        data.containsKey('adCampaigns') ||
        data.containsKey('advertiser_campaigns')) {
      rxBypassAds.value = data['ads'] == true ||
          data['campaigns'] == true ||
          data['adCampaigns'] == true ||
          data['advertiser_campaigns'] == true;
    }
  }

  Future<void> fetchFallbackModerationModes() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('system_settings')
          .doc('moderation_modes')
          .get();
      if (snap.exists && snap.data() != null) {
        applyModerationModes(snap.data()!);
      }
    } catch (e, s) {
      ErrorHandler.log(e,
          stackTrace: s, tag: 'AdminModerationModesMixin.fetchFallbackModerationModes');
    }
  }

  Future<bool> toggleModerationMode(String modeKey, bool value) async {
    // 0ms Instant UI update for the specific switch
    switch (modeKey) {
      case 'thumbnails':
      case 'videoThumbnails':
        rxBypassVideoThumbnails.value = value;
      case 'banner':
      case 'channelBanner':
        rxBypassChannelBanners.value = value;
      case 'avatar':
      case 'channelAvatar':
        rxBypassChannelAvatars.value = value;
      case 'community':
      case 'communityPosts':
        rxBypassCommunityPosts.value = value;
      case 'topics':
      case 'topicThumbnails':
        rxBypassTopicThumbnails.value = value;
      case 'playlists':
      case 'playlistThumbnails':
        rxBypassPlaylistThumbnails.value = value;
      case 'videos':
        rxBypassVideos.value = value;
      case 'channels':
        rxBypassChannels.value = value;
      case 'ads':
      case 'campaigns':
      case 'adCampaigns':
      case 'advertiser_campaigns':
        rxBypassAds.value = value;
    }

    try {
      final updateMap = <String, dynamic>{
        modeKey: value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
      };

      if (modeKey == 'thumbnails' || modeKey == 'videoThumbnails') {
        updateMap['thumbnails'] = value;
        updateMap['videos_thumbnails'] = value;
        updateMap['videoThumbnails'] = value;
      } else if (modeKey == 'banner' || modeKey == 'channelBanner') {
        updateMap['banner'] = value;
        updateMap['channelBanner'] = value;
        updateMap['channel_banner'] = value;
      } else if (modeKey == 'avatar' || modeKey == 'channelAvatar') {
        updateMap['avatar'] = value;
        updateMap['channelAvatar'] = value;
        updateMap['channel_avatar'] = value;
      } else if (modeKey == 'community' || modeKey == 'communityPosts') {
        updateMap['community'] = value;
        updateMap['community_posts'] = value;
        updateMap['communityPosts'] = value;
      } else if (modeKey == 'topics' || modeKey == 'topicThumbnails') {
        updateMap['topics'] = value;
        updateMap['topic_thumbnails'] = value;
        updateMap['topicThumbnails'] = value;
      } else if (modeKey == 'playlists' || modeKey == 'playlistThumbnails') {
        updateMap['playlists'] = value;
        updateMap['playlist_thumbnails'] = value;
        updateMap['playlistThumbnails'] = value;
      } else if (modeKey == 'ads' ||
          modeKey == 'campaigns' ||
          modeKey == 'adCampaigns' ||
          modeKey == 'advertiser_campaigns') {
        updateMap['ads'] = value;
        updateMap['campaigns'] = value;
        updateMap['adCampaigns'] = value;
        updateMap['advertiser_campaigns'] = value;
      }

      // 1. Attempt direct Firestore write
      try {
        await FirebaseFirestore.instance
            .collection('admin_settings')
            .doc('moderation_modes')
            .set(updateMap, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .collection('system_settings')
            .doc('moderation_modes')
            .set(updateMap, SetOptions(merge: true));
      } catch (fsErr, s) {
        ErrorHandler.log(fsErr,
            stackTrace: s, tag: 'AdminModerationModesMixin.moderationModesDirectWrite');
      }

      // 2. Call Cloud Function endpoint with Admin SDK privileges
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final idToken = await user.getIdToken();
          await http.post(
            Uri.parse(
              '${AppConfig.cloudFunctionsBaseUrl}/setModerationModesManual',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'modeKey': modeKey,
              'value': value,
              'modes': updateMap,
            }),
          );
        } catch (cfErr, s) {
          ErrorHandler.log(cfErr,
              stackTrace: s, tag: 'AdminModerationModesMixin.moderationModesCloudFunction');
        }
      }

      return true;
    } catch (e, s) {
      ErrorHandler.log(e,
          stackTrace: s, tag: 'AdminModerationModesMixin.toggleModerationMode');
      return true;
    }
  }

  Future<void> toggleAllMediaModes(bool enableDirectApproval) async {
    rxBypassVideoThumbnails.value = enableDirectApproval;
    rxBypassChannelBanners.value = enableDirectApproval;
    rxBypassChannelAvatars.value = enableDirectApproval;
    rxBypassCommunityPosts.value = enableDirectApproval;
    rxBypassTopicThumbnails.value = enableDirectApproval;
    rxBypassPlaylistThumbnails.value = enableDirectApproval;
    rxBypassAds.value = enableDirectApproval;

    final updateMap = <String, dynamic>{
      'thumbnails': enableDirectApproval,
      'videos_thumbnails': enableDirectApproval,
      'videoThumbnails': enableDirectApproval,
      'banner': enableDirectApproval,
      'channelBanner': enableDirectApproval,
      'channel_banner': enableDirectApproval,
      'avatar': enableDirectApproval,
      'channelAvatar': enableDirectApproval,
      'channel_avatar': enableDirectApproval,
      'community': enableDirectApproval,
      'community_posts': enableDirectApproval,
      'communityPosts': enableDirectApproval,
      'topics': enableDirectApproval,
      'topic_thumbnails': enableDirectApproval,
      'topicThumbnails': enableDirectApproval,
      'playlists': enableDirectApproval,
      'playlist_thumbnails': enableDirectApproval,
      'playlistThumbnails': enableDirectApproval,
      'ads': enableDirectApproval,
      'campaigns': enableDirectApproval,
      'adCampaigns': enableDirectApproval,
      'advertiser_campaigns': enableDirectApproval,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
    };

    try {
      try {
        await FirebaseFirestore.instance
            .collection('admin_settings')
            .doc('moderation_modes')
            .set(updateMap, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .collection('system_settings')
            .doc('moderation_modes')
            .set(updateMap, SetOptions(merge: true));
      } catch (fsErr, s) {
        ErrorHandler.log(fsErr,
            stackTrace: s, tag: 'AdminModerationModesMixin.toggleAllMediaModesDirectWrite');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final idToken = await user.getIdToken();
          await http.post(
            Uri.parse(
              '${AppConfig.cloudFunctionsBaseUrl}/setModerationModesManual',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'modes': updateMap,
            }),
          );
        } catch (cfErr, s) {
          ErrorHandler.log(cfErr,
              stackTrace: s, tag: 'AdminModerationModesMixin.toggleAllMediaModesCloudFunction');
        }
      }
    } catch (e, s) {
      ErrorHandler.log(e,
          stackTrace: s, tag: 'AdminModerationModesMixin.toggleAllMediaModes');
    }
  }
}
