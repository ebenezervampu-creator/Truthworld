import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 2: Classic Vinyl Turntable
/// Audiophile-grade precision vinyl experience with micro-grooved matte obsidian disc,
/// rotating album art center label, and warm, refined analog aesthetic.
class RetroVinylTheme extends StatefulWidget {
  const RetroVinylTheme({
    required this.isPlaying,
    this.video,
    super.key,
  });

  final bool isPlaying;
  final Video? video;

  @override
  State<RetroVinylTheme> createState() => _RetroVinylThemeState();
}

class _RetroVinylThemeState extends State<RetroVinylTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8), // ~33⅓ RPM aesthetic
    );
    if (widget.isPlaying) {
      _spinController.repeat();
    }
  }

  @override
  void didUpdateWidget(RetroVinylTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _spinController.repeat();
      } else {
        _spinController.stop();
      }
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video?.title.isNotEmpty == true
        ? widget.video!.title
        : 'TruthWorld Vinyl Master';
    final channel = widget.video?.channelName.isNotEmpty == true
        ? widget.video!.channelName
        : 'Acoustic Master Series';
    final thumb = widget.video?.thumbnailUrl ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Warm Charcoal Studio Backdrop
        const ColoredBox(color: Color(0xFF0A0A0D)),

        // Soft Ambient Studio Light
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.95,
              colors: [
                const Color(0xFFD4AF37).withValues(alpha: 0.05), // Subtle titanium gold hint
                Colors.black.withValues(alpha: 0.7),
                const Color(0xFF0A0A0D),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        ),

        // Center Stage Vinyl Record + Metadata
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 440;
                final discSize = isNarrow ? 120.0 : 136.0;

                final discWidget = RotationTransition(
                  turns: _spinController,
                  child: Container(
                    width: discSize,
                    height: discSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0F0F12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.5,
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
                        // Micro Grooves
                        CustomPaint(
                          size: Size(discSize, discSize),
                          painter: _VinylGroovesPainter(),
                        ),
                        // Circular Album Art Center Label
                        Container(
                          width: discSize * 0.42,
                          height: discSize * 0.42,
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
                                    errorWidget: (_, _, _) => _vinylCenterHole(),
                                    placeholder: (_, _) => _vinylCenterHole(),
                                  )
                                : _vinylCenterHole(),
                          ),
                        ),
                        // Brushed Aluminum Spindle Ring
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF18181B),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 1.5,
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
                    // Clean Frosted Badge
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
                            Icons.album_rounded,
                            size: 11,
                            color: widget.isPlaying
                                ? const Color(0xFFE2E8F0)
                                : Colors.white38,
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            '33⅓ RPM VINYL',
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
                    // Analog Status
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.isPlaying ? 'PLAYING ANALOG MASTER' : 'PAUSED',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      discWidget,
                      const SizedBox(height: 14),
                      Flexible(child: metaWidget),
                    ],
                  );
                }

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    discWidget,
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

  Widget _vinylCenterHole() {
    return Container(
      color: const Color(0xFF1E2028),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 18,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    final groovePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Concentric micro-grooves
    final grooveRadii = [
      maxR * 0.52,
      maxR * 0.60,
      maxR * 0.68,
      maxR * 0.76,
      maxR * 0.84,
      maxR * 0.92,
    ];

    for (final r in grooveRadii) {
      canvas.drawCircle(center, r, groovePaint);
    }

    // Dynamic light sheen across grooves
    final sheenPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.07),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));

    canvas.drawCircle(center, maxR - 4, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
