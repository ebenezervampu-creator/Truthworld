import 'package:truthworld/core/services/cashfree/cashfree_adapter.dart';

/// Factory constructor implementation for Web and non-mobile platforms.
CashfreeGatewayAdapter getCashfreeGatewayAdapter() => CashfreeAdapterStub();

/// Web / Desktop stub implementation that safely prevents loading native SDK libraries.
class CashfreeAdapterStub implements CashfreeGatewayAdapter {
  @override
  void initCallbacks({
    required void Function(String orderId) onVerify,
    required void Function(String rawMessage, String orderId) onError,
  }) {
    // No-op on Web / unsupported platforms.
  }

  @override
  void doPayment({
    required String orderId,
    required String paymentSessionId,
    required bool isProduction,
  }) {
    throw UnsupportedError(
      'Native Cashfree SDK is only supported on mobile (Android/iOS). Use hosted web checkout instead.',
    );
  }
}
