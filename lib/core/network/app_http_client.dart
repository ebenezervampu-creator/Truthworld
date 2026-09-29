import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 🌐 Persistent HTTP Client with Connection Pooling & Keep-Alive
///
/// Eliminates per-request TCP connection & TLS handshake latency overhead (100–300ms)
/// by maintaining an active connection pool for outgoing HTTP requests.
class AppHttpClient {
  AppHttpClient._();
  static final AppHttpClient instance = AppHttpClient._();

  static const Duration defaultTimeout = Duration(seconds: 15);

  http.Client? _customClient;

  /// Lazy initialized persistent client instance.
  http.Client get client => _customClient ??= http.Client();

  /// Visible for testing: inject a custom or mock HTTP client.
  @visibleForTesting
  set client(http.Client? custom) => _customClient = custom;

  /// Default headers to maintain persistent HTTP/1.1 or HTTP/2 keep-alive connections.
  static const Map<String, String> defaultKeepAliveHeaders = {
    'Connection': 'keep-alive',
    'Keep-Alive': 'timeout=30, max=100',
  };

  /// Performs a high-performance GET request reusing pooled sockets.
  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final mergedHeaders = <String, String>{
      if (!kIsWeb) ...defaultKeepAliveHeaders,
      ...?headers,
    };

    return instance.client
        .get(url, headers: mergedHeaders)
        .timeout(timeout ?? defaultTimeout);
  }

  /// Performs a high-performance POST request reusing pooled sockets.
  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final mergedHeaders = <String, String>{
      if (!kIsWeb) ...defaultKeepAliveHeaders,
      ...?headers,
    };

    return instance.client
        .post(url, headers: mergedHeaders, body: body)
        .timeout(timeout ?? defaultTimeout);
  }

  /// Performs a high-performance HEAD request reusing pooled sockets.
  static Future<http.Response> head(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final mergedHeaders = <String, String>{
      if (!kIsWeb) ...defaultKeepAliveHeaders,
      ...?headers,
    };

    return instance.client
        .head(url, headers: mergedHeaders)
        .timeout(timeout ?? defaultTimeout);
  }

  /// Closes the underlying client and all open connections.
  void close() {
    _customClient?.close();
    _customClient = null;
  }
}
