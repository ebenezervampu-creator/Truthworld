import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_video_player_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class MetadataRow {
  const MetadataRow(this.label, this.value);
  final String label;
  final String value;
}

// Backward compatibility alias
typedef _MetadataRow = MetadataRow;

/// GetX Video Player wrapper for admin queue inspection
class AdminVideoPlayer extends StatefulWidget {
  const AdminVideoPlayer({
    required this.url,
    super.key,
    this.videoData,
  });
  final String url;
  final Map<String, dynamic>? videoData;

  @override
  State<AdminVideoPlayer> createState() => _AdminVideoPlayerState();
}

class _AdminVideoPlayerState extends State<AdminVideoPlayer> {
  late String _tag;
  late AdminVideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    final videoId = widget.videoData?['id'] ?? widget.url;
    _tag = 'admin_player_$videoId';
    _controller = Get.put(
      AdminVideoPlayerController(widget.url, videoData: widget.videoData),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    Get.delete<AdminVideoPlayerController>(tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_controller.error.value != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 36,
                ),
                const SizedBox(height: 8),
                Text(
                  _controller.error.value!,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _controller.retry(),
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                  label: const Text(
                    'Retry',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bgSurfaceHover,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      if (!_controller.isPlayerInitialized.value || _controller.chewieCtrl == null) {
        return const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      }
      return Chewie(controller: _controller.chewieCtrl!);
    });
  }
}
