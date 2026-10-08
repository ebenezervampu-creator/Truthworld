import 'package:http/http.dart' as http;
import 'package:truthworld/core/network/ssl_pinning/ssl_pinning_adapter_stub.dart'
    if (dart.library.io) 'package:truthworld/core/network/ssl_pinning/ssl_pinning_adapter_io.dart';

/// Platform-agnostic adapter for SSL / TLS Certificate Pinning.
abstract class SslPinningAdapter {
  factory SslPinningAdapter() => getSslPinningAdapter();

  /// Creates a persistent HTTP client with strict SSL certificate pinning.
  http.Client createPinnedClient();

  /// Performs an active TLS handshake to verify that the remote certificate matches pinned pins.
  Future<bool> validateHostHandshake(String host, {int port = 443});
}
