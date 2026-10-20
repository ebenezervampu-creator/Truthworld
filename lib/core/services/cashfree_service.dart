import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/network/ssl_pinning_manager.dart';
import 'package:truthworld/core/security/rasp_security_service.dart';
import 'package:truthworld/core/security/screen_security_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree/cashfree_adapter.dart';
import 'package:truthworld/core/services/cashfree/cashfree_country_support.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result object for a Cashfree transaction
class CashfreePaymentResult {
  final bool success;
  final String orderId;
  final String? errorMessage;
  final Map<String, dynamic>? details;

  const CashfreePaymentResult({
    required this.success,
    required this.orderId,
    this.errorMessage,
    this.details,
  });
}

/// Central GetX Service managing Cashfree Payment Gateway flows across TruthWorld.
class CashfreePaymentService extends GetxService with WidgetsBindingObserver {
  static CashfreePaymentService get to {
    if (!Get.isRegistered<CashfreePaymentService>()) {
      Get.put(CashfreePaymentService(), permanent: true);
    }
    return Get.find<CashfreePaymentService>();
  }

  /// Whether native Cashfree PG callbacks should be registered (can be disabled in pure unit tests)
  static bool enableNativeGateway = true;

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  final CashfreeGatewayAdapter _cfGateway = CashfreeGatewayAdapter();
  final RxBool isProcessing = false.obs;
  final RxString activeOrderId = ''.obs;

  Completer<CashfreePaymentResult>? _activeCompleter;
  String? _activePaymentLink;
  String? _activeSubscriptionId;
  bool _isAutoVerifying = false;
  bool _isVerificationPromptOpen = false;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _initGatewayCallbacks();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (isProcessing.value && activeOrderId.value.isNotEmpty && !_isAutoVerifying) {
        _checkPaymentStatusOnResume();
      }
    }
  }

  Future<void> _checkPaymentStatusOnResume() async {
    if (_isAutoVerifying) return;
    final orderId = activeOrderId.value;
    if (orderId.isEmpty) return;

    _isAutoVerifying = true;
    try {
      // Brief pause to allow webhook or gateway state to finalize
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!isProcessing.value || activeOrderId.value != orderId) {
        _isAutoVerifying = false;
        return;
      }

      final subId = _activeSubscriptionId;
      if (subId != null && subId.isNotEmpty) {
        final subRes = await verifySubscriptionOnServer(subId);
        if (subRes.success) {
          AppSnackbar.success('Auto Pay mandate verified successfully!');
          _resolveActivePayment(subRes);
          return;
        }
      }

      final res = await verifyOrderOnServer(orderId);
      if (res.success) {
        AppSnackbar.success('Payment verified successfully!');
        _resolveActivePayment(res);
        return;
      }

      // If gateway is still finalizing transaction, wait and check a second time
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!isProcessing.value || activeOrderId.value != orderId) {
        _isAutoVerifying = false;
        return;
      }

      if (subId != null && subId.isNotEmpty) {
        final subRes2 = await verifySubscriptionOnServer(subId);
        if (subRes2.success) {
          AppSnackbar.success('Auto Pay mandate verified successfully!');
          _resolveActivePayment(subRes2);
          return;
        }
      }

      final res2 = await verifyOrderOnServer(orderId);
      if (res2.success) {
        AppSnackbar.success('Payment verified successfully!');
        _resolveActivePayment(res2);
        return;
      }

      // If still processing and unconfirmed after returning, display manual verification prompt
      if (isProcessing.value && activeOrderId.value == orderId && !_isVerificationPromptOpen) {
        if (subId != null && subId.isNotEmpty) {
          _showSubscriptionVerificationPrompt(subId, orderId);
        } else {
          _showExternalVerificationPrompt(orderId);
        }
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'CashfreePaymentService._checkPaymentStatusOnResume');
    } finally {
      _isAutoVerifying = false;
    }
  }

  void _safeCloseDialog() {
    try {
      if (_isVerificationPromptOpen || (Get.isDialogOpen ?? false)) {
        _isVerificationPromptOpen = false;
        if (Get.isDialogOpen ?? false) {
          Get.back();
        } else {
          final nav = Get.key.currentState;
          if (nav != null && nav.canPop()) {
            nav.pop();
          }
        }
      }
    } catch (e) {
      debugPrint('[CashfreePaymentService] Error closing dialog: $e');
    }
  }

  /// Dispatched by deep link handlers (e.g. truthworld://payment-result or /checkout?action=result)
  Future<void> handlePaymentResult({
    required String orderId,
    String? status,
    String? subscriptionId,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[CashfreePaymentService] handlePaymentResult: orderId=$orderId, status=$status, subId=$subscriptionId',
      );
    }

    _safeCloseDialog();

    final normalizedStatus = status?.trim().toUpperCase();
    if (normalizedStatus == 'CANCELLED' || normalizedStatus == 'FAILED') {
      _resolveActivePayment(
        CashfreePaymentResult(
          success: false,
          orderId: orderId,
          errorMessage: 'Payment was not completed. Please try again.',
        ),
      );
      return;
    }

    if (subscriptionId != null && subscriptionId.isNotEmpty) {
      final subRes = await verifySubscriptionOnServer(subscriptionId);
      if (subRes.success) {
        AppSnackbar.success('Auto Pay mandate verified successfully!');
        _resolveActivePayment(subRes);
        return;
      }
    }

    final res = await verifyOrderOnServer(orderId);
    if (res.success) {
      AppSnackbar.success('Payment verified successfully!');
      _resolveActivePayment(res);
    } else {
      AppSnackbar.warning(
        'Payment is pending or not yet confirmed by gateway. Please check your bank statement.',
      );
      _resolveActivePayment(res);
    }
  }

  void _initGatewayCallbacks() {
    if (!enableNativeGateway) return;
    if (!_isMobile) return;

    try {
      _cfGateway.initCallbacks(
        onVerify: _onPaymentVerify,
        onError: _onPaymentError,
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CashfreePaymentService._initGatewayCallbacks',
      );
    }
  }

  static const _trustedPaymentHosts = {
    'payments.cashfree.com',
    'payments-test.cashfree.com',
    'api.cashfree.com',
    'checkout.cashfree.com',
    'sandbox.cashfree.com',
    'truthworld.app',
    'www.truthworld.in',
    'truthworld.in',
  };

  static bool _isTrustedPaymentUrl(Uri uri) {
    if (uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    return _trustedPaymentHosts.contains(host) || host.endsWith('.cashfree.com');
  }

  /// Triggered by Cashfree SDK when payment flow completes native verification
  Future<void> _onPaymentVerify(String orderId) async {
    if (kDebugMode) {
      debugPrint('[CashfreePaymentService] SDK Callback verified order: $orderId');
    }
    try {
      final verifyResult = await verifyOrderOnServer(orderId);
      if (verifyResult.success) {
        _resolveActivePayment(
          CashfreePaymentResult(
            success: true,
            orderId: orderId,
            details: verifyResult.details,
          ),
        );
      } else {
        _resolveActivePayment(
          CashfreePaymentResult(
            success: false,
            orderId: orderId,
            errorMessage: 'Payment was not confirmed. Please check your bank statement.',
          ),
        );
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'CashfreePaymentService._onPaymentVerify');
      _resolveActivePayment(
        CashfreePaymentResult(
          success: false,
          orderId: orderId,
          errorMessage: 'Unable to verify payment status. Please try again.',
        ),
      );
    }
  }

  /// Triggered by Cashfree SDK when payment is cancelled or failed
  void _onPaymentError(String rawMsg, String orderId) {
    if (kDebugMode) {
      debugPrint(
        '[CashfreePaymentService] Payment error: $rawMsg for order: $orderId',
      );
    }

    // If native checkout fails due to Android debug/sideload integrity checks (installer_package_not_approved)
    // or missing native component, gracefully fallback to TruthWorld's secure hosted checkout link.
    final lowerMsg = rawMsg.toLowerCase();
    final isInstallerOrIntegrityError = lowerMsg.contains('installer_package_not_approved') ||
        lowerMsg.contains('installer') ||
        lowerMsg.contains('package_not_approved') ||
        lowerMsg.contains('not approved') ||
        lowerMsg.contains('verification failed') ||
        lowerMsg.contains('activity not found');

    final fallbackUrl = (_activePaymentLink != null && _activePaymentLink!.isNotEmpty)
        ? _activePaymentLink!
        : 'https://www.truthworld.in/checkout?order_id=${Uri.encodeComponent(orderId)}';

    if (isInstallerOrIntegrityError) {
      if (kDebugMode) {
        debugPrint(
          '[CashfreePaymentService] Native SDK rejected installer in debug/sideloaded build ($rawMsg). '
          'Gracefully launching hosted checkout fallback: $fallbackUrl',
        );
      }
      _launchExternalCheckout(fallbackUrl, orderId);
      return;
    }

    var sanitizedErr = UserFeedbackSanitizer.sanitizeMessage(
      rawMsg.isNotEmpty ? rawMsg : 'Payment could not be completed.',
      defaultActionContext: 'process payment',
    );
    final lowerSanitized = sanitizedErr.trim().toLowerCase();
    if (lowerSanitized == 'internal' ||
        lowerSanitized == 'unavailable' ||
        lowerSanitized == 'internal error' ||
        lowerSanitized.isEmpty) {
      sanitizedErr = 'Payment could not be completed. Please try again.';
    }

    _resolveActivePayment(
      CashfreePaymentResult(
        success: false,
        orderId: orderId,
        errorMessage: sanitizedErr,
      ),
    );
  }

  void _resolveActivePayment(CashfreePaymentResult result) {
    _safeCloseDialog();
    _isVerificationPromptOpen = false;
    isProcessing.value = false;
    _activePaymentLink = null;
    _activeSubscriptionId = null;
    unawaited(ScreenSecurityService.to.disableSecureMode());
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.complete(result);
    }
    _activeCompleter = null;
  }

  /// Initiates payment for any purpose across TruthWorld supporting all
  /// countries provided by Cashfree (200+ countries, 140+ currencies).
  ///
  /// [amount] in specified [currency] (or user's localized currency / INR if not specified)
  /// [purpose] e.g., 'premium_subscription', 'advertiser_campaign', 'advertiser_wallet', 'channel_topup', 'superchat', 'super_thanks'
  /// [currency] 3-letter currency ISO code (e.g., 'INR', 'USD', 'EUR', 'GBP', 'AED', 'CAD', 'AUD', etc.)
  Future<CashfreePaymentResult> startPayment({
    required double amount,
    required String purpose,
    required String orderNote,
    String? currency,
    String? customerPhone,
    Map<String, dynamic>? metadata,
  }) async {
    final auth = AuthService.to;
    if (!auth.isAuthenticated.value) {
      AppSnackbar.warning(
        'Sign in required to proceed with payment.',
        title: 'Sign In Required',
      );
      return const CashfreePaymentResult(
        success: false,
        orderId: '',
        errorMessage: 'User is not authenticated',
      );
    }

    final userCountry = Get.isRegistered<CurrencyLocalizationService>()
        ? CurrencyLocalizationService.to.userCountryCode.value
        : 'IN';

    // Verify country compliance against Cashfree restricted jurisdictions
    if (CashfreeCountrySupport.isRestrictedCountry(userCountry)) {
      AppSnackbar.warning(
        'Payment services are currently unavailable in your region due to regulatory compliance restrictions.',
        title: 'Region Unavailable',
      );
      return const CashfreePaymentResult(
        success: false,
        orderId: '',
        errorMessage: 'Cashfree payment services are unavailable in this region.',
      );
    }

    // Resolve target currency
    final effectiveCurrency = (currency != null && currency.trim().isNotEmpty)
        ? currency.trim().toUpperCase()
        : (Get.isRegistered<CurrencyLocalizationService>()
            ? CurrencyLocalizationService.to.activeUserCurrency
            : 'INR');

    final minAmount = CashfreeCountrySupport.getMinimumAmount(effectiveCurrency);
    if (amount.isNaN || amount.isInfinite || amount < minAmount) {
      final minFormatted = CashfreeCountrySupport.formatAmount(minAmount, effectiveCurrency);
      AppSnackbar.warning('Minimum transaction amount is $minFormatted.');
      return CashfreePaymentResult(
        success: false,
        orderId: '',
        errorMessage: 'Transaction amount must be at least $minFormatted',
      );
    }

    final sanitizedAmount = double.parse(amount.toStringAsFixed(2));

    // Verify runtime integrity (RASP) & SSL certificate pinning
    if (!kIsWeb) {
      try {
        final isSecure = await RaspSecurityService.to.isEnvironmentSecure();
        if (!isSecure && kReleaseMode) {
          await RaspSecurityService.to.enforceAppIntegrity();
          AppSnackbar.warning(
            'Unable to process transaction due to security integrity violation.',
          );
          return const CashfreePaymentResult(
            success: false,
            orderId: '',
            errorMessage: 'Security integrity violation detected.',
          );
        }

        final isSslSecure =
            await SslPinningManager.instance.validatePaymentEndpoints();
        if (!isSslSecure && kReleaseMode) {
          AppSnackbar.warning(
            'Secure connection could not be verified. Please check your network and try again.',
          );
          return const CashfreePaymentResult(
            success: false,
            orderId: '',
            errorMessage: 'SSL Pinning verification failed.',
          );
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'CashfreePaymentService.securityValidation',
        );
      }
    }

    try {
      isProcessing.value = true;
      unawaited(ScreenSecurityService.to.enableSecureMode());

      // 1. Authoritatively create order on server
      final createCallable = _functions.httpsCallable('createCashfreeOrder');
      final createResponse = await createCallable.call({
        'amount': sanitizedAmount,
        'currency': effectiveCurrency,
        'purpose': purpose,
        'orderNote': orderNote,
        'customerPhone': customerPhone,
        'metadata': {
          ...?metadata,
          'userCountry': userCountry,
          'currency': effectiveCurrency,
        },
      });

      final data = Map<String, dynamic>.from(createResponse.data as Map);
      final orderId = data['orderId'] as String;
      final paymentSessionId = data['paymentSessionId'] as String?;
      final paymentLink = data['paymentLink'] as String?;
      final isSubscription = data['isSubscription'] as bool? ?? false;
      final subscriptionId = data['subscriptionId'] as String?;
      final authLink = data['authLink'] as String?;
      final envString = (data['environment'] as String? ?? 'SANDBOX').toUpperCase();

      activeOrderId.value = orderId;
      _activePaymentLink = paymentLink ??
          (paymentSessionId != null
              ? 'https://www.truthworld.in/checkout?session_id=${Uri.encodeComponent(paymentSessionId)}&order_id=${Uri.encodeComponent(orderId)}&env=${envString.toLowerCase()}'
              : null);
      _activeSubscriptionId = isSubscription ? (subscriptionId ?? orderId) : null;
      _activeCompleter = Completer<CashfreePaymentResult>();

      if (isSubscription && authLink != null && authLink.isNotEmpty) {
        // Industry-Standard Cashfree Subscriptions Auto Pay Flow (UPI Autopay / e-Mandate)
        final uri = Uri.parse(authLink);
        if (!_isTrustedPaymentUrl(uri)) {
          ErrorHandler.log(
            ArgumentError('Blocked untrusted subscription mandate URL: ${uri.host}'),
            stackTrace: StackTrace.current,
            tag: 'CashfreePaymentService.startPayment',
          );
          _resolveActivePayment(
            CashfreePaymentResult(
              success: false,
              orderId: orderId,
              errorMessage: 'Untrusted payment link blocked for your security.',
            ),
          );
          return _activeCompleter!.future;
        }

        try {
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) {
            if (!_isMobile) {
              _showSubscriptionVerificationPrompt(subscriptionId ?? orderId, orderId);
            }
          } else {
            _resolveActivePayment(
              CashfreePaymentResult(
                success: false,
                orderId: orderId,
                errorMessage: 'Unable to open mandate authorization page. Please check your browser popup settings.',
              ),
            );
          }
        } catch (authErr, s) {
          ErrorHandler.log(authErr, stackTrace: s, tag: 'CashfreePaymentService.launchAuthLink');
          _resolveActivePayment(
            CashfreePaymentResult(
              success: false,
              orderId: orderId,
              errorMessage: 'Unable to launch Auto Pay authorization. Please try again.',
            ),
          );
        }
      } else if (_isMobile &&
          enableNativeGateway &&
          paymentSessionId != null &&
          paymentSessionId.isNotEmpty) {
        // Mobile platforms (Android / iOS): invoke native Cashfree PG SDK
        try {
          _initGatewayCallbacks();
          _cfGateway.doPayment(
            orderId: orderId,
            paymentSessionId: paymentSessionId,
            isProduction: envString == 'PRODUCTION',
          );
        } catch (nativeErr, stackTrace) {
          ErrorHandler.log(
            nativeErr,
            stackTrace: stackTrace,
            tag: 'CashfreePaymentService.nativePayment',
          );
          final fallbackLink = _activePaymentLink ??
              'https://www.truthworld.in/checkout?session_id=${Uri.encodeComponent(paymentSessionId)}&order_id=${Uri.encodeComponent(orderId)}&env=${envString.toLowerCase()}';
          await _launchExternalCheckout(fallbackLink, orderId);
        }
      } else if (paymentLink != null && paymentLink.isNotEmpty) {
        // Authoritative TruthWorld Hosted Checkout flow (works seamlessly on Android, iOS, Web, and Desktop)
        // Loads Cashfree JS SDK v3 checkout container with full UPI app intent support
        await _launchExternalCheckout(paymentLink, orderId);
      } else if (paymentSessionId != null && paymentSessionId.isNotEmpty) {
        // Fallback checkout link construction
        final envParam = envString.toLowerCase();
        final fallbackLink =
            'https://www.truthworld.in/checkout?session_id=${Uri.encodeComponent(paymentSessionId)}&order_id=${Uri.encodeComponent(orderId)}&env=$envParam';
        await _launchExternalCheckout(fallbackLink, orderId);
      } else {
        _resolveActivePayment(
          CashfreePaymentResult(
            success: false,
            orderId: orderId,
            errorMessage: 'Payment session could not be established. Please try again.',
          ),
        );
      }

      return await _activeCompleter!.future;
    } catch (e, stackTrace) {
      isProcessing.value = false;
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'CashfreePaymentService.startPayment');

      final errString = e.toString().toLowerCase();
      String? code;
      String? rawMsg;
      if (e is FirebaseFunctionsException) {
        code = e.code.toLowerCase();
        rawMsg = (e.message ?? '').toLowerCase();
      } else {
        try {
          final dynamic dyn = e;
          if (dyn.code != null) code = dyn.code.toString().toLowerCase();
          if (dyn.message != null) rawMsg = dyn.message.toString().toLowerCase();
        } catch (_) {}
      }

      String friendlyError;
      if (code == 'failed-precondition' || (rawMsg != null && rawMsg.contains('configured'))) {
        friendlyError = 'Payment service is currently undergoing maintenance. Please check back shortly.';
      } else if (code == 'unauthenticated') {
        friendlyError = 'Please sign in to proceed with your payment.';
      } else if ((code != null &&
              (code.contains('internal') ||
                  code.contains('unavailable') ||
                  code == 'unknown')) ||
          (rawMsg != null &&
              (rawMsg.contains('internal') ||
                  rawMsg.contains('unavailable') ||
                  rawMsg.contains('profile_inactive'))) ||
          errString.contains('internal') ||
          errString.contains('unavailable') ||
          errString.contains('profile_inactive')) {
        friendlyError = 'Unable to connect to the payment gateway right now. Please try again in a few moments.';
      } else if (rawMsg != null && rawMsg.isNotEmpty) {
        friendlyError = UserFeedbackSanitizer.sanitizeMessage(
          rawMsg,
          defaultActionContext: 'process payment',
        );
      } else {
        friendlyError = UserFeedbackSanitizer.sanitizeMessage(
          e,
          defaultActionContext: 'process payment',
        );
      }

      // Hard defensive check: ensure friendlyError is never a raw technical error
      final lowerFriendly = friendlyError.trim().toLowerCase();
      if (lowerFriendly == 'internal' ||
          lowerFriendly == 'unavailable' ||
          lowerFriendly == 'internal error' ||
          lowerFriendly.isEmpty) {
        friendlyError = 'Unable to process payment right now. Please try again in a few moments.';
      }

      unawaited(ScreenSecurityService.to.disableSecureMode());
      return CashfreePaymentResult(
        success: false,
        orderId: activeOrderId.value,
        errorMessage: friendlyError,
      );
    }
  }

  /// Authoritatively queries the backend function to verify payment status
  Future<CashfreePaymentResult> verifyOrderOnServer(String orderId) async {
    try {
      final verifyCallable = _functions.httpsCallable('verifyCashfreePayment');
      final result = await verifyCallable.call({'orderId': orderId});
      final data = Map<String, dynamic>.from(result.data as Map);

      final isSuccess = data['success'] == true && data['orderStatus'] == 'PAID';
      return CashfreePaymentResult(
        success: isSuccess,
        orderId: orderId,
        details: data,
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'CashfreePaymentService.verifyOrderOnServer');
      return CashfreePaymentResult(
        success: false,
        orderId: orderId,
        errorMessage: 'Server verification failed',
      );
    }
  }

  /// Authoritatively queries the backend function to verify Cashfree subscription mandate status
  Future<CashfreePaymentResult> verifySubscriptionOnServer(String subscriptionId) async {
    try {
      final verifyCallable = _functions.httpsCallable('verifyCashfreeSubscription');
      final result = await verifyCallable.call({'subscriptionId': subscriptionId});
      final data = Map<String, dynamic>.from(result.data as Map);

      final isSuccess = data['success'] == true && data['subscriptionStatus'] == 'ACTIVE';
      return CashfreePaymentResult(
        success: isSuccess,
        orderId: subscriptionId,
        details: data,
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'CashfreePaymentService.verifySubscriptionOnServer');
      return CashfreePaymentResult(
        success: false,
        orderId: subscriptionId,
        errorMessage: 'Subscription mandate verification failed',
      );
    }
  }

  /// Cancels an active recurring auto pay subscription with Cashfree and updates Firestore
  Future<bool> cancelSubscriptionOnServer(String subscriptionId, {String? reason}) async {
    try {
      final cancelCallable = _functions.httpsCallable('cancelCashfreeSubscription');
      final result = await cancelCallable.call({
        'subscriptionId': subscriptionId,
        'reason': reason ?? 'Cancelled by user in TruthWorld',
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return data['success'] == true;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'CashfreePaymentService.cancelSubscriptionOnServer');
      return false;
    }
  }

  /// Launches hosted web checkout in external application (browser/custom tab)
  Future<void> _launchExternalCheckout(String link, String orderId) async {
    final uri = Uri.parse(link);
    if (!_isTrustedPaymentUrl(uri)) {
      ErrorHandler.log(
        ArgumentError('Blocked untrusted external checkout URL: ${uri.host}'),
        stackTrace: StackTrace.current,
        tag: 'CashfreePaymentService._launchExternalCheckout',
      );
      _resolveActivePayment(
        CashfreePaymentResult(
          success: false,
          orderId: orderId,
          errorMessage: 'Untrusted payment link blocked for your security.',
        ),
      );
      return;
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) {
        if (!_isMobile) {
          _showExternalVerificationPrompt(orderId);
        }
      } else {
        _resolveActivePayment(
          CashfreePaymentResult(
            success: false,
            orderId: orderId,
            errorMessage: 'Unable to open checkout window. Please check your browser settings.',
          ),
        );
      }
    } catch (launchErr, s) {
      ErrorHandler.log(
        launchErr,
        stackTrace: s,
        tag: 'CashfreePaymentService.launchExternalCheckout',
      );
      _resolveActivePayment(
        CashfreePaymentResult(
          success: false,
          orderId: orderId,
          errorMessage: 'Unable to open checkout page. Please try again.',
        ),
      );
    }
  }

  /// For Desktop/Web link fallback: prompts user to confirm once done
  void _showDesktopVerificationPrompt(String orderId) {
    _showExternalVerificationPrompt(orderId);
  }

  /// For external/hosted browser checkout fallback: prompts user to confirm once done
  void _showExternalVerificationPrompt(String orderId) {
    if (_isVerificationPromptOpen || (Get.isDialogOpen ?? false)) return;
    _isVerificationPromptOpen = true;
    Get.dialog(
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _isVerificationPromptOpen = false;
            _resolveActivePayment(
              CashfreePaymentResult(
                success: false,
                orderId: orderId,
                errorMessage: 'Payment was cancelled by user.',
              ),
            );
          }
        },
        child: Dialog(
          backgroundColor: AppColors.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.searchBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.payment_rounded,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Complete Payment',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please complete the transaction in the checkout window, then confirm below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final res = await verifyOrderOnServer(orderId);
                    if (res.success) {
                      AppSnackbar.success('Payment verified successfully!');
                      _resolveActivePayment(res);
                    } else {
                      AppSnackbar.warning(
                        'Payment is not yet confirmed by gateway. Please check your bank statement.',
                      );
                      _resolveActivePayment(res);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'I Have Paid',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    _resolveActivePayment(
                      CashfreePaymentResult(
                        success: false,
                        orderId: orderId,
                        errorMessage: 'Payment was cancelled by user.',
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Cancel Payment'),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  /// For Subscriptions / Auto Pay link authorization: prompts user to confirm mandate
  void _showSubscriptionVerificationPrompt(String subscriptionId, String orderId) {
    if (_isVerificationPromptOpen || (Get.isDialogOpen ?? false)) return;
    _isVerificationPromptOpen = true;
    Get.dialog(
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _isVerificationPromptOpen = false;
            _resolveActivePayment(
              CashfreePaymentResult(
                success: false,
                orderId: orderId,
                errorMessage: 'Auto Pay authorization was cancelled.',
              ),
            );
          }
        },
        child: Dialog(
          backgroundColor: AppColors.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.searchBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.autorenew_rounded,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Authorize Auto Pay',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Please authorize the recurring mandate in the secure Cashfree window using ${CashfreeCountrySupport.getMandateMethodsSummary(CurrencyLocalizationService.to.userCountryCode.value)}, then click Verify.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final res = await verifySubscriptionOnServer(subscriptionId);
                    if (res.success) {
                      AppSnackbar.success('Auto Pay mandate verified successfully!');
                      _resolveActivePayment(res);
                    } else {
                      // Fallback to order verification if mandate confirmation is in transit
                      final orderRes = await verifyOrderOnServer(orderId);
                      if (orderRes.success) {
                        AppSnackbar.success('Payment verified successfully!');
                        _resolveActivePayment(orderRes);
                      } else {
                        AppSnackbar.warning(
                          'Mandate authorization is pending bank confirmation. It will activate once confirmed.',
                        );
                        _resolveActivePayment(res);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'I Have Authorized',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    _resolveActivePayment(
                      CashfreePaymentResult(
                        success: false,
                        orderId: orderId,
                        errorMessage: 'Auto Pay authorization was cancelled.',
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Cancel Authorization'),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  /// Checks whether Cashfree provides payment gateway for this country
  bool isCountrySupported(String? countryCode) =>
      CashfreeCountrySupport.isCountrySupported(countryCode);

  /// Checks whether a currency is supported by Cashfree
  bool isCurrencySupported(String? currencyCode) =>
      CashfreeCountrySupport.isCurrencySupported(currencyCode);

  /// Gets country metadata
  CashfreeCountryInfo getCountryInfo(String? countryCode) =>
      CashfreeCountrySupport.getCountryInfo(countryCode);
}
