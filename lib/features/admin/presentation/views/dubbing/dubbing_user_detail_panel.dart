import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Placeholder panel shown when no user account is currently selected.
class DubbingEmptyDetailPanel extends StatelessWidget {
  const DubbingEmptyDetailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.record_voice_over_outlined,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select a User Account',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a user account from the list to manage their dubbing wallet, grant free character credits, and configure special discounts or 100% free waivers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Right detail pane: displays user dubbing stats, credit grant controls,
/// special discount configurations, and live wallet ledger.
class DubbingUserDetailPanel extends StatelessWidget {
  final AdminController controller;
  final Map<String, dynamic> user;
  final bool isModal;

  const DubbingUserDetailPanel({
    required this.controller,
    required this.user,
    this.isModal = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = (user['photoURL'] ?? '').toString();
    final name = (user['displayName'] ?? 'User').toString();
    final email = (user['email'] ?? '').toString();
    final userId = (user['id'] ?? user['uid'] ?? '').toString();

    // Reactive form state using GetX observables (Zero setState)
    final creditAmountText = '10000'.obs;
    final usdBonusText = '0'.obs;
    final grantReasonText = 'Creator Partnership Grant'.obs;
    final grantMode = 'add'.obs; // 'add' or 'set'

    final selectedDiscountType = ((user['specialDiscountType'] ?? 'none').toString()).obs;
    final customDiscountPercent = (((user['specialDiscountPercent'] as num?)?.toDouble() ?? 20.0).round()).obs;
    final discountReasonText = ((user['discountReason'] ?? 'VIP Creator Waiver').toString()).obs;
    final applyToChannels = true.obs;

    final creditController = TextEditingController(text: '10000');
    final usdController = TextEditingController(text: '0');
    final grantReasonController = TextEditingController(text: 'Creator Partnership Grant');
    final customDiscountController = TextEditingController(text: customDiscountPercent.value.toString());
    final discountReasonController = TextEditingController(text: discountReasonText.value);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: isModal ? null : BorderRadius.circular(16),
        border: isModal ? null : Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.bgSurface,
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: userId));
                              AppSnackbar.info('User ID copied to clipboard');
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.copy_rounded, size: 12, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    userId.length > 8 ? '${userId.substring(0, 8)}...' : userId,
                                    style: const TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email.isNotEmpty ? email : 'No email associated',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Live Stats Cards Row
            Obx(() {
              final wallet = controller.selectedDubbingWallet.value;
              final balanceCredits = wallet?.balanceCredits ?? (user['balanceCredits'] as num?)?.toInt() ?? 0;
              final balanceUsd = wallet?.balanceUsd ?? (user['balanceUsd'] as num?)?.toDouble() ?? 0.0;
              final totalUsed = wallet?.totalCharactersUsed ?? (user['totalCharactersUsed'] as num?)?.toInt() ?? 0;
              final isFree = wallet?.isDubbingFree ?? user['isDubbingFree'] == true;
              final discountPercent = wallet?.specialDiscountPercent ?? (user['specialDiscountPercent'] as num?)?.toDouble() ?? 0.0;

              return Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'CREDIT BALANCE',
                      value: '${balanceCredits.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} chars',
                      subtitle: '\$${balanceUsd.toStringAsFixed(2)} USD',
                      icon: Icons.bolt_rounded,
                      iconColor: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'LIFETIME USED',
                      value: '${totalUsed.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} chars',
                      subtitle: 'Consumed by user',
                      icon: Icons.history_rounded,
                      iconColor: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'SPECIAL DISCOUNT',
                      value: isFree
                          ? '100% FREE'
                          : discountPercent > 0
                              ? '${discountPercent.round()}% OFF'
                              : 'Standard (0%)',
                      subtitle: isFree ? 'Full Dubbing Waiver' : discountPercent > 0 ? 'Discounted Rate' : 'No Active Discount',
                      icon: Icons.local_offer_rounded,
                      iconColor: isFree ? Colors.greenAccent : discountPercent > 0 ? Colors.amberAccent : AppColors.textTertiary,
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 24),
            // ACTION CARD 1: GRANT FREE CREDITS
            _buildActionSectionCard(
              title: 'Grant Free Dubbing Credits',
              subtitle: 'Allocate complimentary speech synthesis characters directly into the user’s wallet.',
              icon: Icons.card_giftcard_rounded,
              iconColor: Colors.greenAccent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Round Presets',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5000, 10000, 25000, 50000, 100000].map((preset) {
                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () {
                          creditController.text = preset.toString();
                          creditAmountText.value = preset.toString();
                        },
                        child: Text(
                          '+${preset.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} chars',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Character Amount
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Character Amount',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: creditController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (v) => creditAmountText.value = v,
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                suffixText: 'characters',
                                suffixStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.04),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Bonus USD (optional)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bonus USD (\$)',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: usdController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (v) => usdBonusText.value = v,
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                prefixText: '\$ ',
                                prefixStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.04),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Memo / Reason
                  const Text(
                    'Audit Reason / Purpose',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: grantReasonController,
                    onChanged: (v) => grantReasonText.value = v,
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Creator Partnership Grant, VIP User Beta...',
                      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Grant Button (Zero White-on-White Compliant)
                  Obx(
                    () => ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: controller.isSavingDubbingAction.value
                          ? null
                          : () async {
                              final credits = int.tryParse(creditAmountText.value) ?? 0;
                              if (credits <= 0) {
                                AppSnackbar.warning('Please enter a valid character credit amount.');
                                return;
                              }
                              final usd = double.tryParse(usdBonusText.value) ?? 0.0;
                              await controller.grantFreeDubbingCredits(
                                targetUserId: userId,
                                amountCredits: credits,
                                amountUsd: usd,
                                reason: grantReasonText.value,
                                mode: grantMode.value,
                              );
                            },
                      child: controller.isSavingDubbingAction.value
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.black),
                                SizedBox(width: 8),
                                Text(
                                  'Grant Free Credits',
                                  style: TextStyle(
                                    fontFamily: TWTypography.brandFamily,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ACTION CARD 2: SPECIAL DUBBING DISCOUNTS & FREE WAIVER
            _buildActionSectionCard(
              title: 'Special Dubbing Discounts & Free Waiver',
              subtitle: 'Configure persistent discounted billing or 100% free speech synthesis for this account.',
              icon: Icons.local_offer_rounded,
              iconColor: Colors.amberAccent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Discount Tier',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Obx(() {
                    final current = selectedDiscountType.value;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTierChip('Standard (0%)', 'none', current, () {
                          selectedDiscountType.value = 'none';
                        }),
                        _buildTierChip('20% Off', '20%', current, () {
                          selectedDiscountType.value = 'percent';
                          customDiscountPercent.value = 20;
                          customDiscountController.text = '20';
                        }),
                        _buildTierChip('30% Off', '30%', current, () {
                          selectedDiscountType.value = 'percent';
                          customDiscountPercent.value = 30;
                          customDiscountController.text = '30';
                        }),
                        _buildTierChip('50% Off', '50%', current, () {
                          selectedDiscountType.value = 'percent';
                          customDiscountPercent.value = 50;
                          customDiscountController.text = '50';
                        }),
                        _buildTierChip('100% Free Waiver', 'free', current, () {
                          selectedDiscountType.value = 'free';
                          customDiscountPercent.value = 100;
                        }, isFreeTier: true),
                        _buildTierChip('Custom %', 'custom', current, () {
                          selectedDiscountType.value = 'custom';
                        }),
                      ],
                    );
                  }),
                  Obx(() {
                    if (selectedDiscountType.value == 'custom') {
                      return Padding(
                        padding: const EdgeInsets.only(top: 14.0),
                        child: Row(
                          children: [
                            const Text(
                              'Custom Discount: ',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: customDiscountController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onChanged: (v) {
                                  final num = int.tryParse(v) ?? 0;
                                  customDiscountPercent.value = num.clamp(0, 100);
                                },
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  suffixText: '%',
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.04),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  const SizedBox(height: 14),
                  // Scope checkbox
                  Obx(
                    () => InkWell(
                      onTap: () => applyToChannels.toggle(),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: applyToChannels.value,
                                onChanged: (v) => applyToChannels.value = v ?? true,
                                activeColor: Colors.white,
                                checkColor: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Apply discount to all YouTube/Video AI Dubbing jobs in user’s channels',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Audit Reason / Notes',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: discountReasonController,
                    onChanged: (v) => discountReasonText.value = v,
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. VIP Creator Partner Agreement',
                      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Save Discount Button
                  Obx(
                    () => ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: controller.isSavingDubbingAction.value
                          ? null
                          : () async {
                              final type = selectedDiscountType.value;
                              double percent = 0.0;
                              if (type == 'free') {
                                percent = 100.0;
                              } else if (type == 'none') {
                                percent = 0.0;
                              } else {
                                percent = customDiscountPercent.value.toDouble();
                              }

                              await controller.updateDubbingSpecialDiscount(
                                targetUserId: userId,
                                discountPercent: percent,
                                discountType: type,
                                reason: discountReasonText.value,
                                applyToChannels: applyToChannels.value,
                              );
                            },
                      child: controller.isSavingDubbingAction.value
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.black),
                                SizedBox(width: 8),
                                Text(
                                  'Save Special Discount',
                                  style: TextStyle(
                                    fontFamily: TWTypography.brandFamily,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ACTION CARD 3: WALLET LEDGER & AUDIT HISTORY
            _buildActionSectionCard(
              title: 'Wallet Activity Ledger',
              subtitle: 'Transparent ledger of all credit grants, usage debits, and promotional allocations.',
              icon: Icons.history_edu_rounded,
              iconColor: Colors.lightBlueAccent,
              child: Obx(() {
                final wallet = controller.selectedDubbingWallet.value;
                final txs = wallet?.transactions ?? [];

                if (txs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      'No wallet transactions recorded yet for this account.',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: txs.length.clamp(0, 10),
                  separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.06), height: 16),
                  itemBuilder: (context, idx) {
                    final tx = txs[idx];
                    final isGrant = tx.type == 'trial_credit' || tx.type == 'topup';

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isGrant ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isGrant ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            size: 14,
                            color: isGrant ? Colors.greenAccent : Colors.redAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.description.isNotEmpty ? tx.description : tx.type,
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tx.timestamp.toLocal().toString().split('.')[0],
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${isGrant ? '+' : '-'}${tx.amountCredits.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} chars',
                              style: TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: isGrant ? Colors.greenAccent : AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (tx.amountUsd > 0)
                              Text(
                                '\$${tx.amountUsd.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierChip(
    String label,
    String key,
    String current,
    VoidCallback onTap, {
    bool isFreeTier = false,
  }) {
    final isSelected = current == key ||
        (key == '20%' && current == 'percent') ||
        (key == '30%' && current == 'percent') ||
        (key == '50%' && current == 'percent');

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isFreeTier ? Colors.green.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.2))
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isFreeTier ? Colors.greenAccent : Colors.white)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
