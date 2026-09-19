import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/wallet/data/models/user_wallet_transaction.dart';
import 'package:truthworld/features/wallet/presentation/controllers/user_wallet_controller.dart';
import 'package:truthworld/features/wallet/presentation/widgets/user_wallet_card.dart';
import 'package:truthworld/features/wallet/presentation/widgets/user_wallet_topup_sheet.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Full screen view for managing the User Wallet, adding money,
/// and reviewing real-time deposits and spends history.
class UserWalletScreen extends GetView<UserWalletController> {
  const UserWalletScreen({super.key});

  @override
  UserWalletController get controller =>
      Get.isRegistered<UserWalletController>()
          ? Get.find<UserWalletController>()
          : Get.put(UserWalletController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text(
          'My Wallet',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: Get.back,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
            tooltip: 'Wallet Info',
            onPressed: () => _showWalletInfoDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.lightImpact();
            await Future<void>.delayed(const Duration(milliseconds: 300));
          },
          color: Colors.white,
          backgroundColor: AppColors.bgSurface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // 1. Main Wallet Card
              const UserWalletCard(),
              const SizedBox(height: 8),

              // 2. Feature Highlights (What you can use wallet for)
              _buildPerksSection(context),
              const SizedBox(height: 16),

              // 3. Transaction History Header & Filter Tabs
              _buildTransactionHeader(context),
              const SizedBox(height: 8),

              // 4. Transactions List / Empty State
              _buildTransactionsList(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerksSection(BuildContext context) {
    final perks = <Map<String, dynamic>>[
      {
        'icon': Icons.chat_bubble_rounded,
        'color': const Color(0xFF3B82F6),
        'title': 'Superchats',
        'desc': 'Send live fan messages instantly with 1 tap during streams.',
      },
      {
        'icon': Icons.card_membership_rounded,
        'color': const Color(0xFF10B981),
        'title': 'Memberships',
        'desc': 'Join channel fan clubs and unlock custom creator badges.',
      },
      {
        'icon': Icons.volunteer_activism_rounded,
        'color': const Color(0xFFF59E0B),
        'title': 'Creator Tipping',
        'desc': 'Support independent fact-checkers & verified journalism.',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WALLET CAPABILITIES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.bgDivider.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: perks.map((item) {
                final icon = item['icon'] as IconData;
                final color = item['color'] as Color;
                final title = item['title'] as String;
                final desc = item['desc'] as String;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            icon,
                            color: color,
                            size: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'TRANSACTION HISTORY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
          Obx(() {
            return Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 6),
                _buildFilterChip('Deposits', 'credit'),
                const SizedBox(width: 6),
                _buildFilterChip('Spends', 'debit'),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = controller.activeFilter.value == filterKey;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        controller.setFilter(filterKey);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsList(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      }

      final list = controller.filteredTransactions;

      if (list.isEmpty) {
        return _buildEmptyState(context);
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final tx = list[index];
          return _buildTransactionTile(context, tx);
        },
      );
    });
  }

  Widget _buildTransactionTile(BuildContext context, UserWalletTransaction tx) {
    final isCredit = tx.isCredit;
    final iconColor = isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final iconData = isCredit
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;
    final timeStr = DateFormat('MMM dd, yyyy • hh:mm a').format(tx.timestamp);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.bgDivider.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.category.displayName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tx.description.isNotEmpty
                      ? tx.description
                      : (isCredit ? 'Money added' : 'Wallet spend'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tx.formattedAmountWithSign,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isCredit ? const Color(0xFF10B981) : Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Bal: ₹${tx.balanceAfter.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.bgDivider.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          const Text(
            'No Transactions Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your deposits and spending activity will appear here in real time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => UserWalletTopupSheet.show(context),
            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.black),
            label: const Text(
              'Add Money Now',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWalletInfoDialog(BuildContext context) {
    Get.dialog<void>(
      AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'About TruthWorld Wallet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TruthWorld User Wallet allows you to store a funded balance for fast, 1-click in-app payments.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            SizedBox(height: 12),
            Text(
              '• 100% Secure via Cashfree Payment Gateway.\n'
              '• Instant deposits using UPI, GPay, PhonePe, Cards, NetBanking.\n'
              '• Zero transaction fee on wallet deposits.\n'
              '• Immediate Superchat and Membership checkout with no PG redirects.',
              style: TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Got it', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
