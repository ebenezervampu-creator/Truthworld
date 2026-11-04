import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics/revenue_analytics_barrel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/memberships_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization_screen.dart';

export 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics/revenue_analytics_barrel.dart';

/// Controller for Channel Revenue Analytics.
/// Real-time listener across authentic Firestore financial collections.
class RevenueAnalyticsController extends RevenueAnalyticsStateBase
    with
        RevenueAnalyticsStreamsMixin,
        RevenueAnalyticsPayoutMixin,
        RevenueAnalyticsKycMixin {
  static RevenueAnalyticsController get to {
    if (!Get.isRegistered<RevenueAnalyticsController>()) {
      return Get.put(RevenueAnalyticsController());
    }
    return Get.find<RevenueAnalyticsController>();
  }

  // ---------------------------------------------------------------------------
  // Minimum Withdrawal Configuration (100 Rupees Minimum)
  // ---------------------------------------------------------------------------
  static const double minimumWithdrawalAmount =
      RevenueAnalyticsStateBase.minimumWithdrawalAmount;
  static const double minimumWithdrawalAmountINR =
      RevenueAnalyticsStateBase.minimumWithdrawalAmountINR;
  static const double minimumWithdrawalAmountUSD =
      RevenueAnalyticsStateBase.minimumWithdrawalAmountUSD;
  static const String currencySymbol = RevenueAnalyticsStateBase.currencySymbol;
  static const String currencyCode = RevenueAnalyticsStateBase.currencyCode;
  static const String minWithdrawalText =
      RevenueAnalyticsStateBase.minWithdrawalText;

  /// Live Real-Time USD to INR Exchange Rate
  static double get usdToInrRate => RevenueAnalyticsStateBase.usdToInrRate;

  @override
  void onInit() {
    super.onInit();
    initExchangeRateWorker();
  }

  void clearData() {
    disposeStreams();
    channelId.value = '';
    channelName.value = '';
    totalRevenue.value = 0.0;
    totalRevenueUSD.value = 0.0;
    membershipsRevenue.value = 0.0;
    membershipsRevenueINR.value = 0.0;
    membershipsRevenueUSD.value = 0.0;
    superchatRevenue.value = 0.0;
    adsRevenue.value = 0.0;
    premiumSubsRevenue.value = 0.0;
    premiumSubsRevenueUSD.value = 0.0;
  }

  @override
  void onClose() {
    clearData();
    super.onClose();
  }

  /// Formats an INR amount according to active currency selection.
  String formatCurrency(double amountInINR) {
    if (isViewingINR) {
      return '₹${amountInINR.toStringAsFixed(2)}';
    }
    final inUSD = amountInINR / RevenueAnalyticsStateBase.usdToInrRate;
    return '\$${inUSD.toStringAsFixed(2)}';
  }

  /// Toggles between INR and USD display modes.
  void setCurrencyView(String currency) {
    if (currency == 'INR' || currency == 'USD') {
      displayCurrency.value = currency;
      recalculateTotal();
    }
  }

  /// Hydrates channel revenue metrics and sets up real-time Firestore listeners.
  void loadRevenueAnalytics(String chId, {String? chName, String? change}) {
    if (chId.isEmpty) return;
    channelId.value = chId;
    if (chName != null && chName.isNotEmpty) {
      channelName.value = chName;
    }
    if (change != null && change.isNotEmpty) {
      revenueChange.value = change;
    }

    // Reset revenue state for new channel to ensure authentic data
    membershipsRevenue.value = 0.0;
    superchatRevenue.value = 0.0;
    adsRevenue.value = 0.0;
    premiumSubsRevenue.value = 0.0;
    totalRevenue.value = 0.0;
    totalRevenueUSD.value = 0.0;

    // Sync from DashboardController if already loaded
    if (Get.isRegistered<DashboardController>()) {
      final dash = Get.find<DashboardController>();
      if (dash.channelId == chId) {
        membershipsRevenue.value = dash.rxMembershipsRevenue.value;
        superchatRevenue.value = dash.rxSuperchatRevenue.value;
        adsRevenue.value = dash.rxAdsRevenue.value;
        premiumSubsRevenue.value = dash.rxPremiumSubsRevenue.value;
        totalRevenue.value = dash.rxTotalRevenue.value;
        activeMembersCount.value = dash.rxActiveMembersCount.value;
        activeTiersCount.value = dash.rxActiveTiersCount.value;
        if (totalRevenue.value > 0) {
          rxIsLoading.value = false;
        }
      }
    }

    subscribeToAuthenticData();
  }

  @override
  void recalculateWithLiveExchangeRate() {
    final rate = RevenueAnalyticsStateBase.usdToInrRate;
    final rawUsd = originalUsdMemberships.value;
    final rawInr = originalInrMemberships.value;
    if (rawUsd > 0 || rawInr > 0) {
      final sumINR = (rawUsd * rate) + rawInr;
      final sumUSD = rawUsd + (rawInr / rate);
      membershipsRevenueINR.value = sumINR;
      membershipsRevenueUSD.value = sumUSD;
      membershipsRevenue.value = sumINR;
      recalculateTotal();
    }
  }

  @override
  void recalculateTotal() {
    final total = membershipsRevenue.value +
        superchatRevenue.value +
        adsRevenue.value +
        premiumSubsRevenue.value;
    totalRevenue.value = total;
    totalRevenueUSD.value = total / RevenueAnalyticsStateBase.usdToInrRate;
    premiumSubsRevenueUSD.value =
        premiumSubsRevenue.value / RevenueAnalyticsStateBase.usdToInrRate;

    if (total > 0) {
      if (isViewingINR) {
        revenueChange.value = '+₹${total.toStringAsFixed(2)}';
      } else {
        revenueChange.value = '+\$${totalRevenueUSD.value.toStringAsFixed(2)}';
      }
    } else {
      revenueChange.value = isViewingINR ? '+₹0.00' : r'+$0.00';
    }

    // Bidirectionally sync with DashboardController if registered for same channel
    if (Get.isRegistered<DashboardController>()) {
      final dash = Get.find<DashboardController>();
      if (dash.channelId == channelId.value) {
        dash.rxMembershipsRevenue.value = membershipsRevenue.value;
        dash.rxSuperchatRevenue.value = superchatRevenue.value;
        dash.rxAdsRevenue.value = adsRevenue.value;
        dash.rxPremiumSubsRevenue.value = premiumSubsRevenue.value;
        dash.updateRevenueStats();
      }
    }
  }

  /// Navigates to the Memberships tab or screen.
  void navigateToMemberships() {
    final chId = channelId.value;
    if (Get.isRegistered<DashboardController>()) {
      final dash = Get.find<DashboardController>();
      if (!dash.isChannelMonetizationActive) {
        AppSnackbar.info(
          'Channel Memberships are only available for monetized channels.',
        );
        dash.setSelectedIndex(5); // Earnings/Monetization tab
        return;
      }
      dash.setSelectedIndex(18); // Memberships Tab
      if (Get.key.currentState?.canPop() ?? false) {
        Get.back<void>();
      }
    } else {
      Get.to<void>(
        () => MembershipsScreen(channelId: chId),
      );
    }
  }

  /// Navigates to the Monetization tab or screen.
  void navigateToMonetization() {
    if (Get.isRegistered<DashboardController>()) {
      final dash = Get.find<DashboardController>();
      dash.setSelectedIndex(5); // Monetization/Earnings Tab
      if (Get.key.currentState?.canPop() ?? false) {
        Get.back<void>();
      }
    } else {
      Get.to<void>(
        () => const MonetizationScreen(),
      );
    }
  }
}
