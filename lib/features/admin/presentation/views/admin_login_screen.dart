import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject the AdminController if not registered
    final controller = Get.find<AdminController>();

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: Stack(
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
                padding: const EdgeInsets.all(24),
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
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.bgDivider),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Verifying console credentials...',
            style: TextStyle(
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
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.bgDivider),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: 0.4),
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
                style: context.typography.logo.copyWith(
                  fontSize: 38,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Moderator & Audit Center',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Welcome message
          const Text(
            'Admin authentication is required to access data layers, manual queues, and quarantine overrides.',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 13,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Email Input
          TextField(
            controller: controller.emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'ebenezervampu4@gmail.com',
              labelText: 'Admin Email',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.bgInput,
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: AppColors.textPrimary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.bgDivider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.brand),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Password Input
          TextField(
            controller: controller.passwordController,
            obscureText: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '••••••••',
              labelText: 'Admin Password',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.bgInput,
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.textPrimary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.bgDivider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.brand),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Sign In Button
          ElevatedButton(
            onPressed: controller.isLoading.value
                ? null
                : () => controller.signInWithEmailAndPassword(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Sign In with Email & Password',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),

          const SizedBox(height: 20),
          const Row(
            children: [
              Expanded(child: Divider(color: AppColors.bgDivider)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(child: Divider(color: AppColors.bgDivider)),
            ],
          ),
          const SizedBox(height: 20),

          // Google Sign-In Button
          ElevatedButton(
            onPressed: controller.isLoading.value
                ? null
                : () => controller.signInWithGoogle(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.bgPage,
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.bgPage54,
                      ),
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
                      const Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: const Text(
              'Authorized Owner: ebenezervampu4@gmail.com',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: AppColors.textTertiary,
                size: 14,
              ),
              SizedBox(width: 6),
              Text(
                'Secured with Firebase Auth',
                style: TextStyle(
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
    final w = size.width;
    final r = w / 2;

    final paint = Paint()..style = PaintingStyle.fill;
    final path = Path();

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
