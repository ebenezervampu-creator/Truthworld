import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Global Error Boundary Widget used by [ErrorWidget.builder].
/// Replaces Flutter's default red/grey screen of death with an elegant,
/// branded, and recoverable UI placeholder.
class GlobalErrorBoundary extends StatelessWidget {
  const GlobalErrorBoundary({
    required this.details,
    super.key,
  });

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgPage,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error Icon Container
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white, // Rule: Icons must be white
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),

                // Headline
                Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // Friendly Subtitle
                Text(
                  'An unexpected visual glitch occurred. Tapping below will refresh the current view.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                      label: const Text('Reload Page'),
                      onPressed: () {
                        if (Get.key.currentState?.canPop() ?? false) {
                          Get.back<void>();
                        } else {
                          Get.offAllNamed<void>('/');
                        }
                      },
                    ),
                  ],
                ),

                // Technical details in debug mode only
                if (kDebugMode) ...[
                  const SizedBox(height: 32),
                  ExpansionTile(
                    title: Text(
                      'Technical Diagnostics (Debug Only)',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.bgDivider),
                        ),
                        child: Text(
                          details.exceptionAsString(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
