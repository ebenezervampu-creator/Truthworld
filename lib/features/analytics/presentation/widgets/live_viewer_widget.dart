import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Real-time concurrent viewer counter with pulse animation.
///
/// Note: Realtime Database backend was removed. This now shows a static/dummy count.
///
/// Features:
/// - Pulsing red "LIVE" dot animation
/// - Smooth count transition via TweenAnimationBuilder
/// - Dark gradient card matching the app's aesthetic
class LiveViewerWidget extends StatefulWidget {

  const LiveViewerWidget({super.key, this.videoId});
  /// Pass a videoId for per-video count, or null for global count.
  final String? videoId;

  @override
  State<LiveViewerWidget> createState() => _LiveViewerWidgetState();
}

class _LiveViewerWidgetState extends State<LiveViewerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream.value(0), // Dummy stream since RTDB was removed
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE94560).withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated live dot
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE94560),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFE94560,
                          ).withValues(alpha: _pulseAnimation.value * 0.6),
                          blurRadius: 8 * _pulseAnimation.value,
                          spreadRadius: 2 * _pulseAnimation.value,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              // Label
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'LIVE NOW',
                    style: TextStyle(
                      color: Color(0xFFE94560),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: count),
                    duration: const Duration(milliseconds: 600),
                    builder: (context, value, child) {
                      return Text(
                        '$value watching',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
