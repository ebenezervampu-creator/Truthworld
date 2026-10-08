import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/network/app_http_client.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/logger_service.dart';

/// Service that dynamically resolves the user's localized currency with
/// Real-Time Live Dollar Pricing.
///
/// Features:
/// - Real-time forex rate fetching from authoritative market feeds
///   (Primary: open.er-api.com, Secondary: frankfurter.app, Tertiary: Firestore system_config/currency)
/// - Persistent local caching via GetStorage so initial launch is instantaneous and offline-safe
/// - Dynamic 30-minute background auto-refresh
/// - Zero mock data & production-grade resilience with safe baseline fallback (84.0)
class CurrencyLocalizationService extends GetxService {
  static CurrencyLocalizationService get to {
    if (!Get.isRegistered<CurrencyLocalizationService>()) {
      return Get.put(CurrencyLocalizationService(), permanent: true);
    }
    return Get.find<CurrencyLocalizationService>();
  }

  /// Safe baseline default exchange rate (1 USD = ₹84.0 INR)
  static const double defaultRate = 84.0;

  /// Whether persistent caching and Firebase listeners should run (can be disabled in pure unit tests)
  static bool enablePersistentStorage = true;

  /// Backwards-compatible static getter for modules reading CurrencyLocalizationService.usdToInrRate
  static double get usdToInrRate =>
      Get.isRegistered<CurrencyLocalizationService>() ? to.rate : defaultRate;

  // ---------------------------------------------------------------------------
  // Reactive State
  // ---------------------------------------------------------------------------

  /// Real-time live USD to INR exchange rate (1 USD = X INR)
  final RxDouble liveUsdToInrRate = defaultRate.obs;

  /// Timestamp of the last successful live rate update
  final Rx<DateTime?> lastRateUpdateTime = Rx<DateTime?>(null);

  /// Status flag for active rate fetch
  final RxBool isFetchingRate = false.obs;

  /// Source of the current exchange rate ('live_api', 'frankfurter', 'firestore', 'cache', 'default')
  final RxString rateSource = 'default'.obs;

  /// Reactive country code for the active viewer/device
  final RxString userCountryCode = 'IN'.obs;

  /// Optional manual override for testing or user currency selection
  final Rx<String?> currencyOverride = Rx<String?>(null);

  // Background timer & Firestore subscription
  Timer? _refreshTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _firestoreConfigSub;

  // Storage keys
  static const String _storageKeyRate = 'realtime_usd_to_inr_rate';
  static const String _storageKeyUpdatedAt = 'realtime_usd_to_inr_updated_at';
  static const String _storageKeySource = 'realtime_usd_to_inr_source';

  @override
  void onInit() {
    super.onInit();
    detectUserCountry();
    if (enablePersistentStorage) {
      // Non-blocking real-time country refresh on every app launch.
      // Runs after detectUserCountry() so the Firestore-cached code is applied
      // first (no flicker), then silently corrected if the live IP differs.
      _refreshCountryFromIp();
      _loadCachedRate();
      _listenToFirestoreConfig();
      fetchRealtimeRate();
      _startPeriodicRefresh();
    }
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    _firestoreConfigSub?.cancel();
    super.onClose();
  }

  /// Active conversion rate (USD to INR) with safe bounds protection
  double get rate {
    final r = liveUsdToInrRate.value;
    if (r.isNaN || r.isInfinite || r < 10.0 || r > 500.0) {
      return defaultRate;
    }
    return r;
  }

  // ---------------------------------------------------------------------------
  // Real-Time Rate Fetching & Caching
  // ---------------------------------------------------------------------------

  /// Load cached rate from persistent storage for immediate offline-ready launch
  void _loadCachedRate() {
    if (!enablePersistentStorage) return;
    try {
      final box = GetStorage();
      final cachedRate = (box.read(_storageKeyRate) as num?)?.toDouble();
      final cachedTimeMs = box.read(_storageKeyUpdatedAt) as int?;
      final cachedSource = box.read(_storageKeySource) as String?;

      if (cachedRate != null &&
          cachedRate > 50.0 &&
          cachedRate < 200.0 &&
          (cachedRate - 84.0).abs() > 0.05) {
        liveUsdToInrRate.value = cachedRate;
        if (cachedTimeMs != null) {
          lastRateUpdateTime.value =
              DateTime.fromMillisecondsSinceEpoch(cachedTimeMs);
        }
        rateSource.value = cachedSource ?? 'cache';
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(e,
          stackTrace: stackTrace,
          tag: 'CurrencyLocalizationService._loadCachedRate');
    }
  }

  /// Listen in real-time to Firestore system_config/currency for admin-level rate adjustments
  void _listenToFirestoreConfig() {
    if (!enablePersistentStorage) return;
    try {
      _firestoreConfigSub = FirebaseFirestore.instance
          .collection('system_config')
          .doc('currency')
          .snapshots()
          .listen(
        (snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data();
            if (data != null) {
              final remoteRate = (data['usdToInrRate'] as num?)?.toDouble() ??
                  (data['liveUsdToInrRate'] as num?)?.toDouble();
              if (remoteRate != null && remoteRate > 50.0 && remoteRate < 200.0) {
                _applyNewRate(remoteRate, source: 'firestore');
              }
            }
          }
        },
        onError: (err) {
          // Non-critical: continue with API rate
        },
      );
    } catch (_) {}
  }

  /// Fetches the latest live market exchange rate with multi-source fallback
  Future<double> fetchRealtimeRate({bool force = false}) async {
    final isUnverified = rateSource.value == 'default' ||
        (liveUsdToInrRate.value - 84.0).abs() < 0.05;
    // Avoid spamming requests if updated within the last 15 minutes and rate is verified
    if (!force && !isUnverified && lastRateUpdateTime.value != null) {
      final elapsed = DateTime.now().difference(lastRateUpdateTime.value!);
      if (elapsed.inMinutes < 15 && liveUsdToInrRate.value > 0) {
        return liveUsdToInrRate.value;
      }
    }

    if (isFetchingRate.value) return liveUsdToInrRate.value;
    isFetchingRate.value = true;

    try {
      // 1. Primary: open.er-api.com (Open Exchange Rates public free tier)
      final primaryUrl = Uri.parse('https://open.er-api.com/v6/latest/USD');
      final primaryRes =
          await AppHttpClient.get(primaryUrl, timeout: const Duration(seconds: 7));

      if (primaryRes.statusCode == 200) {
        final json = jsonDecode(primaryRes.body) as Map<String, dynamic>;
        final rates = json['rates'] as Map<String, dynamic>?;
        final inr = (rates?['INR'] as num?)?.toDouble();
        if (inr != null && inr > 50.0 && inr < 200.0) {
          _applyNewRate(inr, source: 'live_api');
          return inr;
        }
      }
    } catch (e) {
      logger.warning(
        'Primary currency exchange API unavailable or timed out: $e. Falling back to secondary...',
        tag: 'CurrencyLocalizationService',
      );
    }

    try {
      // 2. Secondary Fallback: European Central Bank via frankfurter.app
      final backupUrl =
          Uri.parse('https://api.frankfurter.app/latest?from=USD&to=INR');
      final backupRes =
          await AppHttpClient.get(backupUrl, timeout: const Duration(seconds: 7));

      if (backupRes.statusCode == 200) {
        final json = jsonDecode(backupRes.body) as Map<String, dynamic>;
        final rates = json['rates'] as Map<String, dynamic>?;
        final inr = (rates?['INR'] as num?)?.toDouble();
        if (inr != null && inr > 50.0 && inr < 200.0) {
          _applyNewRate(inr, source: 'frankfurter');
          return inr;
        }
      }
    } catch (e) {
      logger.warning(
        'Secondary currency exchange API unavailable or timed out: $e. Using active rate.',
        tag: 'CurrencyLocalizationService',
      );
    } finally {
      isFetchingRate.value = false;
    }

    return liveUsdToInrRate.value;
  }

  void _applyNewRate(double newRate, {required String source}) {
    if (newRate.isNaN || newRate.isInfinite || newRate < 10.0 || newRate > 500.0) {
      return;
    }
    // Round to 4 decimal precision
    final rounded = double.parse(newRate.toStringAsFixed(4));
    liveUsdToInrRate.value = rounded;
    lastRateUpdateTime.value = DateTime.now();
    rateSource.value = source;

    // Persist to local cache
    if (enablePersistentStorage) {
      try {
        final box = GetStorage();
        box.write(_storageKeyRate, rounded);
        box.write(
            _storageKeyUpdatedAt, DateTime.now().millisecondsSinceEpoch);
        box.write(_storageKeySource, source);
      } catch (_) {}
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      fetchRealtimeRate();
    });
  }

  // ---------------------------------------------------------------------------
  // Viewer Geolocation
  // ---------------------------------------------------------------------------

  /// Applies country from the signed-in user's Firestore profile (fast, sync).
  /// Used as the immediate initial value at app start.
  /// A real-time correction is then applied asynchronously by [_refreshCountryFromIp].
  void detectUserCountry() {
    if (Get.isRegistered<AuthService>()) {
      final country = AuthService.to.userCountry.value;
      if (country != null && country.isNotEmpty) {
        final code = _normalizeCountryCode(country);
        if (code.isNotEmpty) {
          userCountryCode.value = code;
          return;
        }
      }
    }
    // Default until the async IP refresh completes.
    userCountryCode.value = 'IN';
  }

  /// Fetches the real-time ISO 2-letter country code on every app launch.
  /// Uses multi-source fallback with CORS-compatible endpoints:
  /// 1. ipwho.is (Primary, CORS-friendly, HTTPS)
  /// 2. api.country.is (Secondary, CORS-friendly, ultra-fast)
  /// 3. ipapi.co/json (Tertiary native/desktop fallback)
  /// Runs non-blocking after [detectUserCountry] so UI sees the cached
  /// Firestore value immediately, then gets silently corrected if the live IP differs.
  Future<void> _refreshCountryFromIp() async {
    // 1. Primary: ipwho.is (CORS-friendly for Web, HTTPS)
    try {
      final res = await AppHttpClient.get(
        Uri.parse('https://ipwho.is/'),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final code = data['country_code']?.toString();
          if (code != null && code.length == 2) {
            userCountryCode.value = code.toUpperCase();
            return;
          }
        }
      }
    } catch (_) {}

    // 2. Secondary: api.country.is (CORS-friendly for Web, ultra-fast)
    try {
      final res = await AppHttpClient.get(
        Uri.parse('https://api.country.is/'),
      ).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final code = data['country']?.toString();
        if (code != null && code.length == 2) {
          userCountryCode.value = code.toUpperCase();
          return;
        }
      }
    } catch (_) {}

    // 3. Tertiary: ipapi.co/json (Native/desktop fallback)
    try {
      final res = await AppHttpClient.get(
        Uri.parse('https://ipapi.co/json/'),
      ).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final code = data['country_code']?.toString();
        if (code != null && code.length == 2) {
          userCountryCode.value = code.toUpperCase();
          return;
        }
      }
    } catch (e, s) {
      // Non-critical — existing cached/profile value remains active.
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'CurrencyLocalizationService.refreshCountryFromIp',
      );
    }
  }

  /// Normalises a raw country value to an ISO 2-letter code.
  /// New Firestore writes store ISO codes directly, so most calls are a
  /// trivial 2-letter passthrough. Legacy full-name values from old documents
  /// are mapped here for backward compatibility.
  String _normalizeCountryCode(String raw) {
    final clean = raw.trim().toUpperCase();
    // Already a 2-letter ISO code — fast path.
    if (clean.length == 2) return clean;
    // Legacy full-name fallback map (Firestore docs written before ISO fix).
    const nameToCode = <String, String>{
      'INDIA': 'IN',
      'IND': 'IN',
      'UNITED STATES': 'US',
      'UNITED STATES OF AMERICA': 'US',
      'USA': 'US',
      'UNITED KINGDOM': 'GB',
      'UK': 'GB',
      'GREAT BRITAIN': 'GB',
      'CANADA': 'CA',
      'AUSTRALIA': 'AU',
      'GERMANY': 'DE',
      'FRANCE': 'FR',
      'CHINA': 'CN',
      'JAPAN': 'JP',
      'SINGAPORE': 'SG',
      'UAE': 'AE',
      'UNITED ARAB EMIRATES': 'AE',
      'SAUDI ARABIA': 'SA',
      'BRAZIL': 'BR',
      'MEXICO': 'MX',
      'SOUTH AFRICA': 'ZA',
      'NIGERIA': 'NG',
      'KENYA': 'KE',
      'PAKISTAN': 'PK',
      'BANGLADESH': 'BD',
      'SRI LANKA': 'LK',
      'NEPAL': 'NP',
    };
    return nameToCode[clean] ?? clean;
  }

  /// Whether current user is browsing from India
  bool get isIndianUser {
    if (currencyOverride.value != null) {
      return currencyOverride.value!.toUpperCase() == 'INR';
    }
    final code = userCountryCode.value.toUpperCase();
    return code == 'IN' || code == 'IND' || code == 'INDIA';
  }

  /// Active currency for current user ('USD' for non-Indian, 'INR' for Indian)
  String get activeUserCurrency => isIndianUser ? 'INR' : 'USD';
  String get activeUserCurrencySymbol => isIndianUser ? '₹' : r'$';

  // ---------------------------------------------------------------------------
  // Conversion & Formatting APIs (Powered by Real-Time Market Rate)
  // ---------------------------------------------------------------------------

  /// Convert any price to the current user's local currency using the live rate
  double localizeAmount({required double price, required String itemCurrency}) {
    if (price.isNaN || price.isInfinite || price <= 0.0) return 0.0;
    final isItemInr = itemCurrency.toUpperCase() == 'INR';
    final currentRate = rate;
    if (!isIndianUser) {
      // Non-Indian: convert to USD at live rate
      return isItemInr ? (price / currentRate) : price;
    } else {
      // Indian: convert to INR at live rate
      return isItemInr ? price : (price * currentRate);
    }
  }

  /// Convert USD amount to INR using the real-time live rate
  double convertUsdToInr(double usd) {
    if (usd.isNaN || usd.isInfinite || usd <= 0.0) return 0.0;
    return usd * rate;
  }

  /// Convert INR amount to USD using the real-time live rate
  double convertInrToUsd(double inr) {
    if (inr.isNaN || inr.isInfinite || inr <= 0.0) return 0.0;
    final currentRate = rate;
    return inr / currentRate;
  }

  /// Format any price for the current user in real-time (e.g. '$0.12' or '₹10')
  String formatForUser({
    required double price,
    required String itemCurrency,
  }) {
    if (price.isNaN || price.isInfinite || price <= 0.0) {
      return !isIndianUser ? r'$0.00' : '₹0';
    }
    if (!isIndianUser) {
      final usd = localizeAmount(price: price, itemCurrency: itemCurrency);
      return '\$${usd.toStringAsFixed(2)}';
    } else {
      final inr = localizeAmount(price: price, itemCurrency: itemCurrency);
      final isWhole = inr == inr.truncateToDouble();
      return '₹${isWhole ? inr.toInt() : inr.toStringAsFixed(2)}';
    }
  }
}
