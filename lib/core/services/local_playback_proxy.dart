import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:truthworld/core/services/media_crypto_service.dart';

/// 🌐 LOCAL PLAYBACK PROXY SERVER
///
/// An embedded localhost HTTP server bound only to `127.0.0.1` (loopback) on a
/// dynamic ephemeral port with token authentication.
///
/// Serves on-the-fly decrypted slices of `.twenc` files to `VideoPlayerController`
/// (ExoPlayer on Android, AVPlayer on iOS) using standard HTTP 206 Partial Content
/// / Range requests.
///
/// This eliminates the need to decrypt entire video files onto disk before playback,
/// guaranteeing zero unencrypted media files reside in physical flash storage.
class LocalPlaybackProxyServer {
  LocalPlaybackProxyServer._();
  static final LocalPlaybackProxyServer instance = LocalPlaybackProxyServer._();

  HttpServer? _server;
  String? _sessionToken;
  final Map<String, File> _registeredFiles = {};
  Completer<void>? _startCompleter;

  bool get isRunning => _server != null;
  int? get port => _server?.port;
  String? get sessionToken => _sessionToken;

  /// Starts the localhost proxy server if not already running.
  Future<void> start() async {
    if (kIsWeb) return; // Web uses in-memory Blob URLs instead of loopback HTTP
    if (_server != null) return;
    if (_startCompleter != null) return _startCompleter!.future;

    _startCompleter = Completer<void>();

    try {
      // Generate a secure session token
      final random = Random.secure();
      final tokenBytes = Uint8List(16);
      for (var i = 0; i < 16; i++) {
        tokenBytes[i] = random.nextInt(256);
      }
      _sessionToken = tokenBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      // Bind to 127.0.0.1 on port 0 (OS picks an open port)
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server!.listen(
        _handleRequest,
        onError: (error) {
          debugPrint('[LocalPlaybackProxy] Server error: $error');
        },
      );

      debugPrint(
        '[LocalPlaybackProxy] 🚀 Server running at http://127.0.0.1:${_server!.port}',
      );
      _startCompleter!.complete();
    } catch (e) {
      debugPrint('[LocalPlaybackProxy] ❌ Failed to start server: $e');
      _startCompleter!.completeError(e);
      _startCompleter = null;
      rethrow;
    }
  }

  /// Registers an encrypted file and returns its streamable loopback URL.
  Future<String> serveVideo(String videoId, File encryptedFile) async {
    if (kIsWeb) {
      throw UnsupportedError('LocalPlaybackProxyServer is not used on Web. Use Blob URLs.');
    }

    await start();
    _registeredFiles[videoId] = encryptedFile;
    return 'http://127.0.0.1:${_server!.port}/stream/$videoId?token=$_sessionToken';
  }

  /// Unregisters a video file when playback is dismissed.
  void unregisterVideo(String videoId) {
    _registeredFiles.remove(videoId);
  }

  /// Handles incoming HTTP requests from the media player engine.
  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final uri = request.uri;
      final pathSegments = uri.pathSegments;

      // Validate route: /stream/:videoId
      if (pathSegments.length != 2 || pathSegments[0] != 'stream') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final videoId = pathSegments[1];
      final token = uri.queryParameters['token'];

      // Authenticate session token
      if (token == null || token != _sessionToken) {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.write('Access denied: invalid playback token');
        await request.response.close();
        return;
      }

      final file = _registeredFiles[videoId];
      if (file == null || !await file.exists()) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Media not found for video $videoId');
        await request.response.close();
        return;
      }

      // Read encrypted header to determine MIME type and length
      final headerBytes = await file.openRead(0, MediaCryptoService.headerSize).first;
      if (!MediaCryptoService.instance.isEncryptedMedia(headerBytes)) {
        // Fallback: If not encrypted, stream as raw file
        await _streamRawFile(request, file);
        return;
      }

      final header = MediaCryptoService.instance.parseHeader(headerBytes);
      final mimeType = header.isAudio ? 'audio/mpeg' : 'video/mp4';
      final totalLength = header.originalLength;

      // Common streaming response headers
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      request.response.headers.set(HttpHeaders.contentTypeHeader, mimeType);
      request.response.headers.set(
        HttpHeaders.cacheControlHeader,
        'no-cache, no-store, must-revalidate',
      );
      request.response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');

      // HEAD request support
      if (request.method == 'HEAD') {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.set(HttpHeaders.contentLengthHeader, totalLength.toString());
        await request.response.close();
        return;
      }

      // GET request with Range Header
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final rangeSpec = rangeHeader.substring(6).trim();
        final parts = rangeSpec.split('-');

        final parsedStart = int.tryParse(parts[0]) ?? 0;
        final rawEnd = (parts.length > 1 && parts[1].isNotEmpty)
            ? int.tryParse(parts[1]) ?? (totalLength - 1)
            : (totalLength - 1);

        if (parsedStart >= totalLength) {
          request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$totalLength');
          await request.response.close();
          return;
        }

        final start = parsedStart;
        final end = (rawEnd >= totalLength ? totalLength - 1 : rawEnd).clamp(start, totalLength - 1);
        final chunkSize = (end - start) + 1;

        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$totalLength',
        );
        request.response.headers.set(
          HttpHeaders.contentLengthHeader,
          chunkSize.toString(),
        );

        // Decrypt only the requested byte window on-the-fly
        final decryptedChunk = await MediaCryptoService.instance.readDecryptedRange(
          file,
          start,
          end,
        );

        request.response.add(decryptedChunk);
        await request.response.close();
      } else {
        // Full file stream without Range header
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.set(HttpHeaders.contentLengthHeader, totalLength.toString());

        var offset = 0;
        const bufferSize = 128 * 1024; // 128 KB chunks
        while (offset < totalLength) {
          final end = min(offset + bufferSize - 1, totalLength - 1);
          final chunk = await MediaCryptoService.instance.readDecryptedRange(file, offset, end);
          request.response.add(chunk);
          offset = end + 1;
        }

        await request.response.close();
      }
    } catch (e) {
      debugPrint('[LocalPlaybackProxy] Error handling request: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Fallback streamer for unencrypted legacy downloads.
  Future<void> _streamRawFile(HttpRequest request, File file) async {
    final length = await file.length();
    final isAudio = file.path.endsWith('.mp3');
    final mimeType = isAudio ? 'audio/mpeg' : 'video/mp4';

    request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    request.response.headers.set(HttpHeaders.contentTypeHeader, mimeType);

    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final rangeSpec = rangeHeader.substring(6).trim();
      final parts = rangeSpec.split('-');
      final parsedStart = int.tryParse(parts[0]) ?? 0;
      final rawEnd = (parts.length > 1 && parts[1].isNotEmpty)
          ? int.tryParse(parts[1]) ?? (length - 1)
          : (length - 1);
      final start = parsedStart;
      final end = (rawEnd >= length ? length - 1 : rawEnd).clamp(start, length - 1);
      final chunkSize = (end - start) + 1;

      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$length');
      request.response.headers.set(HttpHeaders.contentLengthHeader, chunkSize.toString());

      await request.response.addStream(file.openRead(start, end + 1));
      await request.response.close();
    } else {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.set(HttpHeaders.contentLengthHeader, length.toString());
      await request.response.addStream(file.openRead());
      await request.response.close();
    }
  }

  /// Stops the proxy server.
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _sessionToken = null;
      _registeredFiles.clear();
      _startCompleter = null;
      debugPrint('[LocalPlaybackProxy] Stopped proxy server');
    }
  }
}
