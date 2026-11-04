import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/channel/data/models/channel_loyalty_badge.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/create_tier_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 100% Responsive, dedicated page for creating or editing Channel Membership Tiers in TruthWorld Studio.
/// Supports Mobile, Tablet, and Desktop widescreen viewports with live fan-facing card preview.
class CreateOrEditTierPage extends StatelessWidget {
  CreateOrEditTierPage({
    required this.controller,
    this.tier,
    this.isDarkMode = true,
    super.key,
  }) : tierController = Get.put(
          CreateTierController(
            membershipsController: controller,
            tier: tier,
            isDarkMode: isDarkMode,
          ),
          tag: tier?.id ?? 'create_tier',
        );

  final MembershipsController controller;
  final ChannelMembershipTier? tier;
  final bool isDarkMode;
  final CreateTierController tierController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.bgPage : AppColors.textPrimary,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 960;
            final isMobile = constraints.maxWidth < 600;

            if (isDesktop) {
              return _buildDesktopLayout(context, constraints);
            }
            return _buildMobileLayout(context, isMobile);
          },
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(context),
    );
  }

  // --- APP BAR ---
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isEditing = tierController.isEditing;
    return AppBar(
      backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: isDarkMode ? AppColors.textPrimary : Colors.black87,
        ),
        tooltip: 'Back to Memberships',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      titleSpacing: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              isEditing ? 'Edit Membership Tier' : 'Create Membership Tier',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.textPrimary : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Obx(() {
            final currentCount = isEditing
                ? controller.tiers.length
                : (controller.tiers.length + 1).clamp(1, 3);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
                  width: 0.8,
                ),
              ),
              child: Text(
                '$currentCount/3 Tiers',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppColors.textSecondary : Colors.black87,
                ),
              ),
            );
          }),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Obx(() {
            final loading = tierController.isSubmitting.value || controller.isSaving.value;
            return TextButton(
              onPressed: loading ? null : tierController.saveTier,
              style: TextButton.styleFrom(
                foregroundColor: isDarkMode ? AppColors.brand : Colors.black,
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isEditing ? 'Save' : 'Create'),
            );
          }),
        ),
      ],
    );
  }

  // --- DESKTOP 2-COLUMN LAYOUT ---
  Widget _buildDesktopLayout(BuildContext context, BoxConstraints constraints) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Form Area
              Expanded(
                flex: 7,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 24, bottom: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderIntro(),
                      const SizedBox(height: 20),
                      _buildTierIdentityCard(),
                      const SizedBox(height: 20),
                      _buildPricingCard(),
                      const SizedBox(height: 20),
                      _buildPremiumBundleCard(),
                      const SizedBox(height: 20),
                      _buildLoyaltyBadgesCard(),
                      const SizedBox(height: 20),
                      _buildDescriptionCard(),
                      const SizedBox(height: 20),
                      _buildPerksCard(context),
                    ],
                  ),
                ),
              ),

              // Right: Sticky Live Fan Preview
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: _buildLiveFanPreviewCard(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MOBILE & TABLET SINGLE-COLUMN LAYOUT ---
  Widget _buildMobileLayout(BuildContext context, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 20,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderIntro(),
          const SizedBox(height: 16),
          _buildTierIdentityCard(),
          const SizedBox(height: 16),
          _buildPricingCard(),
          const SizedBox(height: 16),
          _buildPremiumBundleCard(),
          const SizedBox(height: 16),
          _buildLoyaltyBadgesCard(),
          const SizedBox(height: 16),
          _buildDescriptionCard(),
          const SizedBox(height: 16),
          _buildPerksCard(context),
          const SizedBox(height: 20),
          _buildLiveFanPreviewCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // --- HEADER INTRO ---
  Widget _buildHeaderIntro() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: AppColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tierController.isEditing ? 'Update Membership Tier' : 'Configure New Tier',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Offer exclusive fan benefits and perks. Channels can maintain up to 3 tiers with 0% platform fees.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION 1: TIER IDENTITY & COLOR ---
  Widget _buildTierIdentityCard() {
    return _buildCardWrapper(
      title: 'Tier Identity & Name',
      subtitle: 'Give your tier a recognizable level name and distinctive badge color.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TIER NAME',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: tierController.nameController,
            maxLength: ContentValidator.defaultMaxTierNameLength,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            inputFormatters: TruthworldTextInputFormatters.internationalWithLimit(
              ContentValidator.defaultMaxTierNameLength,
            ),
            style: TextStyle(
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Bronze Supporter, Silver VIP, Gold Patron',
              hintStyle: TextStyle(
                color: isDarkMode ? AppColors.textSecondary : Colors.black38,
                fontSize: 14,
              ),
              filled: true,
              fillColor: isDarkMode ? AppColors.bgInput : Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.success, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'BADGE ACCENT COLOR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Obx(() {
            final activeHex = tierController.selectedColorHex.value;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: CreateTierController.presetColors.map((preset) {
                final isSelected = activeHex.toLowerCase() == preset.hex.toLowerCase();
                return GestureDetector(
                  onTap: () => tierController.selectColor(preset.hex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? preset.color.withValues(alpha: 0.2)
                          : (isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? preset.color : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: preset.color,
                            shape: BoxShape.circle,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 11, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          preset.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? (isDarkMode ? Colors.white : Colors.black87)
                                : (isDarkMode ? AppColors.textSecondary : Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  // --- SECTION 2: MONTHLY PRICING & CURRENCY ---
  Widget _buildPricingCard() {
    return _buildCardWrapper(
      title: 'Monthly Subscription Price',
      subtitle: 'Set a fair monthly recurring price for your channel supporters.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Obx(() => Text(
                    'MONTHLY PRICE (${tierController.selectedCurrency.value})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                    ),
                  )),
              // Currency Toggle
              Obx(() {
                final cur = tierController.selectedCurrency.value;
                return Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppColors.bgInput : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCurrencyButton(
                        label: r'USD ($)',
                        isSelected: cur == 'USD',
                        onTap: () => tierController.selectCurrency('USD'),
                      ),
                      const SizedBox(width: 4),
                      _buildCurrencyButton(
                        label: 'INR (₹)',
                        isSelected: cur == 'INR',
                        onTap: () => tierController.selectCurrency('INR'),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          Obx(() => TextField(
                controller: tierController.priceController,
                maxLength: 6,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  LengthLimitingTextInputFormatter(6),
                ],
                style: TextStyle(
                  color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: tierController.selectedCurrency.value == 'INR' ? '₹ ' : r'$ ',
                  prefixStyle: TextStyle(
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  hintText: tierController.selectedCurrency.value == 'INR' ? '50' : '5',
                  hintStyle: TextStyle(
                    color: isDarkMode ? AppColors.textSecondary : Colors.black38,
                  ),
                  filled: true,
                  fillColor: isDarkMode ? AppColors.bgInput : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 6),
          // Helper text
          Obx(() {
            final curr = tierController.selectedCurrency.value;
            final isBundle = tierController.hasPremiumBundle.value;
            final minText = ChannelMembershipTier.minPriceLabel(curr);
            final recText = ChannelMembershipTier.recommendedBundlePriceLabel(curr);
            return Row(
              children: [
                Icon(
                  isBundle ? Icons.lightbulb_outline_rounded : Icons.info_outline_rounded,
                  size: 14,
                  color: isBundle ? Colors.amberAccent : (isDarkMode ? Colors.white70 : Colors.black54),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isBundle
                        ? 'Minimum: $minText (Recommended: $recText+ for Ad-Free & 2K bundle)'
                        : 'Minimum price: $minText',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode
                          ? (isBundle ? Colors.amber.shade300 : AppColors.textSecondary)
                          : (isBundle ? Colors.amber.shade900 : Colors.black54),
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 10),
          // Quick Price Presets
          Obx(() {
            final curr = tierController.selectedCurrency.value;
            final isBundle = tierController.hasPremiumBundle.value;
            final recPrice = ChannelMembershipTier.recommendedBundlePriceFor(curr);
            final presets = curr == 'INR'
                ? (isBundle
                    ? [150.0, 200.0, 250.0, 300.0, 500.0]
                    : [50.0, 100.0, 150.0, 200.0, 300.0, 500.0])
                : (isBundle
                    ? [5.0, 7.0, 10.0, 15.0, 20.0, 25.0]
                    : [1.0, 2.0, 5.0, 10.0, 15.0, 20.0, 25.0]);

            return Wrap(
              spacing: 8,
              runSpacing: 6,
              children: presets.map((p) {
                final isWhole = p == p.truncateToDouble();
                final isRecommendedPill = isBundle && p == recPrice;
                final isCurrent = tierController.priceRx.value == p;
                final label = curr == 'INR'
                    ? '₹${isWhole ? p.toInt() : p.toStringAsFixed(2)}'
                    : '\$${isWhole ? p.toInt() : p.toStringAsFixed(2)}';

                return GestureDetector(
                  onTap: () => tierController.selectPrice(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? (isDarkMode ? AppColors.brand : Colors.black)
                          : (isRecommendedPill
                              ? (isDarkMode ? Colors.amber.withValues(alpha: 0.2) : Colors.amber.shade50)
                              : (isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade100)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCurrent
                            ? (isDarkMode ? AppColors.brand : Colors.black)
                            : (isRecommendedPill
                                ? (isDarkMode ? Colors.amber.shade600 : Colors.amber.shade400)
                                : (isDarkMode ? AppColors.bgDivider : Colors.grey.shade300)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRecommendedPill && !isCurrent) ...[
                          Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: isDarkMode ? Colors.amber.shade300 : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCurrent
                                ? (isDarkMode ? Colors.black : Colors.white)
                                : (isRecommendedPill
                                    ? (isDarkMode ? Colors.amber.shade300 : Colors.amber.shade900)
                                    : (isDarkMode ? AppColors.textPrimary : Colors.black87)),
                          ),
                        ),
                        if (isRecommendedPill && !isCurrent) ...[
                          const SizedBox(width: 3),
                          Text(
                            'Rec',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.amber.shade300 : Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  // --- SECTION 3: CHANNEL PREMIUM BUNDLE ---
  Widget _buildPremiumBundleCard() {
    return Obx(() {
      final isBundleActive = tierController.hasPremiumBundle.value;
      final currentPrice = tierController.priceRx.value;
      final curr = tierController.selectedCurrency.value;
      final symbol = curr == 'INR' ? '₹' : r'$';
      final isCustom = controller.isCustomChannel.value;
      final standardCreatorAmount = currentPrice * 0.90;
      final standardCreatorFormatted = standardCreatorAmount == standardCreatorAmount.truncateToDouble()
          ? standardCreatorAmount.toInt().toString()
          : standardCreatorAmount.toStringAsFixed(2);
      final creatorAmount = currentPrice * 0.70;
      final platformAmount = currentPrice * 0.30;
      final creatorFormatted = creatorAmount == creatorAmount.truncateToDouble()
          ? creatorAmount.toInt().toString()
          : creatorAmount.toStringAsFixed(2);
      final platformFormatted = platformAmount == platformAmount.truncateToDouble()
          ? platformAmount.toInt().toString()
          : platformAmount.toStringAsFixed(2);
      final priceFormatted = currentPrice == currentPrice.truncateToDouble()
          ? currentPrice.toInt().toString()
          : currentPrice.toStringAsFixed(2);

      final recPriceVal = ChannelMembershipTier.recommendedBundlePriceFor(curr);
      final isBelowRecommended = currentPrice < recPriceVal;
      final recPriceStr = ChannelMembershipTier.recommendedBundlePriceLabel(curr);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isBundleActive
              ? (isDarkMode ? const Color(0xFF1E1B4B).withValues(alpha: 0.5) : const Color(0xFFEEF2FF))
              : (isDarkMode ? AppColors.bgSurface : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isBundleActive
                ? AppColors.info
                : (isDarkMode ? AppColors.bgDivider : Colors.grey.shade200),
            width: isBundleActive ? 1.5 : 1,
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
                    color: isBundleActive
                        ? AppColors.info.withValues(alpha: 0.2)
                        : (isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade200),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    size: 20,
                    color: isBundleActive
                        ? AppColors.info
                        : (isDarkMode ? Colors.white70 : Colors.black54),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Channel Premium Bundle',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isBundleActive
                                  ? Colors.amber.withValues(alpha: 0.2)
                                  : Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              isBundleActive
                                  ? '70% Creator / 30% Cut'
                                  : (isCustom ? '100% Net (0% Cut)' : '90% Net (10% Fee)'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isBundleActive
                                    ? (isDarkMode ? Colors.amber.shade300 : Colors.amber.shade900)
                                    : (isDarkMode ? Colors.green.shade400 : Colors.green.shade800),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Zero ads & high resolutions up to 2K for all channel videos',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isBundleActive,
                  activeColor: AppColors.info,
                  onChanged: tierController.togglePremiumBundle,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Bundle Benefits
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.black.withValues(alpha: 0.3) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode ? AppColors.bgSurface : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBenefitRow(
                    'Zero ads on all videos for members of this tier',
                    isBundleActive,
                  ),
                  const SizedBox(height: 4),
                  _buildBenefitRow(
                    'High resolutions up to 2K (1440p QHD) streaming enabled',
                    isBundleActive,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Revenue Split Notice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isBundleActive
                    ? Colors.amber.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: isBundleActive
                        ? (isDarkMode ? Colors.amber.shade300 : Colors.amber.shade800)
                        : (isDarkMode ? Colors.green.shade400 : Colors.green.shade800),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isBundleActive
                          ? 'Creator receives 70% ($symbol$creatorFormatted/mo) • TruthWorld fee 30% ($symbol$platformFormatted/mo) from $symbol$priceFormatted/mo.'
                          : (isCustom
                              ? 'Creator receives 100% of revenue ($symbol$priceFormatted/mo) with 0% platform commission.'
                              : 'Creator receives 90% of revenue ($symbol$standardCreatorFormatted/mo) with 10% platform fee.'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isBundleActive
                            ? (isDarkMode ? Colors.amber.shade200 : Colors.amber.shade900)
                            : (isDarkMode ? Colors.green.shade300 : Colors.green.shade800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isBundleActive && isBelowRecommended) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.amber.withValues(alpha: 0.14) : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode ? Colors.amber.shade600 : Colors.amber.shade400,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_rounded,
                      size: 16,
                      color: isDarkMode ? Colors.amber.shade300 : Colors.amber.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recommend setting price to $recPriceStr+ to maintain healthy creator earnings.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.amber.shade200 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => tierController.selectPrice(recPriceVal),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text('Set $recPriceStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  // --- SECTION 4: LOYALTY BADGES ---
  Widget _buildLoyaltyBadgesCard() {
    return _buildCardWrapper(
      title: 'YouTube-Grade Loyalty Badges',
      subtitle: 'Tenure upgrades automatically beside subscriber names as their membership matures.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: isDarkMode ? Colors.amberAccent : Colors.amber.shade700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'AUTOMATIC TENURE PROGRESSION (INCLUDED FREE)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Subscribers automatically level up from New Member, 3 months, 6 months, 1 year, 2 years, up to 10 years in comments and community discussions.',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ChannelLoyaltyBadge.allMilestones.map((m) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChannelLoyaltyBadgeWidget(milestone: m.milestone),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION 5: DESCRIPTION ---
  Widget _buildDescriptionCard() {
    return _buildCardWrapper(
      title: 'Description & Welcome Message (Optional)',
      subtitle: 'Tell your fans why they should join this level and what to expect.',
      child: TextField(
        controller: tierController.descController,
        maxLength: ContentValidator.defaultMaxTierDescLength,
        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
        inputFormatters: TruthworldTextInputFormatters.internationalWithLimit(
          ContentValidator.defaultMaxTierDescLength,
        ),
        maxLines: 3,
        style: TextStyle(
          color: isDarkMode ? AppColors.textPrimary : Colors.black87,
          fontSize: 13.5,
        ),
        decoration: InputDecoration(
          hintText: 'Briefly tell your fans what makes this tier special...',
          hintStyle: TextStyle(
            color: isDarkMode ? AppColors.textSecondary : Colors.black38,
            fontSize: 13,
          ),
          filled: true,
          fillColor: isDarkMode ? AppColors.bgInput : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
            ),
          ),
        ),
      ),
    );
  }

  // --- SECTION 6: PERKS & BENEFITS ---
  Widget _buildPerksCard(BuildContext context) {
    return _buildCardWrapper(
      title: 'Tier Perks & Benefits',
      subtitle: 'Add benefits and special privileges that fans in this tier receive.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Perks List
          Obx(() {
            final perks = tierController.activePerks;
            if (perks.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'At least one perk is required before saving this tier.',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: perks.map((perk) {
                final isBundle = perk == ChannelMembershipTier.premiumBundlePerkTitle ||
                    perk.toLowerCase().contains('channel premium');
                return Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isBundle
                        ? const Color(0xFF312E81)
                        : (isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isBundle
                          ? AppColors.info
                          : (isDarkMode ? AppColors.bgDivider : Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isBundle) ...[
                        const Icon(
                          Icons.workspace_premium_rounded,
                          size: 14,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          perk,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isBundle
                                ? const Color(0xFFA5B4FC)
                                : (isDarkMode ? Colors.white : Colors.black87),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => tierController.removePerk(perk),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
          const SizedBox(height: 14),

          // Custom Perk Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: tierController.customPerkController,
                  maxLength: ContentValidator.defaultMaxPerkLength,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: TruthworldTextInputFormatters.withLimit(
                    ContentValidator.defaultMaxPerkLength,
                  ),
                  style: TextStyle(
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add custom perk (e.g. VIP Discord Role)...',
                    hintStyle: TextStyle(
                      color: isDarkMode ? AppColors.textSecondary : Colors.black38,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: isDarkMode ? AppColors.bgInput : Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  onSubmitted: tierController.addCustomPerk,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => tierController.addCustomPerk(
                  tierController.customPerkController.text,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Suggested Perks
          Text(
            'QUICK-ADD POPULAR PERKS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Obx(() {
            final active = tierController.activePerks;
            final suggestions = MembershipsController.popularPerkSuggestions
                .where((p) => !active.contains(p))
                .take(4)
                .toList();

            if (suggestions.isEmpty) return const SizedBox.shrink();

            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: suggestions.map((p) {
                return GestureDetector(
                  onTap: () => tierController.addCustomPerk(p),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 240),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 13, color: AppColors.success),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            p,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? AppColors.textSecondary : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  // --- SECTION 7: LIVE FAN PREVIEW CARD ---
  Widget _buildLiveFanPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.remove_red_eye_rounded, size: 16, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                'LIVE FAN PREVIEW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Fan Card Simulation
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [AppColors.bgPage, const Color(0xFF09090B)]
                    : [Colors.grey.shade50, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Badge & Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Obx(() {
                        final title = tierController.nameRx.value.isEmpty
                            ? 'Your Tier Name'
                            : tierController.nameRx.value;
                        final colorHex = tierController.selectedColorHex.value;
                        final color = Color(int.tryParse(colorHex) ?? 0xFF10B981);

                        return Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                    Obx(() {
                      final isBundle = tierController.hasPremiumBundle.value;
                      if (!isBundle) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.info.withValues(alpha: 0.5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.workspace_premium_rounded, size: 12, color: AppColors.info),
                            SizedBox(width: 4),
                            Text(
                              'Premium',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.info),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 12),

                // Price display
                Obx(() {
                  final curr = tierController.selectedCurrency.value;
                  final p = tierController.priceRx.value;
                  final isWhole = p == p.truncateToDouble();
                  final priceStr = curr == 'INR'
                      ? '₹${isWhole ? p.toInt() : p.toStringAsFixed(2)}'
                      : '\$${isWhole ? p.toInt() : p.toStringAsFixed(2)}';

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        priceStr,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/month',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
                ),
                const SizedBox(height: 12),

                // Benefits summary list
                Text(
                  'INCLUDED PERKS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() {
                  final perks = tierController.activePerks;
                  if (perks.isEmpty) {
                    return Text(
                      'No perks selected yet',
                      style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white38 : Colors.black38),
                    );
                  }
                  return Column(
                    children: perks.map((p) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                }),
                const SizedBox(height: 16),

                // Join button simulation
                Container(
                  width: double.infinity,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Join Tier',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Fan Funding Projection Summary
          Obx(() {
            final curr = tierController.selectedCurrency.value;
            final isBundle = tierController.hasPremiumBundle.value;
            final price = tierController.priceRx.value;
            final netPerMember = isBundle ? price * 0.70 : price;
            final symbol = curr == 'INR' ? '₹' : r'$';
            final hundredMembersIncome = netPerMember * 100;
            final formattedIncome = hundredMembersIncome == hundredMembersIncome.truncateToDouble()
                ? hundredMembersIncome.toInt().toString()
                : hundredMembersIncome.toStringAsFixed(2);

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up_rounded, size: 18, color: AppColors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '100 members = $symbol$formattedIncome/mo net recurring fan revenue for you.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- BOTTOM ACTION BAR ---
  Widget _buildBottomActionBar(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final cancelButton = OutlinedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDarkMode ? AppColors.textPrimary : Colors.black87,
            side: BorderSide(
              color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Cancel'),
        );

        final submitButton = Obx(() {
          final loading = tierController.isSubmitting.value || controller.isSaving.value;
          return ElevatedButton(
            onPressed: loading ? null : tierController.saveTier,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text(tierController.isEditing ? 'Save Changes' : 'Create Tier'),
          );
        });

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.bgSurface : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
              ),
            ),
          ),
          child: isMobile
              ? Row(
                  children: [
                    Expanded(child: cancelButton),
                    const SizedBox(width: 12),
                    Expanded(child: submitButton),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    cancelButton,
                    const SizedBox(width: 12),
                    submitButton,
                  ],
                ),
        );
      },
    );
  }

  // --- REUSABLE CARD WRAPPER ---
  Widget _buildCardWrapper({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildCurrencyButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? AppColors.bgSurfaceHigh : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? (isDarkMode ? AppColors.textPrimary : Colors.black87)
                : (isDarkMode ? AppColors.textSecondary : Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(String text, bool isActive) {
    return Row(
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 14,
          color: isActive ? AppColors.info : Colors.grey,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
