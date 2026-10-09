import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/data/models/channel_loyalty_badge.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Shows the Create or Edit Membership Tier modal dialog.
void showCreateOrEditTierDialog({
  required BuildContext context,
  required MembershipsController controller,
  required bool isDarkMode,
  ChannelMembershipTier? tier,
}) {
  final isEditing = tier != null;
  final selectedCurrency = (tier?.currency ?? 'USD').obs;
  final nameController = TextEditingController(text: tier?.name ?? '');
  final priceController = TextEditingController(
    text: tier != null
        ? (tier.price == tier.price.truncateToDouble()
            ? tier.price.toInt().toString()
            : tier.price.toStringAsFixed(2))
        : '5',
  );
  final priceRx = (tier?.price ?? 5.0).obs;
  final descController = TextEditingController(text: tier?.description ?? '');
  final customPerkController = TextEditingController();

  final activePerks = <String>[
    if (tier != null) ...tier.perks,
  ].obs;

  final hasPremiumBundle = (tier?.includesPremiumBundle ??
      activePerks.any((p) {
        final s = p.toLowerCase();
        return s.contains('channel premium') ||
            (s.contains('no ads') && (s.contains('2k') || s.contains('4k'))) ||
            s.contains('ad-free') ||
            s.contains('up to 2k');
      })).obs;

  final allAvailablePerks = <String>[
    ...MembershipsController.popularPerkSuggestions,
    ...activePerks.where(
      (p) => !MembershipsController.popularPerkSuggestions.contains(p),
    ),
  ].obs;

  void togglePremiumBundle(bool val) {
    hasPremiumBundle.value = val;
    if (val) {
      if (!activePerks.contains(ChannelMembershipTier.premiumBundlePerkTitle)) {
        activePerks.insert(0, ChannelMembershipTier.premiumBundlePerkTitle);
      }
      if (!allAvailablePerks.contains(ChannelMembershipTier.premiumBundlePerkTitle)) {
        allAvailablePerks.insert(0, ChannelMembershipTier.premiumBundlePerkTitle);
      }
      final curPrice = double.tryParse(priceController.text.trim()) ?? 0.0;
      final curr = selectedCurrency.value;
      final recMin = ChannelMembershipTier.recommendedBundlePriceFor(curr);
      if (curPrice < recMin) {
        priceController.text = curr == 'INR' ? '150' : '5';
        priceRx.value = recMin;
      }
    } else {
      activePerks.removeWhere((p) {
        final s = p.toLowerCase();
        return s == ChannelMembershipTier.premiumBundlePerkTitle.toLowerCase() ||
            s.contains('channel premium') ||
            (s.contains('no ads') && (s.contains('2k') || s.contains('4k'))) ||
            s.contains('ad-free') ||
            s.contains('up to 2k');
      });
    }
  }

  void addCustomPerk(String val) {
    final t = val.trim();
    if (t.isNotEmpty) {
      final pVal = ContentValidator.validate(
        t,
        checkEnglishOnly: false,
        fieldName: 'Perk',
      );
      if (!pVal.isValid) {
        AppSnackbar.warning(pVal.message);
        return;
      }
      if (!allAvailablePerks.contains(t)) {
        allAvailablePerks.insert(0, t);
      }
      if (!activePerks.contains(t)) {
        activePerks.add(t);
      }
      customPerkController.clear();
    }
  }

  void showPerksPickerBottomSheet(BuildContext sheetContext) {
    final sheetCustomPerkController = TextEditingController();

    Get.bottomSheet(
      Material(
        color: const Color(0xFF18181B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          height: 520,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Obx(
                    () => Text(
                      'Select Perks (${activePerks.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'You can pick multiple perks for this channel tier.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              // Channel Premium Features Bundle Card
              Obx(() {
                final isBundleSelected = hasPremiumBundle.value;
                return GestureDetector(
                  onTap: () => togglePremiumBundle(!isBundleSelected),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isBundleSelected
                          ? const Color(0xFF1E1B4B).withValues(alpha: 0.6)
                          : const Color(0xFF1F1F23),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isBundleSelected
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF27272A),
                        width: isBundleSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isBundleSelected
                                ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                                : const Color(0xFF27272A),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            color: isBundleSelected
                                ? const Color(0xFF818CF8)
                                : Colors.white70,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Flexible(
                                    child: Text(
                                      'Channel Premium Bundle',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isBundleSelected
                                          ? Colors.amber.withValues(alpha: 0.2)
                                          : const Color(0xFF3F3F46),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isBundleSelected
                                          ? '70% Creator • 30% Cut'
                                          : '0% Cut',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isBundleSelected
                                            ? Colors.amberAccent
                                            : Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Zero ads & high resolutions up to 2K for entire channel videos.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Checkbox(
                          value: isBundleSelected,
                          onChanged: (val) {
                            togglePremiumBundle(val ?? false);
                          },
                          activeColor: const Color(0xFF6366F1),
                          checkColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF52525B)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: sheetCustomPerkController,
                      inputFormatters: [
                        ...TruthworldTextInputFormatters.standard,
                      ],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add custom perk (e.g. VIP Discord Role)...',
                        hintStyle: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF121212),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF27272A),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF27272A),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      onSubmitted: (val) {
                        addCustomPerk(val);
                        sheetCustomPerkController.clear();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      addCustomPerk(sheetCustomPerkController.text);
                      sheetCustomPerkController.clear();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Obx(
                  () => ListView.builder(
                    itemCount: allAvailablePerks.length,
                    itemBuilder: (context, index) {
                      final perk = allAvailablePerks[index];
                      return Obx(() {
                        final isSelected = activePerks.contains(perk);
                        final isBundlePerk = perk ==
                                ChannelMembershipTier.premiumBundlePerkTitle ||
                            perk.toLowerCase().contains('channel premium');
                        return ListTile(
                          leading: isBundlePerk
                              ? const Icon(
                                  Icons.workspace_premium_rounded,
                                  color: Color(0xFF818CF8),
                                  size: 20,
                                )
                              : null,
                          title: Text(
                            perk,
                            style: TextStyle(
                              color: isSelected
                                  ? (isBundlePerk
                                      ? const Color(0xFFA5B4FC)
                                      : Colors.white)
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (val) {
                              if (isBundlePerk) {
                                togglePremiumBundle(val ?? false);
                              } else {
                                if (isSelected) {
                                  activePerks.remove(perk);
                                } else {
                                  activePerks.add(perk);
                                }
                              }
                            },
                            activeColor: isBundlePerk
                                ? const Color(0xFF6366F1)
                                : Colors.white,
                            checkColor:
                                isBundlePerk ? Colors.white : Colors.black,
                            side: const BorderSide(color: Color(0xFF52525B)),
                          ),
                          onTap: () {
                            if (isBundlePerk) {
                              togglePremiumBundle(!isSelected);
                            } else {
                              if (isSelected) {
                                activePerks.remove(perk);
                              } else {
                                activePerks.add(perk);
                              }
                            }
                          },
                        );
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: Get.back,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  final selectedColorHex = (tier?.badgeColorHex ?? '0xFFF59E0B').obs;
  final nameRx = (tier?.name ?? 'Silver VIP').obs;
  final isSubmitting = false.obs;

  nameController.addListener(() {
    nameRx.value = nameController.text.trim().isEmpty
        ? 'Tier Name'
        : nameController.text.trim();
  });

  priceController.addListener(() {
    final p = double.tryParse(priceController.text.trim());
    if (p != null) priceRx.value = p;
  });

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing
                        ? 'Edit Membership Tier'
                        : 'Create Membership Tier (${(controller.tiers.length + 1).clamp(1, 3)}/3)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppColors.textPrimary
                          : Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Scrollable Form Content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tier Name
                      Text(
                        'TIER NAME',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        inputFormatters: [
                          ...TruthworldTextInputFormatters.standard,
                        ],
                        style: TextStyle(
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'e.g. Bronze Supporter, Silver VIP, Gold Patron',
                          hintStyle: TextStyle(
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black38,
                          ),
                          filled: true,
                          fillColor: AppColors.bgInput,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Monthly Price Header & Currency Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Obx(() => Text(
                            'MONTHLY PRICE (${selectedCurrency.value})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? AppColors.textSecondary
                                  : Colors.black54,
                            ),
                          )),
                          // Currency Toggle (USD vs INR)
                          Obx(() {
                            final cur = selectedCurrency.value;
                            return Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? AppColors.bgInput
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildCurrencyOption(
                                    label: r'USD ($)',
                                    isSelected: cur == 'USD',
                                    isDarkMode: isDarkMode,
                                    onTap: () {
                                      if (selectedCurrency.value != 'USD') {
                                        selectedCurrency.value = 'USD';
                                        final curPrice =
                                            double.tryParse(priceController.text.trim()) ?? 0.0;
                                        if (curPrice >= 10.0 && curPrice != 1.0) {
                                          priceController.text = '5';
                                          priceRx.value = 5.0;
                                        } else if (curPrice < 1.0) {
                                          priceController.text = '1';
                                          priceRx.value = 1.0;
                                        }
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  _buildCurrencyOption(
                                    label: 'INR (₹)',
                                    isSelected: cur == 'INR',
                                    isDarkMode: isDarkMode,
                                    onTap: () {
                                      if (selectedCurrency.value != 'INR') {
                                        selectedCurrency.value = 'INR';
                                        final curPrice =
                                            double.tryParse(priceController.text.trim()) ?? 0.0;
                                        if (curPrice < 10.0) {
                                          priceController.text = '10';
                                          priceRx.value = 10.0;
                                        } else if (curPrice == curPrice.truncateToDouble()) {
                                          priceController.text = curPrice.toInt().toString();
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Obx(() => TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        style: TextStyle(
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          prefixText: selectedCurrency.value == 'INR' ? '₹ ' : r'$ ',
                          prefixStyle: TextStyle(
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          hintText: selectedCurrency.value == 'INR'
                              ? 'e.g. 25 or 50'
                              : 'e.g. 2 or 5',
                          hintStyle: TextStyle(
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black38,
                          ),
                          filled: true,
                          fillColor: AppColors.bgInput,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      )),
                      const SizedBox(height: 6),

                      // Helper text with minimum pricing rule and bundle recommendation
                      Obx(() {
                        final curr = selectedCurrency.value;
                        final isBundle = hasPremiumBundle.value;
                        final minText =
                            ChannelMembershipTier.minPriceLabel(curr);
                        final recText = ChannelMembershipTier
                            .recommendedBundlePriceLabel(curr);
                        return Row(
                          children: [
                            Icon(
                              isBundle
                                  ? Icons.lightbulb_outline_rounded
                                  : Icons.info_outline_rounded,
                              size: 13,
                              color: isBundle ? Colors.amberAccent : Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                isBundle
                                    ? 'Minimum: $minText (Recommended: $recText+ for 2K & Ad-Free bundle)'
                                    : 'Minimum price: $minText',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode
                                      ? (isBundle
                                          ? Colors.amber.shade300
                                          : AppColors.textSecondary)
                                      : (isBundle
                                          ? Colors.amber.shade900
                                          : Colors.black54),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 8),

                      // Quick Price Preset Pills
                      Obx(() {
                        final curr = selectedCurrency.value;
                        final isBundle = hasPremiumBundle.value;
                        final recPrice = ChannelMembershipTier
                            .recommendedBundlePriceFor(curr);
                        final presets = curr == 'INR'
                            ? (isBundle
                                ? [150.0, 200.0, 250.0, 300.0, 500.0]
                                : [10.0, 25.0, 50.0, 100.0, 150.0, 200.0, 300.0])
                            : (isBundle
                                ? [5.0, 7.0, 10.0, 15.0, 20.0, 25.0]
                                : [1.0, 2.0, 5.0, 10.0, 15.0, 20.0, 25.0]);

                        return Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: presets.map((p) {
                            final isWhole = p == p.truncateToDouble();
                            final isRecommendedPill = isBundle && p == recPrice;
                            final label = curr == 'INR'
                                ? '₹${isWhole ? p.toInt() : p.toStringAsFixed(2)}'
                                : '\$${isWhole ? p.toInt() : p.toStringAsFixed(2)}';
                            return GestureDetector(
                              onTap: () {
                                priceController.text = isWhole
                                    ? p.toInt().toString()
                                    : p.toStringAsFixed(2);
                                priceRx.value = p;
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isRecommendedPill
                                      ? (isDarkMode
                                          ? Colors.amber
                                              .withValues(alpha: 0.2)
                                          : Colors.amber.shade50)
                                      : (isDarkMode
                                          ? AppColors.bgSurfaceHigh
                                          : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isRecommendedPill
                                        ? (isDarkMode
                                            ? Colors.amber.shade600
                                            : Colors.amber.shade400)
                                        : (isDarkMode
                                            ? AppColors.bgDivider
                                            : Colors.grey.shade300),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isRecommendedPill) ...[
                                      Icon(
                                        Icons.star_rounded,
                                        size: 13,
                                        color: isDarkMode
                                            ? Colors.amber.shade300
                                            : Colors.amber.shade800,
                                      ),
                                      const SizedBox(width: 3),
                                    ],
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isRecommendedPill
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: isRecommendedPill
                                            ? (isDarkMode
                                                ? Colors.amber.shade300
                                                : Colors.amber.shade900)
                                            : (isDarkMode
                                                ? AppColors.textPrimary
                                                : Colors.black87),
                                      ),
                                    ),
                                    if (isRecommendedPill) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        'Rec',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.amber.shade300
                                              : Colors.amber.shade800,
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
                      const SizedBox(height: 16),

                      // YouTube-Style Standard Loyalty Badges (Automatic Tenure Progression)
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: isDarkMode ? Colors.amberAccent : Colors.amber.shade700,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'LOYALTY BADGES (AUTOMATIC TENURE PROGRESSION)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? AppColors.textSecondary
                                    : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Loyalty badges upgrade beside members’ names in comments and live chat automatically as their tenure grows (New member, 3 months, 6 months, 1 year, 2 years, 3 years, 4 years, 5 years, 7 years, 10 years) — exactly like YouTube.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black54,
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
                              child: ChannelLoyaltyBadgeWidget(
                                milestone: m.milestone,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Text(
                        'DESCRIPTION / WELCOME MESSAGE (OPTIONAL)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descController,
                        inputFormatters: [
                          ...TruthworldTextInputFormatters.standard,
                        ],
                        maxLines: 2,
                        style: TextStyle(
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Briefly tell your fans what makes this tier special...',
                          hintStyle: TextStyle(
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black38,
                          ),
                          filled: true,
                          fillColor: AppColors.bgInput,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Channel Premium Features Bundle Card
                      Text(
                        'PREMIUM FEATURES BUNDLE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Obx(() {
                        final isBundleActive = hasPremiumBundle.value;
                        final currentPrice = priceRx.value;
                        final curr = selectedCurrency.value;
                        final symbol = curr == 'INR' ? '₹' : r'$';
                        final creatorAmount = currentPrice * 0.70;
                        final platformAmount = currentPrice * 0.30;
                        final isWholeCreator =
                            creatorAmount == creatorAmount.truncateToDouble();
                        final isWholePlatform =
                            platformAmount == platformAmount.truncateToDouble();
                        final creatorFormatted = isWholeCreator
                            ? creatorAmount.toInt().toString()
                            : creatorAmount.toStringAsFixed(2);
                        final platformFormatted = isWholePlatform
                            ? platformAmount.toInt().toString()
                            : platformAmount.toStringAsFixed(2);
                        final priceFormatted = currentPrice ==
                                currentPrice.truncateToDouble()
                            ? currentPrice.toInt().toString()
                            : currentPrice.toStringAsFixed(2);

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isBundleActive
                                ? (isDarkMode
                                    ? const Color(0xFF1E1B4B)
                                        .withValues(alpha: 0.5)
                                    : const Color(0xFFEEF2FF))
                                : (isDarkMode
                                    ? AppColors.bgInput
                                    : Colors.grey.shade50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isBundleActive
                                  ? const Color(0xFF6366F1)
                                  : (isDarkMode
                                      ? AppColors.bgDivider
                                      : Colors.grey.shade300),
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
                                          ? const Color(0xFF6366F1)
                                              .withValues(alpha: 0.2)
                                          : (isDarkMode
                                              ? AppColors.bgSurfaceHigh
                                              : Colors.grey.shade200),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.workspace_premium_rounded,
                                      size: 20,
                                      color: isBundleActive
                                          ? const Color(0xFF818CF8)
                                          : (isDarkMode
                                              ? Colors.white70
                                              : Colors.black54),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Channel Premium Bundle',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isDarkMode
                                                    ? AppColors.textPrimary
                                                    : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isBundleActive
                                                    ? Colors.amber
                                                        .withValues(alpha: 0.2)
                                                    : Colors.green
                                                        .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isBundleActive
                                                    ? '70% Creator / 30% Cut'
                                                    : '100% Net (0% Cut)',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isBundleActive
                                                      ? (isDarkMode
                                                          ? Colors
                                                              .amber.shade300
                                                          : Colors
                                                              .amber.shade900)
                                                      : (isDarkMode
                                                          ? Colors
                                                              .green.shade400
                                                          : Colors
                                                              .green.shade800),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'No ads & high resolutions up to 2K for entire channel videos',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDarkMode
                                                ? AppColors.textSecondary
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: isBundleActive,
                                    activeColor: const Color(0xFF6366F1),
                                    onChanged: togglePremiumBundle,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Features List
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.black.withValues(alpha: 0.25)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDarkMode
                                        ? const Color(0xFF27272A)
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: isBundleActive
                                              ? const Color(0xFF818CF8)
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Zero ads on entire channel videos for members of this tier',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: isDarkMode
                                                  ? AppColors.textPrimary
                                                  : Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: isBundleActive
                                              ? const Color(0xFF818CF8)
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'High resolutions up to 2K (1440p QHD) for all channel videos',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: isDarkMode
                                                  ? AppColors.textPrimary
                                                  : Colors.black87,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Revenue Split Live Preview
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
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
                                      size: 13,
                                      color: isBundleActive
                                          ? (isDarkMode
                                              ? Colors.amber.shade300
                                              : Colors.amber.shade800)
                                          : (isDarkMode
                                              ? Colors.green.shade400
                                              : Colors.green.shade800),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        isBundleActive
                                            ? 'Creator receives 70% ($symbol$creatorFormatted/mo) • TruthWorld fee 30% ($symbol$platformFormatted/mo) from $symbol$priceFormatted/mo.'
                                            : 'Creator receives 100% of revenue ($symbol$priceFormatted/mo) with 0% platform commission.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: isBundleActive
                                              ? (isDarkMode
                                                  ? Colors.amber.shade200
                                                  : Colors.amber.shade900)
                                              : (isDarkMode
                                                  ? Colors.green.shade300
                                                  : Colors.green.shade800),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isBundleActive) ...[
                                const SizedBox(height: 8),
                                Builder(builder: (context) {
                                  final recPriceVal = ChannelMembershipTier
                                      .recommendedBundlePriceFor(curr);
                                  final isBelowRecommended =
                                      currentPrice < recPriceVal;
                                  final recPriceStr = ChannelMembershipTier
                                      .recommendedBundlePriceLabel(curr);

                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isBelowRecommended
                                          ? (isDarkMode
                                              ? Colors.amber
                                                  .withValues(alpha: 0.14)
                                              : Colors.amber.shade50)
                                          : (isDarkMode
                                              ? Colors.green
                                                  .withValues(alpha: 0.10)
                                              : Colors.green.shade50),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isBelowRecommended
                                            ? (isDarkMode
                                                ? Colors.amber.shade600
                                                : Colors.amber.shade400)
                                            : (isDarkMode
                                                ? Colors.green.shade700
                                                : Colors.green.shade300),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              isBelowRecommended
                                                  ? Icons.lightbulb_rounded
                                                  : Icons.check_circle_rounded,
                                              size: 15,
                                              color: isBelowRecommended
                                                  ? (isDarkMode
                                                      ? Colors.amber.shade300
                                                      : Colors.amber.shade800)
                                                  : Colors.green,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                isBelowRecommended
                                                    ? 'Recommend pricing the bundle tier at $recPriceStr or higher'
                                                    : 'Optimal Pricing: Healthy Margin ($symbol$priceFormatted/mo)',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: isBelowRecommended
                                                      ? (isDarkMode
                                                          ? Colors.amber.shade300
                                                          : Colors.amber.shade900)
                                                      : (isDarkMode
                                                          ? Colors.green.shade300
                                                          : Colors.green.shade900),
                                                ),
                                              ),
                                            ),
                                            if (isBelowRecommended)
                                              GestureDetector(
                                                onTap: () {
                                                  priceController.text =
                                                      curr == 'INR'
                                                          ? '150'
                                                          : '5';
                                                  priceRx.value = recPriceVal;
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.brand,
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    'Set to $recPriceStr',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          curr == 'INR'
                                              ? "At ₹10, a 30% cut is only ₹3, which could be eroded by heavy 2K video consumption. At ₹150 to ₹300, the creator earns a healthy ₹105 – ₹210 net per member, and TruthWorld's 30% cut comfortably covers CDN bandwidth and video delivery."
                                              : r"At $1, a 30% cut is only $0.30, which could be eroded by heavy 2K video consumption. At $5 to $10, the creator earns a healthy $3.50 – $7.00 net per member, and TruthWorld's 30% cut comfortably covers CDN bandwidth and video delivery.",
                                          style: TextStyle(
                                            fontSize: 11,
                                            height: 1.35,
                                            color: isBelowRecommended
                                                ? (isDarkMode
                                                    ? Colors.amber.shade200
                                                    : Colors.amber.shade900)
                                                : (isDarkMode
                                                    ? Colors.green.shade200
                                                    : Colors.green.shade900),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),

                      // Perks Manager
                      Text(
                        'TIER PERKS & BENEFITS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select one or more perks that members of this tier will receive.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Category-style Selector Box
                      GestureDetector(
                        onTap: () => showPerksPickerBottomSheet(dialogCtx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121212),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF27272A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.stars_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Obx(
                                  () {
                                    if (activePerks.isEmpty) {
                                      return const Text(
                                        'Select perks',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textTertiary,
                                        ),
                                      );
                                    }
                                    return Text(
                                      activePerks.join(', '),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  },
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Category-style Selected Perks Badges / Wrap
                      Obx(() {
                        if (activePerks.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'No perks selected yet. Select perks to incentivize your fans!',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: activePerks.map((perk) {
                              final isBundlePerk = perk ==
                                      ChannelMembershipTier
                                          .premiumBundlePerkTitle ||
                                  perk
                                      .toLowerCase()
                                      .contains('channel premium');
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isBundlePerk
                                      ? const Color(0xFF312E81)
                                      : const Color(0xFF27272A),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isBundlePerk
                                        ? const Color(0xFF6366F1)
                                        : const Color(0xFF3F3F46),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isBundlePerk) ...[
                                      const Icon(
                                        Icons.workspace_premium_rounded,
                                        size: 14,
                                        color: Color(0xFF818CF8),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Flexible(
                                      child: Text(
                                        perk,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isBundlePerk
                                              ? const Color(0xFFA5B4FC)
                                              : Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () {
                                        activePerks.remove(perk);
                                        if (isBundlePerk) {
                                          hasPremiumBundle.value = false;
                                        }
                                      },
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }),
                      const SizedBox(height: 14),

                      // Custom Perk Input
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customPerkController,
                              inputFormatters: [
                                ...TruthworldTextInputFormatters.standard,
                              ],
                              style: TextStyle(
                                color: isDarkMode
                                    ? AppColors.textPrimary
                                    : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Add custom perk (e.g. VIP Discord Role)...',
                                hintStyle: TextStyle(
                                  color: isDarkMode
                                      ? AppColors.textSecondary
                                      : Colors.black38,
                                ),
                                filled: true,
                                fillColor: AppColors.bgInput,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: addCustomPerk,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () =>
                                addCustomPerk(customPerkController.text),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Divider(
                height: 1,
                color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
              ),
              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Obx(() {
                    final loading =
                        isSubmitting.value || controller.isSaving.value;

                    return ElevatedButton(
                      onPressed: loading
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final price =
                                  double.tryParse(
                                    priceController.text.trim(),
                                  ) ??
                                  0.0;
                              final desc = descController.text.trim();
                              final perks = activePerks.toList();
                              final badgeHex = selectedColorHex.value;

                              if (name.isEmpty) {
                                AppSnackbar.warning(
                                  'Please enter a tier name.',
                                );
                                return;
                              }
                              final nameVal = ContentValidator.validate(
                                name,
                                checkEnglishOnly: false,
                                fieldName: 'Tier Name',
                              );
                              if (!nameVal.isValid) {
                                AppSnackbar.warning(nameVal.message);
                                return;
                              }
                              if (desc.isNotEmpty) {
                                final descVal = ContentValidator.validate(
                                  desc,
                                  checkEnglishOnly: false,
                                  fieldName: 'Description',
                                );
                                if (!descVal.isValid) {
                                  AppSnackbar.warning(descVal.message);
                                  return;
                                }
                              }
                              final curr = selectedCurrency.value;
                              final minAllowed =
                                  ChannelMembershipTier.minPriceFor(curr);
                              if (price < minAllowed) {
                                AppSnackbar.warning(
                                  'Minimum price for $curr membership plans is ${ChannelMembershipTier.minPriceLabel(curr)}.',
                                );
                                return;
                              }
                              if (perks.isEmpty) {
                                AppSnackbar.warning(
                                  'Please add at least one perk.',
                                );
                                return;
                              }

                              if (!isEditing && controller.hasReachedMaxTiers) {
                                AppSnackbar.warning(
                                  'Channels can have up to 3 membership tiers only. Please edit or remove an existing tier to add a new one.',
                                );
                                return;
                              }

                              isSubmitting.value = true;
                              bool success;

                              if (isEditing) {
                                success = await controller.updateTier(
                                  tier.copyWith(
                                    name: name,
                                    price: price,
                                    currency: curr,
                                    description: desc,
                                    perks: perks,
                                    badgeColorHex: badgeHex,
                                    hasPremiumBundle: hasPremiumBundle.value,
                                  ),
                                );
                              } else {
                                success = await controller.createTier(
                                  name: name,
                                  price: price,
                                  currency: curr,
                                  description: desc,
                                  perks: perks,
                                  badgeColorHex: badgeHex,
                                  hasPremiumBundle: hasPremiumBundle.value,
                                );
                              }

                              isSubmitting.value = false;
                              if (success && dialogCtx.mounted) {
                                Navigator.pop(dialogCtx);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                          : Text(isEditing ? 'Save Changes' : 'Create Tier'),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildCurrencyOption({
  required String label,
  required bool isSelected,
  required bool isDarkMode,
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
