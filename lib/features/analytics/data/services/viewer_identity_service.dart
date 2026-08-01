import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/logger_service.dart';

/// Privacy-safe viewer identity for analytics dedup.
///
/// Identity resolution order:
///   1. Authenticated userId (strongest)
///   2. Persistent device hash from GetStorage (survives restarts)
///   3. Device fingerprint hash (survives storage clear, per-device unique)
///
/// All hashes are one-way SHA-256 — no PII is stored or transmitted.
/// Compliant with GDPR/DPDP: no raw device IDs leave the client.
class ViewerIdentityService extends GetxService {
  static const String _tag = 'ViewerIdentityService';
  static const String _storageKey = 'viewer_identity_hash';
  static const String _installIdKey = 'install_id';

  String? _cachedIdentity;
  String? _cachedDeviceFingerprint;

  /// Alias for [getViewerIdentity]
  Future<String> getViewerHash() => getViewerIdentity();

  /// Get the viewer identity for dedup purposes.
  /// Returns a privacy-safe hash, never raw PII.
  Future<String> getViewerIdentity() async {
    // 1. Authenticated user — strongest identity
    final uid = AuthService.to.uid;
    if (uid.isNotEmpty) return uid;

    // 2. Check cache
    if (_cachedIdentity != null) return _cachedIdentity!;

    // 3. Persistent install ID (survives app restarts, but not reinstalls)
    final storage = GetStorage();
    final storedHash = storage.read<String>(_storageKey);
    if (storedHash != null && storedHash.isNotEmpty) {
      _cachedIdentity = storedHash;
      return storedHash;
    }

    // 4. Generate new identity from device fingerprint
    final fingerprint = await _getDeviceFingerprint();
    final hash = _privacySafeHash(fingerprint);

    // Persist for future sessions
    try {
      await storage.write(_storageKey, hash);
    } catch (_) {}

    _cachedIdentity = hash;
    logger.info('Generated anonymous viewer identity', tag: _tag);
    return hash;
  }

  /// Get privacy-safe device fingerprint.
  /// Uses salted SHA-256 — raw device IDs never leave this function.
  Future<String> _getDeviceFingerprint() async {
    if (_cachedDeviceFingerprint != null) return _cachedDeviceFingerprint!;

    try {
      final deviceInfo = DeviceInfoPlugin();

      String rawFingerprint;

      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        rawFingerprint = [
          webInfo.browserName.name,
          webInfo.platform ?? '',
          webInfo.language ?? '',
          webInfo.hardwareConcurrency?.toString() ?? '',
          webInfo.userAgent ?? '',
        ].join('|');
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        rawFingerprint = [
          androidInfo.fingerprint,
          androidInfo.model,
          androidInfo.brand,
          androidInfo.hardware,
          androidInfo.display,
        ].join('|');
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        rawFingerprint = [
          iosInfo.identifierForVendor ?? '',
          iosInfo.model,
          iosInfo.systemVersion,
          iosInfo.name,
        ].join('|');
      } else {
        // Desktop / other
        rawFingerprint = 'desktop_${DateTime.now().microsecondsSinceEpoch}';
      }

      _cachedDeviceFingerprint = rawFingerprint;
      return rawFingerprint;
    } catch (e) {
      logger.warning(
        'Device fingerprint failed, using install ID: $e',
        tag: _tag,
      );
      return _getOrCreateInstallId();
    }
  }

  /// Fallback: persistent random install ID
  String _getOrCreateInstallId() {
    final storage = GetStorage();
    var installId = storage.read<String>(_installIdKey);
    if (installId == null || installId.isEmpty) {
      installId =
          'install_${DateTime.now().microsecondsSinceEpoch}_${identityHashCode(this)}';
      try {
        storage.write(_installIdKey, installId);
      } catch (_) {}
    }
    return installId;
  }

  /// One-way salted SHA-256 hash — GDPR/DPDP compliant.
  /// Raw PII never leaves this function.
  String _privacySafeHash(String input) {
    // Salt prevents rainbow table attacks if DB is compromised
    const salt = 'towerb_analytics_v2_2026';
    final bytes = utf8.encode('$salt:$input');
    final digest = sha256.convert(bytes);
    return 'anon_${digest.toString().substring(0, 24)}';
  }

  /// Generate a dedup key for server-side qualified view enforcement.
  /// Format: `{videoId}_{viewerHash}_{YYYYMMDD}`
  Future<String> generateDedupKey(String videoId) async {
    final identity = await getViewerIdentity();
    final today = DateTime.now();
    final dateKey =
        '${today.year}_${today.month.toString().padLeft(2, '0')}_${today.day.toString().padLeft(2, '0')}';
    return '${videoId}_${identity}_$dateKey';
  }

  /// Clear cached identity (for logout scenarios)
  void clearIdentity() {
    _cachedIdentity = null;
    _cachedDeviceFingerprint = null;
  }
}
