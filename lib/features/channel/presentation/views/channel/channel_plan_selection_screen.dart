import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';

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
    fadeAnim = Tween<double>(begin: 0, end: 1).animate(
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
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          final rejectionCount =
              (data['channelRejectionCount'] as num?)?.toInt() ?? 0;
          final lastRejectedAt = (data['channelLastRejectedAt'] as num?)
              ?.toInt();
          if (rejectionCount >= 2 && lastRejectedAt != null) {
            final lastRejectedDateTime = DateTime.fromMillisecondsSinceEpoch(
              lastRejectedAt,
            );
            final unlockDateTime = lastRejectedDateTime.add(
              const Duration(days: 30),
            );
            if (DateTime.now().isBefore(unlockDateTime)) {
              final unlockDateStr = unlockDateTime.toLocal().toString().split(
                ' ',
              )[0];
              AppSnackbar.show(
                'Locked',
                'Channel creation is locked until $unlockDateStr due to multiple moderation failures.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppColors.error,
                colorText: AppColors.textPrimary,
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
            Icons.arrow_back,
            color: isDark ? AppColors.textPrimary : AppColors.bgPage,
          ),
          onPressed: Get.back,
        ),
      ),
      body: FadeTransition(
        opacity: controller.fadeAnim,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 64.0 : 24.0,
              vertical: 24,
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  'Choose Your Creator Path',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 48 : 32,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimary
                        : const Color(0xFF1A202C),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select the monetization plan that aligns with your goals.\nYou can choose standard YouTube-like sharing or our unique Custom plan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark
                        ? AppColors.textSecondary
                        : const Color(0xFF1E293B),
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
                        'Continue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: controller.selectedPlan.value != null
                              ? AppColors.textPrimary
                              : (isDark
                                    ? AppColors.textTertiary
                                    : Colors.black26),
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
    final primaryColor = isStandard
        ? const Color(0xFF3B82F6)
        : const Color(0xFF8B5CF6);
    final gradientStart = isStandard
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
            transform: Matrix4.identity()..scaleByDouble(scale, scale, 1, 1),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark
                  ? (isSelected
                        ? const Color(0xFF1E293B)
                        : (isHovered
                              ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                              : const Color(0xFF111827)))
                  : (isSelected
                        ? AppColors.textPrimary
                        : (isHovered
                              ? AppColors.textPrimary
                              : const Color(0xFFF8FAFC))),
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
                        color: AppColors.textPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isStandard ? 'Standard Plan' : 'Custom Plan',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : const Color(0xFF1A202C),
                            ),
                          ),
                          Text(
                            isStandard
                                ? 'YouTube-style Model'
                                : 'Maximum Revenue',
                            style: TextStyle(
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
                              : (isDark
                                    ? AppColors.textTertiary
                                    : Colors.black26),
                          width: 2,
                        ),
                        color: isSelected ? primaryColor : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 18,
                              color: AppColors.textPrimary,
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Revenue Highlights
                _buildHighlight(
                  isStandard
                      ? '75% Creator Ad Revenue'
                      : '100% Creator Ad Revenue',
                  isStandard ? '25% Platform Fee' : '0% Platform Fee',
                  primaryColor,
                ),
                const SizedBox(height: 20),
                _buildHighlight(
                  isStandard
                      ? '100% Subscriptions Revenue'
                      : '75% Subscriptions Revenue',
                  isStandard ? '0% Platform Fee' : '25% Platform Fee',
                  primaryColor,
                ),
                const SizedBox(height: 32),

                const Divider(
                  color: AppColors.textSecondary,
                  height: 1,
                  thickness: 0.3,
                ),
                const SizedBox(height: 24),

                // Features List & How It Works
                if (isStandard) ...[
                  _buildFeatureRow(
                    'Fully managed platform infrastructure (\$0 hosting fees)',
                    isDark,
                  ),
                  _buildFeatureRow(
                    'Up to 5 Videos upload limit (Max 10 mins total cumulative duration)',
                    isDark,
                  ),
                  _buildFeatureRow('55% Net Revenue Share from Day 1', isDark),
                  _buildFeatureRow(
                    '10 Hours watch-time cash-out threshold per video',
                    isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildHowItWorksBox(
                    'How Standard Channel Works:',
                    'Standard channels require zero upfront costs or technical management. '
                        'Truthworld hosts your video and handles infrastructure. Ad & viewer revenue accumulates immediately from Day 1, '
                        'and cash out unlocks per video once that video crosses 10 hours of watch time.',
                    primaryColor,
                    isDark,
                  ),
                ] else ...[
                  _buildFeatureRow(
                    '100% Gross Revenue Share (minus raw infrastructure usage)',
                    isDark,
                  ),
                  _buildFeatureRow(
                    'Unlimited video uploads & up to 24-hour video length',
                    isDark,
                  ),
                  _buildFeatureRow(
                    'Instant cash withdrawals on all accumulated revenue',
                    isDark,
                  ),
                  _buildFeatureRow(
                    'Full control over media storage and streaming economics',
                    isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildHowItWorksBox(
                    'How Custom Channel Works:',
                    'Custom channels operate on a direct infrastructure cost model. '
                        'You retain 100% of all ad, tip, and subscription revenue, paying only for the actual bandwidth & storage consumed. '
                        'Earnings are available for instant cash-out without watch-time restrictions.',
                    primaryColor,
                    isDark,
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHowItWorksBox(
    String title,
    String description,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
              height: 1.45,
            ),
          ),
        ],
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
          Icon(Icons.monetization_on_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mainText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subText,
                  style: TextStyle(
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
              color: isDark ? AppColors.textSecondary : AppColors.bgPage54,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: isDark
                    ? AppColors.textSecondary
                    : const Color(0xFF334155),
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

/// Reusable Modal / Sheet for selecting Channel Type anywhere in the app
class ChannelTypeSelectorModal extends StatefulWidget {
  const ChannelTypeSelectorModal({
    this.initialPlan = ChannelPlanType.standard,
    this.onSelect,
    super.key,
  });

  final ChannelPlanType initialPlan;
  final ValueChanged<ChannelPlanType>? onSelect;

  static Future<ChannelPlanType?> show(
    BuildContext context, {
    ChannelPlanType initialPlan = ChannelPlanType.standard,
  }) {
    return showModalBottomSheet<ChannelPlanType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: ChannelTypeSelectorModal(
          initialPlan: initialPlan,
          onSelect: (selected) => Navigator.of(ctx).pop(selected),
        ),
      ),
    );
  }

  @override
  State<ChannelTypeSelectorModal> createState() =>
      _ChannelTypeSelectorModalState();
}

class _ChannelTypeSelectorModalState extends State<ChannelTypeSelectorModal> {
  late ChannelPlanType _selectedPlan;

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.initialPlan;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isStandard = _selectedPlan == ChannelPlanType.standard;
    final primaryColor = isStandard
        ? const Color(0xFF3B82F6)
        : const Color(0xFF8B5CF6);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgSurface : AppColors.textPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle & Header
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Channel Type',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimary
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose your channel monetization & infrastructure plan',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondary
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark
                        ? AppColors.textSecondary
                        : const Color(0xFF64748B),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.bgDivider),

          // Scrollable Cards
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Standard Card
                  _buildOptionCard(
                    type: ChannelPlanType.standard,
                    title: 'Standard Channel',
                    subtitle: 'Zero upfront costs • 55% Net Revenue Share',
                    icon: Icons.play_circle_filled,
                    primaryColor: const Color(0xFF3B82F6),
                    gradientStart: const Color(0xFF60A5FA),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  // Custom Card
                  _buildOptionCard(
                    type: ChannelPlanType.custom,
                    title: 'Custom Channel',
                    subtitle:
                        '100% Gross Revenue Share - Infra • Unlimited Uploads',
                    icon: Icons.rocket_launch,
                    primaryColor: const Color(0xFF8B5CF6),
                    gradientStart: const Color(0xFFA78BFA),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 24),

                  // Benefits & How It Works breakdown for selected option
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.stars_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isStandard
                                  ? 'Standard Channel Benefits'
                                  : 'Custom Channel Benefits',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (isStandard) ...[
                          _buildBulletPoint(
                            'Revenue Share: 55% Net Creator Share (\$0 Platform Fee)',
                          ),
                          _buildBulletPoint(
                            'Upload Limit: Up to 5 Videos (Min 2 min per video, 10 min total duration)',
                          ),
                          _buildBulletPoint(
                            'Infrastructure: 100% Free platform hosting & streaming',
                          ),
                          _buildBulletPoint(
                            'Cash-Out Rule: Earnings unlocked after 10 Hours watch time per video',
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: AppColors.bgDivider),
                          const SizedBox(height: 12),
                          Text(
                            'How it Works:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Standard channels require zero technical setup or infrastructure charges. Truthworld manages video transcoding, streaming, and storage. Day-1 ad revenue accumulates automatically.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : const Color(0xFF475569),
                              height: 1.4,
                            ),
                          ),
                        ] else ...[
                          _buildBulletPoint(
                            'Revenue Share: 100% Gross Creator Revenue Share (minus raw infra)',
                          ),
                          _buildBulletPoint(
                            'Upload Limit: Unlimited Videos (up to 24 Hours duration)',
                          ),
                          _buildBulletPoint(
                            'Infrastructure: Custom bandwidth, storage & transcoding control',
                          ),
                          _buildBulletPoint(
                            'Cash-Out Rule: Direct & instant cash withdrawals on all earnings',
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: AppColors.bgDivider),
                          const SizedBox(height: 12),
                          Text(
                            'How it Works:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Custom channels give you maximum economic leverage. You retain 100% of all ad & subscription gross earnings, paying only for the exact cloud bandwidth and storage consumed.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : const Color(0xFF475569),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Continue Action Dock
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgPage : const Color(0xFFF8FAFC),
              border: const Border(top: BorderSide(color: AppColors.bgDivider)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  if (widget.onSelect != null) {
                    widget.onSelect!(_selectedPlan);
                  } else {
                    Navigator.of(context).pop(_selectedPlan);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'Continue with ${isStandard ? 'Standard Channel' : 'Custom Channel'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required ChannelPlanType type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required Color gradientStart,
    required bool isDark,
  }) {
    final isSelected = _selectedPlan == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark
              ? (isSelected ? const Color(0xFF1E293B) : AppColors.bgInput)
              : (isSelected
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradientStart, primaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimary
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondary
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : (isDark ? AppColors.textTertiary : Colors.black26),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
