import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/widgets/creator_kyc_dialog.dart';
import 'package:truthworld/features/analytics/presentation/widgets/manage_bank_account_dialog.dart';
import 'package:truthworld/features/analytics/presentation/widgets/revenue_withdrawal_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Production-grade Revenue Analytics Page.
/// Displays all revenue streams that the channel has earned with authentic
/// Firestore data and 100% compliant icon styling (Colors.white).
class RevenueAnalyticsPage extends StatelessWidget {
  const RevenueAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RevenueAnalyticsController.to;
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final channelId = args['channelId'] as String? ?? '';
    final channelName = args['channelName'] as String? ?? 'Channel';
    final revenueChange = args['revenueChange'] as String? ?? r'+$0.00';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (channelId.isNotEmpty) {
        controller.loadRevenueAnalytics(
          channelId,
          chName: channelName,
          change: revenueChange,
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: Get.back,
        ),
        title: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Revenue Analytics',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              if (controller.channelName.value.isNotEmpty)
                Text(
                  controller.channelName.value,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Analytics',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: controller.refreshData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        if (controller.rxIsLoading.value && controller.totalRevenue.value == 0.0) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFFF59E0B),
          onRefresh: controller.refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroMetricCard(controller),
                const SizedBox(height: 18),
                _buildWithdrawalThresholdCard(context, controller),
                const SizedBox(height: 14),
                _buildDirectBankAccountCard(context, controller),
                const SizedBox(height: 14),
                _buildCreatorKycCard(context, controller),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  title: 'Ways You Earned',
                  badge: 'All Active Streams',
                ),
                const SizedBox(height: 14),
                _buildMembershipsStreamCard(controller),
                const SizedBox(height: 14),
                _buildSuperchatStreamCard(controller),
                const SizedBox(height: 14),
                _buildAdRevenueStreamCard(controller),
                const SizedBox(height: 14),
                _buildWatchTimeStreamCard(controller),
                const SizedBox(height: 24),
                _buildRevenueDistributionCard(controller),
                const SizedBox(height: 24),
                _buildPayoutAndUsabilityCard(controller),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? badge,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeroMetricCard(RevenueAnalyticsController controller) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF18181B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF312E81)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Estimated Revenue',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      controller.revenueChange.value,
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '₹${controller.totalRevenue.value.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPillTag(
                icon: Icons.verified_rounded,
                label: '0% Platform Fee on Fan Support',
                color: const Color(0xFF10B981),
              ),
              _buildPillTag(
                icon: Icons.calendar_today_rounded,
                label: 'Last 28 days',
                color: const Color(0xFF6366F1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. Channel Memberships Stream ──────────────────────────────────────────
  Widget _buildMembershipsStreamCard(RevenueAnalyticsController controller) {
    final income = controller.membershipsRevenue.value;
    final members = controller.activeMembersCount.value;
    final tiers = controller.activeTiersCount.value;

    return _buildStreamContainer(
      icon: Icons.card_membership_rounded,
      accentColor: const Color(0xFF10B981),
      title: 'Channel Memberships & Fan Funding',
      subtitle: '$members Direct Supporter${members == 1 ? '' : 's'} • $tiers Active Tier${tiers == 1 ? '' : 's'}',
      amount: '₹${income.toStringAsFixed(2)}',
      badgeText: '100% Direct Payout (0% Platform Fee)',
      badgeColor: const Color(0xFF10B981),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _buildSplitRow(
            label: 'Gross Recurring Income',
            value: '₹${income.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 6),
          _buildSplitRow(
            label: 'Platform Cut / Commission',
            value: '0.0% (₹0.00)',
            isGreen: true,
          ),
          const SizedBox(height: 6),
          _buildSplitRow(
            label: 'Creator Net Payout',
            value: '₹${income.toStringAsFixed(2)}',
            isBold: true,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: controller.navigateToMemberships,
              icon: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 16),
              label: const Text('Manage Memberships & Tiers'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Superchats Stream ───────────────────────────────────────────────────
  Widget _buildSuperchatStreamCard(RevenueAnalyticsController controller) {
    final amount = controller.superchatRevenue.value;
    final creatorCut = amount * 0.70;

    return _buildStreamContainer(
      icon: Icons.bolt_rounded,
      accentColor: const Color(0xFFF59E0B),
      title: 'Superchats & Live Fan Support',
      subtitle: 'Instant fan contributions and highlighted messages during live streams',
      amount: '₹${amount.toStringAsFixed(2)}',
      badgeText: '70% Creator Split',
      badgeColor: const Color(0xFFF59E0B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _buildSplitRow(
            label: 'Gross Live Earnings',
            value: '₹${amount.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 6),
          _buildSplitRow(
            label: 'Platform Share (30%)',
            value: '₹${(amount * 0.30).toStringAsFixed(2)}',
          ),
          const SizedBox(height: 6),
          _buildSplitRow(
            label: 'Creator Share (70%)',
            value: '₹${creatorCut.toStringAsFixed(2)}',
            isBold: true,
          ),
        ],
      ),
    );
  }

  // ── 3. Video Ads Stream ───────────────────────────────────────────────────
  Widget _buildAdRevenueStreamCard(RevenueAnalyticsController controller) {
    final amount = controller.adsRevenue.value;
    final views = controller.totalViews.value;
    final creatorCut = amount * 0.70;

    return _buildStreamContainer(
      icon: Icons.ondemand_video_rounded,
      accentColor: const Color(0xFF3B82F6),
      title: 'Video Ads & Monetization',
      subtitle: '$views View${views == 1 ? '' : 's'} • Day 1 Monetization Enabled',
      amount: '₹${amount.toStringAsFixed(2)}',
      badgeText: '70% Creator Split',
      badgeColor: const Color(0xFF3B82F6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _buildSplitRow(
            label: 'Estimated RPM (Per 1K Views)',
            value: views > 0
                ? '₹${((amount / views) * 1000).toStringAsFixed(2)}'
                : '₹50.00',
          ),
          const SizedBox(height: 6),
          _buildSplitRow(
            label: 'Platform Share (30%)',
            value: '₹${(amount * 0.30).toStringAsFixed(2)}',
          ),
          const SizedBox(height: 6),
          _buildSplitRow(
            label: 'Creator Share (70%)',
            value: '₹${creatorCut.toStringAsFixed(2)}',
            isBold: true,
          ),
        ],
      ),
    );
  }

  // ── 4. Watch Time Royalties Stream ─────────────────────────────────────────
  Widget _buildWatchTimeStreamCard(RevenueAnalyticsController controller) {
    final amount = controller.watchTimeRevenue.value;
    final mins = controller.totalWatchMinutes.value;
    final creatorCut = amount * 0.70;

    return _buildStreamContainer(
      icon: Icons.timer_rounded,
      accentColor: const Color(0xFF8B5CF6),
      title: 'Watch Time & Premium Royalties',
      subtitle: '$mins Mins Watch Time • Subscriber Retention Royalty',
      amount: '₹${amount.toStringAsFixed(2)}',
      badgeText: '70% Creator Split',
      badgeColor: const Color(0xFF8B5CF6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _buildSplitRow(
            label: 'Total Watch Time Accumulated',
            value: '$mins min${mins == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 6),
          _buildSplitRow(
            label: 'Platform Share (30%)',
            value: '₹${(amount * 0.30).toStringAsFixed(2)}',
          ),
          const SizedBox(height: 6),
          _buildSplitRow(
            label: 'Creator Share (70%)',
            value: '₹${creatorCut.toStringAsFixed(2)}',
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStreamContainer({
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required String amount,
    required String badgeText,
    required Color badgeColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121218),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                amount,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildSplitRow({
    required String label,
    required String value,
    bool isBold = false,
    bool isGreen = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isGreen
                ? const Color(0xFF10B981)
                : (isBold ? AppColors.textPrimary : AppColors.textSecondary),
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Revenue Distribution Bar ───────────────────────────────────────────────
  Widget _buildRevenueDistributionCard(RevenueAnalyticsController controller) {
    final total = controller.totalRevenue.value;
    final memberships = controller.membershipsRevenue.value;
    final superchats = controller.superchatRevenue.value;
    final ads = controller.adsRevenue.value;
    final watchTime = controller.watchTimeRevenue.value;

    final memPct = total > 0 ? (memberships / total) : (memberships > 0 ? 1.0 : 0.0);
    final scPct = total > 0 ? (superchats / total) : 0.0;
    final adsPct = total > 0 ? (ads / total) : 0.0;
    final wtPct = total > 0 ? (watchTime / total) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121218),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue Distribution',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Contribution by earning method for this channel',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (memPct > 0)
                    Expanded(
                      flex: (memPct * 1000).toInt().clamp(1, 1000),
                      child: Container(color: const Color(0xFF10B981)),
                    ),
                  if (scPct > 0)
                    Expanded(
                      flex: (scPct * 1000).toInt().clamp(1, 1000),
                      child: Container(color: const Color(0xFFF59E0B)),
                    ),
                  if (adsPct > 0)
                    Expanded(
                      flex: (adsPct * 1000).toInt().clamp(1, 1000),
                      child: Container(color: const Color(0xFF3B82F6)),
                    ),
                  if (wtPct > 0)
                    Expanded(
                      flex: (wtPct * 1000).toInt().clamp(1, 1000),
                      child: Container(color: const Color(0xFF8B5CF6)),
                    ),
                  if (total == 0)
                    Expanded(
                      child: Container(color: const Color(0xFF334155)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem(
                label: 'Memberships: ${(memPct * 100).toStringAsFixed(0)}%',
                color: const Color(0xFF10B981),
              ),
              _buildLegendItem(
                label: 'Superchats: ${(scPct * 100).toStringAsFixed(0)}%',
                color: const Color(0xFFF59E0B),
              ),
              _buildLegendItem(
                label: 'Ads: ${(adsPct * 100).toStringAsFixed(0)}%',
                color: const Color(0xFF3B82F6),
              ),
              _buildLegendItem(
                label: 'Watch Time: ${(wtPct * 100).toStringAsFixed(0)}%',
                color: const Color(0xFF8B5CF6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({required String label, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  // ── Payout Terms & AI Usability ────────────────────────────────────────────
  Widget _buildPayoutAndUsabilityCard(RevenueAnalyticsController controller) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121218),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF27272A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Creator Payout & Terms',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Payout Schedule: Monthly automatic transfer to your verified creator account.\n'
            '• Zero-Debt Guarantee: Payout is protected at a floor of ₹0.00 — creator balance never goes negative.\n'
            '• Instant AI Features: Unwithdrawn revenue can be used anytime for AI Subtitles and Dubbing!',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: controller.navigateToMonetization,
              icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
              label: const Text('Monetization & Payout Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Withdrawal & 100 Rupees Minimum Threshold Section ─────────────────────
  Widget _buildWithdrawalThresholdCard(
    BuildContext context,
    RevenueAnalyticsController controller,
  ) {
    final available = controller.totalRevenue.value;
    final canWithdraw = controller.canWithdraw;
    final remaining = controller.remainingToWithdraw;
    final progress = controller.withdrawalProgress;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121218),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canWithdraw ? const Color(0xFF10B981) : const Color(0xFF27272A),
          width: canWithdraw ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (canWithdraw ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cash Payout & Withdrawal',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      canWithdraw
                          ? 'Available for cash withdrawal to your bank or UPI'
                          : 'Minimum cash withdrawal threshold is ₹100 (100 Rupees)',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (canWithdraw ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (canWithdraw ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  canWithdraw ? 'Unlocked' : 'Min ₹100',
                  style: TextStyle(
                    color: canWithdraw ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Progress Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available: ₹${available.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Threshold: ₹100 (100 Rupees)',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF27272A),
                valueColor: AlwaysStoppedAnimation(
                  canWithdraw ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            canWithdraw
                ? 'Your channel balance has reached ₹100! Cash withdrawals are unlocked.'
                : '₹${remaining.toStringAsFixed(2)} more needed to reach the ₹100 (100 Rupees) cash withdrawal threshold.',
            style: TextStyle(
              color: canWithdraw ? const Color(0xFF10B981) : AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (canWithdraw) {
                  RevenueWithdrawalDialog.show(context);
                } else {
                  _showThresholdNoticeDialog(context, controller);
                }
              },
              icon: Icon(
                canWithdraw ? Icons.payments_rounded : Icons.lock_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                canWithdraw ? 'Withdraw Funds' : 'Withdraw Earnings (Minimum ₹100)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canWithdraw ? const Color(0xFF10B981) : const Color(0xFF27272A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: canWithdraw ? const Color(0xFF10B981) : const Color(0xFF3F3F46),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Instant AI Tool note
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Instant Use: You do not need to wait for ₹100 to use your earnings — your balance of ₹${available.toStringAsFixed(2)} is immediately usable for AI Subtitles and Dubbing!',
                    style: const TextStyle(
                      color: Color(0xFFC7D2FE),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showThresholdNoticeDialog(
    BuildContext context,
    RevenueAnalyticsController controller,
  ) {
    Get.defaultDialog(
      title: 'Withdrawal Threshold: ₹100 (100 Rupees)',
      backgroundColor: const Color(0xFF18181B),
      titleStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'The minimum cash withdrawal threshold is ₹100 (100 Rupees).'
              '\n\n'
              'Your current accumulated earnings are ₹${controller.totalRevenue.value.toStringAsFixed(2)}. '
              'You need ₹${controller.remainingToWithdraw.toStringAsFixed(2)} more in creator revenue to unlock direct cash withdrawals.'
              '\n\n'
              'Platform Advantage: 100% of your earnings can be spent immediately anytime on platform AI features (Subtitles, Dubbing, and Highlights) without meeting the ₹100 payout gate!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
      textConfirm: 'Got it',
      confirmTextColor: Colors.black,
      buttonColor: const Color(0xFFF59E0B),
      onConfirm: Get.back,
    );
  }

  // ── Direct Bank Account Card ───────────────────────────────────────────────
  Widget _buildDirectBankAccountCard(
    BuildContext context,
    RevenueAnalyticsController controller,
  ) {
    return Obx(() {
      final bank = controller.savedBankAccount.value;
      final isLinked = bank != null && bank.accountNumber.isNotEmpty;

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF121218),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLinked
                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                : const Color(0xFF27272A),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isLinked ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Direct Bank Account Arrangement',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isLinked
                            ? 'Ready for instant NEFT / IMPS revenue credit'
                            : 'Set up your bank account for direct revenue withdrawals',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isLinked ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (isLinked ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    isLinked ? 'Ready for Payout' : 'Setup Required',
                    style: TextStyle(
                      color: isLinked ? const Color(0xFF10B981) : const Color(0xFF60A5FA),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isLinked) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF09090B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bank.bankName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${bank.maskedAccountNumber} • ${bank.accountHolderName} (${bank.accountType})',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'IFSC: ${bank.formattedIfsc}',
                          style: const TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: () => ManageBankAccountDialog.show(context),
                      icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                      label: const Text('Update'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: Color(0xFF3F3F46)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => ManageBankAccountDialog.show(context),
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  label: const Text('Add Bank Account for Direct Payouts'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  // ── Creator KYC Document Verification Card ─────────────────────────────────
  Widget _buildCreatorKycCard(
    BuildContext context,
    RevenueAnalyticsController controller,
  ) {
    return Obx(() {
      final isVerified = controller.isKycVerified;
      final isPending = controller.isKycPending;
      final isRejected = controller.isKycRejected;
      final kyc = controller.creatorKyc.value;

      Color badgeBg;
      Color badgeBorder;
      Color badgeTextColor;
      String badgeLabel;
      IconData icon;

      if (isVerified) {
        badgeBg = const Color(0xFF10B981).withValues(alpha: 0.15);
        badgeBorder = const Color(0xFF10B981).withValues(alpha: 0.3);
        badgeTextColor = const Color(0xFF10B981);
        badgeLabel = 'KYC Verified';
        icon = Icons.verified_rounded;
      } else if (isPending) {
        badgeBg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        badgeBorder = const Color(0xFFF59E0B).withValues(alpha: 0.3);
        badgeTextColor = const Color(0xFFF59E0B);
        badgeLabel = 'Under Review';
        icon = Icons.hourglass_top_rounded;
      } else if (isRejected) {
        badgeBg = const Color(0xFFEF4444).withValues(alpha: 0.15);
        badgeBorder = const Color(0xFFEF4444).withValues(alpha: 0.3);
        badgeTextColor = const Color(0xFFEF4444);
        badgeLabel = 'Action Required';
        icon = Icons.error_outline_rounded;
      } else {
        badgeBg = const Color(0xFF3B82F6).withValues(alpha: 0.15);
        badgeBorder = const Color(0xFF3B82F6).withValues(alpha: 0.3);
        badgeTextColor = const Color(0xFF60A5FA);
        badgeLabel = 'Verification Needed';
        icon = Icons.assignment_ind_outlined;
      }

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF121218),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isVerified
                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                : const Color(0xFF27272A),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Creator Identity Verification (KYC)',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'PAN & Government ID verification for bank payouts',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeBorder),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isVerified && kyc != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF09090B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PAN: ${kyc.maskedPan} (${kyc.panLegalName})',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Verified ID: ${kyc.identityProofType.displayName} • Payouts Active',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => CreatorKycDialog.show(context),
                      child: const Text(
                        'Details',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                isPending
                    ? 'Your documents have been submitted and are currently being reviewed by our compliance team.'
                    : (isRejected
                        ? (kyc?.rejectionReason ?? 'Document verification check failed. Please re-upload your valid government ID.')
                        : 'In compliance with financial regulations, verify your PAN and Government ID to enable direct bank payouts.'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => CreatorKycDialog.show(context),
                  icon: const Icon(Icons.verified_user_outlined, color: Colors.white, size: 16),
                  label: Text(
                    isPending
                        ? 'View / Update Submitted Documents'
                        : (isRejected ? 'Resubmit KYC Documents' : 'Complete KYC Verification'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isRejected ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                    side: BorderSide(
                      color: (isRejected ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)).withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
