import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_models.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_navigation_handler.dart';

/// Controller managing async avatar resolution with in-memory & disk caching.
class DynamicAvatarController extends BaseController {
  DynamicAvatarController({
    required this.item,
    required this.initialAvatarUrl,
  });

  final UnifiedNotificationItem item;
  final String initialAvatarUrl;

  final RxString avatarUrl = ''.obs;
  final RxBool rxIsLoading = false.obs;

  // Persistent local cache to eliminate repeat Firestore lookups
  static final _storage = GetStorage('AvatarCache');
  static final Map<String, String> _avatarCache = {};
  static final Map<String, Future<String>> _avatarFetchFutures = {};

  @override
  void onInit() {
    super.onInit();
    avatarUrl.value = initialAvatarUrl;
    if (avatarUrl.value.isEmpty) {
      fetchAvatarIfNeeded();
    }
  }

  void updateInitialAvatarUrl(String url) {
    if (avatarUrl.value != url) {
      avatarUrl.value = url;
      if (avatarUrl.value.isEmpty) {
        fetchAvatarIfNeeded();
      }
    }
  }

  Future<void> fetchAvatarIfNeeded() async {
    final alert = item.alert;
    if (alert == null) return;
    final metadata = alert.metadata;
    if (metadata == null) return;

    // Check action performer's ID first, instead of the video owner's channelId
    final targetId = metadata['subscriberId'] as String? ??
        metadata['likerId'] as String? ??
        metadata['commentAuthorId'] as String? ??
        metadata['senderUserId'] as String? ??
        metadata['channelId'] as String? ??
        '';

    if (targetId.isEmpty) return;

    // 1. In-memory Cache lookup
    if (_avatarCache.containsKey(targetId)) {
      avatarUrl.value = _avatarCache[targetId]!;
      return;
    }

    // 2. Persistent Disk Cache lookup (O(1) local read, 0ms latency)
    final cachedUrl = _storage.read(targetId);
    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      _avatarCache[targetId] = cachedUrl;
      avatarUrl.value = cachedUrl;
      return;
    }

    // 3. Fallback: Firestore async resolve (non-blocking)
    rxIsLoading.value = true;

    try {
      Future<String> fetchFuture;
      if (_avatarFetchFutures.containsKey(targetId)) {
        fetchFuture = _avatarFetchFutures[targetId]!;
      } else {
        fetchFuture = _performFetch(targetId);
        _avatarFetchFutures[targetId] = fetchFuture;
      }

      final url = await fetchFuture;
      _avatarFetchFutures.remove(targetId);

      if (url.isNotEmpty) {
        _avatarCache[targetId] = url;
        _storage.write(targetId, url);
      }

      avatarUrl.value = url;
      rxIsLoading.value = false;

      // Update Firestore document metadata so we never hit this fallback again
      final currentMetaAvatar = metadata['userAvatar'] as String? ??
          metadata['avatarUrl'] as String? ??
          '';
      if (currentMetaAvatar.isEmpty && url.isNotEmpty) {
        unawaited(() async {
          try {
            final updatedMetadata = Map<String, dynamic>.from(metadata);
            updatedMetadata['userAvatar'] = url;
            await FirebaseFirestore.instance
                .collection('user_notifications')
                .doc(alert.id)
                .update({'metadata': updatedMetadata});
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'DynamicAvatarController.metadata',
            );
          }
        }());
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'DynamicAvatarController.fetchAvatar',
      );
    } finally {
      rxIsLoading.value = false;
    }
  }

  Future<String> _performFetch(String targetId) async {
    try {
      // 1. Check user document first (performer of action)
      final userDoc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(targetId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          final photo = userData['avatarUrl'] as String? ??
              userData['photoURL'] as String? ??
              userData['photoUrl'] as String? ??
              '';
          if (photo.isNotEmpty) return photo;

          final userChannelId = userData['channelId'] as String?;
          if (userChannelId != null && userChannelId.isNotEmpty) {
            final userChannelDoc = await FirebaseFirestore.instance
                .collection(FirestoreCollections.channels)
                .doc(userChannelId)
                .get();
            if (userChannelDoc.exists) {
              final chanData = userChannelDoc.data();
              if (chanData != null) {
                final chanPhoto = chanData['avatarUrl'] as String? ??
                    chanData['channelImage'] as String? ??
                    (chanData['profile'] as Map<String, dynamic>?)?['photoUrl']
                        as String? ??
                    '';
                if (chanPhoto.isNotEmpty) return chanPhoto;
              }
            }
          }
        }
      }

      // 2. Check channel document
      final channelDoc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .doc(targetId)
          .get();

      if (channelDoc.exists) {
        final data = channelDoc.data();
        if (data != null) {
          final photo = data['avatarUrl'] as String? ??
              data['channelImage'] as String? ??
              (data['profile'] as Map<String, dynamic>?)?['photoUrl']
                  as String? ??
              '';
          if (photo.isNotEmpty) return photo;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'DynamicAvatarController._performFetch',
      );
    }

    return '';
  }

  @override
  void onClose() {
    avatarUrl.value = '';
    rxIsLoading.value = false;
    super.onClose();
  }
}

/// Renders cached remote network avatar with fallback colored initial placeholder.
class DynamicNotificationAvatar extends StatelessWidget {
  const DynamicNotificationAvatar({
    required this.item,
    required this.initialAvatarUrl,
    required this.displayName,
    super.key,
  });

  final UnifiedNotificationItem item;
  final String initialAvatarUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DynamicAvatarController>(
      init: DynamicAvatarController(
        item: item,
        initialAvatarUrl: initialAvatarUrl,
      ),
      tag: item.video?.id ?? item.alert?.id ?? displayName,
      builder: (controller) {
        return Obx(() {
          final url = controller.avatarUrl.value;
          if (url.isNotEmpty) {
            return Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF272727),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildPlaceholderAvatar(),
                errorWidget: (context, url, error) => _buildPlaceholderAvatar(),
              ),
            );
          }

          return _buildPlaceholderAvatar();
        });
      },
    );
  }

  Widget _buildPlaceholderAvatar() {
    final cleanName = displayName.trim().replaceAll('@', '');
    final lowerName = cleanName.toLowerCase();
    final alertType = item.alert?.type.toLowerCase() ?? '';

    final isTruthWorld = lowerName == 'truthworld' ||
        lowerName.contains('truthworld') ||
        alertType == 'system' ||
        alertType == 'announcement' ||
        alertType == 'admin';

    if (isTruthWorld) {
      return const AppLogo(size: 40);
    }

    final initial = cleanName.isNotEmpty ? cleanName[0].toUpperCase() : '';
    final bgColor = NotificationNavigationHandler.getAvatarColor(cleanName);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: initial.isNotEmpty
          ? Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.0,
              ),
            )
          : const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 22,
            ),
    );
  }
}
