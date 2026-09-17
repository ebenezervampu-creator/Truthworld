import 'dart:io' as io;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Preview card displaying video thumbnail, title, channel avatar, visibility, and playlist.
class CreateContentPublishPreview extends StatelessWidget {
  const CreateContentPublishPreview({
    super.key,
    this.isDark = true,
    this.uploadController,
    this.playlistController,
    this.titleController,
    this.title,
    this.getPlaylistName,
  });

  final bool isDark;
  final UploadController? uploadController;
  final PlaylistController? playlistController;
  final TextEditingController? titleController;
  final String? title;
  final String Function(String id)? getPlaylistName;

  UploadController get _controller =>
      uploadController ?? Get.find<UploadController>();

  PlaylistController get _playlists =>
      playlistController ?? Get.find<PlaylistController>();

  String _resolvePlaylistName(String id) {
    if (getPlaylistName != null) {
      return getPlaylistName!(id);
    }
    if (id.isEmpty) return 'None';
    final playlist = _playlists.publicPlaylists.firstWhereOrNull(
      (p) => p.id == id,
    );
    return playlist?.playlistName ?? 'Selected Playlist';
  }

  Color _getVisibilityColor(String visibility) {
    switch (visibility.toLowerCase()) {
      case 'public':
        return const Color(0xFF10B981);
      case 'unlisted':
        return const Color(0xFFF59E0B);
      case 'private':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6366F1);
    }
  }

  IconData _getVisibilityIcon(String visibility) {
    switch (visibility.toLowerCase()) {
      case 'public':
        return Icons.public_rounded;
      case 'private':
        return Icons.lock_rounded;
      case 'members':
        return Icons.group_rounded;
      case 'subscribersonly':
        return Icons.people_alt_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Widget _buildTitle(BuildContext context) {
    if (titleController != null) {
      return ValueListenableBuilder<TextEditingValue>(
        valueListenable: titleController!,
        builder: (context, value, _) {
          final displayText = value.text.isNotEmpty
              ? value.text
              : (title?.isNotEmpty == true ? title! : 'Untitled Video');
          return Text(
            displayText,
            style: context.themeTypography.body.copyWith(
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
        },
      );
    }

    final displayText =
        (title != null && title!.isNotEmpty) ? title! : 'Untitled Video';
    return Text(
      displayText,
      style: context.themeTypography.body.copyWith(
        fontWeight: FontWeight.w500,
        color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
        height: 1.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.visibility_rounded,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Preview',
                style: context.themeTypography.headline.copyWith(
                  color: isDark
                      ? AppColors.textPrimary
                      : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail preview
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 160,
                  height: 90,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0D1117)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Obx(() {
                    final image = _controller.pickedImage.value;
                    if (image != null) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(
                            image: (kIsWeb && image.bytes != null)
                                ? MemoryImage(image.bytes!) as ImageProvider
                                : (image.path != null
                                    ? FileImage(io.File(image.path!))
                                    : (image.bytes != null
                                        ? MemoryImage(image.bytes!)
                                        : const AssetImage(
                                            'assets/images/logo.png',
                                          ) as ImageProvider)),
                            fit: BoxFit.cover,
                          ),
                          // Duration badge
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgPage.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '00:00',
                                style: context.themeTypography.label.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 32,
                        color: isDark
                            ? AppColors.textPrimary.withValues(alpha: 0.2)
                            : const Color(0xFFD1D5DB),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 16),
              // Video info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitle(context),
                    const SizedBox(height: 10),
                    Obx(() {
                      final channel = _controller.selectedChannel.value;
                      return Row(
                        children: [
                          if (channel != null) ...[
                            CachedNetworkImage(
                              imageUrl: channel.avatarUrl,
                              imageBuilder: (context, imageProvider) =>
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundImage: imageProvider,
                                  ),
                              placeholder: (context, url) => const CircleAvatar(
                                radius: 10,
                                backgroundColor: AppColors.textSecondary,
                                child: Icon(
                                  Icons.person,
                                  size: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  const CircleAvatar(
                                    radius: 10,
                                    backgroundColor: AppColors.textSecondary,
                                    child: Icon(
                                      Icons.person,
                                      size: 10,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              channel?.channelName ?? 'No channel',
                              style: context.themeTypography.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 10),
                    Obx(() {
                      final visibility =
                          _controller.selectedVisibility.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _getVisibilityColor(
                            visibility,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getVisibilityIcon(
                                visibility,
                              ),
                              size: 14,
                              color: _getVisibilityColor(
                                visibility,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              visibility,
                              style: context.themeTypography.bodySmall.copyWith(
                                color: _getVisibilityColor(
                                  visibility,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Obx(() {
                      final playlistId =
                          _controller.selectedPlaylist.value;
                      if (playlistId.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.playlist_play_rounded,
                              size: 16,
                              color: Color(0xFF3B82F6),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _resolvePlaylistName(playlistId),
                                style: context.themeTypography.bodySmall
                                    .copyWith(
                                      color: isDark
                                          ? AppColors.textSecondary
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
