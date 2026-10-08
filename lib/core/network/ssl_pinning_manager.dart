import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/network/ssl_pinning/ssl_pinning_adapter.dart';

/// 🔒 Central SSL / Certificate Pinning Manager
///
/// Guards TruthWorld's payment, authentication, and cloud endpoints against
/// Man-in-the-Middle (MitM) attacks, proxy interception (Burp Suite, Charles Proxy, mitmproxy),
/// and rogue certificate authorities.
class SslPinningManager {
  SslPinningManager._();
  static final SslPinningManager instance = SslPinningManager._();

  final SslPinningAdapter _adapter = SslPinningAdapter();

  /// Creates an HTTP client configured with strict SSL certificate validation.
  http.Client createPinnedHttpClient() {
    return _adapter.createPinnedClient();
  }

  /// Verifies an active TLS handshake against pinned endpoints.
  Future<bool> validateHostHandshake(String host, {int port = 443}) {
    return _adapter.validateHostHandshake(host, port: port);
  }

  /// Pre-validates payment gateway endpoints before executing financial transactions.
  ///
  /// Returns `true` if payment endpoints pass SSL integrity verification.
  Future<bool> validatePaymentEndpoints() async {
    if (kIsWeb) return true; // Web browsers enforce browser TLS sandbox

    // Verify Cashfree production/sandbox endpoint TLS integrity
    final isCashfreeValid = await validateHostHandshake('api.cashfree.com') ||
        await validateHostHandshake('payments.cashfree.com') ||
        await validateHostHandshake('sandbox.cashfree.com');

    return isCashfreeValid;
  }

  /// Pre-validates authentication and cloud function endpoints.
  Future<bool> validateAuthEndpoints() async {
    if (kIsWeb) return true;

    final isAuthValid =
        await validateHostHandshake('identitytoolkit.googleapis.com');
    return isAuthValid;
  }
}
