import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';

class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject the AdminController if not registered
    final controller = Get.put(AdminController());

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Stack(
        children: [
          // Background Gradient Orbs
          Positioned(
            top: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.15),
                    blurRadius: 120,
                    spreadRadius: 80,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandHover.withValues(alpha: 0.1),
                    blurRadius: 150,
                    spreadRadius: 100,
                  ),
                ],
              ),
            ),
          ),

          // Main Login Layout
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Obx(() {
                  if (controller.isAuthChecking.value) {
                    return _buildLoadingCard();
                  }
                  return _buildLoginCard(context, controller);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(40.0),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: AppColors.bgDivider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Verifying console credentials...',
            style: GoogleFonts.roboto(
              color: AppColors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context, AdminController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 48.0),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: AppColors.bgDivider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo & Header
          Center(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFE0B0FF), AppColors.brand],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                'TruthWorld',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Moderator & Audit Center',
              style: GoogleFonts.roboto(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Welcome message
          Text(
            'Admin authentication is required to access data layers, manual queues, and quarantine overrides.',
            style: GoogleFonts.roboto(
              color: AppColors.textTertiary,
              fontSize: 13,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),

          // Google Sign-In Button
          ElevatedButton(
            onPressed: controller.isLoading.value
                ? null
                : () => controller.signInWithGoogle(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: controller.isLoading.value ? 0 : 2,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: controller.isLoading.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Drawing a vector-based Google icon since images can be missing
                      CustomPaint(
                        size: const Size(18, 18),
                        painter: GoogleIconPainter(),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Continue with Google',
                        style: GoogleFonts.roboto(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  color: AppColors.textTertiary, size: 14),
              const SizedBox(width: 6),
              Text(
                'Secured with Firebase Auth',
                style: GoogleFonts.roboto(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double r = w / 2;

    final Paint paint = Paint()..style = PaintingStyle.fill;
    final Path path = Path();

    // Red sector
    paint.color = const Color(0xFFEA4335);
    path.reset();
    path.moveTo(r, r);
    path.lineTo(r - r * 0.707, r - r * 0.707);
    path.arcTo(
      Rect.fromCircle(center: Offset(r, r), radius: r),
      -2.356, // -135 deg
      1.571, // 90 deg
      false,
    );
    path.lineTo(r, r);
    canvas.drawPath(path, paint);

    // Yellow sector
    paint.color = const Color(0xFFFBBC05);
    path.reset();
    path.moveTo(r, r);
    path.lineTo(r - r * 0.707, r + r * 0.707);
    path.arcTo(
      Rect.fromCircle(center: Offset(r, r), radius: r),
      2.356, // 135 deg
      -1.571, // -90 deg
      false,
    );
    path.lineTo(r, r);
    canvas.drawPath(path, paint);

    // Green sector
    paint.color = const Color(0xFF34A853);
    path.reset();
    path.moveTo(r, r);
    path.lineTo(r + r * 0.707, r + r * 0.707);
    path.arcTo(
      Rect.fromCircle(center: Offset(r, r), radius: r),
      0.785, // 45 deg
      1.571, // 90 deg
      false,
    );
    path.lineTo(r, r);
    canvas.drawPath(path, paint);

    // Blue sector & G bar
    paint.color = const Color(0xFF4285F4);
    path.reset();
    path.moveTo(r, r);
    path.lineTo(r + r * 0.707, r - r * 0.707);
    path.arcTo(
      Rect.fromCircle(center: Offset(r, r), radius: r),
      -0.785, // -45 deg
      1.571, // 90 deg
      false,
    );
    path.lineTo(r, r);
    canvas.drawPath(path, paint);

    // Inner cutout
    paint.color = AppColors.bgSurface;
    canvas.drawCircle(Offset(r, r), r * 0.6, paint);

    // Blue horizontal bar
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTRB(r, r - r * 0.2, w, r + r * 0.2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
