import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/community/presentation/controllers/upload/community_post_upload_state_base.dart';

/// Mixin handling channel loading, fallback queries, and topic discovery.
mixin CommunityPostChannelTopicMixin on CommunityPostUploadStateBase {
  Map<String, String>? getChannelMetadata(String channelId) {
    for (final ch in channels) {
      if (ch.channelId == channelId || ch.id == channelId) {
        return {
          'name': ch.channelName,
          'handle': ch.handle,
          'avatarUrl': ch.avatarUrl,
        };
      }
    }
    return null;
  }

  @override
  Future<void> fetchAvailableTopics() async {
    try {
      isTopicsLoading.value = true;
      final topics =
          await topicRepository.fetchTopics(category: 'all', limit: 50);
      availableTopics.value = topics;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CommunityPostUploadController.fetchAvailableTopics',
      );
    } finally {
      isTopicsLoading.value = false;
    }
  }

  /// Fetch channels for community post uploads
  @override
  Future<void> fetchChannelsForCommunity() async {
    try {
      final user = auth.currentUser;
      if (user == null) {
        channelsError.value = 'User not authenticated';
        debugPrint('❌ Community: User not authenticated');
        return;
      }

      isChannelsLoading.value = true;
      channelsError.value = '';

      firestore
          .collection(FirestoreCollections.channels)
          .where('ownerId', isEqualTo: user.uid)
          .get()
          .then((snapshot) async {
            var loaded = snapshot.docs
                .map(Channel.fromDocumentSnapshot)
                .where((c) => c.status != ChannelStatus.deleted)
                .toList();

            // Fallback 1: Query by userId if ownerId returned 0
            if (loaded.isEmpty) {
              try {
                final userSnap = await firestore
                    .collection(FirestoreCollections.channels)
                    .where('userId', isEqualTo: user.uid)
                    .get();
                loaded = userSnap.docs
                    .map(Channel.fromDocumentSnapshot)
                    .where((c) => c.status != ChannelStatus.deleted)
                    .toList();
              } catch (e, stackTrace) {
                ErrorHandler.log(
                  e,
                  stackTrace: stackTrace,
                  tag: 'CommunityPostUploadController.fetchChannelsFallback1',
                );
              }
            }

            // Fallback 2: Check user document for channelId reference
            if (loaded.isEmpty) {
              try {
                final userDoc = await firestore
                    .collection(FirestoreCollections.users)
                    .doc(user.uid)
                    .get();
                final chId = userDoc.data()?['channelId'] as String?;
                if (chId != null && chId.isNotEmpty) {
                  final chDoc = await firestore
                      .collection(FirestoreCollections.channels)
                      .doc(chId)
                      .get();
                  if (chDoc.exists && chDoc.data() != null) {
                    final ch = Channel.fromDocumentSnapshot(chDoc);
                    if (ch.status != ChannelStatus.deleted) {
                      loaded = [ch];
                    }
                  }
                }
              } catch (e, stackTrace) {
                ErrorHandler.log(
                  e,
                  stackTrace: stackTrace,
                  tag: 'CommunityPostUploadController.fetchChannelsFallback2',
                );
              }
            }

            // Fallback 3: In-memory AuthService channel
            if (loaded.isEmpty && AuthService.to.userChannel != null) {
              final authCh = AuthService.to.userChannel!;
              if (authCh.status != ChannelStatus.deleted) {
                loaded = [authCh];
              }
            }

            channels.value = loaded;
            isChannelsLoading.value = false;
            channelsError.value = '';

            debugPrint('✅ Community channels loaded: ${channels.length}');

            if (channels.isNotEmpty && selectedChannel.value == null) {
              selectedChannel.value = channels.first;
              debugPrint(
                '✅ Auto-selected community channel: ${selectedChannel.value!.channelName}',
              );
            }
          })
          .catchError((error) {
            isChannelsLoading.value = false;
            channelsError.value = 'Unable to load channels. Please try again.';
            ErrorHandler.log(error);
            AppSnackbar.error(
              'Unable to load channels. Please try again.',
              onAction: fetchChannelsForCommunity,
              actionLabel: 'Retry',
            );
          });
    } catch (e) {
      isChannelsLoading.value = false;
      channelsError.value = 'Unable to load channels. Please try again.';
      ErrorHandler.log(e);
    }
  }

  /// Select a channel for community post
  void selectChannelForCommunity(Channel channel) {
    if (channel.id.isEmpty) {
      ErrorHandler.log('Invalid community channel selection');
      AppSnackbar.warning('Please select a valid channel.');
      return;
    }

    selectedChannel.value = channel;
    debugPrint('✅ Community channel selected: ${channel.channelName}');
  }

  /// Select a channel for the post
  void selectChannel(Channel? channel) {
    selectedChannel.value = channel;
  }
}
