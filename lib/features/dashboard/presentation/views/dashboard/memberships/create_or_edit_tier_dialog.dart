import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
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
        ? (tier.currency == 'INR' && tier.price == tier.price.truncateToDouble()
            ? tier.price.toInt().toString()
            : tier.price.toStringAsFixed(2))
        : '4.99',
  );
  final descController = TextEditingController(text: tier?.description ?? '');
  final customPerkController = TextEditingController();

  final activePerks = <String>[
    if (tier != null)
      ...tier.perks
    else ...[
      'Loyalty badge beside channel comments',
      'Custom emojis in live chat',
      'Early access to new videos',
    ],
  ].obs;

  final selectedColorHex = (tier?.badgeColorHex ?? '0xFFF59E0B').obs;
  final nameRx = (tier?.name ?? 'Silver VIP').obs;
  final priceRx = (tier?.price ?? 4.99).obs;
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
                        : 'Create Membership Tier',
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
                          fillColor: isDarkMode
                              ? AppColors.bgInput
                              : const Color(0xFFF1F5F9),
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
                                    : const Color(0xFFE2E8F0),
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
                                        if (curPrice >= 10.0 && curPrice != 0.10) {
                                          priceController.text = '4.99';
                                          priceRx.value = 4.99;
                                        } else if (curPrice < 0.10) {
                                          priceController.text = '0.10';
                                          priceRx.value = 0.10;
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
                              ? 'e.g. 10 or 59'
                              : 'e.g. 0.10 or 4.99',
                          hintStyle: TextStyle(
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black38,
                          ),
                          filled: true,
                          fillColor: isDarkMode
                              ? AppColors.bgInput
                              : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      )),
                      const SizedBox(height: 6),

                      // Helper text with minimum pricing rule
                      Obx(() {
                        final curr = selectedCurrency.value;
                        final minText = ChannelMembershipTier.minPriceLabel(curr);
                        return Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Minimum price: $minText',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode
                                    ? AppColors.textSecondary
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 8),

                      // Quick Price Preset Pills
                      Obx(() {
                        final curr = selectedCurrency.value;
                        final presets = curr == 'INR'
                            ? [10.0, 29.0, 59.0, 89.0, 159.0, 199.0, 299.0]
                            : [0.10, 0.99, 1.99, 4.99, 9.99, 19.99, 24.99];

                        return Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: presets.map((p) {
                            final label = curr == 'INR'
                                ? '₹${p == p.truncateToDouble() ? p.toInt() : p.toStringAsFixed(2)}'
                                : '\$${p.toStringAsFixed(2)}';
                            return GestureDetector(
                              onTap: () {
                                priceController.text = curr == 'INR' && p == p.truncateToDouble()
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
                                  color: isDarkMode
                                      ? AppColors.bgSurfaceHigh
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDarkMode
                                        ? AppColors.bgDivider
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? AppColors.textPrimary
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      }),
                      const SizedBox(height: 16),

                      // Loyalty Badge Color Selector
                      Text(
                        'LOYALTY BADGE COLOR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Obx(() {
                        final curHex = selectedColorHex.value;
                        return Row(
                          children: MembershipsController.presetBadgeColors.map((
                            colorMap,
                          ) {
                            final hex = colorMap['hex']! as String;
                            final color = colorMap['color']! as Color;
                            final isSelected = curHex == hex;

                            return GestureDetector(
                              onTap: () => selectedColorHex.value = hex,
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        )
                                      : null,
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.6),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: isSelected
                                    ? const Center(
                                        child: Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        );
                      }),
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
                          fillColor: isDarkMode
                              ? AppColors.bgInput
                              : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
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
                      const SizedBox(height: 8),

                      // Popular Perk Suggestions Chips
                      Text(
                        'Quick-add popular perks:',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: MembershipsController.popularPerkSuggestions
                            .map((suggestion) {
                              return ActionChip(
                                label: Text(
                                  '+ $suggestion',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDarkMode
                                        ? AppColors.textPrimary
                                        : Colors.black87,
                                  ),
                                ),
                                backgroundColor: isDarkMode
                                    ? AppColors.bgSurfaceHigh
                                    : Colors.grey.shade100,
                                onPressed: () {
                                  if (!activePerks.contains(suggestion)) {
                                    activePerks.add(suggestion);
                                  }
                                },
                              );
                            })
                            .toList(),
                      ),
                      const SizedBox(height: 12),

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
                                fillColor: isDarkMode
                                    ? AppColors.bgInput
                                    : const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (val) {
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
                                  if (!activePerks.contains(t)) {
                                    activePerks.add(t);
                                    customPerkController.clear();
                                  }
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final t = customPerkController.text.trim();
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
                                if (!activePerks.contains(t)) {
                                  activePerks.add(t);
                                  customPerkController.clear();
                                }
                              }
                            },
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
                      const SizedBox(height: 12),

                      // Active Perks List
                      Obx(() {
                        if (activePerks.isEmpty) {
                          return const Text(
                            'No perks added yet. Add perks to incentivize your fans!',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          );
                        }

                        return Column(
                          children: activePerks.map((p) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? AppColors.bgSurfaceHigh
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      p,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDarkMode
                                            ? AppColors.textPrimary
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                    onPressed: () => activePerks.remove(p),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      }),
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
