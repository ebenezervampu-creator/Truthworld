import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 2: Retro Vinyl Turntable
/// Spinning 33⅓ RPM grooved vinyl record with album art center, rotational animation, and analog audio vibe.
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
      duration: const Duration(seconds: 8), // ~33 RPM aesthetic
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
        : 'TruthWorld Acoustic Records';
    final thumb = widget.video?.thumbnailUrl ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Warm Analog Background
        const ColoredBox(color: Color(0xFF0C0D10)),
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 0.9,
              colors: [
                const Color(0xFFD97706).withValues(alpha: 0.12),
                Colors.black,
              ],
            ),
          ),
        ),

        // Center Stage Vinyl Record + Metadata
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Spinning Grooved Vinyl Disc
                RotationTransition(
                  turns: _spinController,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF141416),
                      border: Border.all(
                        color: const Color(0xFF26262B),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.85),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Concentric Grooves
                        CustomPaint(
                          size: const Size(140, 140),
                          painter: _VinylGroovesPainter(),
                        ),
                        // Center Vinyl Label with Thumbnail
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFF59E0B),
                              width: 1.5,
                            ),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFB45309), Color(0xFFF59E0B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: ClipOval(
                            child: thumb.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: thumb,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) =>
                                        _vinylCenterHole(),
                                    placeholder: (_, _) => _vinylCenterHole(),
                                  )
                                : _vinylCenterHole(),
                          ),
                        ),
                        // Spindle Hole
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // Vinyl Metadata Card
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
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
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                '33⅓ RPM HIGH-FIDELITY',
                                style: TextStyle(
                                  color: Color(0xFFFBBF24),
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
                          children: [
                            Text(
                              'Analog Remaster',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              ' • Lossless Stereo',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
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

  Widget _vinylCenterHole() {
    return const ColoredBox(
      color: Color(0xFFB45309),
      child: Center(
        child: Icon(Icons.album_rounded, size: 28, color: Colors.white70),
      ),
    );
  }
}

class _VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    for (var r = 32.0; r < size.width / 2 - 4; r += 5.5) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_VinylGroovesPainter oldDelegate) => false;
}
