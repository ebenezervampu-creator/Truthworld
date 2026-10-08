import 'package:http/http.dart' as http;
import 'package:truthworld/core/network/ssl_pinning/ssl_pinning_adapter.dart';

/// Web and non-IO platform implementation of [SslPinningAdapter].
///
/// On Web platforms, browsers enforce TLS and certificate validation at the
/// browser sandbox level, rendering raw socket manipulation unavailable.
class SslPinningAdapterStub implements SslPinningAdapter {
  @override
  http.Client createPinnedClient() {
    return http.Client();
  }

  @override
  Future<bool> validateHostHandshake(String host, {int port = 443}) async {
    // Browsers natively enforce browser trust stores and HSTS
    return true;
  }
}

SslPinningAdapter getSslPinningAdapter() => SslPinningAdapterStub();
