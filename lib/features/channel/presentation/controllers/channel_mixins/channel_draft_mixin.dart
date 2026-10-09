import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_mixins/channel_controller_base.dart';

mixin ChannelDraftMixin on ChannelControllerBase {
  Future<void> _loadDraft() async {
    try {
      final user = auth.currentUser;
      if (user == null) return;

      final draftSnapshot = await firestore
          .collection('channel_drafts')
          .where('ownerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (draftSnapshot.docs.isNotEmpty) {
        final draftData = draftSnapshot.docs.first.data();
        draftId.value = draftSnapshot.docs.first.id;

        // Restore form data
        channelName.text = draftData['channelName'] ?? '';
        description.text = draftData['description'] ?? '';
        customUrl.text = draftData['customUrl'] ?? '';
        tags.text = draftData['tags'] ?? '';
        contactEmail.text = draftData['contactEmail'] ?? '';
        websiteUrl.text = draftData['websiteUrl'] ?? '';
        isPublic.value = draftData['isPublic'] ?? true;
        language.value = draftData['language'] ?? 'en';
        selectedPlan.value = draftData['channelPlan'] ?? draftData['selectedPlan'] ?? 'standard';
        selectedCategories.value = List<String>.from(
          draftData['categories'] ?? [],
        );

        if (draftData['socialLinks'] != null) {
          socialLinks.value = Map<String, String>.from(
            draftData['socialLinks'],
          );
        }

        if (draftData['customLinks'] != null && draftData['customLinks'] is Iterable) {
          customLinks.value = (draftData['customLinks'] as Iterable)
              .whereType<Map>()
              .map((e) => Map<String, String>.from(e.map((k, v) => MapEntry(k.toString(), v.toString()))))
              .toList();
        }

        if (draftData['advancedSettings'] != null) {
          advancedSettings.value = Map<String, dynamic>.from(
            draftData['advancedSettings'],
          );
        }

        if (draftData['channelType'] != null) {
          final typeStr = draftData['channelType'] as String;
          selectedChannelType.value = ChannelType.values.firstWhere(
            (e) => e.name == typeStr,
            orElse: () => ChannelType.standard,
          );
        }

        bannerUrl.value = draftData['bannerUrl'] ?? '';
        avatarUrl.value = draftData['avatarUrl'] ?? '';
        bannerFileId.value = draftData['bannerFileId'] ?? '';
        avatarFileId.value = draftData['avatarFileId'] ?? '';
        bannerStatus.value = draftData['bannerStatus'] ?? '';
        avatarStatus.value = draftData['avatarStatus'] ?? '';
        bannerStatusReason.value = draftData['bannerStatusReason'] ?? '';
        avatarStatusReason.value = draftData['avatarStatusReason'] ?? '';

        if (avatarFileId.value.isNotEmpty &&
            (avatarStatus.value == 'PENDING' || avatarStatus.value.isEmpty)) {
          startAvatarModerationListener(avatarFileId.value);
        }
        if (bannerFileId.value.isNotEmpty &&
            (bannerStatus.value == 'PENDING' || bannerStatus.value.isEmpty)) {
          startBannerModerationListener(bannerFileId.value);
        }

        hasDraft.value = true;
        lastDraftSaveTime.value = (draftData['updatedAt'] as Timestamp?)
            ?.toDate();
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelDraftMixin._loadDraft');
    }
  }

  Future<void> saveDraft({int? currentStep}) async {
    try {
      final user = auth.currentUser;
      if (user == null) {
        debugPrint('❌ Cannot save draft: No user logged in');
        return;
      }

      debugPrint('💾 Saving draft for user: ${user.uid}');
      isSavingDraft.value = true;

      final draftData = {
        'ownerId': user.uid,
        'channelType': selectedChannelType.value.name,
        'channelName': channelName.text.trim(),
        'description': description.text.trim(),
        'customUrl': customUrl.text.trim(),
        'tags': tags.text.trim(),
        'contactEmail': contactEmail.text.trim(),
        'websiteUrl': websiteUrl.text.trim(),
        'isPublic': isPublic.value,
        'language': language.value,
        'channelPlan': selectedPlan.value,
        'selectedPlan': selectedPlan.value,
        'categories': selectedCategories.toList(),
        'socialLinks': Map<String, dynamic>.from(socialLinks),
        'customLinks': customLinks.toList(),
        'advancedSettings': Map<String, dynamic>.from(advancedSettings),
        'bannerUrl': bannerUrl.value,
        'avatarUrl': avatarUrl.value,
        'bannerFileId': bannerFileId.value,
        'avatarFileId': avatarFileId.value,
        'bannerStatus': bannerStatus.value,
        'avatarStatus': avatarStatus.value,
        'bannerStatusReason': bannerStatusReason.value,
        'avatarStatusReason': avatarStatusReason.value,
        'currentStep': currentStep ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': draftId.value == null
            ? FieldValue.serverTimestamp()
            : null,
      };

      if (draftId.value != null) {
        draftData.remove('createdAt');
      }

      if (draftId.value == null) {
        debugPrint('ðŸ“ Creating new draft document...');
        final docRef = await firestore
            .collection('channel_drafts')
            .add(draftData);
        draftId.value = docRef.id;
        debugPrint('âœ… Draft created with ID: ${docRef.id}');
      } else {
        debugPrint('ðŸ“ Updating draft: ${draftId.value}');
        await firestore
            .collection('channel_drafts')
            .doc(draftId.value)
            .update(draftData);
        debugPrint('âœ… Draft updated successfully');
      }

      hasDraft.value = true;
      lastDraftSaveTime.value = DateTime.now();
      isSavingDraft.value = false;

      // Silent draft save - no snackbar
    } catch (e, stackTrace) {
      isSavingDraft.value = false;
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelDraftMixin.saveDraft');
      // Silent error - draft save is automatic
    }
  }

  Future<void> deleteDraft() async {
    try {
      final user = auth.currentUser;
      if (user == null || draftId.value == null) return;

      // Delete uploaded images
      if (bannerUrl.value.isNotEmpty) {
        try {
          await storage.refFromURL(bannerUrl.value).delete();
        } catch (e, stackTrace) {
          ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelDraftMixin.deleteBanner');
        }
      }

      if (avatarUrl.value.isNotEmpty) {
        try {
          await storage.refFromURL(avatarUrl.value).delete();
        } catch (e, stackTrace) {
          ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelDraftMixin.deleteAvatar');
        }
      }

      // Delete draft document
      await firestore.collection('channel_drafts').doc(draftId.value).delete();

      hasDraft.value = false;
      draftId.value = null;
      lastDraftSaveTime.value = null;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelDraftMixin.deleteDraft');
      showErrorSnackbar('Unable to delete draft. Please try again.');
    }
  }


  @override
  Future<void> loadDraft() => _loadDraft();
}
