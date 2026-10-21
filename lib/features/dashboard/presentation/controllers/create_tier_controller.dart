import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';

/// Preset badge colors for Membership Tiers in TruthWorld Studio.
class TierBadgeColorPreset {
  const TierBadgeColorPreset({
    required this.name,
    required this.hex,
    required this.color,
  });

  final String name;
  final String hex;
  final Color color;
}

/// Controller managing state and business logic for creating or editing a membership tier.
class CreateTierController extends GetxController {
  CreateTierController({
    MembershipsController? membershipsController,
    this.tier,
    this.isDarkMode = true,
  }) : _membershipsController = membershipsController;

  final MembershipsController? _membershipsController;
  final ChannelMembershipTier? tier;
  final bool isDarkMode;

  bool get isEditing => tier != null;

  MembershipsController get membershipsController {
    if (_membershipsController != null) return _membershipsController;
    if (Get.isRegistered<MembershipsController>()) {
      return Get.find<MembershipsController>();
    }
    return Get.put(MembershipsController());
  }

  // Text Controllers
  late final TextEditingController nameController;
  late final TextEditingController priceController;
  late final TextEditingController descController;
  late final TextEditingController customPerkController;

  // Reactive State
  final RxString selectedCurrency = 'USD'.obs;
  final RxDouble priceRx = 5.0.obs;
  final RxString nameRx = ''.obs;
  final RxList<String> activePerks = <String>[].obs;
  final RxList<String> allAvailablePerks = <String>[].obs;
  final RxBool hasPremiumBundle = false.obs;
  final RxString selectedColorHex = '0xFF10B981'.obs;
  final RxBool isSubmitting = false.obs;

  /// 8 Premium Preset Colors for Channel Loyalty & Tier Badges
  static const List<TierBadgeColorPreset> presetColors = [
    TierBadgeColorPreset(
      name: 'Emerald',
      hex: '0xFF10B981',
      color: Color(0xFF10B981),
    ),
    TierBadgeColorPreset(
      name: 'Sky Blue',
      hex: '0xFF0284C7',
      color: Color(0xFF0284C7),
    ),
    TierBadgeColorPreset(
      name: 'Royal Purple',
      hex: '0xFF8B5CF6',
      color: Color(0xFF8B5CF6),
    ),
    TierBadgeColorPreset(
      name: 'Amber Gold',
      hex: '0xFFF59E0B',
      color: Color(0xFFF59E0B),
    ),
    TierBadgeColorPreset(
      name: 'Crimson Rose',
      hex: '0xFFF43F5E',
      color: Color(0xFFF43F5E),
    ),
    TierBadgeColorPreset(
      name: 'Indigo VIP',
      hex: '0xFF6366F1',
      color: Color(0xFF6366F1),
    ),
    TierBadgeColorPreset(
      name: 'Coral Orange',
      hex: '0xFFF97316',
      color: Color(0xFFF97316),
    ),
    TierBadgeColorPreset(
      name: 'Teal Cyan',
      hex: '0xFF14B8A6',
      color: Color(0xFF14B8A6),
    ),
  ];

  @override
  void onInit() {
    super.onInit();

    selectedCurrency.value = tier?.currency ?? 'USD';
    final initialPrice = tier?.price ?? 5.0;
    priceRx.value = initialPrice;

    nameController = TextEditingController(text: tier?.name ?? '');
    priceController = TextEditingController(
      text: initialPrice == initialPrice.truncateToDouble()
          ? initialPrice.toInt().toString()
          : initialPrice.toStringAsFixed(2),
    );
    descController = TextEditingController(text: tier?.description ?? '');
    customPerkController = TextEditingController();

    nameRx.value = tier?.name ?? '';
    selectedColorHex.value = tier?.badgeColorHex ?? '0xFF10B981';

    if (tier != null) {
      activePerks.assignAll(tier!.perks);
    } else {
      activePerks.assignAll([
        'Loyalty badges beside your name in comments and live chat',
        'Custom emoji to use in live chat and comments',
        'Members-only community posts & updates',
      ]);
    }

    hasPremiumBundle.value = tier?.includesPremiumBundle ??
        activePerks.any((p) {
          final s = p.toLowerCase();
          return s.contains('channel premium') ||
              (s.contains('no ads') && (s.contains('2k') || s.contains('4k'))) ||
              s.contains('ad-free') ||
              s.contains('up to 2k');
        });

    final pool = <String>[
      ...MembershipsController.popularPerkSuggestions,
      ...activePerks.where(
        (p) => !MembershipsController.popularPerkSuggestions.contains(p),
      ),
    ];
    allAvailablePerks.assignAll(pool);

    nameController.addListener(() {
      nameRx.value = nameController.text.trim();
    });

    priceController.addListener(() {
      final p = double.tryParse(priceController.text.trim());
      if (p != null) {
        priceRx.value = p;
      }
    });
  }

  @override
  void onClose() {
    nameController.dispose();
    priceController.dispose();
    descController.dispose();
    customPerkController.dispose();
    super.onClose();
  }

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
    if (t.isEmpty) return;

    final pVal = ContentValidator.validate(
      t,
      maxLength: ContentValidator.defaultMaxPerkLength,
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

  void removePerk(String perk) {
    activePerks.remove(perk);
    if (perk == ChannelMembershipTier.premiumBundlePerkTitle ||
        perk.toLowerCase().contains('channel premium')) {
      hasPremiumBundle.value = false;
    }
  }

  void selectCurrency(String currency) {
    if (selectedCurrency.value == currency) return;
    selectedCurrency.value = currency;

    final curPrice = double.tryParse(priceController.text.trim()) ?? 0.0;
    if (currency == 'INR') {
      if (curPrice < ChannelMembershipTier.minPriceINR) {
        priceController.text = ChannelMembershipTier.minPriceINR.toInt().toString();
        priceRx.value = ChannelMembershipTier.minPriceINR;
      } else if (curPrice == curPrice.truncateToDouble()) {
        priceController.text = curPrice.toInt().toString();
      }
    } else {
      if (curPrice >= ChannelMembershipTier.minPriceINR && curPrice != 1.0) {
        priceController.text = '5';
        priceRx.value = 5.0;
      } else if (curPrice < 1.0) {
        priceController.text = '1';
        priceRx.value = 1.0;
      }
    }
  }

  void selectPrice(double price) {
    final isWhole = price == price.truncateToDouble();
    priceController.text = isWhole ? price.toInt().toString() : price.toStringAsFixed(2);
    priceRx.value = price;
  }

  void selectColor(String hex) {
    selectedColorHex.value = hex;
  }

  Future<bool> saveTier() async {
    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text.trim()) ?? 0.0;
    final desc = descController.text.trim();
    final perks = activePerks.toList();
    final badgeHex = selectedColorHex.value;
    final curr = selectedCurrency.value;

    if (name.isEmpty) {
      AppSnackbar.warning('Please enter a tier name.');
      return false;
    }

    final nameVal = ContentValidator.validate(
      name,
      maxLength: ContentValidator.defaultMaxTierNameLength,
      fieldName: 'Tier Name',
    );
    if (!nameVal.isValid) {
      AppSnackbar.warning(nameVal.message);
      return false;
    }

    if (desc.isNotEmpty) {
      final descVal = ContentValidator.validate(
        desc,
        maxLength: ContentValidator.defaultMaxTierDescLength,
        fieldName: 'Description',
      );
      if (!descVal.isValid) {
        AppSnackbar.warning(descVal.message);
        return false;
      }
    }

    final minAllowed = ChannelMembershipTier.minPriceFor(curr);
    if (price < minAllowed) {
      AppSnackbar.warning(
        'Minimum price for $curr membership plans is ${ChannelMembershipTier.minPriceLabel(curr)}.',
      );
      return false;
    }

    if (perks.isEmpty) {
      AppSnackbar.warning('Please add at least one perk.');
      return false;
    }

    if (!isEditing && membershipsController.hasReachedMaxTiers) {
      AppSnackbar.warning(
        'Channels can have up to 3 membership tiers only. Please edit or remove an existing tier to add a new one.',
      );
      return false;
    }

    isSubmitting.value = true;
    bool success;

    if (isEditing) {
      success = await membershipsController.updateTier(
        tier!.copyWith(
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
      success = await membershipsController.createTier(
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
    if (success) {
      Get.back();
    }
    return success;
  }
}
