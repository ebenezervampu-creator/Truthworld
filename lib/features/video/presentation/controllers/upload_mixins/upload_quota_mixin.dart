import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_controller_base.dart';

mixin UploadQuotaMixin on UploadControllerBase {
  /// Human-readable string for today's uploaded duration (e.g., "15m 00s")
  String get todayUploadedDurationFormatted =>
      ContentValidationMixin.formatDurationMinutesSeconds(
        todayUploadedDurationSeconds.value,
      );

  /// Human-readable string for remaining daily duration (e.g., "5m 00s")
  String get remainingDailyDurationFormatted =>
      ContentValidationMixin.formatDurationMinutesSeconds(
        remainingDailyDurationSeconds.value,
      );

  /// Progress ratio (0.0 to 1.0) of today's 10-minute daily limit used
  double get dailyQuotaUsedRatio {
    final limit = selectedChannel.value?.maxDailyVideoDurationSeconds.toDouble() ?? 600.0;
    return (todayUploadedDurationSeconds.value / limit).clamp(0.0, 1.0);
  }

  /// Fetches the total duration in seconds of videos uploaded today by the given channel
  @override
  Future<int> getTodayUploadedDurationSeconds(String channelId) async {
    if (channelId.trim().isEmpty) return 0;

    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      final snapshot = await firestore
          .collection('videos')
          .where('channelId', isEqualTo: channelId)
          .get();

      var totalDurationSeconds = 0;
      for (final doc in snapshot.docs) {
        // Do not double count the active draft currently being resumed/edited
        if (currentVideoId != null && doc.id == currentVideoId) continue;

        final data = doc.data();
        final status = (data['status'] as String?)?.toLowerCase();
        // Exclude deleted, rejected, uncompleted drafts, and uploading placeholders
        if (status == 'deleted' ||
            status == 'rejected' ||
            status == 'draft' ||
            status == 'uploading') {
          continue;
        }

        final rawDate =
            data['uploadedAt'] ?? data['publishedAt'] ?? data['createdAt'];
        if (rawDate == null) continue;

        final uploadTime = TimestampUtils.parse(rawDate).toDate();
        if (uploadTime.isAfter(startOfToday) ||
            uploadTime.isAtSameMomentAs(startOfToday)) {
          var durSecs = 0;
          if (data['durationMs'] != null) {
            final ms = (data['durationMs'] as num).toInt();
            durSecs = (ms / 1000).round();
          } else if (data['duration'] != null) {
            final raw = (data['duration'] as num).toInt();
            durSecs = raw > 86400 ? (raw / 1000).round() : raw;
          }

          // Legacy correction: If an old video doc got assigned the 600s default without durationMs
          if (durSecs == 600 &&
              data['durationMs'] == null &&
              data['codec'] == 'unknown') {
            final fileSize = (data['fileSize'] as num?)?.toInt() ?? 0;
            if (fileSize > 0) {
              // Estimate duration based on standard 1080p/720p bitrate (~1.5 MB/sec)
              durSecs =
                  (fileSize / (1024 * 1024 * 1.5)).clamp(30, 300).round();
            } else {
              durSecs = 120; // 2 minutes safe fallback
            }
          }

          totalDurationSeconds += durSecs;
        }
      }
      return totalDurationSeconds;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UploadQuotaMixin.getTodayUploadedDurationSeconds',
      );
      return 0;
    }
  }

  /// Refreshes the daily upload quota for the selected channel
  @override
  Future<void> refreshDailyUploadQuota() async {
    final channel = selectedChannel.value;
    if (channel == null) return;

    if (channel.channelType != ChannelType.standard) {
      updateState((s) => s.copyWith(
            todayUploadedDurationSeconds: 0,
            remainingDailyDurationSeconds: 86400, // 24 hours
            isDailyLimitReached: false,
          ));
      return;
    }

    try {
      updateState((s) => s.copyWith(isQuotaLoading: true));
      final usedSeconds = await getTodayUploadedDurationSeconds(channel.id);
      final maxDaily = channel.maxDailyVideoDurationSeconds;
      final remaining = (maxDaily - usedSeconds).clamp(0, maxDaily);
      final limitReached = usedSeconds >= maxDaily;
      updateState((s) => s.copyWith(
            isQuotaLoading: false,
            todayUploadedDurationSeconds: usedSeconds,
            remainingDailyDurationSeconds: remaining,
            isDailyLimitReached: limitReached,
          ));
      debugPrint(
        '📊 [UploadController] Daily quota for ${channel.channelName}: ${usedSeconds}s / ${maxDaily}s used (${remaining}s remaining)',
      );
    } catch (e) {
      updateState((s) => s.copyWith(isQuotaLoading: false));
      rethrow;
    }
  }

  void selectChannel(Channel channel) {
    updateState((s) => s.copyWith(selectedChannel: channel));
    refreshDailyUploadQuota();
  }

  Future<void> fetchChannelsWithRetry() async {
    isChannelsLoading.value = true;
    channelsError.value = '';
    fetchChannels();
  }

  // Fetch channels with robust multi-tier fallback (ownerId, userId, user doc, in-memory)
  void fetchChannels() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      isChannelsLoading.value = false;
      channelsError.value = 'User not logged in';
      return;
    }

    debugPrint('🔍 Fetching channels for user: ${user.uid}');

    // Cancel existing subscription
    channelsSubscription?.cancel();

    channelsSubscription = firestore
        .collection('channels')
        .where('ownerId', isEqualTo: user.uid)
        .snapshots()
        .listen(
          (snapshot) async {
            debugPrint('✅ Channels loaded by ownerId: ${snapshot.docs.length}');

            var loadedChannels = snapshot.docs
                .map(Channel.fromDocumentSnapshot)
                .where((channel) => channel.status != ChannelStatus.deleted)
                .toList();

            // Fallback 1: Query by userId if ownerId returned 0 channels
            if (loadedChannels.isEmpty) {
              try {
                final userSnap = await firestore
                    .collection('channels')
                    .where('userId', isEqualTo: user.uid)
                    .get();
                loadedChannels = userSnap.docs
                    .map(Channel.fromDocumentSnapshot)
                    .where((channel) => channel.status != ChannelStatus.deleted)
                    .toList();
              } catch (e, stackTrace) {
                ErrorHandler.log(
                  e,
                  stackTrace: stackTrace,
                  tag: 'UploadQuotaMixin.fetchChannelsFallbackUserId',
                );
              }
            }

            // Fallback 2: Check user document for channelId reference
            if (loadedChannels.isEmpty) {
              try {
                final userDoc =
                    await firestore.collection('users').doc(user.uid).get();
                final chId = userDoc.data()?['channelId'] as String?;
                if (chId != null && chId.isNotEmpty) {
                  final chDoc =
                      await firestore.collection('channels').doc(chId).get();
                  if (chDoc.exists && chDoc.data() != null) {
                    final ch = Channel.fromDocumentSnapshot(chDoc);
                    if (ch.status != ChannelStatus.deleted) {
                      loadedChannels = [ch];
                    }
                  }
                }
              } catch (e, stackTrace) {
                ErrorHandler.log(
                  e,
                  stackTrace: stackTrace,
                  tag: 'UploadQuotaMixin.fetchChannelsFallbackUserDoc',
                );
              }
            }

            // Fallback 3: In-memory AuthService channel
            if (loadedChannels.isEmpty && AuthService.to.userChannel != null) {
              final authCh = AuthService.to.userChannel!;
              if (authCh.status != ChannelStatus.deleted) {
                loadedChannels = [authCh];
              }
            }

            channels.value = loadedChannels;
            isChannelsLoading.value = false;
            channelsError.value = '';

            // Auto-select first channel if none selected or if selected channel changed
            if (channels.isNotEmpty) {
              if (selectedChannel.value == null ||
                  !channels.any((c) => c.id == selectedChannel.value!.id)) {
                selectedChannel.value = channels.first;
                refreshDailyUploadQuota();
                debugPrint(
                  'Auto-selected channel: ${channels.first.channelName}',
                );
              }
            }
          },
          onError: (error, stackTrace) {
            ErrorHandler.log(
              error,
              stackTrace: stackTrace,
              tag: 'UploadController.fetchChannels',
            );
            if (AuthService.to.userChannel != null) {
              channels.value = [AuthService.to.userChannel!];
              selectedChannel.value = AuthService.to.userChannel;
              isChannelsLoading.value = false;
              channelsError.value = '';
            } else {
              isChannelsLoading.value = false;
              channelsError.value = 'Unable to load channels. Please try again.';
            }
          },
        );
  }
}
