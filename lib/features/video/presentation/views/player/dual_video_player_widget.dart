import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 🪙 DUAL VIDEO "COIN SPLIT" PLAYER WIDGET
///
/// Displays two videos side-by-side (Desktop/Tablet) or stacked (Mobile).
/// Video A = Perspective A (Current Video)
/// Video B = Perspective B (Opposite Perspective)
///
/// Allows 1-tap audio focus toggle between Perspective A and B.
class DualVideoPlayerWidget extends StatefulWidget {
  final Video videoA;
  final Video videoB;
  final VoidCallback onClose;

  const DualVideoPlayerWidget({
    required this.videoA, required this.videoB, required this.onClose, super.key,
  });

  @override
  State<DualVideoPlayerWidget> createState() => _DualVideoPlayerWidgetState();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DualVideoPlayerWidget &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          videoA == other.videoA &&
          videoB == other.videoB;

  @override
  int get hashCode => Object.hash(key, videoA, videoB);
}

class _DualVideoPlayerWidgetState extends State<DualVideoPlayerWidget> {
  final RxInt activeAudioIndex = 0.obs; // 0 = Video A, 1 = Video B

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF9C27B0).withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              // ── Header Bar ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.published_with_changes_rounded,
                      color: Colors.white, // RULE ENFORCEMENT: White icon
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '🪙 Dual Perspective Debate (Coin Split)',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      onPressed: widget.onClose,
                      tooltip: 'Exit Split Screen',
                    ),
                  ],
                ),
              ),

              // ── Split Screen Player Container ────────────────────────────
              Expanded(
                child: isMobile
                    ? Column(
                        children: [
                          Expanded(
                            child: _buildVideoCard(
                              widget.videoA,
                              'Perspective A',
                              0,
                            ),
                          ),
                          const Divider(height: 2, color: Color(0xFF9C27B0)),
                          Expanded(
                            child: _buildVideoCard(
                              widget.videoB,
                              'Perspective B (Opposite)',
                              1,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _buildVideoCard(
                              widget.videoA,
                              'Perspective A',
                              0,
                            ),
                          ),
                          const VerticalDivider(
                            width: 2,
                            color: Color(0xFF9C27B0),
                          ),
                          Expanded(
                            child: _buildVideoCard(
                              widget.videoB,
                              'Perspective B (Opposite)',
                              1,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoCard(Video video, String tagLabel, int index) {
    return Obx(() {
      final isActiveAudio = activeAudioIndex.value == index;

      return InkWell(
        onTap: () {
          activeAudioIndex.value = index;
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail background
            CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Container(color: Colors.black45),
            ),

            // Dim overlay
            Container(
              color: isActiveAudio
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.6),
            ),

          // Tag Label (Top Left)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: index == 0 ? Colors.black87 : const Color(0xFF9C27B0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white30),
              ),
              child: Text(
                tagLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),

          // Audio Focus Indicator (Top Right)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActiveAudio ? const Color(0xFF4CAF50) : Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActiveAudio
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: Colors.white, // RULE ENFORCEMENT: White icon
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isActiveAudio ? 'Audio Active' : 'Tap to Listen',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center Play Button & Title (Bottom)
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    shadows: [Shadow(blurRadius: 4)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  video.channelName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    });
  }
}
