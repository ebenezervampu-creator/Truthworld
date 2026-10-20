import 'dart:math';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 6: Vintage Cassette Tape
/// Dual spinning tape spools, magnetic tape ribbon, retro mixtape label, and warm analog backlighting.
class VintageCassetteTheme extends StatefulWidget {
  const VintageCassetteTheme({
    required this.isPlaying,
    this.video,
    super.key,
  });

  final bool isPlaying;
  final Video? video;

  @override
  State<VintageCassetteTheme> createState() => _VintageCassetteThemeState();
}

class _VintageCassetteThemeState extends State<VintageCassetteTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spoolController;

  @override
  void initState() {
    super.initState();
    _spoolController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.isPlaying) {
      _spoolController.repeat();
    }
  }

  @override
  void didUpdateWidget(VintageCassetteTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _spoolController.repeat();
      } else {
        _spoolController.stop();
      }
    }
  }

  @override
  void dispose() {
    _spoolController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video?.title.isNotEmpty == true
        ? widget.video!.title
        : 'TruthWorld Mixtape Vol. 1';
    final channel = widget.video?.channelName.isNotEmpty == true
        ? widget.video!.channelName
        : 'Studio Cassette';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark Vintage Background with Warm Ambient Radial Aura
        const ColoredBox(color: Color(0xFF0D0A08)),
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 0.9,
              colors: [
                const Color(0xFFB45309).withValues(alpha: 0.15),
                Colors.black,
              ],
            ),
          ),
        ),

        // Center Stage Cassette Shell
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              width: 330,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
              color: const Color(0xFF1C1917), // Charcoal cassette plastic
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF44403C),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mixtape Top Label Sticker
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7), // Vintage cream paper
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFD97706),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB45309),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SIDE A',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1C1917),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              channel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF78350F),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'TYPE II 90',
                        style: TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Transparent Acrylic Spool Window
                Container(
                  width: double.infinity,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0A09),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF292524),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Magnetic Tape Ribbon Bridge
                      Positioned(
                        left: 45,
                        right: 45,
                        top: 30,
                        height: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF451A03), // Brown tape
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Spool Pair
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTapeSpool(_spoolController),
                          // Center Tick Marks & Tape Window
                          Container(
                            width: 32,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                widget.isPlaying ? 'PLAY' : 'PAUSE',
                                style: TextStyle(
                                  color: widget.isPlaying
                                      ? const Color(0xFFF59E0B)
                                      : Colors.white38,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          _buildTapeSpool(_spoolController),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
  }

  Widget _buildTapeSpool(AnimationController controller) {
    return RotationTransition(
      turns: controller,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF292524),
          border: Border.all(
            color: const Color(0xFF57534E),
            width: 2,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 6-toothed Spool Cog Teeth
            for (var i = 0; i < 6; i++)
              Transform.rotate(
                angle: (i * pi) / 3,
                child: Container(
                  width: 3,
                  height: 38,
                  color: const Color(0xFFD6D3D1),
                ),
              ),
            // Spool Hub Center
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0C0A09),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
