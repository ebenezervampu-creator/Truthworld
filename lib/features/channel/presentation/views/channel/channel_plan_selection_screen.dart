import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

import 'package:truthworld/core/services/auth_service.dart';

class ChannelPlanSelectionController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final selectedPlan = Rx<ChannelPlanType?>(null);
  final hoveredPlan = Rx<ChannelPlanType?>(null);
  late AnimationController animController;
  late Animation<double> fadeAnim;

  @override
  void onInit() {
    super.onInit();
    animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animController, curve: Curves.easeOutCubic),
    );
    animController.forward();
  }

  @override
  void onClose() {
    animController.dispose();
    super.onClose();
  }

  Future<void> proceedToChannelCreation() async {
    if (selectedPlan.value == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          final rejectionCount = (data['channelRejectionCount'] as num?)?.toInt() ?? 0;
          final lastRejectedAt = (data['channelLastRejectedAt'] as num?)?.toInt();
          if (rejectionCount >= 2 && lastRejectedAt != null) {
            final lastRejectedDateTime = DateTime.fromMillisecondsSinceEpoch(lastRejectedAt);
            final unlockDateTime = lastRejectedDateTime.add(const Duration(days: 30));
            if (DateTime.now().isBefore(unlockDateTime)) {
              final unlockDateStr = unlockDateTime.toLocal().toString().split(' ')[0];
              AppSnackbar.show(
                'Locked',
                'Channel creation is locked until $unlockDateStr due to multiple moderation failures.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.red,
                colorText: Colors.white,
              );
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('Error checking user channel rejection lock: $e');
      }
    }

    Get.toNamed('/channelscreen', arguments: {'planType': selectedPlan.value});
  }
}

class ChannelPlanSelectionScreen extends StatelessWidget {
  const ChannelPlanSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (AuthService.to.hasChannel.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed('/studio');
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final controller = Get.find<ChannelPlanSelectionController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgPage : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: FadeTransition(
        opacity: controller.fadeAnim,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 64.0 : 24.0,
              vertical: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Text(
                  "Choose Your Creator Path",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: isDesktop ? 48 : 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A202C),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Select the monetization plan that aligns with your goals.\nYou can choose standard YouTube-like sharing or our unique Custom plan.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 56),

                // Plan Cards
                if (isDesktop)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildPlanCard(
                          controller,
                          ChannelPlanType.standard,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: _buildPlanCard(
                          controller,
                          ChannelPlanType.custom,
                          isDark,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildPlanCard(
                        controller,
                        ChannelPlanType.standard,
                        isDark,
                      ),
                      const SizedBox(height: 24),
                      _buildPlanCard(
                        controller,
                        ChannelPlanType.custom,
                        isDark,
                      ),
                    ],
                  ),

                const SizedBox(height: 56),

                // Continue Button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isDesktop ? 400 : double.infinity,
                  height: 56,
                  child: Obx(
                    () => ElevatedButton(
                      onPressed: controller.selectedPlan.value != null
                          ? controller.proceedToChannelCreation
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        disabledBackgroundColor: isDark
                            ? const Color(0xFF2D3748)
                            : const Color(0xFFE2E8F0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: controller.selectedPlan.value != null
                            ? 8
                            : 0,
                        shadowColor: const Color(
                          0xFF6366F1,
                        ).withValues(alpha: 0.5),
                      ),
                      child: Text(
                        "Continue",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: controller.selectedPlan.value != null
                              ? Colors.white
                              : (isDark ? Colors.white38 : Colors.black26),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    ChannelPlanSelectionController controller,
    ChannelPlanType type,
    bool isDark,
  ) {
    final isStandard = type == ChannelPlanType.standard;

    // Aesthetic colors for standard vs custom
    final Color primaryColor = isStandard
        ? const Color(0xFF3B82F6)
        : const Color(0xFF8B5CF6);
    final Color gradientStart = isStandard
        ? const Color(0xFF60A5FA)
        : const Color(0xFFA78BFA);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => controller.hoveredPlan.value = type,
      onExit: (_) => controller.hoveredPlan.value = null,
      child: GestureDetector(
        onTap: () => controller.selectedPlan.value = type,
        child: Obx(() {
          final isSelected = controller.selectedPlan.value == type;
          final isHovered = controller.hoveredPlan.value == type;
          final scale = isSelected ? 1.03 : (isHovered ? 1.015 : 1.0);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()
              ..scaleByDouble(scale, scale, 1.0, 1.0),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark
                  ? (isSelected
                        ? const Color(0xFF1E293B)
                        : (isHovered
                              ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                              : const Color(0xFF111827)))
                  : (isSelected
                        ? Colors.white
                        : (isHovered ? Colors.white : const Color(0xFFF8FAFC))),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? primaryColor
                    : (isHovered
                          ? primaryColor.withValues(alpha: 0.5)
                          : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0))),
                width: isSelected ? 2.5 : (isHovered ? 1.5 : 1),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : (isHovered
                        ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : []),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [gradientStart, primaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isStandard
                            ? Icons.play_circle_filled
                            : Icons.rocket_launch,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isStandard ? "Standard Plan" : "Custom Plan",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A202C),
                            ),
                          ),
                          Text(
                            isStandard
                                ? "YouTube-style Model"
                                : "Maximum Revenue",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Selection Indicator
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? primaryColor
                              : (isDark ? Colors.white30 : Colors.black26),
                          width: 2,
                        ),
                        color: isSelected ? primaryColor : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 18,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Revenue Highlights
                _buildHighlight(
                  isStandard
                      ? "75% Creator Ad Revenue"
                      : "100% Creator Ad Revenue",
                  isStandard ? "25% Platform Fee" : "0% Platform Fee",
                  primaryColor,
                ),
                const SizedBox(height: 20),
                _buildHighlight(
                  isStandard
                      ? "100% Subscriptions Revenue"
                      : "75% Subscriptions Revenue",
                  isStandard ? "0% Platform Fee" : "25% Platform Fee",
                  primaryColor,
                ),
                const SizedBox(height: 32),

                const Divider(color: Colors.grey, height: 1, thickness: 0.3),
                const SizedBox(height: 24),

                // Features List
                if (isStandard) ...[
                  _buildFeatureRow("Fully managed infrastructure", isDark),
                  _buildFeatureRow("No out-of-pocket costs", isDark),
                  _buildFeatureRow("Similar to traditional platforms", isDark),
                ] else ...[
                  _buildFeatureRow(
                    "Creator pays for infrastructure used",
                    isDark,
                  ),
                  _buildFeatureRow("Maximum ad revenue potential", isDark),
                  _buildFeatureRow("Full control over economics", isDark),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHighlight(String mainText, String subText, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.monetization_on_rounded, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mainText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle,
              size: 18,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum ChannelPlanType { standard, custom }

