import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/utils/mentions_helper.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_ai_features_mixin.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_controller_base.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_media_picker_mixin.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_pipeline_mixin.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_quota_mixin.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_topics_mixin.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_wizard_mixin.dart';
import 'package:uuid/uuid.dart';

mixin UploadSubmissionMixin on
    UploadControllerBase,
    UploadQuotaMixin,
    UploadAiFeaturesMixin,
    UploadMediaPickerMixin,
    UploadTopicsMixin,
    UploadPipelineMixin,
    UploadWizardMixin {
  final Uuid _uuid = const Uuid();


  List<String> _generateKeywords(String title) {
    final cleanTitle = title.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final words = cleanTitle
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final keywords = <String>{};
    for (final word in words) {
      keywords.add(word);
      for (var i = 1; i <= word.length; i++) {
        keywords.add(word.substring(0, i));
      }
    }
    return keywords.toList();
  }



  Future<void> uploadVideo(
    String title,
    String description,
    String channelName,
    String channelId,
    String channelImage,
    List<String> tags,
    List<String> selectedLanguages, {
    bool isDraft = false,
  }) async {
    debugPrint('Starting final video metadata update (isDraft: $isDraft)...');

    final channelLang = channelLanguageCode;
    final effectiveSelectedLangs = selectedLanguages.contains(channelLang)
        ? selectedLanguages
        : [channelLang, ...selectedLanguages];

    // Store metadata for multi-stage flow
    videoMetadata = {
      'title': title,
      'description': description,
      'channelName': channelName,
      'channelId': channelId,
      'channelImage': channelImage,
      'tags': tags,
      'language': channelLang,
      'languages': effectiveSelectedLangs,
    };

    if (pickedVideo.value == null &&
        resumedVideoDraft.value == null &&
        videoUrl.value.trim().isEmpty) {
      AppSnackbar.warning('Please select a video.');
      throw Exception('Please select a video.');
    }

    final isStillUploading = videoUrl.value.isEmpty &&
        (isUploading.value || pickedVideo.value != null);

    // All your validations...
    if (title.isEmpty || title.length > UploadControllerBase.maxTitleLength) {
      AppSnackbar.warning('Please provide a valid title between 1 and $UploadControllerBase.maxTitleLength characters.');
      throw Exception(
        'Invalid title (length must be between 1 and $UploadControllerBase.maxTitleLength characters).',
      );
    }

    final titleValidation = await validateContent(title, fieldName: 'Title');
    if (!titleValidation.isValid) {
      AppSnackbar.warning(titleValidation.message);
      throw Exception(titleValidation.message);
    }

    // Description validation
    if (description.isEmpty || description.length > UploadControllerBase.maxDescriptionLength) {
      AppSnackbar.warning('Please provide a valid description up to $UploadControllerBase.maxDescriptionLength characters.');
      throw Exception('Invalid description.');
    }

    final descValidation = await validateContent(
      description,
      fieldName: 'Description',
      checkPhoneNumbers: true,
    );
    if (!descValidation.isValid) {
      AppSnackbar.warning(descValidation.message);
      throw Exception(descValidation.message);
    }

    // Tags validation
    final validTags = tags.where((t) => t.trim().isNotEmpty).toList();
    if (validTags.isNotEmpty) {
      final tagsValidation = await validateTags(validTags);
      if (!tagsValidation.isValid) {
        AppSnackbar.warning(tagsValidation.message);
        throw Exception(tagsValidation.message);
      }
    }

    if (channelName.trim().isEmpty) {
      AppSnackbar.warning('Selected channel name is missing. Please select a valid channel.');
      throw Exception(
        'Selected channel name is missing. Please select a valid channel.',
      );
    }

    if (channelId.trim().isEmpty) {
      AppSnackbar.warning('Selected channel ID is missing. Please select a valid channel.');
      throw Exception(
        'Selected channel ID is missing. Please select a valid channel.',
      );
    }

    try {
      // 🔑 REFRESH TOKEN BEFORE FINAL PUBLISH
      debugPrint('🔐 Refreshing token before final publish...');
      final authValid = await verifyAuthentication();
      if (!authValid) {
        throw Exception('Authentication failed before publishing');
      }

      debugPrint('🔐 Checking authentication...');
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      final userId = currentUser.uid;
      debugPrint('✅ User authenticated: $userId');

      // Get video duration in milliseconds
      var durationMs = 0;
      if (pickedVideo.value != null) {
        durationMs = await getVideoDurationMs(pickedVideo.value!);
      } else if (resumedVideoDraft.value != null) {
        durationMs = resumedVideoDraft.value!.durationMs > 0
            ? resumedVideoDraft.value!.durationMs
            : resumedVideoDraft.value!.durationValue.inMilliseconds;
      }
      if (durationMs <= 0) {
        if (videoDuration.value.inMilliseconds > 0) {
          durationMs = videoDuration.value.inMilliseconds;
        } else if (videoDurationSeconds.value > 0) {
          durationMs = videoDurationSeconds.value * 1000;
        }
      }

      // Validate daily quota for selected channel before publishing
      final currentChan = selectedChannel.value;
      if (currentChan != null && !isDraft) {
        final durationSeconds = durationMs ~/ 1000;
        final used = await getTodayUploadedDurationSeconds(currentChan.id);
        final validation = validateChannelVideoUpload(
          currentChan,
          durationSeconds: durationSeconds,
          dailyUploadedDurationSeconds: used,
        );
        if (!validation.isValid) {
          AppSnackbar.warning(validation.message);
          throw Exception(validation.message);
        }
      }

      // Validate and deduct AI Features Payment (Dubbing & Subtitles are NOT free)
      final effectiveDurationSec = durationMs > 0
          ? (durationMs ~/ 1000)
          : videoDurationSeconds.value;
      var dubbingCost = 0.0;
      WalletTransaction? dubbingTx;
      if (aiGenerateDubbing.value &&
          aiDubbingLanguages.isNotEmpty &&
          currentChan != null &&
          !isDraft) {
        dubbingCost = ChannelWalletService.calculateDubbingCost(
          languageCount: aiDubbingLanguages.length,
          durationSeconds: effectiveDurationSec,
          channelType: currentChan.channelType,
        );
      }

      var subtitleCost = 0.0;
      WalletTransaction? subtitleTx;
      final subLangsToBill = (aiGenerateDubbing.value
              ? aiTranslationLanguages
                  .where((l) => !aiDubbingLanguages.contains(l))
                  .toList()
              : aiTranslationLanguages.toList())
          .where((l) => l.trim().isNotEmpty)
          .toList();

      if (aiGenerateSubtitles.value &&
          subLangsToBill.isNotEmpty &&
          currentChan != null &&
          !isDraft) {
        subtitleCost = ChannelWalletService.calculateSubtitleCost(
          languageCount: subLangsToBill.length,
          durationSeconds: effectiveDurationSec,
          channelType: currentChan.channelType,
        );
      }

      final totalAiComputeCost = dubbingCost + subtitleCost;
      if (totalAiComputeCost > 0 && currentChan != null && !isDraft) {
        final walletService = ChannelWalletService();
        final balance = await walletService.getSpendableBalanceForChannelId(currentChan.id);

        if (!balance.canAfford(totalAiComputeCost)) {
          final balanceStr = '\$${balance.totalSpendableBalance.toStringAsFixed(2)}';
          final totalStr = '\$${totalAiComputeCost.toStringAsFixed(2)}';
          String detailMsg;
          if (dubbingCost > 0 && subtitleCost > 0) {
            detailMsg =
                'AI Features are not free. Your channel balance of $balanceStr is insufficient for combined Dubbing (\$${dubbingCost.toStringAsFixed(2)}) and Subtitles (\$${subtitleCost.toStringAsFixed(2)}), totaling $totalStr.';
          } else if (dubbingCost > 0) {
            final rate = ChannelWalletService.getFlatDubbingPricePerLanguage(
              durationSeconds: effectiveDurationSec,
              channelType: currentChan.channelType,
            );
            detailMsg =
                'Dubbing is not free. Your channel balance of $balanceStr is insufficient for the flat dubbing cost of $totalStr (\$${rate.toStringAsFixed(2)}/lang × ${aiDubbingLanguages.length} languages for ${effectiveDurationSec}s video).';
          } else {
            final rate = ChannelWalletService.getFlatSubtitlePricePerLanguage(
              durationSeconds: effectiveDurationSec,
              channelType: currentChan.channelType,
            );
            detailMsg =
                'Subtitles are not free. Your channel balance of $balanceStr is insufficient for the subtitle cost of $totalStr (\$${rate.toStringAsFixed(2)}/lang × ${subLangsToBill.length} languages for ${effectiveDurationSec}s video).';
          }
          final msg = '$detailMsg Please add funds to your wallet or reduce selected languages.';
          AppSnackbar.warning(msg);
          throw Exception(msg);
        }

        // Deduct dubbing payment if selected
        if (dubbingCost > 0) {
          dubbingTx = await walletService.spendBalance(
            channel: currentChan,
            userId: userId,
            amount: dubbingCost,
            category: WalletTransactionCategory.aiDubbing,
            description: 'AI Dubbing (${aiDubbingLanguages.length} langs, ${effectiveDurationSec}s)',
            metadata: {
              'channelType': currentChan.channelType.name,
              'durationSeconds': effectiveDurationSec,
              'languageCount': aiDubbingLanguages.length,
              'dubbingLanguages': aiDubbingLanguages.toList(),
              'flatRatePerLanguage': ChannelWalletService.getFlatDubbingPricePerLanguage(
                durationSeconds: effectiveDurationSec,
                channelType: currentChan.channelType,
              ),
              'costUSD': dubbingCost,
            },
          );

          if (dubbingTx == null) {
            const msg = 'Unable to complete dubbing deduction from channel balance. Please check your wallet and try again.';
            AppSnackbar.error(msg);
            throw Exception(msg);
          }
        }

        // Deduct subtitles payment if selected
        if (subtitleCost > 0) {
          subtitleTx = await walletService.spendBalance(
            channel: currentChan,
            userId: userId,
            amount: subtitleCost,
            category: WalletTransactionCategory.aiSubtitles,
            description: 'AI Subtitles (${subLangsToBill.length} langs, ${effectiveDurationSec}s)',
            metadata: {
              'channelType': currentChan.channelType.name,
              'durationSeconds': effectiveDurationSec,
              'languageCount': subLangsToBill.length,
              'subtitleLanguages': subLangsToBill,
              'flatRatePerLanguage': ChannelWalletService.getFlatSubtitlePricePerLanguage(
                durationSeconds: effectiveDurationSec,
                channelType: currentChan.channelType,
              ),
              'costUSD': subtitleCost,
            },
          );

          if (subtitleTx == null) {
            const msg = 'Unable to complete subtitle deduction from channel balance. Please check your wallet and try again.';
            AppSnackbar.error(msg);
            throw Exception(msg);
          }
        }
      }

      // Upload thumbnail if needed
      if (thumbnailUrl.value.isEmpty && pickedImage.value != null) {
        await startImageUpload(pickedImage.value!, forCommunity: false);
      }
      if (thumbnailUrl.value.isEmpty) {
        thumbnailUrl.value =
            'https://via.placeholder.com/1280x720.png?text=No+Thumbnail';
      }

      final validLanguages = selectedLanguages.whereType<String>().toList();

      // Use the ID that was created during video upload, or resumed draft ID, or generate a new one
      currentVideoId ??= resumedVideoDraft.value?.id ?? _uuid.v4();
      final videoId = currentVideoId!;

      debugPrint('📄 Video ID: $videoId');
      debugPrint('👤 Owner ID: $userId');

      // CHECK IF DOCUMENT EXISTS FIRST
      debugPrint('🔍 Checking if document exists...');
      final docRef = firestore.collection('videos').doc(videoId);
      final docSnapshot = await docRef.get();

      // Prepare update data
      final updateData = {
        'title': title.trim(),
        'description': description.trim(),
        'keywords': _generateKeywords(title.trim()),
        'videoUrl': videoUrl.value.isNotEmpty
            ? videoUrl.value
            : (docSnapshot.data()?['videoUrl'] as String? ?? ''),
        'thumbnailUrl': thumbnailUrl.value.isNotEmpty
            ? thumbnailUrl.value
            : (docSnapshot.data()?['thumbnailUrl'] as String? ?? ''),
        'channelName': channelName.trim(),
        'channelId': channelId.trim(),
        'channelImage': channelImage,
        'category': selectedCategory.value.isEmpty
            ? 'Uncategorized'
            : selectedCategory.value,
        'tags': validTags,
        'language': channelLanguageCode,
        'languages': validLanguages.contains(channelLanguageCode)
            ? validLanguages
            : [channelLanguageCode, ...validLanguages],
        'visibility': isDraft ? 'private' : selectedVisibility.value,
        'targetVisibility': isDraft ? 'private' : selectedVisibility.value,
        'isKidFriendly': isKidFriendly.value,
        'isShort': isShort.value,
        'uploadQuality': uploadQuality.value.isEmpty
            ? 'Auto'
            : uploadQuality.value,
        'enableComments': enableComments.value,
        'allowRatings': allowRatings.value,
        'duration': durationMs > 0
            ? (durationMs ~/ 1000)
            : ((docSnapshot.data()?['duration'] as int?) ??
                ((docSnapshot.data()?['durationMs'] as int?) != null
                    ? (docSnapshot.data()!['durationMs'] as int) ~/ 1000
                    : 0)),
        'durationMs': durationMs > 0
            ? durationMs
            : ((docSnapshot.data()?['durationMs'] as int?) ??
                ((docSnapshot.data()?['duration'] as int?) != null
                    ? (docSnapshot.data()!['duration'] as int) * 1000
                    : 0)),
        'fileName': pickedVideo.value?.name ??
            (resumedVideoDraft.value?.title.isNotEmpty == true
                ? '${resumedVideoDraft.value!.title}.mp4'
                : (docSnapshot.data()?['fileName'] as String? ?? 'unnamed_video.mp4')),
        'status': isDraft
            ? 'draft'
            : (isStillUploading
                ? 'uploading'
                : (isScheduled.value ? 'scheduled' : 'published')),
        'targetStatus': isDraft
            ? 'draft'
            : (isScheduled.value ? 'scheduled' : 'published'),
        'aiFeatures': buildFeaturesMap(
          pipelineStage: isDraft ? 'draft' : 'published',
        ),
        'factCheckTier': aiFactCheckEnabled.value
            ? (aiFactCheckTier.value.isEmpty || aiFactCheckTier.value == 'none'
                ? 'full_ground'
                : aiFactCheckTier.value)
            : 'none',
        'enableFactCheck': aiFactCheckEnabled.value,
        'factChecking': aiFactCheckEnabled.value,
        'truthVerification': aiFactCheckEnabled.value,
        'isFactChecked': aiFactCheckEnabled.value,
        'factCheckReviewMode': aiFactCheckReviewMode.value,
        'isFactCheckApproved':
            aiFactCheckReviewMode.value != 'first_to_creator',
      };

      if (dubbingCost > 0) {
        updateData['dubbingPaid'] = true;
        updateData['dubbingCostUSD'] = dubbingCost;
        updateData['dubbingDurationSeconds'] = effectiveDurationSec;
        if (dubbingTx != null) {
          updateData['dubbingWalletTxId'] = dubbingTx.id;
        }
      }

      if (subtitleCost > 0) {
        updateData['subtitlesPaid'] = true;
        updateData['subtitlesCostUSD'] = subtitleCost;
        updateData['subtitlesDurationSeconds'] = effectiveDurationSec;
        if (subtitleTx != null) {
          updateData['subtitlesWalletTxId'] = subtitleTx.id;
        }
      }

      if (!docSnapshot.exists) {
        debugPrint('📄 Creating initial Firestore document with metadata...');
        await docRef.set({
          'id': videoId,
          'ownerId': userId,
          'userId': userId,
          'uploadedAt': Timestamp.now(),
          'likes': 0,
          'likeCount': 0,
          'dislikes': 0,
          'dislikeCount': 0,
          'views': 0,
          'viewCount': 0,
          'shareCount': 0,
          'downloads': 0,
          'reportCount': 0,
          'isBlocked': false,
          ...updateData,
        });
      } else {
        // Verify ownership if document exists
        final existingOwnerId = docSnapshot.data()?['ownerId'];
        if (existingOwnerId != null && existingOwnerId != userId) {
          debugPrint('❌ OWNERSHIP MISMATCH!');
          debugPrint('   Document ownerId: $existingOwnerId');
          debugPrint('   Current user ID: $userId');
          throw Exception('Ownership verification failed');
        }
        await docRef.update(updateData);
      }

      if (isDraft) {
        try {
          await firestore.collection('user_drafts').doc(videoId).set({
            'id': videoId,
            'title': title.trim(),
            'type': 'video',
            'content': description.trim(),
            'description': description.trim(),
            'mediaUrl': thumbnailUrl.value,
            'updatedAt': DateTime.now().toIso8601String(),
            'status': 'draft',
            'userId': userId,
            'channelId': channelId.trim(),
          }, SetOptions(merge: true));
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'UploadSubmissionMixin.syncUserDrafts',
          );
        }
      } else {
        try {
          await firestore.collection('user_drafts').doc(videoId).delete();
        } catch (_) {}
      }

      debugPrint('✅ Document updated with creator metadata');

      // Handle inline topic creation if needed
      if (newTopicData.isNotEmpty) {
        debugPrint('🆕 Creating new inline topic: ${newTopicData['title']}');

        final newTitle = (newTopicData['title'] as String?) ?? '';
        final newDescription = (newTopicData['description'] as String?) ?? '';
        final newCategory = (newTopicData['category'] as String?) ?? 'Science & Technology';
        final newVisibility =
            (newTopicData['visibilityType'] as TopicVisibilityType?) ??
            TopicVisibilityType.public;
        final newAccessCode = newTopicData['accessCode'] as String?;
        final thumbnailSource =
            (newTopicData['thumbnailSource'] as String?) ?? 'video';

        String? finalThumbnailUrl;
        if (thumbnailSource == 'custom' &&
            newTopicData['customThumbnailBytes'] != null) {
          final bytes = newTopicData['customThumbnailBytes'] as Uint8List;
          final customName = (newTopicData['customThumbnailName'] as String?) ?? 'thumb.jpg';
          final fileName = 'topic_${const Uuid().v4().substring(0, 8)}_$customName';
          finalThumbnailUrl = await uploadTopicCustomThumbnail(bytes, fileName);
        } else {
          // Use first video's thumbnail
          finalThumbnailUrl = thumbnailUrl.value;
        }

        final newSlug = newTitle
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
            .replaceAll(RegExp(r'\s+'), '-');

        final rawHandle = (newTopicData['handle'] as String?) ?? '';
        var cleanHandle = rawHandle.trim();
        if (cleanHandle.startsWith('T/')) {
          cleanHandle = cleanHandle.substring(2);
        }
        if (cleanHandle.startsWith('t/')) {
          cleanHandle = cleanHandle.substring(2);
        }
        cleanHandle = cleanHandle
            .replaceAll(RegExp('[^a-zA-Z0-9_-]'), '-')
            .replaceAll(RegExp('-+'), '-');
        if (cleanHandle.isEmpty) {
          cleanHandle = newSlug;
        }
        final finalHandle = 'T/$cleanHandle';
        final finalHandleLowercase = finalHandle.toLowerCase();

        // Check if topic already exists by slug or handle to prevent duplicate documents
        DocumentSnapshot? existingTopicDoc;
        final existingSlugQuery = await firestore
            .collection('topics')
            .where('slug', isEqualTo: newSlug)
            .limit(1)
            .get();
        if (existingSlugQuery.docs.isNotEmpty) {
          existingTopicDoc = existingSlugQuery.docs.first;
        } else {
          final handleQuery = await firestore
              .collection('topics')
              .where('handleLowercase', isEqualTo: finalHandleLowercase)
              .limit(1)
              .get();
          if (handleQuery.docs.isNotEmpty) {
            existingTopicDoc = handleQuery.docs.first;
          }
        }

        if (existingTopicDoc != null && existingTopicDoc.exists) {
          final existingData = existingTopicDoc.data() as Map<String, dynamic>?;
          final canonicalSlug = (existingData?['slug'] as String?) ?? newSlug;
          debugPrint(
            'ℹ️ Inline topic already exists with slug: $canonicalSlug. Reusing existing topic to prevent duplicate document creation.',
          );
          selectedTopicId.value = canonicalSlug;
          newTopicData.clear();
        } else {
          final newTopicRef = firestore.collection('topics').doc();
          final newTopic = Topic(
            id: newTopicRef.id,
            title: newTitle,
            slug: newSlug,
            handle: finalHandle,
            handleLowercase: finalHandleLowercase,
            description: newDescription,
            category: newCategory,
            thumbnailUrl: finalThumbnailUrl,
            channelId: channelId.trim(),
            creatorId: userId,
            visibilityType: newVisibility,
            accessCode: newVisibility == TopicVisibilityType.private
                ? newAccessCode
                : null,
            videoCount: 1, // First video linked
            featuredVideoIds: [videoId],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: 'underReview',
          );

          await newTopicRef.set(newTopic.toMap());
          debugPrint(
            '✅ Inline topic created with slug: $newSlug and handle: $finalHandle',
          );

          selectedTopicId.value = newSlug;
          newTopicData.clear();
        }
      }

      // Link video to topic if selected
      if (selectedTopicId.value.isNotEmpty && selectedTopicId.value != 'new_topic_draft') {
        debugPrint('🔗 Linking video to topic: ${selectedTopicId.value}');
        // Resolve canonical slug and increment video count on topic
        DocumentSnapshot? topicDoc;
        final bySlugQuery = await firestore
            .collection('topics')
            .where('slug', isEqualTo: selectedTopicId.value)
            .limit(1)
            .get();
        if (bySlugQuery.docs.isNotEmpty) {
          topicDoc = bySlugQuery.docs.first;
        } else {
          final byIdDoc = await firestore.collection('topics').doc(selectedTopicId.value).get();
          if (byIdDoc.exists) {
            topicDoc = byIdDoc;
          }
        }

        var finalTopicSlug = selectedTopicId.value;
        if (topicDoc != null && topicDoc.exists && topicDoc.data() != null) {
          final tData = topicDoc.data()! as Map<String, dynamic>;
          finalTopicSlug = (tData['slug'] as String?) ?? selectedTopicId.value;
          final topicCreatedAt = (tData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          if (DateTime.now().difference(topicCreatedAt).inSeconds > 5) {
            await topicDoc.reference.update({
              'videoCount': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            debugPrint('✅ Incremented videoCount for existing topic: $finalTopicSlug');
          }
        }

        updateData['topicId'] = finalTopicSlug;
        updateData['topics'] = [finalTopicSlug];
      }

      if (isScheduled.value) {
        updateData['scheduledTime'] = Timestamp.fromDate(scheduledDate.value);
      }

      debugPrint('📝 Updating document with metadata...');
      debugPrint('Update data keys: ${updateData.keys.toList()}');

      // IMPORTANT: Use update() not set() to preserve Cloud Function data
      await docRef.update(updateData);

      // Scan for handle mentions and notify
      final fullMetadataText = '${title.trim()} ${description.trim()}';
      try {
        await MentionsHelper.processAndNotifyMentions(
          text: fullMetadataText,
          videoId: videoId,
          videoTitle: title.trim(),
          videoThumbnailUrl: thumbnailUrl.value,
          videoChannelId: channelId.trim(),
        );
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'UploadSubmissionMixin.processMentions',
        );
      }

      debugPrint('✅ Document updated successfully!');

      // Add to playlist if selected
      if (selectedPlaylist.value.isNotEmpty) {
        debugPrint('📂 Adding to playlist: ${selectedPlaylist.value}');
        try {
          final playlistController = Get.isRegistered<PlaylistController>()
              ? Get.find<PlaylistController>()
              : Get.put(PlaylistController());

          final playlist = playlistController.allUserPlaylists.firstWhereOrNull((p) => p.id == selectedPlaylist.value)
              ?? playlistController.playlists.firstWhereOrNull((p) => p.id == selectedPlaylist.value)
              ?? playlistController.publicPlaylists.firstWhereOrNull((p) => p.id == selectedPlaylist.value);
          final isPublic = playlist?.isPublic ?? true;

          await playlistController.addVideoToPlaylist(
            selectedPlaylist.value,
            videoId,
            isPublic,
          );
          debugPrint(
            '✅ Successfully added video to playlist via PlaylistController',
          );
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'UploadSubmissionMixin.addToPlaylistController',
          );
          // Resilient direct Firestore update fallback
          try {
            final publicDoc = await firestore.collection('public_playlists').doc(selectedPlaylist.value).get();
            if (publicDoc.exists) {
              await firestore.collection('public_playlists').doc(selectedPlaylist.value).update({
                'videoIds': FieldValue.arrayUnion([videoId]),
                'videoCount': FieldValue.increment(1),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              await firestore.collection('public_playlists').doc(selectedPlaylist.value).collection('items').doc(videoId).set({
                'videoId': videoId,
                'addedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } else {
              await firestore
                  .collection(FirestoreCollections.users)
                  .doc(userId)
                  .collection(FirestoreCollections.playlists)
                  .doc(selectedPlaylist.value)
                  .update({
                    'videoIds': FieldValue.arrayUnion([videoId]),
                    'videoCount': FieldValue.increment(1),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
              await firestore
                  .collection(FirestoreCollections.users)
                  .doc(userId)
                  .collection(FirestoreCollections.playlists)
                  .doc(selectedPlaylist.value)
                  .collection('items')
                  .doc(videoId)
                  .set({
                    'videoId': videoId,
                    'addedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
            }
          } catch (fallbackErr, fallbackStack) {
            ErrorHandler.log(
              fallbackErr,
              stackTrace: fallbackStack,
              tag: 'UploadSubmissionMixin.directPlaylistUpdate',
            );
          }
        }
      }

      // Move to publish stage
      setUploadStage(3);

      if (isStillUploading) {
        debugPrint('🎉 Video metadata updated! Video is uploading in background...');
        AppSnackbar.success(
          isDraft
              ? 'Your video was saved as a draft successfully.'
              : 'Video details saved! Uploading in background; it will be published automatically once processing completes.',
        );
      } else {
        debugPrint('🎉 Upload completed successfully!');
        AppSnackbar.success(
          isDraft
              ? 'Your video was saved as a draft successfully.'
              : 'Video uploaded successfully!',
        );
      }

      if (aiFactCheckEnabled.value && !isDraft) {
        try {
          final notifId = firestore.collection('user_notifications').doc().id;
          final isReviewFirst =
              aiFactCheckReviewMode.value == 'first_to_creator';
          final notifData = {
            'id': notifId,
            'userId': userId,
            'channelId': channelId.trim(),
            'type': 'fact_check_pending',
            'severity': 'info',
            'title': isReviewFirst
                ? 'Truth Verification Queued (Private Review)'
                : 'Truth Verification Queued',
            'message': isReviewFirst
                ? 'Fact-checking for "${title.trim()}" is in progress. Results will be held in Studio Notifications for your review and approval before viewers can watch them.'
                : 'Fact-checking for "${title.trim()}" is in progress and will be published directly to viewers once analysis completes.',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'metadata': {
              'videoId': videoId,
              'channelId': channelId.trim(),
              'videoTitle': title.trim(),
              'factCheckReviewMode': aiFactCheckReviewMode.value,
              'isFactCheckApproved': !isReviewFirst,
            },
          };
          await Future.wait([
            firestore
                .collection('user_notifications')
                .doc(notifId)
                .set(notifData),
            firestore
                .collection(FirestoreCollections.users)
                .doc(userId)
                .collection('notifications_active')
                .doc(notifId)
                .set(notifData),
          ]);
        } catch (e) {
          debugPrint('⚠️ Initial upload notification error (non-fatal): $e');
        }
      }

      uploadProgress.value = 0.0;
      resetUploads();
      if (Get.currentRoute != '/studio') {
        Get.offAllNamed('/studio');
      }
    } on FirebaseException catch (e) {
      debugPrint('🔥 FirebaseException caught:');
      debugPrint('   Code: ${e.code}');
      debugPrint('   Message: ${e.message}');
      debugPrint('   Plugin: ${e.plugin}');

      var errorMessage = 'Unable to complete video upload. Please try again.';
      if (e.code == 'permission-denied' ||
          (e.message?.contains('not authorized') ?? false)) {
        errorMessage =
            'Permission denied. Please log in again and try uploading.';
        debugPrint('⚠️ AUTH ERROR - User needs to re-authenticate');
      }

      ErrorHandler.log(e, context: 'UploadController.updateVideo');
      AppSnackbar.error(errorMessage);
      rethrow;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, context: 'UploadController.completeUpload');
      AppSnackbar.error('Unable to complete video upload. Please try again.');
      rethrow;
    }
  }

}
