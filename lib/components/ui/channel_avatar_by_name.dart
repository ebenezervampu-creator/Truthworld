import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/theme/app_theme.dart';

/// A reusable widget that fetches a channel's avatar image from Firestore
/// using its name. When tapped, it navigates to the channel's details page.
/// Includes an optimized static cache to prevent redundant Firestore lookups.
class ChannelAvatarByName extends StatelessWidget {
  ChannelAvatarByName({
    required this.channelName,
    super.key,
    this.radius = 20,
    this.showName = false,
    this.nameStyle,
    this.spacing = 8,
    this.onTap,
  }) {
    _resolveChannel();
  }

  final String channelName;
  final double radius;
  final bool showName;
  final TextStyle? nameStyle;
  final double spacing;
  final VoidCallback? onTap;

  static final Map<String, Channel?> _cache = {};
  static final Map<String, Future<Channel?>> _pendingQueries = {};
  final _channel = Rxn<Channel>();

  Future<void> _resolveChannel() async {
    final key = channelName.trim().toLowerCase();
    if (key.isEmpty) {
      _channel.value = null;
      return;
    }

    if (_cache.containsKey(key)) {
      _channel.value = _cache[key];
      return;
    }

    final channel = await _fetchChannelByName(channelName);
    _channel.value = channel;
  }

  static Future<Channel?> _fetchChannelByName(String name) {
    final key = name.trim().toLowerCase();
    if (_cache.containsKey(key)) {
      return Future.value(_cache[key]);
    }
    if (_pendingQueries.containsKey(key)) {
      return _pendingQueries[key]!;
    }

    final future = FirebaseFirestore.instance
        .collection(FirestoreCollections.channels)
        .where('nameLowercase', isEqualTo: key)
        .limit(1)
        .get()
        .then((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final channel = Channel.fromDocumentSnapshot(snapshot.docs.first);
            _cache[key] = channel;
            return channel;
          }
          return null;
        })
        .catchError((error) {
          debugPrint('Error fetching channel avatar by name ($name): $error');
          return null;
        })
        .whenComplete(() {
          _pendingQueries.remove(key);
        });

    _pendingQueries[key] = future;
    return future;
  }

  void _handleTap() {
    if (onTap != null) {
      onTap!();
      return;
    }

    if (_channel.value != null) {
      Get.toNamed(
        _channel.value!.channelRoute,
        arguments: {'channel': _channel.value},
      );
    } else {
      // Fallback: try loading channel by handle or query via loader screen
      final cleanName = channelName.trim();
      final routeName = cleanName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      Get.toNamed('/@$routeName');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final avatar = UserAvatar(
        radius: radius,
        photoUrl: _channel.value?.avatarUrl,
        displayName: channelName,
        backgroundColor: AppColors.bgSurfaceHover,
        textColor: AppColors.textPrimary,
      );

      final Widget content;
      if (showName) {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            avatar,
            SizedBox(width: spacing),
            Flexible(
              child: Text(
                channelName,
                style:
                    nameStyle ??
                    const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      } else {
        content = avatar;
      }

      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _handleTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    });
  }
}
