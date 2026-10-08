import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/app_logo.dart';

// =============================================================
// TRUTHWORLD LONG VIDEO - MOTION SYSTEM & SPLASH IN ONE FILE
// Works for Mobile, Tablet, Foldable, Web, Desktop
// =============================================================

abstract class TLong {
  static const Duration fast = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration splash = Duration(milliseconds: 350);
  static const Curve curve = Curves.easeOutCubic;
  static const Curve exit = Curves.fastOutSlowIn;
}

// =============================================================
// 1. FINAL SPLASH SCREEN - CINEMATIC FOR LONG VIDEOS
// =============================================================
class TruthworldSplashScreen extends StatefulWidget {
  const TruthworldSplashScreen({
    required this.child,
    super.key,
    this.duration = TLong.splash,
    this.backgroundColor = const Color(0xFF0B0F1A),
    this.message = 'Love everyone Trust no one',
    this.onCompleted,
  });

  final Widget child;
  final Duration duration;
  final Color backgroundColor;
  final String? message;
  final VoidCallback? onCompleted;

  static final RxBool _dismissSignal = false.obs;

  /// Trigger immediate graceful exit animation as soon as the Home feed is loaded.
  static void dismiss() {
    if (!_dismissSignal.value) {
      _dismissSignal.value = true;
    }
  }

  /// Reset the signal for testing or session restarts.
  static void reset() {
    _dismissSignal.value = false;
  }

  @override
  State<TruthworldSplashScreen> createState() => _TruthworldSplashScreenState();
}

class _TruthworldSplashScreenState extends State<TruthworldSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<double> _exitScale;
  late final Animation<double> _exitFade;

  final RxBool _done = false.obs;
  Worker? _dismissWorker;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _logoScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.70, curve: TLong.curve)),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.55, curve: Curves.easeOut)),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.35, 0.70, curve: Curves.easeOut)),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.70, 1.0, curve: TLong.curve)),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.70, 1.0, curve: Curves.easeOut)),
    );

    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _done.value = true;
        widget.onCompleted?.call();
      }
    });

    if (TruthworldSplashScreen._dismissSignal.value) {
      _done.value = true;
      widget.onCompleted?.call();
    } else {
      _dismissWorker = ever(TruthworldSplashScreen._dismissSignal, (dismiss) {
        if (dismiss && mounted && !_done.value) {
          if (_controller.value < 0.70) {
            _controller.animateTo(
              1.0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
            );
          }
        }
      });
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _dismissWorker?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_done.value) return widget.child;

      return Stack(
        fit: StackFit.expand,
        children: [
          TickerMode(enabled: true, child: widget.child),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (_exitFade.value <= 0.01) return const SizedBox.shrink();
              return Opacity(
                opacity: _exitFade.value,
                child: Transform.scale(
                  scale: _logoScale.value * _exitScale.value,
                  child: ColoredBox(
                    color: widget.backgroundColor,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final availableHeight = constraints.maxHeight;
                        final availableWidth = constraints.maxWidth;
                        final shortest = math.min(availableWidth, availableHeight);

                        // Prominently sized Truthworld Logo (increased size: 130px - 220px)
                        final logoSize = math.min(
                          availableHeight * 0.36,
                          shortest * 0.42,
                        ).clamp(130.0, 220.0);

                        final spacing = (logoSize * 0.16).clamp(16.0, 26.0);
                        final titleSize = (logoSize * 0.22).clamp(26.0, 38.0);
                        final hasMessage = widget.message != null && widget.message!.trim().isNotEmpty;
                        final messageSize = (titleSize * 0.42).clamp(13.0, 16.0);
                        final messageSpacing = (logoSize * 0.05).clamp(6.0, 10.0);

                        // Check if "Truthworld" text and message comfortably fit without crowding or overflowing
                        final estimatedTotalHeight = logoSize +
                            spacing +
                            (titleSize * 1.35) +
                            (hasMessage ? messageSpacing + (messageSize * 1.35) : 0.0);
                        final fitsText = availableHeight >= (estimatedTotalHeight + 48.0);

                        return Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FadeTransition(
                                    opacity: _logoFade,
                                    child: AppLogo(
                                      size: logoSize,
                                      borderRadius: logoSize * 0.22,
                                    ),
                                  ),
                                  if (fitsText) ...[
                                    SizedBox(height: spacing),
                                    FadeTransition(
                                      opacity: _textFade,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Truthworld',
                                            style: TextStyle(
                                              fontSize: titleSize,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                          if (hasMessage) ...[
                                            SizedBox(height: messageSpacing),
                                            Text(
                                              widget.message!,
                                              style: TextStyle(
                                                fontSize: messageSize,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white.withValues(alpha: 0.72),
                                                letterSpacing: 0.6,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    });
  }
}

// =============================================================
// 2. ANIMATIONS FOR LONG VIDEO PLATFORM (Truthworld style)
// =============================================================

// Truthworld-style press - subtle 0.98 scale, no bounce
class VideoCardLong extends StatelessWidget {
  VideoCardLong({required this.thumbnail, required this.onTap, super.key});

  final Widget thumbnail;
  final VoidCallback onTap;
  final RxBool _pressed = false.obs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressed.value = true,
      onTapUp: (_) {
        _pressed.value = false;
        onTap();
      },
      onTapCancel: () => _pressed.value = false,
      child: Obx(
        () => AnimatedScale(
          scale: _pressed.value ? 0.98 : 1.0,
          duration: TLong.medium,
          curve: TLong.curve,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(aspectRatio: 16 / 9, child: thumbnail),
          ),
        ),
      ),
    );
  }
}

// Shimmer for 16:9 thumbnails
class TruthworldShimmer extends StatefulWidget {
  const TruthworldShimmer({super.key, this.borderRadius = 12});
  final double borderRadius;
  @override State<TruthworldShimmer> createState() => _TruthworldShimmerState();
}
class _TruthworldShimmerState extends State<TruthworldShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override void initState() { _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(); super.initState(); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _c, builder: (context, _) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: Alignment(-1.0 + _c.value * 2, 0), end: Alignment(1.0 + _c.value * 2, 0),
            colors: const [Color(0xFF1A1A1A), Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
          ),
        ),
      );
    });
  }
}

// Subscribe button morph - for long-form channels
class SubscribeButton extends StatelessWidget {
  const SubscribeButton({required this.subscribed, required this.onTap, super.key});
  final bool subscribed;
  final VoidCallback onTap;
  @override Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TLong.medium,
      curve: TLong.curve,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: subscribed? Colors.white.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Text(subscribed? 'Subscribed' : 'Subscribe',
            style: TextStyle(color: subscribed? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }
}

// Staggered entrance for home feed
class StaggeredFeed extends StatelessWidget {
  const StaggeredFeed({required this.children, super.key});
  final List<Widget> children;
  @override Widget build(BuildContext context) {
    return Column(
      children: List.generate(children.length, (i) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 400 + i * 60),
          curve: TLong.curve,
          builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child)),
          child: children[i],
        );
      }),
    );
  }
}
