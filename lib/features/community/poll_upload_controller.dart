import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/community/data/models/poll_model.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dedicated GetX controller for **standalone Poll** posts.
///
/// A poll-only post has no images Ã¢â‚¬â€ just a question, options,
/// optional expiry, and channel/visibility settings.
class PollUploadController extends GetxController with ContentValidationMixin {
  final _firestore = FirebaseFirestore.instance;

  // Ã¢â€â‚¬Ã¢â€â‚¬ Channels Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  final channels = <Channel>[].obs;
  final selectedChannel = Rx<Channel?>(null);

  // Ã¢â€â‚¬Ã¢â€â‚¬ Poll data Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  final pollType = PollType.yesNo.obs;
  final pollQuestion = ''.obs;
  final pollOptions = <String>['', '', ''].obs;
  final pollDurationDays = Rx<int?>(null);

  // Ã¢â€â‚¬Ã¢â€â‚¬ Settings Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  final selectedVisibility = 'Public'.obs;
  final isUploading = false.obs;

  @override
  void onInit() {
    super.onInit();
    initializeContentFilters();
    final auth = AuthService.to;
    if (auth.hasChannel.value) {
      selectedChannel.value = auth.userChannel;
    }
    _fetchChannels();
  }

  void _fetchChannels() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (kDebugMode) {
        debugPrint('⚠ PollUploadController: No user logged in');
      }
      return;
    }
    _firestore
        .collection('channels')
        .where('ownerId', isEqualTo: uid)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snap) {
            channels.value = snap.docs
                .map((d) => Channel.fromDocumentSnapshot(d))
                .toList();
            _autoSelectFirstChannel();
          },
          onError: (e) {
            if (kDebugMode) {
              debugPrint('⚠ Channels query fallback: $e');
            }
            _firestore
                .collection('channels')
                .where('ownerId', isEqualTo: uid)
                .snapshots()
                .listen((snap) {
                  channels.value = snap.docs
                      .map((d) => Channel.fromDocumentSnapshot(d))
                      .toList();
                  _autoSelectFirstChannel();
                });
          },
        );
  }

  void _autoSelectFirstChannel() {
    if (selectedChannel.value == null && channels.isNotEmpty) {
      selectedChannel.value = channels.first;
    }
  }

  void selectChannel(Channel ch) => selectedChannel.value = ch;

  // Ã¢â€â‚¬Ã¢â€â‚¬ Poll management Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  void setPollType(PollType type) {
    pollType.value = type;
    if (type == PollType.yesNo) {
      pollOptions.clear();
    } else if (pollOptions.length < 3) {
      pollOptions.assignAll(['', '', '']);
    }
  }

  void updateQuestion(String text) => pollQuestion.value = text;

  void updateOption(int index, String text) {
    if (index >= 0 && index < pollOptions.length) pollOptions[index] = text;
  }

  void addOption() {
    if (pollOptions.length < 5) pollOptions.add('');
  }

  void removeOption(int index) {
    if (pollOptions.length > 3 && index >= 0 && index < pollOptions.length) {
      pollOptions.removeAt(index);
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Can publish Ã¢â‚¬â€ reactive check Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  bool get canPublish =>
      pollQuestion.value.trim().isNotEmpty &&
      selectedChannel.value != null &&
      !isUploading.value;

  // Ã¢â€â‚¬Ã¢â€â‚¬ Publish Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Future<void> publishPoll() async {
    if (pollQuestion.value.trim().isEmpty) {
      AppSnackbar.show(
        'Missing Question',
        'Please enter a poll question.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.colors.textSecondary,
        colorText: AppTheme.colors.textPrimary,
      );
      return;
    }
    if (selectedChannel.value == null) {
      AppSnackbar.show(
        'No Channel',
        'Please select a channel first.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.colors.textSecondary,
        colorText: AppTheme.colors.textPrimary,
      );
      return;
    }

    if (selectedChannel.value!.status != ChannelStatus.active) {
      String message = 'Your channel is not active.';
      if (selectedChannel.value!.status == ChannelStatus.underReview) {
        message = 'Your channel details are currently under review by Gemini AI. You can create polls once approved.';
      } else if (selectedChannel.value!.status == ChannelStatus.verificationRejected) {
        message = selectedChannel.value!.moderationReason != null && selectedChannel.value!.moderationReason!.isNotEmpty
            ? 'Branding Rejected: ${selectedChannel.value!.moderationReason!}'
            : 'Your channel details were rejected by Gemini AI. Please update your channel details in customization to re-verify.';
      } else if (selectedChannel.value!.status == ChannelStatus.verificationPending) {
        message = 'Your channel is currently verification pending. You can create polls once your branding is verified.';
      } else if (selectedChannel.value!.status == ChannelStatus.suspended) {
        message = 'Your channel is suspended. Publishing is disabled.';
      }
      AppSnackbar.show(
        'Verification Required',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.colors.textSecondary,
        colorText: AppTheme.colors.textPrimary,
      );
      return;
    }

    // Validate question text
    final qResult = await validateContent(
      pollQuestion.value,
      fieldName: 'Poll question',
    );
    if (!qResult.isValid) {
      AppSnackbar.show(
        'Content Issue',
        qResult.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.colors.textSecondary,
        colorText: AppTheme.colors.textPrimary,
      );
      return;
    }

    // Build options
    List<PollOption> options;
    if (pollType.value == PollType.yesNo) {
      options = [
        PollOption(id: 'yes', text: 'Yes'),
        PollOption(id: 'no', text: 'No'),
      ];
    } else {
      final nonEmpty = pollOptions.where((o) => o.trim().isNotEmpty).toList();
      if (nonEmpty.length < 2) {
        AppSnackbar.show(
          'Need Options',
          'Please provide at least 2 options.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.colors.textSecondary,
          colorText: AppTheme.colors.textPrimary,
        );
        return;
      }
      for (final opt in nonEmpty) {
        final r = await validateContent(opt, fieldName: 'Poll option');
        if (!r.isValid) {
          AppSnackbar.show(
            'Content Issue',
            r.message,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppTheme.colors.textSecondary,
            colorText: AppTheme.colors.textPrimary,
          );
          return;
        }
      }
      options = nonEmpty
          .asMap()
          .entries
          .map((e) => PollOption(id: 'opt_${e.key}', text: e.value.trim()))
          .toList();
    }

    DateTime? expiresAt;
    if (pollDurationDays.value != null) {
      expiresAt = DateTime.now().add(Duration(days: pollDurationDays.value!));
    }

    final poll = PollModel(
      question: pollQuestion.value.trim(),
      type: pollType.value,
      options: options,
      expiresAt: expiresAt,
    );

    isUploading.value = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to create a poll');
      }
      final channel = selectedChannel.value!;
      final docRef = _firestore.collection('Community').doc();

      await docRef.set({
        'id': docRef.id,
        'type': 'poll',
        'title': poll.question,
        'description': '',
        'images': <String>[],
        'image': '',
        'poll': poll.toMap(),
        'likes': 0,
        'likedby': [],
        'views': 0,
        'shares': [],
        'downloads': 0,
        'uploadedAt': Timestamp.now(),
        'ownerId': user.uid,
        'channelName': channel.channelName.trim(),
        'channelId': channel.channelId.trim(),
        'channelImage': channel.avatarUrl,
        'selectedCategory': 'Poll',
        'tags': <String>[],
        'processed': false,
        'visibility': selectedVisibility.value,
        'isKidFriendly': false,
      });

      AppSnackbar.show(
        'Poll Created! Ã°Å¸Å½â€°',
        'Your poll is now live.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.colors.background,
        colorText: AppTheme.colors.textPrimary,
        duration: const Duration(seconds: 3),
      );
      _reset();
      Future.delayed(const Duration(seconds: 1), () => Get.back());
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        AppSnackbar.show(
          'Permission Denied',
          'You do not have permission to create polls. Please check your account permissions.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.colors.textSecondary,
          colorText: AppTheme.colors.textPrimary,
          duration: const Duration(seconds: 4),
        );
      } else {
        AppSnackbar.show(
          'Firebase Error',
          e.message ?? 'Unknown Firebase error',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.colors.textSecondary,
          colorText: AppTheme.colors.textPrimary,
        );
      }
      if (kDebugMode) debugPrint('Ã°Å¸â€Â¥ Firebase error in publishPoll: $e');
    } catch (e, stackTrace) {
      AppSnackbar.show(
        'Error',
        'Failed to create poll. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.colors.textSecondary,
        colorText: AppTheme.colors.textPrimary,
      );
      if (kDebugMode) debugPrint('Ã¢ÂÅ’ publishPoll error: $e\n$stackTrace');
    } finally {
      isUploading.value = false;
    }
  }

  void _reset() {
    pollQuestion.value = '';
    pollType.value = PollType.yesNo;
    pollOptions.assignAll(['', '', '']);
    pollDurationDays.value = null;
  }
}
