import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 9: Prism Compact Disc
/// Precision audio compact disc with metallic mirror finish, subtle specular sheen,
/// circular album artwork hub, and sleek frosted acrylic jewel case aesthetic.
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
        : 'Digital Audio Master';
    final thumb = widget.video?.thumbnailUrl ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark Obsidian Canvas
        const ColoredBox(color: Color(0xFF090A0D)),

        // Soft Studio Vignette
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.95,
              colors: [
                const Color(0xFF1E293B).withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.75),
                const Color(0xFF090A0D),
              ],
              stops: const [0.0, 0.65, 1.0],
            ),
          ),
        ),

        // Center Stage CD & Typography
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 440;
                final cdSize = isNarrow ? 120.0 : 136.0;

                final cdWidget = RotationTransition(
                  turns: _cdSpinController,
                  child: Container(
                    width: cdSize,
                    height: cdSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          Color(0xFF181A20),
                          Color(0xFF262A35),
                          Color(0xFF181A20),
                          Color(0xFF2E3340),
                          Color(0xFF181A20),
                        ],
                        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Dynamic Mirror Specular Sheen
                        CustomPaint(
                          size: Size(cdSize, cdSize),
                          painter: _CdSheenPainter(),
                        ),
                        // Inner Clear Data Track Ring
                        Container(
                          width: cdSize * 0.75,
                          height: cdSize * 0.75,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        // Center Circular Artwork Label
                        Container(
                          width: cdSize * 0.42,
                          height: cdSize * 0.42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1.2,
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
                        // Transparent Spindle Hole
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF090A0D),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                final metaWidget = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isNarrow
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    // Frosted Digital Audio Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.disc_full_rounded,
                            size: 11,
                            color: widget.isPlaying
                                ? const Color(0xFFE2E8F0)
                                : Colors.white38,
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'COMPACT DISC',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: isNarrow ? TextAlign.center : TextAlign.start,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      channel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: isNarrow ? TextAlign.center : TextAlign.start,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.isPlaying ? 'PCM 44.1 kHz / 16-BIT' : 'DISC PAUSED',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      cdWidget,
                      const SizedBox(height: 14),
                      Flexible(child: metaWidget),
                    ],
                  );
                }

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    cdWidget,
                    const SizedBox(width: 24),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: metaWidget,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _cdCenter() {
    return Container(
      color: const Color(0xFF1E2028),
      child: const Center(
        child: Icon(
          Icons.album_rounded,
          size: 18,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _CdSheenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final sheenPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.08),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius - 2, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
