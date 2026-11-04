import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/tw_radius.dart';

/// Comprehensive Financial History & Immutable Audit Ledger.
/// Retains all credits, debts, and cash payouts up to the 8-Year Industry Standard
/// (Companies Act 2013 s.128, Income Tax Act s.44AA, and IRS 7-Year Tax Accounting Standards).
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
    final rxSelectedType = 'all'.obs; // 'all', 'credit', 'debt', 'payout'
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

    Future<void> loadTransactions({bool forceRefresh = false}) async {
      try {
        rxIsLoading.value = true;
        final start = getStartDateForRange(rxSelectedRange.value);
        final end = getEndDateForRange(rxSelectedRange.value);

        final items = await walletService.fetchHistoricalLedger(
          channelId: channel.id,
          userId: channel.ownerId.isNotEmpty ? channel.ownerId : null,
          startDate: start,
          endDate: end,
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
        final moreItems = await walletService.fetchHistoricalLedger(
          channelId: channel.id,
          userId: channel.ownerId.isNotEmpty ? channel.ownerId : null,
          startDate: start,
          endDate: oldestTimestamp.subtract(const Duration(milliseconds: 1)),
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
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: Get.back,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial History & Ledger',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${channel.name} • 8-Year Statutory Archive',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: 'Export CSV Statement',
            onPressed: () => _exportCsvStatement(
              context,
              channel,
              rxTransactions,
              walletService,
              rxSelectedRange.value,
              getStartDateForRange(rxSelectedRange.value),
              getEndDateForRange(rxSelectedRange.value),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Ledger',
            onPressed: () => loadTransactions(forceRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Period & Range Selector Bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.bgSurface,
            child: Column(
              children: [
                // Date Range Buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildRangeButton('Last 30 Days', '30_days', rxSelectedRange, loadTransactions),
                      const SizedBox(width: 8),
                      _buildRangeButton('Last 90 Days', '90_days', rxSelectedRange, loadTransactions),
                      const SizedBox(width: 8),
                      _buildRangeButton('Current FY (2026-27)', 'current_fy', rxSelectedRange, loadTransactions),
                      const SizedBox(width: 8),
                      _buildRangeButton('Last FY (2025-26)', 'last_fy', rxSelectedRange, loadTransactions),
                      const SizedBox(width: 8),
                      _buildRangeButton('All Time (8-Year Audit)', 'all_time', rxSelectedRange, loadTransactions),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Search Bar
                TextField(
                  onChanged: (val) => rxSearchQuery.value = val.trim().toLowerCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by description, transaction ID, or status...',
                    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 18),
                    filled: true,
                    fillColor: AppColors.bgPage,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Inflow/Outflow Filter Pills
                Row(
                  children: [
                    _buildTypeChip('All Entries', 'all', rxSelectedType),
                    const SizedBox(width: 6),
                    _buildTypeChip('Credits (+)', 'credit', rxSelectedType),
                    const SizedBox(width: 6),
                    _buildTypeChip('Debits (-)', 'debt', rxSelectedType),
                    const SizedBox(width: 6),
                    _buildTypeChip('Cashouts', 'payout', rxSelectedType),
                  ],
                ),
              ],
            ),
          ),

          // ── Real-Time Financial Summary Banner ──
          Obx(() {
            final transactions = rxTransactions;
            var totalCreditsUSD = 0.0;
            var totalDebtsUSD = 0.0;
            var totalCreditsINR = 0.0;
            var totalDebtsINR = 0.0;

            for (final tx in transactions) {
              if (tx.isCredit) {
                if (tx.currency == 'INR') {
                  totalCreditsINR += tx.amount;
                } else {
                  totalCreditsUSD += tx.amount;
                }
              } else {
                if (tx.currency == 'INR') {
                  totalDebtsINR += tx.amount;
                } else {
                  totalDebtsUSD += tx.amount;
                }
              }
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.bgSurfaceHover,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL CREDITS (INFLOW)',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '+₹${totalCreditsINR.toStringAsFixed(0)} / +\$${totalCreditsUSD.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: AppColors.bgDivider),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL DEBITS (OUTFLOW)',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '-₹${totalDebtsINR.toStringAsFixed(0)} / -\$${totalDebtsUSD.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: AppColors.bgDivider),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'TOTAL RECORDS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Obx(
                        () => Text(
                          '${transactions.length}${rxHasMore.value ? '+' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          // ── Ledger Transaction List ──
          Expanded(
            child: Obx(() {
              if (rxIsLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                );
              }

              final query = rxSearchQuery.value;
              final typeFilter = rxSelectedType.value;

              final filtered = rxTransactions.where((tx) {
                // Type Filter
                if (typeFilter == 'credit' && !tx.isCredit) return false;
                if (typeFilter == 'debt' && tx.isCredit) return false;
                if (typeFilter == 'payout' && tx.type != UnifiedTransactionType.payout) return false;

                // Search Query
                if (query.isNotEmpty) {
                  final text = '${tx.title} ${tx.subtitle} ${tx.id} ${tx.status}'.toLowerCase();
                  if (!text.contains(query)) return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'No ledger entries found for this period.',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'All credits, deductions, and payouts will be preserved in this statutory ledger.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final showLoadMore = rxHasMore.value && query.isEmpty;
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: filtered.length + (showLoadMore ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(color: AppColors.bgDivider, height: 12),
                itemBuilder: (context, index) {
                  if (showLoadMore && index == filtered.length) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: rxIsLoadingMore.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : OutlinedButton.icon(
                                onPressed: loadMore,
                                icon: const Icon(Icons.expand_more_rounded, size: 16, color: Colors.white),
                                label: const Text(
                                  'Load Older Records',
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.bgDivider),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                      ),
                    );
                  }
                  final tx = filtered[index];
                  return _buildLedgerCard(context, tx);
                },
              );
            }),
          ),

          // ── Statutory Audit Retention Footer ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.bgSurface,
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.textSecondary, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Immutable statutory ledger preserved for 8 financial years (Companies Act 2013 §128 / IT Act §44AA).',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Date Range Button ──
  Widget _buildRangeButton(String label, String value, RxString activeRange, VoidCallback onSelect) {
    return Obx(() {
      final isSelected = activeRange.value == value;
      return InkWell(
        onTap: () {
          activeRange.value = value;
          onSelect();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : AppColors.bgPage,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? Colors.white : AppColors.bgDivider),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.black : AppColors.textSecondary,
            ),
          ),
        ),
      );
    });
  }

  // ── Inflow/Outflow Filter Chip ──
  Widget _buildTypeChip(String label, String value, RxString activeType) {
    return Obx(() {
      final isSelected = activeType.value == value;
      return Expanded(
        child: InkWell(
          onTap: () => activeType.value = value,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.bgSurfaceHover : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isSelected ? Colors.white70 : AppColors.bgDivider),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    });
  }

  // ── Single Ledger Card Item ──
  Widget _buildLedgerCard(BuildContext context, UnifiedChannelTransaction tx) {
    final formattedDate = DateFormat('yyyy-MM-dd • h:mm a').format(tx.timestamp);

    IconData icon;
    switch (tx.type) {
      case UnifiedTransactionType.topup:
        icon = Icons.add_circle_outline_rounded;
      case UnifiedTransactionType.payout:
        icon = Icons.account_balance_rounded;
      case UnifiedTransactionType.revenueEarned:
        icon = Icons.trending_up_rounded;
      case UnifiedTransactionType.planUpgrade:
        icon = Icons.stars_rounded;
      case UnifiedTransactionType.aiSpend:
        icon = Icons.auto_awesome_rounded;
    }

    final isCredit = tx.isCredit;
    final isPayout = tx.type == UnifiedTransactionType.payout;
    final isRejected = tx.status == 'rejected';
    final isHeld = tx.status == 'held';
    final isProcessing = tx.status == 'processing' || tx.status == 'pending';

    return InkWell(
      onTap: () => _showTransactionAuditDetails(context, tx),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceHover,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          tx.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isPayout) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isRejected
                                ? Colors.red.withValues(alpha: 0.2)
                                : (isHeld
                                    ? Colors.orange.withValues(alpha: 0.2)
                                    : (isProcessing
                                        ? Colors.amber.withValues(alpha: 0.2)
                                        : Colors.green.withValues(alpha: 0.2))),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tx.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isRejected
                                  ? Colors.redAccent
                                  : (isHeld
                                      ? Colors.orangeAccent
                                      : (isProcessing
                                          ? Colors.amberAccent
                                          : Colors.greenAccent)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$formattedDate • ID: ${tx.id.length > 12 ? tx.id.substring(0, 12) : tx.id}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              tx.formattedAmount,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isCredit ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Transaction Audit Detail Modal ──
  void _showTransactionAuditDetails(BuildContext context, UnifiedChannelTransaction tx) {
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
                  'Ledger Audit Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: Get.back,
                ),
              ],
            ),
            const Divider(color: AppColors.bgDivider),
            const SizedBox(height: 8),
            _buildAuditRow('Transaction ID', tx.id),
            _buildAuditRow('Type', tx.type.name),
            _buildAuditRow('Status', tx.status.toUpperCase()),
            _buildAuditRow('Amount', tx.formattedAmount),
            _buildAuditRow('Currency', tx.currency),
            _buildAuditRow('Date & Time', DateFormat('yyyy-MM-dd HH:mm:ss').format(tx.timestamp)),
            _buildAuditRow('Description', tx.title),
            if (tx.metadata != null && tx.metadata!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Audit Metadata', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                tx.metadata.toString(),
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace'),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: 'TX ID: ${tx.id}\nAmount: ${tx.formattedAmount}\nDate: ${tx.timestamp}\nStatus: ${tx.status}'));
                  Get.back<void>();
                  AppSnackbar.success('Audit record copied to clipboard.');
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
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
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
