import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:truthworld/core/services/cashfree/cashfree_adapter.dart';

/// Factory constructor implementation for mobile platforms (Android/iOS).
CashfreeGatewayAdapter getCashfreeGatewayAdapter() => CashfreeAdapterMobile();

/// Mobile implementation utilizing native flutter_cashfree_pg_sdk.
class CashfreeAdapterMobile implements CashfreeGatewayAdapter {
  final CFPaymentGatewayService _cfGateway = CFPaymentGatewayService();

  @override
  void initCallbacks({
    required void Function(String orderId) onVerify,
    required void Function(String rawMessage, String orderId) onError,
  }) {
    _cfGateway.setCallback(
      onVerify,
      (errorResponse, orderId) {
        final rawMsg = errorResponse.getMessage() ??
            errorResponse.getCode() ??
            errorResponse.getStatus() ??
            '';
        onError(rawMsg, orderId);
      },
    );
  }

  @override
  void doPayment({
    required String orderId,
    required String paymentSessionId,
    required bool isProduction,
  }) {
    final cfEnv = isProduction
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
  }
}
