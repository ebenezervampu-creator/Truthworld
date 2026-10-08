import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Web implementation stub of FlutterCashfreePgSdk plugin.
///
/// Direct web checkout in TruthWorld uses the hosted payment gateway URL,
/// preventing the need for legacy browser DOM manipulation in WebAssembly.
class FlutterCashfreePgSdkWeb {
  /// Constructs a FlutterCashfreePgSdkWeb
  FlutterCashfreePgSdkWeb();

  /// Registers the plugin with the Flutter Web plugin registrar.
  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'flutter_cashfree_pg_sdk',
      const StandardMethodCodec(),
      registrar,
    );

    final pluginInstance = FlutterCashfreePgSdkWeb();
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);
  }

  /// Handles method calls over the MethodChannel of this plugin.
  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'doPayment':
      case 'doWebPayment':
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Direct SDK payment on Web is replaced with secure hosted checkout in TruthWorld.',
        );
      default:
        return null;
    }
  }
}
