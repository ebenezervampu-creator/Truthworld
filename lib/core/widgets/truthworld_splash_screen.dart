import 'package:flutter/foundation.dart' show kIsWeb;
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
  static const Duration splash = Duration(milliseconds: 2200);
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
    this.backgroundColor = const Color(0xFF08070E),
    this.onCompleted,
  });

  final Widget child;
  final Duration duration;
  final Color backgroundColor;
  final VoidCallback? onCompleted;

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
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return widget.child;

    return Obx(() {
      if (_done.value) return widget.child;

      final shortest = MediaQuery.sizeOf(context).shortestSide;
      final logoSize = (shortest * 0.24).clamp(72.0, 110.0);
      final titleSize = (shortest * 0.06).clamp(20.0, 26.0);

      return Stack(
        fit: StackFit.expand,
        children: [
          TickerMode(enabled: _done.value, child: widget.child),
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
                    child: Stack(
                      children: [
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FadeTransition(opacity: _logoFade, child: AppLogo(size: logoSize, borderRadius: 20)),
                                SizedBox(height: logoSize * 0.28),
                                FadeTransition(
                                  opacity: _textFade,
                                  child: Column(
                                    children: [
                                      Text('Truthworld', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                                      const SizedBox(height: 6),
                                      Text('LONG FORM • TRUTH FIRST',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 2.0, color: Colors.white.withValues(alpha: 0.5))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Truthworld style loading line - perfect for long video
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: SafeArea(
                            top: false,
                            child: SizedBox(
                              height: 2.5,
                              child: LinearProgressIndicator(
                                value: _controller.value,
                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                                valueColor: const AlwaysStoppedAnimation(Color(0xFF9B30FF)),
                              ),
                            ),
                          ),
                        ),
                      ],
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
