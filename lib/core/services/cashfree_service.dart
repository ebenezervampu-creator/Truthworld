import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
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
class CashfreePaymentService extends GetxService {
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

  final CFPaymentGatewayService _cfGateway = CFPaymentGatewayService();
  final RxBool isProcessing = false.obs;
  final RxString activeOrderId = ''.obs;

  Completer<CashfreePaymentResult>? _activeCompleter;
  String? _activePaymentLink;

  @override
  void onInit() {
    super.onInit();
    _initGatewayCallbacks();
  }

  void _initGatewayCallbacks() {
    if (!enableNativeGateway) return;
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!isMobile) return;

    try {
      _cfGateway.setCallback(
        _onPaymentVerify,
        _onPaymentError,
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CashfreePaymentService._initGatewayCallbacks',
      );
    }
  }

  /// Triggered by Cashfree SDK when payment flow completes native verification
  Future<void> _onPaymentVerify(String orderId) async {
    debugPrint('[CashfreePaymentService] SDK Callback verified order: $orderId');
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
  void _onPaymentError(CFErrorResponse errorResponse, String orderId) {
    final rawMsg = errorResponse.getMessage() ?? '';
    debugPrint(
      '[CashfreePaymentService] Payment error: $rawMsg for order: $orderId',
    );

    // If native checkout fails due to Android debug/sideload integrity checks (installer_package_not_approved)
    // or missing native component, gracefully fallback to TruthWorld's secure hosted checkout link.
    final lowerMsg = rawMsg.toLowerCase();
    final isInstallerOrIntegrityError = lowerMsg.contains('installer_package_not_approved') ||
        lowerMsg.contains('installer') ||
        lowerMsg.contains('package_not_approved') ||
        lowerMsg.contains('not approved') ||
        lowerMsg.contains('verification failed') ||
        lowerMsg.contains('activity not found');

    if (isInstallerOrIntegrityError && _activePaymentLink != null && _activePaymentLink!.isNotEmpty) {
      debugPrint(
        '[CashfreePaymentService] Native SDK rejected installer in debug/sideloaded build ($rawMsg). '
        'Gracefully launching hosted checkout fallback.',
      );
      _launchExternalCheckout(_activePaymentLink!, orderId);
      return;
    }

    _resolveActivePayment(
      CashfreePaymentResult(
        success: false,
        orderId: orderId,
        errorMessage: rawMsg.isNotEmpty ? rawMsg : 'Payment could not be completed.',
      ),
    );
  }

  void _resolveActivePayment(CashfreePaymentResult result) {
    isProcessing.value = false;
    _activePaymentLink = null;
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.complete(result);
    }
    _activeCompleter = null;
  }

  /// Initiates payment for any purpose across TruthWorld.
  ///
  /// [amount] in INR
  /// [purpose] e.g., 'premium_subscription', 'advertiser_campaign', 'advertiser_wallet', 'channel_topup', 'superchat'
  Future<CashfreePaymentResult> startPayment({
    required double amount,
    required String purpose,
    required String orderNote,
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

    if (amount.isNaN || amount.isInfinite || amount < 1.0) {
      AppSnackbar.warning('Minimum transaction amount is ₹1.00.');
      return const CashfreePaymentResult(
        success: false,
        orderId: '',
        errorMessage: 'Transaction amount must be at least ₹1.00',
      );
    }

    final sanitizedAmount = double.parse(amount.toStringAsFixed(2));

    try {
      isProcessing.value = true;

      // 1. Authoritatively create order on server
      final createCallable = _functions.httpsCallable('createCashfreeOrder');
      final createResponse = await createCallable.call({
        'amount': sanitizedAmount,
        'currency': 'INR',
        'purpose': purpose,
        'orderNote': orderNote,
        'customerPhone': customerPhone,
        'metadata': metadata ?? {},
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
      _activePaymentLink = paymentLink;
      _activeCompleter = Completer<CashfreePaymentResult>();

      final isMobile = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);

      if (isSubscription && authLink != null && authLink.isNotEmpty) {
        // Industry-Standard Cashfree Subscriptions Auto Pay Flow (UPI Autopay / e-Mandate)
        final uri = Uri.parse(authLink);
        try {
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) {
            _showSubscriptionVerificationPrompt(subscriptionId ?? orderId, orderId);
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
      } else if (isMobile && paymentSessionId != null && paymentSessionId.isNotEmpty) {
        // Native Mobile Flow via Cashfree PG SDK
        final cfEnv = envString == 'PRODUCTION'
            ? CFEnvironment.PRODUCTION
            : CFEnvironment.SANDBOX;

        // Cashfree native Android SDK enforces strict Google Play Store installer verification
        // in PRODUCTION mode ('installer_package_not_approved'). During development/debug builds (kDebugMode),
        // or when running on an emulator or sideloaded APK with PRODUCTION credentials,
        // bypass the native installer restriction by launching the secure TruthWorld hosted checkout link.
        final shouldBypassNativeInDebug = kDebugMode &&
            defaultTargetPlatform == TargetPlatform.android &&
            cfEnv == CFEnvironment.PRODUCTION &&
            paymentLink != null &&
            paymentLink.isNotEmpty;

        if (shouldBypassNativeInDebug) {
          debugPrint(
            '[CashfreePaymentService] Android debug mode detected with PRODUCTION Cashfree environment. '
            'Bypassing native Play Store installer check and launching secure hosted checkout.',
          );
          await _launchExternalCheckout(paymentLink, orderId);
        } else {
          try {
            _initGatewayCallbacks();

            final session = CFSessionBuilder()
                .setEnvironment(cfEnv)
                .setOrderId(orderId)
                .setPaymentSessionId(paymentSessionId)
                .build();

            final theme = CFThemeBuilder()
                .setPrimaryTextColor('#FFFFFF')
                .setBackgroundColor('#161618')
                .setButtonBackgroundColor('#FFFFFF')
                .setButtonTextColor('#000000')
                .build();

            final cfPayment = CFWebCheckoutPaymentBuilder()
                .setSession(session)
                .setTheme(theme)
                .build();

            _cfGateway.doPayment(cfPayment);
          } catch (nativeErr, stackTrace) {
            ErrorHandler.log(
              nativeErr,
              stackTrace: stackTrace,
              tag: 'CashfreePaymentService.nativePayment',
            );
            if (paymentLink != null && paymentLink.isNotEmpty) {
              debugPrint(
                '[CashfreePaymentService] Native payment invocation failed ($nativeErr). Falling back to hosted checkout.',
              );
              await _launchExternalCheckout(paymentLink, orderId);
            } else {
              _resolveActivePayment(
                CashfreePaymentResult(
                  success: false,
                  orderId: orderId,
                  errorMessage: 'Unable to start payment on this device. Please try again.',
                ),
              );
            }
          }
        }
      } else if (paymentLink != null && paymentLink.isNotEmpty) {
        // Web / Desktop / Fallback flow: launch hosted checkout URL
        await _launchExternalCheckout(paymentLink, orderId);
      } else if (kIsWeb && paymentSessionId != null && paymentSessionId.isNotEmpty) {
        // Web direct checkout fallback when SDK is present
        try {
          final cfEnv = envString == 'PRODUCTION'
              ? CFEnvironment.PRODUCTION
              : CFEnvironment.SANDBOX;

          final session = CFSessionBuilder()
              .setEnvironment(cfEnv)
              .setOrderId(orderId)
              .setPaymentSessionId(paymentSessionId)
              .build();

          final cfPayment = CFWebCheckoutPaymentBuilder()
              .setSession(session)
              .build();

          _cfGateway.doPayment(cfPayment);
        } catch (webErr, ws) {
          ErrorHandler.log(webErr, stackTrace: ws, tag: 'CashfreePaymentService.webCheckout');
          _resolveActivePayment(
            CashfreePaymentResult(
              success: false,
              orderId: orderId,
              errorMessage: 'Unable to launch web checkout session. Please try again.',
            ),
          );
        }
      } else {
        _resolveActivePayment(
          CashfreePaymentResult(
            success: false,
            orderId: orderId,
            errorMessage: isMobile
                ? 'Payment session could not be established. Please try again.'
                : 'Direct checkout link is unavailable for this platform. Please use mobile or try again later.',
          ),
        );
      }

      return await _activeCompleter!.future;
    } catch (e, stackTrace) {
      isProcessing.value = false;
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'CashfreePaymentService.startPayment');

      var friendlyError = UserFeedbackSanitizer.sanitizeMessage(
        e,
        defaultActionContext: 'process payment',
      );
      if (e is FirebaseFunctionsException) {
        if (e.code == 'failed-precondition' || (e.message?.contains('configured') ?? false)) {
          friendlyError = 'Payment service is currently undergoing maintenance. Please check back shortly.';
        } else if (e.code == 'unauthenticated') {
          friendlyError = 'Please sign in to proceed with your payment.';
        } else if (e.message != null && e.message!.isNotEmpty) {
          friendlyError = UserFeedbackSanitizer.sanitizeMessage(e.message);
        }
      }

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
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) {
        _showExternalVerificationPrompt(orderId);
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
    Get.defaultDialog(
      title: 'Complete Payment',
      middleText: 'Please complete the payment in your browser window, then click Verify.',
      textConfirm: 'I Have Paid',
      textCancel: 'Cancel',
      confirmTextColor: Get.theme.colorScheme.onPrimary,
      barrierDismissible: false,
      onWillPop: () async {
        _resolveActivePayment(
          CashfreePaymentResult(
            success: false,
            orderId: orderId,
            errorMessage: 'Payment was cancelled by user.',
          ),
        );
        return true;
      },
      onConfirm: () async {
        Get.back();
        AppSnackbar.info('Verifying payment with gateway...');
        final res = await verifyOrderOnServer(orderId);
        if (res.success) {
          AppSnackbar.success('Payment verified successfully!');
          _resolveActivePayment(res);
        } else {
          AppSnackbar.warning('Payment is not yet confirmed by gateway. Please try again.');
          _resolveActivePayment(res);
        }
      },
      onCancel: () {
        _resolveActivePayment(
          CashfreePaymentResult(
            success: false,
            orderId: orderId,
            errorMessage: 'Payment was cancelled by user.',
          ),
        );
      },
    );
  }

  /// For Subscriptions / Auto Pay link authorization: prompts user to confirm mandate
  void _showSubscriptionVerificationPrompt(String subscriptionId, String orderId) {
    Get.defaultDialog(
      title: 'Authorize Auto Pay',
      middleText:
          'Please authorize the recurring mandate in the secure Cashfree window using your preferred UPI app, debit card, or netbanking, then click Verify.',
      textConfirm: 'I Have Authorized',
      textCancel: 'Cancel',
      confirmTextColor: Get.theme.colorScheme.onPrimary,
      barrierDismissible: false,
      onWillPop: () async {
        _resolveActivePayment(
          CashfreePaymentResult(
            success: false,
            orderId: orderId,
            errorMessage: 'Auto Pay authorization was cancelled.',
          ),
        );
        return true;
      },
      onConfirm: () async {
        Get.back();
        AppSnackbar.info('Verifying Auto Pay mandate with gateway...');
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
      onCancel: () {
        _resolveActivePayment(
          CashfreePaymentResult(
            success: false,
            orderId: orderId,
            errorMessage: 'Auto Pay authorization was cancelled.',
          ),
        );
      },
    );
  }
}
