import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:truthworld/features/splash/presentation/controllers/splash_controller.dart';

// 🔹 Change to GetView<SplashController>
class SplashScreen extends GetView<SplashController> {
  const SplashScreen({super.key});

  // Get responsive dimensions based on screen size
  ResponsiveDimensions _getResponsiveDimensions(BuildContext context) {
    // ... (Your responsive logic is perfect, no change needed)
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 900;
    final isLandscape = screenWidth > screenHeight;

    return ResponsiveDimensions(
      containerPadding: isLargeTablet
          ? 60.0
          : (isTablet ? 50.0 : (screenWidth * 0.08)),
      borderRadius: isTablet ? 45.0 : 35.0,
      logoSize: isLargeTablet
          ? 100.0
          : (isTablet ? 90.0 : (screenWidth * 0.18)),
      logoPadding: isTablet ? 20.0 : 15.0,
      titleFontSize: isLargeTablet
          ? 48.0
          : (isTablet ? 42.0 : (screenWidth * 0.09)),
      subtitleFontSize: isLargeTablet
          ? 20.0
          : (isTablet ? 18.0 : (screenWidth * 0.04)),
      titleSpacing: isTablet ? 35.0 : 30.0,
      subtitleSpacing: isTablet ? 20.0 : 15.0,
      loadingSpacing: isTablet ? 45.0 : 35.0,
      loadingSize: isTablet ? 50.0 : 40.0,
      titleLetterSpacing: isTablet ? 2.5 : 2.0,
      subtitleLetterSpacing: isTablet ? 1.0 : 0.8,
      maxContainerWidth: isLandscape ? screenWidth * 0.7 : screenWidth * 0.85,
      maxContainerHeight: isLandscape ? screenHeight * 0.8 : double.infinity,
      particleCount: isLargeTablet ? 80 : (isTablet ? 60 : 40),
      connectionCount: isLargeTablet ? 30 : (isTablet ? 25 : 15),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 The controller is automatically provided by GetView
    // We just call controller.onInit() in the binding,
    // so we just need to build the UI here.

    final dimensions = _getResponsiveDimensions(context);
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0D0D0D), // Deep black
                Color(0xFF1A1A2E), // Dark navy
                Color(0xFF16213E), // Midnight blue
                Color(0xFF0F3460), // Deep blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // 🔹 Animated background particles
              // Reads animation value from the controller
              AnimatedBuilder(
                animation: controller.particleAnimation,
                builder: (context, child) => CustomPaint(
                  painter: ParticlePainter(
                    controller.particleAnimation.value, // 🔹 Use controller.
                    dimensions.particleCount,
                    dimensions.connectionCount,
                  ),
                  size: Size.infinite,
                ),
              ),

              Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: dimensions.maxContainerWidth,
                      maxHeight: dimensions.maxContainerHeight,
                    ),
                    // 🔹 Main AnimatedBuilder now listens to the controller
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        controller.fadeInAnimation,
                        controller.scaleAnimation,
                        controller.rotationAnimation,
                        controller.pulseAnimation,
                      ]),
                      builder: (context, child) => FadeTransition(
                        opacity:
                            controller.fadeInAnimation, // 🔹 Use controller.
                        child: ScaleTransition(
                          scale:
                              controller.scaleAnimation, // 🔹 Use controller.
                          child: Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: mediaQuery.size.width * 0.05,
                              vertical: mediaQuery.size.height * 0.02,
                            ),
                            padding: EdgeInsets.all(
                              dimensions.containerPadding,
                            ),
                            decoration: BoxDecoration(
                              // ... (your gradients, borders, shadows)
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.05),
                                  Colors.white.withValues(alpha: 0.02),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(
                                dimensions.borderRadius,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0F3460,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 🔹 Animated logo with rotation and pulse
                                Transform.rotate(
                                  angle: controller
                                      .rotationAnimation
                                      .value, // 🔹 Use controller.
                                  child: ScaleTransition(
                                    scale: controller
                                        .pulseAnimation, // 🔹 Use controller.
                                    child: Container(
                                      // ... (your logo container style)
                                      padding: EdgeInsets.all(
                                        dimensions.logoPadding,
                                      ),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const RadialGradient(
                                          colors: [
                                            Color(0xFF4FACFE),
                                            Color(0xFF00F2FE),
                                          ],
                                          stops: [0.0, 1.0],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF00F2FE,
                                            ).withValues(alpha: 0.4),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.play_circle_filled,
                                        size: dimensions.logoSize,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: dimensions.titleSpacing),

                                // 🔹 Animated app name
                                AnimatedBuilder(
                                  animation: Listenable.merge([
                                    controller.textSlideAnimation,
                                    controller.textOpacityAnimation,
                                  ]),
                                  builder: (context, child) => Transform.translate(
                                    offset: Offset(
                                      0,
                                      controller.textSlideAnimation.value,
                                    ), // 🔹 Use controller.
                                    child: FadeTransition(
                                      opacity: controller
                                          .textOpacityAnimation, // 🔹 Use controller.
                                      child: ShaderMask(
                                        // ... (your shader text)
                                        shaderCallback: (bounds) =>
                                            const LinearGradient(
                                              colors: [
                                                Color(0xFF4FACFE),
                                                Color(0xFF00F2FE),
                                                Color(0xFFFFFFFF),
                                              ],
                                            ).createShader(bounds),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            "TruthWorld",
                                            style: GoogleFonts.orbitron(
                                              fontSize:
                                                  dimensions.titleFontSize,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing:
                                                  dimensions.titleLetterSpacing,
                                              shadows: [
                                                Shadow(
                                                  color: const Color(
                                                    0xFF00F2FE,
                                                  ).withValues(alpha: 0.5),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: dimensions.subtitleSpacing),

                                // 🔹 Animated tagline
                                AnimatedBuilder(
                                  animation: controller.textOpacityAnimation,
                                  builder: (context, child) => Transform.translate(
                                    offset: Offset(
                                      0,
                                      controller.textSlideAnimation.value + 10,
                                    ), // 🔹 Use controller.
                                    child: FadeTransition(
                                      opacity: controller
                                          .textOpacityAnimation, // 🔹 Use controller.
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          "Share Your World in Seconds",
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.roboto(
                                            fontSize:
                                                dimensions.subtitleFontSize,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w300,
                                            letterSpacing: dimensions
                                                .subtitleLetterSpacing,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: dimensions.loadingSpacing),

                                // 🔹 Modern loading indicator
                                SizedBox(
                                  width: dimensions.loadingSize,
                                  height: dimensions.loadingSize,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF00F2FE),
                                        ),
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🔹 Your helper classes remain unchanged
class ResponsiveDimensions {
  // ... (no changes needed)
  final double containerPadding;
  final double borderRadius;
  final double logoSize;
  final double logoPadding;
  final double titleFontSize;
  final double subtitleFontSize;
  final double titleSpacing;
  final double subtitleSpacing;
  final double loadingSpacing;
  final double loadingSize;
  final double titleLetterSpacing;
  final double subtitleLetterSpacing;
  final double maxContainerWidth;
  final double maxContainerHeight;
  final int particleCount;
  final int connectionCount;

  ResponsiveDimensions({
    required this.containerPadding,
    required this.borderRadius,
    required this.logoSize,
    required this.logoPadding,
    required this.titleFontSize,
    required this.subtitleFontSize,
    required this.titleSpacing,
    required this.subtitleSpacing,
    required this.loadingSpacing,
    required this.loadingSize,
    required this.titleLetterSpacing,
    required this.subtitleLetterSpacing,
    required this.maxContainerWidth,
    required this.maxContainerHeight,
    required this.particleCount,
    required this.connectionCount,
  });
}

class ParticlePainter extends CustomPainter {
  // ... (no changes needed)
  final double animationValue;
  final int particleCount;
  final int connectionCount;

  ParticlePainter(
    this.animationValue,
    this.particleCount,
    this.connectionCount,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00F2FE).withValues(alpha: 0.1)
      ..strokeWidth = 1.0;

    final random = math.Random(42); // Fixed seed for consistent animation

    // Draw particles
    for (int i = 0; i < particleCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final offset = animationValue * 100;

      final adjustedY = (y + offset) % size.height;
      final opacity = (math.sin(animationValue * 2 * math.pi + i) + 1) / 2;

      paint.color = Color(0xFF00F2FE).withValues(alpha: opacity * 0.3);

      canvas.drawCircle(
        Offset(x, adjustedY),
        random.nextDouble() * 2 + 0.5,
        paint,
      );
    }

    // Draw connecting lines
    paint.strokeWidth = 0.5;
    for (int i = 0; i < connectionCount; i++) {
      final x1 = random.nextDouble() * size.width;
      final y1 =
          (random.nextDouble() * size.height + animationValue * 50) %
          size.height;
      final x2 = random.nextDouble() * size.width;
      final y2 =
          (random.nextDouble() * size.height + animationValue * 50) %
          size.height;

      final distance = math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));

      if (distance < 100) {
        paint.color = const Color(
          0xFF4FACFE,
        ).withValues(alpha: 0.1 * (1 - distance / 100));
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    return animationValue != oldDelegate.animationValue;
  }
}






