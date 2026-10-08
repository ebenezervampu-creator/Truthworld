import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dedicated high-contrast, production-grade audio-only visual stage for Miniplayer.
///
/// Renders an ambient backdrop, vinyl disc / album artwork, pulsating animated equalizer
/// bars, and high-contrast "AUDIO ONLY" indicator matching TruthWorld audio experience.
class MiniplayerAudioStage extends StatefulWidget {
  final MiniplayerController controller;
  final bool isPlaying;
  final String thumbnailUrl;
  final bool isCompact;

  const MiniplayerAudioStage({
    required this.controller,
    required this.isPlaying,
    required this.thumbnailUrl,
    this.isCompact = true,
    super.key,
  });

  @override
  State<MiniplayerAudioStage> createState() => _MiniplayerAudioStageState();
}

class _MiniplayerAudioStageState extends State<MiniplayerAudioStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.isPlaying) {
      _animController.repeat();
    }
  }

  @override
  void didUpdateWidget(MiniplayerAudioStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _animController.repeat();
      } else {
        _animController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = widget.isCompact;
    final thumb = widget.thumbnailUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Ambient Backdrop Glow ──────────────────────────────────────────
        AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            final t = _animController.value * 2 * pi;
            final glowOpacity = widget.isPlaying ? (0.12 + 0.06 * sin(t)) : 0.08;

            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: isCompact ? 1.0 : 1.3,
                  colors: [
                    AppColors.brand.withValues(alpha: glowOpacity),
                    const Color(0xFF14141B),
                    const Color(0xFF0C0C10),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            );
          },
        ),

        // ── Blurred Thumbnail Atmosphere ───────────────────────────────────
        if (thumb.isNotEmpty)
          Positioned.fill(
            child: Opacity(
              opacity: 0.18,
              child: CachedNetworkImage(
                imageUrl: thumb.replaceAll(' ', '%20'),
                fit: BoxFit.cover,
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),

        // ── Center Audio Visualizer Stage ──────────────────────────────────
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 24,
              vertical: isCompact ? 8 : 16,
            ),
            child: isCompact
                ? _buildCompactStage(thumb)
                : _buildExpandedStage(thumb),
          ),
        ),

        // ── Top-Right High-Contrast Audio Only Badge ──────────────────────
        Positioned(
          top: isCompact ? 8 : 14,
          right: isCompact ? 8 : 14,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 7 : 10,
              vertical: isCompact ? 3 : 5,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.brand.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.headphones_rounded,
                  color: AppColors.textPrimary,
                  size: 11,
                ),
                const SizedBox(width: 4),
                Text(
                  'AUDIO ONLY',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: isCompact ? 9 : 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStage(String thumb) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Rounded Album Art / Disc
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.bgSurface,
            border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: thumb.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: thumb.replaceAll(' ', '%20'),
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const Icon(
                    Icons.music_note_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                )
              : const Icon(
                  Icons.music_note_rounded,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
        ),
        const SizedBox(width: 14),

        // Animated Equalizer Frequency Bars
        _AnimatedEqualizer(
          animation: _animController,
          isPlaying: widget.isPlaying,
          barCount: 5,
          maxHeight: 24,
        ),
      ],
    );
  }

  Widget _buildExpandedStage(String thumb) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : 200.0;
        final discSize = (availableHeight * 0.52).clamp(50.0, 130.0);
        final spacing = (availableHeight * 0.08).clamp(6.0, 20.0);
        final eqHeight = (availableHeight * 0.16).clamp(16.0, 36.0);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Elevated Vinyl / Album Art
            Container(
              width: discSize,
              height: discSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bgSurface,
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: thumb.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: thumb.replaceAll(' ', '%20'),
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Icon(
                        Icons.music_note_rounded,
                        color: AppColors.textPrimary,
                        size: discSize * 0.38,
                      ),
                    )
                  : Icon(
                      Icons.music_note_rounded,
                      color: AppColors.textPrimary,
                      size: discSize * 0.38,
                    ),
            ),
            SizedBox(height: spacing),

            // Large Animated Equalizer Bars
            _AnimatedEqualizer(
              animation: _animController,
              isPlaying: widget.isPlaying,
              barCount: 7,
              maxHeight: eqHeight,
            ),
          ],
        );
      },
    );
  }
}

/// Dynamic Animated Equalizer Bars reacting rhythmically to animation controller.
class _AnimatedEqualizer extends StatelessWidget {
  final Animation<double> animation;
  final bool isPlaying;
  final int barCount;
  final double maxHeight;

  const _AnimatedEqualizer({
    required this.animation,
    required this.isPlaying,
    required this.barCount,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value * 2 * pi;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(barCount, (i) {
            final phase = i * (pi / (barCount / 2));
            final dynamicFraction =
                isPlaying ? (0.3 + 0.7 * (sin(t + phase).abs())) : 0.25;
            final h = (maxHeight * dynamicFraction).clamp(4.0, maxHeight);

            return Container(
              width: 3.5,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(
                  alpha: isPlaying ? (0.6 + 0.4 * dynamicFraction) : 0.4,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
