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
    debugPrint(
      '[CashfreePaymentService] Payment error: ${errorResponse.getMessage()} for order: $orderId',
    );
    _resolveActivePayment(
      CashfreePaymentResult(
        success: false,
        orderId: orderId,
        errorMessage: errorResponse.getMessage() ?? 'Payment could not be completed.',
      ),
    );
  }

  void _resolveActivePayment(CashfreePaymentResult result) {
    isProcessing.value = false;
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
      final envString = (data['environment'] as String? ?? 'SANDBOX').toUpperCase();

      activeOrderId.value = orderId;
      _activeCompleter = Completer<CashfreePaymentResult>();

      final isMobile = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);

      if (isMobile && paymentSessionId != null && paymentSessionId.isNotEmpty) {
        // Native Mobile Flow via Cashfree PG SDK
        final cfEnv = envString == 'PRODUCTION'
            ? CFEnvironment.PRODUCTION
            : CFEnvironment.SANDBOX;

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
      } else if (paymentLink != null && paymentLink.isNotEmpty) {
        // Web / Desktop flow: launch hosted checkout URL
        final uri = Uri.parse(paymentLink);
        try {
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) {
            _showDesktopVerificationPrompt(orderId);
          } else {
            _resolveActivePayment(
              CashfreePaymentResult(
                success: false,
                orderId: orderId,
                errorMessage: 'Unable to open checkout window. Please check your browser popup settings.',
              ),
            );
          }
        } catch (launchErr, s) {
          ErrorHandler.log(launchErr, stackTrace: s, tag: 'CashfreePaymentService.launchUrl');
          _resolveActivePayment(
            CashfreePaymentResult(
              success: false,
              orderId: orderId,
              errorMessage: 'Unable to open checkout page. Please try again.',
            ),
          );
        }
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

  /// For Desktop/Web link fallback: prompts user to confirm once done
  void _showDesktopVerificationPrompt(String orderId) {
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
}
