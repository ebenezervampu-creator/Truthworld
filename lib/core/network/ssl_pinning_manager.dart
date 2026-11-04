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

  SslPinningAdapter _adapter = SslPinningAdapter();
  bool _isCustomAdapterForTesting = false;

  DateTime? _lastValidatedPaymentTime;
  bool? _lastPaymentValidationResult;
  bool _lastIsSandbox = false;
  static const Duration _validationTtl = Duration(minutes: 30);

  @visibleForTesting
  void setAdapterForTesting(SslPinningAdapter adapter) {
    _adapter = adapter;
    _isCustomAdapterForTesting = true;
    clearCache();
  }

  @visibleForTesting
  void resetAdapter() {
    _adapter = SslPinningAdapter();
    _isCustomAdapterForTesting = false;
    clearCache();
  }

  @visibleForTesting
  void clearCache() {
    _lastValidatedPaymentTime = null;
    _lastPaymentValidationResult = null;
  }

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
  ///
  /// In production (`isSandbox = false`), strictly requires BOTH [api.cashfree.com]
  /// and [payments.cashfree.com] to validate successfully (`&&`).
  /// In sandbox mode (`isSandbox = true`), validates [sandbox.cashfree.com].
  Future<bool> validatePaymentEndpoints({
    bool isSandbox = false,
    bool force = false,
  }) async {
    if (kIsWeb) return true; // Web browsers enforce browser TLS sandbox

    final now = DateTime.now();
    if (!force &&
        !_isCustomAdapterForTesting &&
        _lastValidatedPaymentTime != null &&
        _lastPaymentValidationResult == true &&
        _lastIsSandbox == isSandbox &&
        now.difference(_lastValidatedPaymentTime!) < _validationTtl) {
      return true;
    }

    if (isSandbox) {
      final valid = await validateHostHandshake('sandbox.cashfree.com');
      if (valid && !_isCustomAdapterForTesting) {
        _lastValidatedPaymentTime = DateTime.now();
        _lastPaymentValidationResult = true;
        _lastIsSandbox = true;
      }
      return valid;
    }

    // Strictly validate both production Cashfree endpoints using conjunction (&&).
    // An attacker cannot bypass verification if one endpoint fails or is tampered with.
    // Concurrently handshake both hosts via Future.wait to prevent 3-4s serial stalls.
    final results = await Future.wait([
      validateHostHandshake('api.cashfree.com'),
      validateHostHandshake('payments.cashfree.com'),
    ]);

    final isValid = results[0] && results[1];
    if (isValid && !_isCustomAdapterForTesting) {
      _lastValidatedPaymentTime = DateTime.now();
      _lastPaymentValidationResult = true;
      _lastIsSandbox = false;
    }
    return isValid;
  }

  /// Pre-validates authentication and cloud function endpoints.
  Future<bool> validateAuthEndpoints() async {
    if (kIsWeb) return true;

    final isAuthValid =
        await validateHostHandshake('identitytoolkit.googleapis.com');
    return isAuthValid;
  }
}
