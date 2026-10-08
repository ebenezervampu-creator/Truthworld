import 'package:truthworld/core/services/cashfree/cashfree_adapter_stub.dart'
    if (dart.library.io) 'package:truthworld/core/services/cashfree/cashfree_adapter_mobile.dart';

/// Platform-agnostic adapter for Cashfree Payment Gateway SDK.
///
/// On mobile (Android & iOS), delegates to native `flutter_cashfree_pg_sdk`.
/// On Web and desktop platforms where native SDK is unavailable, stubs out
/// the native interface so WebAssembly (`dart2wasm`) and Web builds compile cleanly.
abstract class CashfreeGatewayAdapter {
  factory CashfreeGatewayAdapter() => getCashfreeGatewayAdapter();

  void initCallbacks({
    required void Function(String orderId) onVerify,
    required void Function(String rawMessage, String orderId) onError,
  });

  void doPayment({
    required String orderId,
    required String paymentSessionId,
    required bool isProduction,
  });
}
