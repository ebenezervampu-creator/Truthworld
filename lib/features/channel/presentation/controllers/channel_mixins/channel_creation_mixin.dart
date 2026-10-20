import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/constants/platform_limits.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_mixins/channel_controller_base.dart';

mixin ChannelCreationMixin on ChannelControllerBase {
  Future<void> createChannel() async {
    if (isSubmitting.value) return;
    isSubmitting.value = true;

    try {
      final user = auth.currentUser;
      if (user == null) {
        showErrorSnackbar('You must be signed in to create a channel.');
        isSubmitting.value = false;
        return;
      }
      final uid = user.uid;

      // 0. Strict 1-Channel Limit Check per Google Account
      // Check existing channels collection in Firestore directly first
      try {
        final existingChannelsSnap = await firestore
            .collection(ChannelControllerBase.channelsCol)
            .where('ownerId', isEqualTo: uid)
            .get();

        final activeExistingChannels = existingChannelsSnap.docs
            .map(Channel.fromDocumentSnapshot)
            .where((c) => c.status != ChannelStatus.deleted)
            .toList();

        if (activeExistingChannels.isNotEmpty) {
          final existing = activeExistingChannels.first;
          channels.assignAll(activeExistingChannels);
          AuthService.to.setUserChannel(existing);
          showErrorSnackbar(
            'You already have a channel. Only one channel is allowed per Google account.',
          );
          isSubmitting.value = false;
          Get.offAllNamed('/studio', arguments: {'channel': existing});
          return;
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'ChannelCreationMixin.checkOwnerChannels');
      }

      // Check user document directly in Firestore to guarantee no second channel
      try {
        final userDoc = await firestore
            .collection(FirestoreCollections.users)
            .doc(uid)
            .get();
        final userData = userDoc.data() ?? {};
        final existingChannelId = userData['channelId'] as String?;

        if (existingChannelId != null && existingChannelId.isNotEmpty) {
          final existingChDoc = await firestore
              .collection(ChannelControllerBase.channelsCol)
              .doc(existingChannelId)
              .get();

          if (existingChDoc.exists &&
              existingChDoc.data()?['status'] != 'deleted') {
            final existingCh = Channel.fromDocumentSnapshot(existingChDoc);
            channels.assignAll([existingCh]);
            AuthService.to.setUserChannel(existingCh);
            showErrorSnackbar(
              'You already have a channel. Only one channel is allowed per Google account.',
            );
            isSubmitting.value = false;
            Get.offAllNamed('/studio', arguments: {'channel': existingCh});
            return;
          } else {
            // Orphaned/stale channel reference on user doc — clean it up so creation can proceed
            await firestore
                .collection(FirestoreCollections.users)
                .doc(uid)
                .set({
              'channelId': null,
              'hasChannel': false,
            }, SetOptions(merge: true));
          }
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'ChannelCreationMixin.checkExistingChannelDoc');
      }

      // 0.1. Phase 1 Platform Capacity Check:
      // Standard channels capped at 100 max.
      // Custom channels have ZERO restriction (unlimited).
      if (selectedChannelType.value == ChannelType.standard) {
        try {
          final countSnap = await firestore
              .collection(ChannelControllerBase.channelsCol)
              .where('channelType', isEqualTo: ChannelType.standard.name)
              .where('status', isNotEqualTo: ChannelStatus.deleted.name)
              .count()
              .get();

          final count = countSnap.count ?? 0;
          if (count >= PlatformLimits.maxStandardChannels) {
            showErrorSnackbar(
              PlatformLimits.standardChannelLimitMessage,
            );
            isSubmitting.value = false;
            return;
          }
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'ChannelCreationMixin.checkStandardChannelCapacity',
          );
        }
      }

      // 1. Validation for requirements
      if (bannerUrl.value.isEmpty) {
        showErrorSnackbar('Please select and upload a Channel Banner image.');
        isSubmitting.value = false;
        return;
      }
      if (bannerFileId.value.isEmpty) {
        bannerFileId.value = 'banner_${uid}_${DateTime.now().millisecondsSinceEpoch}';
      }

      if (avatarUrl.value.isEmpty) {
        showErrorSnackbar('Please select and upload a Channel Avatar image.');
        isSubmitting.value = false;
        return;
      }
      if (avatarFileId.value.isEmpty) {
        avatarFileId.value = 'avatar_${uid}_${DateTime.now().millisecondsSinceEpoch}';
      }

      if (channelName.text.trim().isEmpty) {
        showErrorSnackbar('Please enter a Channel Name.');
        isSubmitting.value = false;
        return;
      }

      final nameValidation = await validateContent(channelName.text, fieldName: 'Channel Name');
      if (!nameValidation.isValid) {
        showErrorSnackbar('Please avoid offensive or profane language in Channel Name.');
        isSubmitting.value = false;
        return;
      }

      if (customUrl.text.trim().isEmpty) {
        showErrorSnackbar('Please enter a Channel Handle.');
        isSubmitting.value = false;
        return;
      }

      final handleValidation = await validateContent(customUrl.text, fieldName: 'Channel Handle');
      if (!handleValidation.isValid) {
        showErrorSnackbar('Please avoid offensive or profane language in Channel Handle.');
        isSubmitting.value = false;
        return;
      }

      if (description.text.trim().isEmpty) {
        showErrorSnackbar('Please enter a Channel Description.');
        isSubmitting.value = false;
        return;
      }

      final descValidation = await validateContent(description.text, fieldName: 'Channel Description');
      if (!descValidation.isValid) {
        showErrorSnackbar('Please avoid offensive or profane language in Channel Description.');
        isSubmitting.value = false;
        return;
      }

      final checkTags = tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (checkTags.isEmpty) {
        showErrorSnackbar('Please add at least 1 Tag.');
        isSubmitting.value = false;
        return;
      }

      final tagsValidation = await validateTags(checkTags);
      if (!tagsValidation.isValid) {
        showErrorSnackbar('Please avoid offensive or profane language in Channel Tags.');
        isSubmitting.value = false;
        return;
      }

      // Profanity check on websiteUrl and contactEmail
      if (websiteUrl.text.trim().isNotEmpty) {
        final webValidation = await validateContent(websiteUrl.text.trim(), fieldName: 'Website');
        if (!webValidation.isValid) {
          showErrorSnackbar('Please avoid offensive or profane language in Website.');
          isSubmitting.value = false;
          return;
        }
      }

      if (contactEmail.text.trim().isNotEmpty) {
        final emailValidation = await validateContent(contactEmail.text.trim(), fieldName: 'Contact Email');
        if (!emailValidation.isValid) {
          showErrorSnackbar('Please avoid offensive or profane language in Contact Email.');
          isSubmitting.value = false;
          return;
        }
      }

      // Profanity check on all social links
      for (final entry in socialLinks.entries) {
        if (entry.value.trim().isNotEmpty) {
          final linkValidation = await validateContent(entry.value.trim(), fieldName: 'Link (${entry.key})');
          if (!linkValidation.isValid) {
            showErrorSnackbar('Please avoid offensive or profane language in ${entry.key} link.');
            isSubmitting.value = false;
            return;
          }
        }
      }

      // Profanity check on all custom links
      for (final linkMap in customLinks) {
        final title = (linkMap['title'] ?? '').trim();
        final url = (linkMap['url'] ?? '').trim();
        if (title.isNotEmpty) {
          final titleValidation = await validateContent(title, fieldName: 'Custom Link Title');
          if (!titleValidation.isValid) {
            showErrorSnackbar('Please avoid offensive or profane language in custom link title.');
            isSubmitting.value = false;
            return;
          }
        }
        if (url.isNotEmpty) {
          final urlValidation = await validateContent(url, fieldName: 'Custom Link URL');
          if (!urlValidation.isValid) {
            showErrorSnackbar('Please avoid offensive or profane language in custom link URL.');
            isSubmitting.value = false;
            return;
          }
        }
      }

      if (selectedCategory.value == null ||
          selectedCategory.value!.trim().isEmpty ||
          selectedCategories.isEmpty) {
        if (selectedCategories.isNotEmpty) {
          selectedCategory.value = selectedCategories.first;
        } else {
          showErrorSnackbar('Please select at least 1 Category.');
          isSubmitting.value = false;
          return;
        }
      }

      if (selectedPlan.value.isEmpty) {
        selectedPlan.value = 'standard';
      }
      planSelectionError.value = false;

      // 🔒 Language Policy Enforcement: Truthworld is accepting only English channels as of now
      if (language.value.trim().toLowerCase() != 'en') {
        showErrorSnackbar(
          'Truthworld currently accepts channel creation only in English. All other languages are invite-only at this stage.',
        );
        isSubmitting.value = false;
        return;
      }

      if (!agreeTerms.value || !agreeGuidelines.value) {
        showErrorSnackbar('Please agree to both Terms & Conditions and Community Guidelines.');
        isSubmitting.value = false;
        return;
      }

      if (channelTypeCategory.value == 'Organization / Company') {
        final emailText = socialLinks['email'] ?? contactEmail.text;
        if (emailText.trim().isEmpty) {
          showErrorSnackbar('Please enter a custom business domain email (e.g. contact@company.com).');
          isSubmitting.value = false;
          return;
        }
        if (!isCustomBusinessEmail(emailText)) {
          showErrorSnackbar('Please enter a custom business domain email. Free email services (@gmail.com, @yahoo.com) are not allowed.');
          isSubmitting.value = false;
          return;
        }
      }

      if (!formKey.currentState!.validate()) {
        showErrorSnackbar('Please fill in all required fields correctly.');
        isSubmitting.value = false;
        return;
      }

      // 2. Moderation checks (Background verification does not block creation if status is PENDING or optimistic approved)
      if (avatarUrl.value.isNotEmpty && avatarStatus.value == 'REJECTED') {
        showErrorSnackbar(
          'Your avatar was rejected: ${avatarStatusReason.value}. Please select a different image.',
        );
        isSubmitting.value = false;
        return;
      }

      if (bannerUrl.value.isNotEmpty && bannerStatus.value == 'REJECTED') {
        showErrorSnackbar(
          'Your banner was rejected: ${bannerStatusReason.value}. Please select a different image.',
        );
        isSubmitting.value = false;
        return;
      }

      // Animation
      try {
        await buttonAnimationController.forward();
        await buttonAnimationController.reverse();
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'ChannelCreationMixin.buttonAnimation');
      }

      // Prepare data
      final parsedTags = tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      if (parsedTags.length > 5) {
        showErrorSnackbar('Maximum 5 tags allowed. Please reduce the number of tags.');
        isSubmitting.value = false;
        return;
      }

      final tagsList = parsedTags.take(5).toList();

      final channelNameText = channelName.text.trim();
      final customUrlText = customUrl.text.trim();
      final cleanHandle = customUrlText.startsWith('@')
          ? customUrlText.substring(1).trim()
          : customUrlText.trim();
      final handleLower = cleanHandle.toLowerCase();

      // 1. Check handle availability against existing channels collection
      final handleQuery = await firestore
          .collection(ChannelControllerBase.channelsCol)
          .where('handleLowercase', isEqualTo: handleLower)
          .limit(1)
          .get();

      if (handleQuery.docs.isNotEmpty) {
        showErrorSnackbar('Handle "@$cleanHandle" is already taken. Please choose a different handle.');
        isSubmitting.value = false;
        return;
      }

      // Also check channel_handles collection
      try {
        final existingHandleDoc = await firestore
            .collection('channel_handles')
            .doc(handleLower)
            .get();
        if (existingHandleDoc.exists && existingHandleDoc.data()?['ownerId'] != uid) {
          showErrorSnackbar('Handle "@$cleanHandle" is already claimed. Please choose a different handle.');
          isSubmitting.value = false;
          return;
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'ChannelCreationMixin.checkHandleRegistry');
      }

      // 2. Create Channel Document in Firestore
      final channelRef = firestore.collection(ChannelControllerBase.channelsCol).doc();
      final newChannelId = channelRef.id;
      final now = FieldValue.serverTimestamp();

      final channelData = {
        'id': newChannelId,
        // Core fields matching Channel model (V2)
        'channelType': selectedChannelType.value.name,
        'name': channelNameText,
        'nameLowercase': channelNameText.toLowerCase(),
        'channelName': channelNameText,
        'channelNameLowercase': channelNameText.toLowerCase(),
        'description': description.text.trim(),
        'bannerUrl': bannerUrl.value,
        'avatarUrl': avatarUrl.value,
        'avatarFileId': avatarFileId.value,
        'avatarStatus': avatarUrl.value.isNotEmpty
            ? (avatarStatus.value == 'REJECTED' || avatarStatus.value == 'FLAGGED'
                ? avatarStatus.value
                : 'APPROVED')
            : '',
        'bannerStatus': bannerUrl.value.isNotEmpty
            ? (bannerStatus.value == 'REJECTED' || bannerStatus.value == 'FLAGGED'
                ? bannerStatus.value
                : 'APPROVED')
            : '',
        'avatarStatusReason': avatarStatusReason.value,
        'bannerStatusReason': bannerStatusReason.value,
        'ownerId': uid,
        'userId': uid,
        'isArchived': false,
        'geminiApproved': false,
        'createdAt': now,
        'updatedAt': now,

        // Public settings
        'channelPlan': selectedPlan.value,
        'monetizationTier': 'free',
        'superchatRevenueTotal': 0,
        'customPricingTier': customPricingTier.value,
        'customPlanAutoPay': customPlanAutoPay.value,
        'autoPay': customPlanAutoPay.value,
        'visibility': visibility.value,
        'isPublic': visibility.value.toLowerCase() == 'public',
        'isVerified': false,
        'subscriberCount': 0,
        'videoCount': 0,
        'language': 'en',
        'country': country.value,
        'channelTypeCategory': channelTypeCategory.value,
        'entityType': channelTypeCategory.value,
        'tags': tagsList,

        // Custom URL mapped to handle
        'handle': cleanHandle,
        'handleLowercase': handleLower,
        'customUrl': cleanHandle,
        'customUrlLowercase': handleLower,

        // Moderation lists
        'moderatorIds': [],
        'blockedUserIds': [],

        // Optional fields
        'category': selectedCategories.isEmpty
            ? (selectedCategory.value ?? 'other')
            : selectedCategories.join(', '),
        'categories': selectedCategories.isEmpty
            ? [(selectedCategory.value ?? 'other')]
            : selectedCategories.toList(),
        'contactEmail': contactEmail.text.trim(),
        'websiteUrl': websiteUrl.text.trim(),
        'socialLinks': Map<String, dynamic>.from(socialLinks),
        'customLinks': customLinks.where((e) => (e['url'] ?? '').trim().isNotEmpty).toList(),

        // Advanced settings from form
        'allowComments': advancedSettings['allowComments'] ?? true,
        'allowSubscriptions': advancedSettings['allowSubscriptions'] ?? true,
        'showSubscriberCount': advancedSettings['showSubscriberCount'] ?? true,
        'showLikeCount': advancedSettings['showLikeCount'] ?? true,
        'showDislikeCount': advancedSettings['showDislikeCount'] ?? true,

        // Branding
        'brandingSettings': {
          'primaryColor': '#6B46C1',
          'secondaryColor': '#9333EA',
          'bannerStyle': 'gradient',
        },

        // Status & Metrics
        'status': ChannelStatus.active.name,
        'isLive': false,
        'metrics': {
          'totalViews': 0,
          'totalWatchTimeMinutes': 0,
          'averageRetention': 0.0,
        },
      };

      await channelRef.set(channelData);

      // 3. Update User Document
      try {
        final userRef = firestore.collection(FirestoreCollections.users).doc(uid);
        await userRef.set({
          'channelId': newChannelId,
          'hasChannel': true,
          'channelsCount': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'ChannelCreationMixin.updateUserDoc');
      }

      // 4. Update Handle Registry
      try {
        final handleRef = firestore.collection('channel_handles').doc(handleLower);
        await handleRef.set({
          'channelId': newChannelId,
          'ownerId': uid,
          'claimedAt': FieldValue.serverTimestamp(),
        });
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'ChannelCreationMixin.updateHandleRegistry');
      }

      // 5. Clean up drafts if any
      if (draftId.value != null && draftId.value!.isNotEmpty) {
        try {
          final draftRef = firestore.collection('channel_drafts').doc(draftId.value);
          await draftRef.delete();
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'ChannelCreationMixin.deleteDraft');
        }
      }

      // Success
      hasDraft.value = false;
      draftId.value = null;

      // Increment tag usage counts
      await _incrementTagUsageCounts(tagsList);

      final createdChannel = Channel.fromMap(
        {
          ...channelData,
          'id': newChannelId,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        },
        newChannelId,
      );

      // Immediately sync memory state
      AuthService.to.setUserChannel(createdChannel);
      AuthService.to.hasChannel.value = true;
      AuthService.to.rxUserChannel.value = createdChannel;
      channels.assignAll([createdChannel]);

      showSuccessSnackbar('Channel "$channelNameText" created successfully!');
      if (kDebugMode) {
        debugPrint('✅ Channel created with ID: $newChannelId');
        debugPrint('📌 Channel name: $channelNameText');
      }

      resetForm();

      // Navigate directly to Creator Studio with the resolved channel
      Get.offAllNamed('/studio', arguments: {
        'channel': createdChannel,
      });
    } on FirebaseException catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelCreationMixin.createChannel.firebase');
      channels.clear();
      final userMessage = _mapFirebaseError(e.code);
      showErrorSnackbar(userMessage);
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelCreationMixin.createChannel');
      channels.clear();
      showErrorSnackbar('Something went wrong while creating your channel. Please try again.');
    } finally {
      isSubmitting.value = false;
    }
  }

  // ==========================================================================
  // FIREBASE ERROR MAPPER — never expose raw error codes/messages to users
  // ==========================================================================
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'permission-denied':
        return 'You do not have permission to perform this action. Please contact support.';
      case 'unavailable':
        return 'The service is temporarily unavailable. Please try again in a moment.';
      case 'deadline-exceeded':
        return 'The request timed out. Please check your connection and try again.';
      case 'already-exists':
        return 'A channel with this handle already exists. Please choose a different handle.';
      case 'resource-exhausted':
        return 'Too many requests. Please wait a moment and try again.';
      case 'unauthenticated':
        return 'Your session has expired. Please sign in again.';
      case 'not-found':
        return 'Required data was not found. Please refresh and try again.';
      case 'cancelled':
        return 'The operation was cancelled. Please try again.';
      default:
        return 'Something went wrong while creating your channel. Please try again.';
    }
  }

  Future<void> _incrementTagUsageCounts(List<String> tagsList) async {
    for (final rawTag in tagsList) {
      final tagClean = rawTag.trim();
      if (tagClean.isEmpty) continue;
      final docId = tagClean.toLowerCase();
      final tagRef = firestore.collection(FirestoreCollections.hashtags).doc(docId);
      try {
        final doc = await tagRef.get();
        if (doc.exists) {
          await tagRef.update({
            'usageCount': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
            'lastUsedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await tagRef.set({
            'name': tagClean,
            'usageCount': 1,
            'videoCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'lastUsedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'ChannelCreationMixin._incrementTagUsageCounts');
      }
    }
  }

}
