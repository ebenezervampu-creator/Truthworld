import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 9: Holographic CD Jewel Case
/// Iridescent prism rainbow sheen, spinning compact disc, and frosted glass jewel case.
class HolographicCdTheme extends StatefulWidget {
  const HolographicCdTheme({
    required this.isPlaying,
    this.video,
    super.key,
  });

  final bool isPlaying;
  final Video? video;

  @override
  State<HolographicCdTheme> createState() => _HolographicCdThemeState();
}

class _HolographicCdThemeState extends State<HolographicCdTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cdSpinController;

  @override
  void initState() {
    super.initState();
    _cdSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (widget.isPlaying) {
      _cdSpinController.repeat();
    }
  }

  @override
  void didUpdateWidget(HolographicCdTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _cdSpinController.repeat();
      } else {
        _cdSpinController.stop();
      }
    }
  }

  @override
  void dispose() {
    _cdSpinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video?.title.isNotEmpty == true
        ? widget.video!.title
        : 'TruthWorld Compact Disc';
    final channel = widget.video?.channelName.isNotEmpty == true
        ? widget.video!.channelName
        : 'Digital Audio';
    final thumb = widget.video?.thumbnailUrl ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark Obsidian Background
        const ColoredBox(color: Color(0xFF0A0C10)),

        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Spinning Holographic CD
                RotationTransition(
                  turns: _cdSpinController,
                  child: Container(
                    width: 115,
                    height: 115,
                    decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(
                      colors: [
                        Color(0xFFE2E8F0),
                        Color(0xFF93C5FD),
                        Color(0xFFF472B6),
                        Color(0xFFFBBF24),
                        Color(0xFF34D399),
                        Color(0xFF93C5FD),
                        Color(0xFFE2E8F0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Inner Mirror Luster
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      // Center Artwork Ring
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: thumb.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: thumb,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => _cdCenter(),
                                  placeholder: (_, _) => _cdCenter(),
                                )
                              : _cdCenter(),
                        ),
                      ),
                      // Center Spindle Hole (See-through)
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0A0C10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Jewel Case Metadata Card
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Text(
                          'CD DIGITAL AUDIO',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        channel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.isPlaying ? 'PCM 44.1kHz • 16-Bit' : 'Laser Paused',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  }

  Widget _cdCenter() {
    return const ColoredBox(
      color: Color(0xFF334155),
      child: Center(
        child: Icon(Icons.disc_full_rounded, color: Colors.white70, size: 28),
      ),
    );
  }
}
