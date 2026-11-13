import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/channel_wallet_topup_sheet.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/tw_radius.dart';

/// Comprehensive Financial History & Immutable Audit Ledger.
/// Retains all credits, debts, and cash payouts up to the 8-Year Industry Standard
/// (Companies Act 2013 s.128, Income Tax Act s.44AA, and IRS 7-Year Tax Accounting Standards).
/// Styled with ElevenLabs & Stripe-grade high-contrast clarity and precision.
class ChannelFinancialHistoryPage extends StatelessWidget {
  const ChannelFinancialHistoryPage({
    required this.channel,
    super.key,
  });

  final Channel channel;

  static void show(BuildContext context, {required Channel channel}) {
    Get.to<void>(
      () => ChannelFinancialHistoryPage(channel: channel),
      transition: Transition.rightToLeft,
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletService = ChannelWalletService();

    final rxSelectedRange = '30_days'.obs;
    final rxSelectedType = 'all'.obs; // 'all', 'topup', 'aiSpend', 'payout', 'revenueEarned'
    final rxSearchQuery = ''.obs;
    final rxIsLoading = true.obs;
    final rxIsLoadingMore = false.obs;
    final rxHasMore = true.obs;
    final rxTransactions = <UnifiedChannelTransaction>[].obs;
    const pageSize = 30;

    DateTime? getStartDateForRange(String range) {
      final now = DateTime.now();
      switch (range) {
        case '30_days':
          return now.subtract(const Duration(days: 30));
        case '90_days':
          return now.subtract(const Duration(days: 90));
        case 'current_fy':
          // Current Indian Fiscal Year (Apr 1 to Mar 31)
          final year = now.month >= 4 ? now.year : now.year - 1;
          return DateTime(year, 4);
        case 'last_fy':
          final year = (now.month >= 4 ? now.year : now.year - 1) - 1;
          return DateTime(year, 4);
        case 'all_time':
        default:
          // 8-Year Statutory Record Retention (Companies Act 2013 s.128)
          return now.subtract(const Duration(days: 365 * 8));
      }
    }

    DateTime? getEndDateForRange(String range) {
      final now = DateTime.now();
      if (range == 'last_fy') {
        final year = (now.month >= 4 ? now.year : now.year - 1);
        return DateTime(year, 3, 31, 23, 59, 59);
      }
      return now;
    }

    UnifiedTransactionType? resolveFilterType(String typeKey) {
      switch (typeKey) {
        case 'topup':
          return UnifiedTransactionType.topup;
        case 'aiSpend':
          return UnifiedTransactionType.aiSpend;
        case 'payout':
          return UnifiedTransactionType.payout;
        case 'revenueEarned':
          return UnifiedTransactionType.revenueEarned;
        default:
          return null;
      }
    }

    Future<void> loadTransactions({bool forceRefresh = false}) async {
      try {
        rxIsLoading.value = true;
        final start = getStartDateForRange(rxSelectedRange.value);
        final end = getEndDateForRange(rxSelectedRange.value);
        final filter = resolveFilterType(rxSelectedType.value);

        final items = await walletService.fetchHistoricalLedger(
          channelId: channel.id,
          userId: channel.ownerId.isNotEmpty ? channel.ownerId : null,
          startDate: start,
          endDate: end,
          filterType: filter,
          forceRefresh: forceRefresh,
        );
        rxTransactions.assignAll(items);
        rxHasMore.value = items.length >= pageSize;
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'ChannelFinancialHistoryPage.load');
        AppSnackbar.error('Unable to load transaction history. Please try again.');
      } finally {
        rxIsLoading.value = false;
      }
    }

    Future<void> loadMore() async {
      if (rxIsLoadingMore.value || !rxHasMore.value || rxTransactions.isEmpty) return;
      try {
        rxIsLoadingMore.value = true;
        final start = getStartDateForRange(rxSelectedRange.value);
        final oldestTimestamp = rxTransactions.last.timestamp;
        final filter = resolveFilterType(rxSelectedType.value);
        final moreItems = await walletService.fetchHistoricalLedger(
          channelId: channel.id,
          userId: channel.ownerId.isNotEmpty ? channel.ownerId : null,
          startDate: start,
          endDate: oldestTimestamp.subtract(const Duration(milliseconds: 1)),
          filterType: filter,
          forceRefresh: true,
        );
        if (moreItems.isEmpty) {
          rxHasMore.value = false;
        } else {
          final existingIds = rxTransactions.map((e) => e.id).toSet();
          final newUnique = moreItems.where((e) => !existingIds.contains(e.id)).toList();
          rxTransactions.addAll(newUnique);
          if (moreItems.length < pageSize) {
            rxHasMore.value = false;
          }
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'ChannelFinancialHistoryPage.loadMore');
      } finally {
        rxIsLoadingMore.value = false;
      }
    }

    // Trigger initial load
    loadTransactions();

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: Get.back,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial History & Ledger',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${channel.name} • 8-Year Statutory Archive',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Ledger',
            onPressed: () => loadTransactions(forceRefresh: true),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Export CSV Statement',
            onPressed: () {
              final start = getStartDateForRange(rxSelectedRange.value);
              final end = getEndDateForRange(rxSelectedRange.value);
              _exportCsvStatement(
                context,
                channel,
                rxTransactions,
                walletService,
                rxSelectedRange.value,
                start,
                end,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
            loadMore();
          }
          return false;
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Summary & Wallet Quick Action Banner ──
              _buildWalletOverviewBanner(context, channel),
              const SizedBox(height: 16),

              // ── Statutory Record Retention Standard Banner ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Statutory 8-Year Audit Archive: Transactions, billing receipts, and creator payout records are immutably preserved (Companies Act 2013 §128 & IT Act §44AA).',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Date Range Selector ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Obx(
                  () => Row(
                    children: [
                      _buildRangeChip('30_days', 'Last 30 Days', rxSelectedRange, loadTransactions),
                      _buildRangeChip('90_days', 'Last 90 Days', rxSelectedRange, loadTransactions),
                      _buildRangeChip('current_fy', _getCurrentFyLabel(), rxSelectedRange, loadTransactions),
                      _buildRangeChip('last_fy', _getLastFyLabel(), rxSelectedRange, loadTransactions),
                      _buildRangeChip('all_time', 'All Time (8-Year Audit)', rxSelectedRange, loadTransactions),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Type Filter Selector ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Obx(
                  () => Row(
                    children: [
                      _buildTypeChip('all', 'All Activity', rxSelectedType, loadTransactions),
                      _buildTypeChip('topup', 'Wallet Deposits', rxSelectedType, loadTransactions),
                      _buildTypeChip('aiSpend', 'Dubbing & AI Spends', rxSelectedType, loadTransactions),
                      _buildTypeChip('payout', 'Cash Payouts', rxSelectedType, loadTransactions),
                      _buildTypeChip('revenueEarned', 'Monthly Settlements', rxSelectedType, loadTransactions),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Search & Filter Input ──
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (val) => rxSearchQuery.value = val.trim().toLowerCase(),
                  decoration: const InputDecoration(
                    hintText: 'Search by video title, transaction ID, or service...',
                    hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Inflow vs Outflow KPI Bar ──
              Obx(() {
                final filtered = _filterTransactions(rxTransactions, rxSearchQuery.value);
                final totalCredits = filtered.where((t) => t.isCredit).fold<double>(0.0, (acc, t) => acc + t.amount);
                final totalDebits = filtered.where((t) => !t.isCredit).fold<double>(0.0, (acc, t) => acc + t.amount);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL CREDITS (INFLOW)',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '+${totalCredits.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: AppColors.bgDivider),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL DEBITS (OUTFLOW)',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '-${totalDebits.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),

              // ── Transactions Ledger List ──
              Obx(() {
                if (rxIsLoading.value) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  );
                }

                final filtered = _filterTransactions(rxTransactions, rxSearchQuery.value);

                if (filtered.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.bgDivider),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: AppColors.textTertiary, size: 36),
                        const SizedBox(height: 12),
                        const Text(
                          'No Transactions Found',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rxSearchQuery.value.isNotEmpty
                              ? 'No records match "${rxSearchQuery.value}".'
                              : 'No financial activity recorded in this date range.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length + (rxHasMore.value ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index >= filtered.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                      );
                    }
                    final tx = filtered[index];
                    return _buildTransactionCard(context, tx);
                  },
                );
              }),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Wallet Overview & Action Banner ──
  Widget _buildWalletOverviewBanner(BuildContext context, Channel channel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Wallet Balance',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${channel.walletBalanceUSD.toStringAsFixed(2)} USD',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Spendable on Dubbing (ElevenLabs), Subtitles & Tools',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              ChannelWalletTopupSheet.show(
                context,
                channel: channel,
                onTopupSuccess: () {
                  ChannelWalletService.invalidateLedgerCache(channelId: channel.id);
                  Get.back<void>();
                  ChannelFinancialHistoryPage.show(context, channel: channel);
                },
              );
            },
            icon: const Icon(Icons.add_rounded, color: Colors.black, size: 16),
            label: const Text(
              'Add Money',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: TWRadius.mdBorderRadius,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──
  static String _getCurrentFyLabel() {
    final now = DateTime.now();
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    final endYear = (startYear + 1) % 100;
    return 'Current FY ($startYear-${endYear.toString().padLeft(2, '0')})';
  }

  static String _getLastFyLabel() {
    final now = DateTime.now();
    final startYear = (now.month >= 4 ? now.year : now.year - 1) - 1;
    final endYear = (startYear + 1) % 100;
    return 'Last FY ($startYear-${endYear.toString().padLeft(2, '0')})';
  }

  List<UnifiedChannelTransaction> _filterTransactions(
    List<UnifiedChannelTransaction> list,
    String query,
  ) {
    if (query.isEmpty) return list;
    return list.where((t) {
      final titleMatch = t.title.toLowerCase().contains(query);
      final subtitleMatch = t.subtitle.toLowerCase().contains(query);
      final idMatch = t.id.toLowerCase().contains(query);
      final metadataMatch = t.metadata?.values.any((v) => v.toString().toLowerCase().contains(query)) ?? false;
      return titleMatch || subtitleMatch || idMatch || metadataMatch;
    }).toList();
  }

  Widget _buildRangeChip(
    String key,
    String label,
    RxString rxSelectedRange,
    Future<void> Function({bool forceRefresh}) loadTransactions,
  ) {
    final isSelected = rxSelectedRange.value == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          rxSelectedRange.value = key;
          loadTransactions(forceRefresh: true);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : AppColors.bgSurfaceHover,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? Colors.white : AppColors.bgDivider),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.black : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(
    String key,
    String label,
    RxString rxSelectedType,
    Future<void> Function({bool forceRefresh}) loadTransactions,
  ) {
    final isSelected = rxSelectedType.value == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          rxSelectedType.value = key;
          loadTransactions(forceRefresh: true);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.bgSurfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? Colors.white : AppColors.bgDivider),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, UnifiedChannelTransaction tx) {
    final isCredit = tx.isCredit;
    final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(tx.timestamp);
    final isTopup = tx.type == UnifiedTransactionType.topup;
    final isDubbing = tx.title.toLowerCase().contains('dubbing') || tx.subtitle.toLowerCase().contains('dubbing');
    final isSubtitles = tx.title.toLowerCase().contains('subtitles') || tx.subtitle.toLowerCase().contains('subtitles');

    IconData getIcon() {
      if (isTopup) return Icons.add_card_rounded;
      if (isDubbing) return Icons.record_voice_over_rounded;
      if (isSubtitles) return Icons.subtitles_rounded;
      if (tx.type == UnifiedTransactionType.payout) return Icons.account_balance_rounded;
      if (tx.type == UnifiedTransactionType.revenueEarned) return Icons.trending_up_rounded;
      return Icons.receipt_long_rounded;
    }

    return InkWell(
      onTap: () => _showAuditDetailsModal(context, tx),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.bgDivider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceHover,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
              ),
              child: Icon(getIcon(), color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tx.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurfaceHover,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          tx.status.toUpperCase(),
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formattedDate,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        tx.formattedAmount,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isCredit ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Audit Details Bottom Sheet ──
  void _showAuditDetailsModal(BuildContext context, UnifiedChannelTransaction tx) {
    Get.bottomSheet<void>(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transaction Audit Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: Get.back,
                ),
              ],
            ),
            const Divider(color: AppColors.bgDivider),
            const SizedBox(height: 8),
            _buildAuditRow('Transaction ID', tx.id),
            _buildAuditRow('Type', tx.type.name),
            _buildAuditRow('Category', tx.subtitle),
            _buildAuditRow('Amount', tx.formattedAmount),
            _buildAuditRow('Currency', tx.currency),
            _buildAuditRow('Status', tx.status.toUpperCase()),
            _buildAuditRow('Timestamp', DateFormat('yyyy-MM-dd HH:mm:ss').format(tx.timestamp)),
            if (tx.metadata != null && tx.metadata!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Execution & Provider Metadata:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              ...tx.metadata!.entries.take(5).map((e) => _buildAuditRow(e.key, e.value.toString())),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: 'TX ID: ${tx.id}\nAmount: ${tx.formattedAmount}\nDate: ${tx.timestamp.toIso8601String()}\nStatus: ${tx.status}'));
                  Get.back<void>();
                  AppSnackbar.info('Audit record copied to clipboard.');
                },
                icon: const Icon(Icons.copy_rounded, color: Colors.black, size: 16),
                label: const Text('Copy Audit Record'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: TWRadius.mdBorderRadius),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── CSV Statement Export Action ──
  void _exportCsvStatement(
    BuildContext context,
    Channel channel,
    List<UnifiedChannelTransaction> transactions,
    ChannelWalletService walletService,
    String rangeLabel,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (transactions.isEmpty) {
      AppSnackbar.info('No transactions to export for the selected period.');
      return;
    }

    final csvContent = walletService.generateFinancialStatementCSV(
      channelName: channel.name,
      channelId: channel.id,
      transactions: transactions,
      startDate: startDate,
      endDate: endDate,
    );

    Get.bottomSheet<void>(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Export Financial Statement',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: Get.back,
                ),
              ],
            ),
            const Divider(color: AppColors.bgDivider),
            const SizedBox(height: 8),
            Text(
              'Generated RFC-4180 compliant CSV statement for ${transactions.length} records. Retained in accordance with the 8-Year Statutory Record Retention Policy.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              constraints: const BoxConstraints(maxHeight: 120),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: SingleChildScrollView(
                child: Text(
                  csvContent,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontFamily: 'monospace'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: csvContent));
                  Get.back<void>();
                  AppSnackbar.success(
                    'Financial Statement CSV copied to clipboard. You can paste it directly into Excel or Google Sheets.',
                    title: 'Statement Exported',
                  );
                },
                icon: const Icon(Icons.copy_all_rounded, color: Colors.black, size: 16),
                label: const Text('Copy CSV Statement to Clipboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: TWRadius.mdBorderRadius),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
