import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/features/analytics/data/models/creator_bank_account.dart';
import 'package:truthworld/features/analytics/data/models/creator_kyc_verification.dart';

/// Abstract base state holding reactive properties and financial metrics for [RevenueAnalyticsController].
abstract class RevenueAnalyticsStateBase extends BaseController {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  // ---------------------------------------------------------------------------
  // Minimum Withdrawal Configuration (100 Rupees Minimum)
  // ---------------------------------------------------------------------------
  static const double minimumWithdrawalAmount = 100.0;
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';
  static const String minWithdrawalText = '₹100 (100 Rupees)';

  /// Live Real-Time USD to INR Exchange Rate
  static double get usdToInrRate =>
      Get.isRegistered<CurrencyLocalizationService>()
          ? CurrencyLocalizationService.to.rate
          : CurrencyLocalizationService.defaultRate;

  // ---------------------------------------------------------------------------
  // Reactive State
  // ---------------------------------------------------------------------------
  final RxString channelId = ''.obs;
  final RxString channelName = ''.obs;
  final RxBool rxIsLoading = true.obs;

  // Currency View Selection (INR vs USD)
  final RxString displayCurrency = 'INR'.obs;

  // Earnings Breakdown
  final RxDouble totalRevenue = 0.0.obs; // In INR for Bank Payout
  final RxDouble totalRevenueUSD = 0.0.obs; // In USD equivalent
  final RxDouble membershipsRevenue = 0.0.obs; // In INR
  final RxDouble membershipsRevenueINR = 0.0.obs;
  final RxDouble membershipsRevenueUSD = 0.0.obs;
  final RxDouble originalUsdMemberships = 0.0.obs;
  final RxDouble originalInrMemberships = 0.0.obs;
  final RxDouble superchatRevenue = 0.0.obs;
  final RxDouble adsRevenue = 0.0.obs;
  final RxDouble watchTimeRevenue = 0.0.obs;

  bool get isViewingINR => displayCurrency.value == 'INR';
  String get activeDisplayCurrencySymbol => isViewingINR ? '₹' : r'$';
  String get activeDisplayCurrencyCode => isViewingINR ? 'INR' : 'USD';

  double get displayTotalRevenue =>
      isViewingINR ? totalRevenue.value : totalRevenueUSD.value;

  // Bank Account & Direct Payout Arrangement
  final Rx<CreatorBankAccount?> savedBankAccount = Rx<CreatorBankAccount?>(null);
  final RxBool isLoadingBankAccount = false.obs;

  // Creator KYC Document Verification State
  final Rx<CreatorKycVerification?> creatorKyc = Rx<CreatorKycVerification?>(null);
  final RxString channelKycStatus = 'not_submitted'.obs;
  final RxBool isSubmittingKyc = false.obs;
  final RxDouble kycUploadProgress = 0.0.obs;

  bool get isKycVerified => channelKycStatus.value.toLowerCase() == 'verified';
  bool get isKycPending => channelKycStatus.value.toLowerCase() == 'pending';
  bool get isKycRejected => channelKycStatus.value.toLowerCase() == 'rejected';
  bool get isKycNotSubmitted =>
      channelKycStatus.value.toLowerCase() == 'not_submitted' ||
      channelKycStatus.value.isEmpty;

  // Withdrawal States
  final RxBool isSubmittingWithdrawal = false.obs;

  bool get canWithdraw => totalRevenue.value >= minimumWithdrawalAmount;
  double get remainingToWithdraw =>
      (minimumWithdrawalAmount - totalRevenue.value)
          .clamp(0.0, minimumWithdrawalAmount);
  double get withdrawalProgress =>
      (totalRevenue.value / minimumWithdrawalAmount).clamp(0.0, 1.0);

  // Auxiliary Metrics
  final RxInt activeMembersCount = 0.obs;
  final RxInt activeTiersCount = 0.obs;
  final RxInt totalViews = 0.obs;
  final RxInt totalWatchMinutes = 0.obs;
  final RxString revenueChange = '+₹0.00'.obs;

  /// Recalculates total revenue sum across revenue streams.
  void recalculateTotal();

  /// Recalculates currency equivalents using the latest exchange rate.
  void recalculateWithLiveExchangeRate();
}
