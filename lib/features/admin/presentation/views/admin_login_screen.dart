import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AdminLoginScreen extends GetView<AdminController> {
  AdminLoginScreen({super.key});

  final RxBool _obscurePassword = true.obs;

  void _submitLogin(AdminController controller) {
    final email = (controller.verifiedAdminUser.value?['email'] ??
            controller.emailController.text)
        .toString()
        .trim();
    final password = controller.passwordController.text.trim().isNotEmpty
        ? controller.passwordController.text.trim()
        : controller.loginPassword.value.trim();

    controller.signInWithAdminProtocol(
      emailInput: email.isNotEmpty ? email : controller.loginEmail.value,
      passwordInput: password,
    );
  }

  @override
  Widget build(BuildContext context) {

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
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Verifying console credentials...',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
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
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
          const Center(
            child: AppLogo(
              size: 56,
              borderRadius: 14,
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'TruthWorld',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Moderator & Audit Center',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Step-based dynamic authentication fields
          if (controller.loginStep.value == 1) ...[
            // Welcome message
            const Text(
              'Enter your administrator username to verify console authorization.',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textTertiary,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Username Input
            TextField(
              controller: controller.usernameController,
              maxLength: 40,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: [
                LengthLimitingTextInputFormatter(40),
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              keyboardType: TextInputType.text,
              onChanged: (val) {
                controller.loginUsername.value = val.trim();
              },
              onSubmitted: (_) => controller.verifyAdminUsername(),
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. hello1 or moderator1',
                labelText: 'Admin Username',
                labelStyle: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.bgInput,
                prefixIcon: const Icon(
                  Icons.alternate_email_rounded,
                  color: Colors.white,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.brand),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Step 1: Verify Username Continue Button
            ElevatedButton(
              onPressed: controller.isVerifyingUsername.value
                  ? null
                  : () => controller.verifyAdminUsername(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: controller.isVerifyingUsername.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Text(
                      'Continue',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ] else ...[
            // Step 2: Verified Identity Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.brand.withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.verifiedAdminUser.value?['username'] ??
                              controller.usernameController.text,
                          style: const TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          controller.verifiedAdminUser.value?['role'] ??
                              'Administrator',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: controller.resetLoginStep,
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Password Input with Visibility Toggle
            Obx(
              () => TextField(
                controller: controller.passwordController,
                maxLength: 128,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(128),
                ],
                obscureText: _obscurePassword.value,
                onChanged: (val) {
                  controller.loginPassword.value = val.trim();
                },
                onSubmitted: (_) => _submitLogin(controller),
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  labelText: 'Admin Password',
                  labelStyle: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  prefixIcon: const Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword.value
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _obscurePassword.toggle,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.brand),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Step 2: Sign In Button
            ElevatedButton(
              onPressed: controller.isLoading
                  ? null
                  : () => _submitLogin(controller),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: controller.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Text(
                      'Sign In to Admin Portal',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
            const SizedBox(height: 12),

            Center(
              child: TextButton.icon(
                onPressed: controller.resetLoginStep,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                label: const Text(
                  'Switch Username',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],

          if (controller.loginStep.value == 1) ...[
            const SizedBox(height: 20),
            const Row(
              children: [
                Expanded(child: Divider(color: AppColors.bgDivider)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
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
              onPressed: controller.isLoading
                  ? null
                  : () => controller.signInWithGoogle(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.bgPage,
                elevation: controller.isLoading ? 0 : 2,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: controller.isLoading
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
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ],

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: Colors.white,
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Truthworld Unified Administration Portal',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: Colors.white,
                size: 14,
              ),
              SizedBox(width: 6),
              Text(
                'Secured with Firebase Auth',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
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
    paint.color = AppColors.error;
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
    paint.color = AppColors.warning;
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
    paint.color = AppColors.success;
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
    paint.color = AppColors.info;
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
    paint.color = AppColors.info;
    canvas.drawRect(
      Rect.fromLTRB(r, r - r * 0.2, w, r + r * 0.2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
