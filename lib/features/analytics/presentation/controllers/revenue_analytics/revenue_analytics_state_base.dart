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
  // Minimum Withdrawal Configuration (₹100 for India / $10 for Other Countries)
  // ---------------------------------------------------------------------------
  static const double minimumWithdrawalAmountINR = 100.0;
  static const double minimumWithdrawalAmountUSD = 10.0;
  static const double minimumWithdrawalAmount = minimumWithdrawalAmountINR;
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';
  static const String minWithdrawalText = '₹100 (100 Rupees)';
  static const String minWithdrawalTextUSD = r'$10 (10 Dollars)';

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

  // Active Sub-Tab on Unified Earnings Page (0: All, 1: Revenue & Payouts, 2: Ways You Earn, 3: Video Eligibility, 4: Tier & Rules)
  final RxInt selectedEarningsTab = 0.obs;

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
  // Premium subscription revenue share earned from the monthly distribution
  final RxDouble premiumSubsRevenue = 0.0.obs;
  final RxDouble premiumSubsRevenueUSD = 0.0.obs;
  final RxBool isPremiumInfoExpanded = false.obs;

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

  // ---------------------------------------------------------------------------
  // YouTube-Style Monthly Payout Window Configuration (1st + 1-Day Grace)
  // ---------------------------------------------------------------------------
  /// Optional debug/test reactive override for current date in payout window calculations.
  static final Rx<DateTime?> rxDebugDateOverride = Rx<DateTime?>(null);

  static DateTime? get debugDateOverride => rxDebugDateOverride.value;
  static set debugDateOverride(DateTime? val) => rxDebugDateOverride.value = val;

  static DateTime get currentDate => rxDebugDateOverride.value ?? DateTime.now();

  /// True on the primary payout day (1st of the month).
  static bool get isPrimaryPayoutDay => currentDate.day == 1;

  /// True during the 1-day grace period if creator missed the 1st (2nd of the month).
  static bool get isGracePeriodDay => currentDate.day == 2;

  /// True if today is within the YouTube-style monthly payout window (1st day or 2nd day grace period).
  static bool get isPayoutDay => isPrimaryPayoutDay || isGracePeriodDay;

  /// Next payout date (current day if today is within Days 1-2, or 1st day of next month).
  static DateTime get nextPayoutDate {
    final now = currentDate;
    if (now.day == 1 || now.day == 2) {
      return DateTime(now.year, now.month, now.day);
    }
    if (now.month == 12) {
      return DateTime(now.year + 1);
    } else {
      return DateTime(now.year, now.month + 1);
    }
  }

  /// Calculates upcoming month's 1st day (for rollover display when window closes).
  static DateTime get upcomingFirstOfMonth {
    final now = currentDate;
    if (now.month == 12) {
      return DateTime(now.year + 1);
    } else {
      return DateTime(now.year, now.month + 1);
    }
  }

  static const List<String> _monthNames = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const List<String> _shortMonthNames = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String get nextPayoutDateFormatted {
    final target = (currentDate.day == 1 || currentDate.day == 2)
        ? nextPayoutDate
        : upcomingFirstOfMonth;
    final dayNum = target.day;
    final suffix = dayNum == 1 ? '1st' : (dayNum == 2 ? '2nd' : '${dayNum}th');
    return '$suffix ${_monthNames[target.month - 1]} ${target.year}';
  }

  static String get upcomingFirstOfMonthFormatted {
    final target = upcomingFirstOfMonth;
    return '1st ${_monthNames[target.month - 1]} ${target.year}';
  }

  static String get nextPayoutShortMonth {
    final target = (currentDate.day == 1 || currentDate.day == 2)
        ? nextPayoutDate
        : upcomingFirstOfMonth;
    return _shortMonthNames[target.month - 1];
  }

  // Withdrawal States
  final RxBool isSubmittingWithdrawal = false.obs;
  final RxBool isWithdrawalHeld = false.obs;
  final RxString withdrawalHoldReason = ''.obs;

  bool get isTodayPayoutDay => RevenueAnalyticsStateBase.isPayoutDay;
  bool get isTodayGraceDay => RevenueAnalyticsStateBase.isGracePeriodDay;

  bool get isIndianChannel {
    if (!Get.isRegistered<CurrencyLocalizationService>()) return true;
    return CurrencyLocalizationService.to.isIndianUser;
  }

  double get activeMinimumWithdrawalAmount =>
      isViewingINR ? minimumWithdrawalAmountINR : minimumWithdrawalAmountUSD;

  String get activeMinWithdrawalText =>
      isViewingINR ? minWithdrawalText : minWithdrawalTextUSD;

  bool get hasReachedThreshold =>
      isViewingINR
          ? totalRevenue.value >= minimumWithdrawalAmountINR
          : totalRevenueUSD.value >= minimumWithdrawalAmountUSD;

  /// True only when balance reaches minimum threshold, withdrawal is not held,
  /// and today is within the monthly payout window (1st or 2nd day of the month).
  bool get canWithdraw =>
      hasReachedThreshold && !isWithdrawalHeld.value && isTodayPayoutDay;

  /// True when creator reached threshold but withdrawal window is locked until 1st of next month.
  bool get isThresholdMetButAwaitingFirstOfMonth =>
      hasReachedThreshold && !isWithdrawalHeld.value && !isTodayPayoutDay;

  double get remainingToWithdraw {
    final target = activeMinimumWithdrawalAmount;
    final balance = isViewingINR ? totalRevenue.value : totalRevenueUSD.value;
    return (target - balance).clamp(0.0, target);
  }

  double get withdrawalProgress {
    final target = activeMinimumWithdrawalAmount;
    final balance = isViewingINR ? totalRevenue.value : totalRevenueUSD.value;
    return target > 0 ? (balance / target).clamp(0.0, 1.0) : 1.0;
  }

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
