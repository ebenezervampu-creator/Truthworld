import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/logger_service.dart';

/// Versioned algorithm weight configuration.
/// Supports dynamic Remote Config sync via Firestore and local 12-hour GetStorage caching.
/// Falls back seamlessly to compile-time v1 defaults when offline.
class AlgorithmRemoteConfig extends GetxService {
  static const String _currentVersion = 'v1';
  static const String _cacheKeyWeights = 'algorithm_remote_config_weights';
  static const String _cacheKeyVersion = 'algorithm_remote_config_version';
  static const String _cacheKeyTimestamp = 'algorithm_remote_config_timestamp';
  static const int _cacheTtlMs = 12 * 60 * 60 * 1000; // 12 hours

  static bool get _defaultEnableStorage {
    if (kIsWeb) return true;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return false;
      }
    } catch (_) {
      // Platform.environment might throw on unsupported platforms
    }
    return true;
  }

  final bool _enableStorage;
  GetStorage? _storageInstance;

  AlgorithmRemoteConfig({GetStorage? storage, bool? enableStorage})
      : _storageInstance = storage,
        _enableStorage = enableStorage ?? _defaultEnableStorage;

  GetStorage? get _storage {
    if (!_enableStorage) return null;
    try {
      return _storageInstance ??= GetStorage();
    } catch (_) {
      return null;
    }
  }

  /// Default weight profiles (compile-time fallback, enhanced with Two-Tower neural affinity)
  static const Map<String, Map<String, Map<String, double>>> _versionedWeights =
      {
        'v1': {
          'homeFeedAll': {
            'topicAffinity': 0.18,
            'channelAffinity': 0.10,
            'engagement': 0.05,
            'freshness': 0.12,
            'trending': 0.08,
            'watchCompletion': 0.05,
            'sessionBoost': 0.13,
            'penalty': 0.07,
            'knowledgeQuality': 0.10,
            'twoTowerAffinity': 0.12,
            'languageAffinity': 0.15,
          },
          'homeFeedCategory': {
            'topicAffinity': 0.08,
            'channelAffinity': 0.08,
            'engagement': 0.20,
            'freshness': 0.16,
            'trending': 0.12,
            'watchCompletion': 0.05,
            'sessionBoost': 0.09,
            'penalty': 0.08,
            'knowledgeQuality': 0.00,
            'twoTowerAffinity': 0.14,
            'languageAffinity': 0.15,
          },
          'videoRelated': {
            'topicAffinity': 0.22,
            'channelAffinity': 0.16,
            'engagement': 0.05,
            'freshness': 0.07,
            'trending': 0.04,
            'watchCompletion': 0.05,
            'sessionBoost': 0.14,
            'penalty': 0.07,
            'knowledgeQuality': 0.08,
            'twoTowerAffinity': 0.12,
            'languageAffinity': 0.15,
          },
          'autoplayNext': {
            'topicAffinity': 0.18,
            'channelAffinity': 0.20,
            'engagement': 0.10,
            'freshness': 0.07,
            'trending': 0.04,
            'watchCompletion': 0.05,
            'sessionBoost': 0.15,
            'penalty': 0.07,
            'knowledgeQuality': 0.00,
            'twoTowerAffinity': 0.14,
            'languageAffinity': 0.16,
          },
          'searchResults': {
            'topicAffinity': 0.07,
            'channelAffinity': 0.03,
            'engagement': 0.02,
            'freshness': 0.10,
            'trending': 0.07,
            'watchCompletion': 0.07,
            'sessionBoost': 0.05,
            'penalty': 0.04,
            'knowledgeQuality': 0.12,
            'twoTowerAffinity': 0.15,
            'languageAffinity': 0.15,
          },
          'subscriptionFeed': {
            'topicAffinity': 0.08,
            'channelAffinity': 0.22,
            'engagement': 0.12,
            'freshness': 0.16,
            'trending': 0.08,
            'watchCompletion': 0.05,
            'sessionBoost': 0.09,
            'penalty': 0.05,
            'knowledgeQuality': 0.00,
            'twoTowerAffinity': 0.10,
            'languageAffinity': 0.10,
          },
          'trending': {
            'topicAffinity': 0.04,
            'channelAffinity': 0.04,
            'engagement': 0.18,
            'freshness': 0.13,
            'trending': 0.28,
            'watchCompletion': 0.05,
            'sessionBoost': 0.08,
            'penalty': 0.08,
            'knowledgeQuality': 0.00,
            'twoTowerAffinity': 0.06,
            'languageAffinity': 0.08,
          },
          'discoverChannels': {
            'topicAffinity': 0.25,
            'channelAffinity': 0.00,
            'engagement': 0.12,
            'freshness': 0.08,
            'trending': 0.12,
            'watchCompletion': 0.07,
            'sessionBoost': 0.10,
            'penalty': 0.10,
            'knowledgeQuality': 0.00,
            'twoTowerAffinity': 0.16,
            'languageAffinity': 0.12,
          },
          'exploreTopics': {
            'topicAffinity': 0.28,
            'channelAffinity': 0.04,
            'engagement': 0.12,
            'freshness': 0.08,
            'trending': 0.12,
            'watchCompletion': 0.04,
            'sessionBoost': 0.10,
            'penalty': 0.08,
            'knowledgeQuality': 0.00,
            'twoTowerAffinity': 0.14,
            'languageAffinity': 0.10,
          },
          'shortsFeed': {
            'topicAffinity': 0.16,
            'channelAffinity': 0.11,
            'engagement': 0.17,
            'freshness': 0.12,
            'trending': 0.12,
            'watchCompletion': 0.00,
            'sessionBoost': 0.11,
            'penalty': 0.07,
            'knowledgeQuality': 0.00,
            'twoTowerAffinity': 0.10,
            'languageAffinity': 0.16,
          },
          'endScreen': {
            'topicAffinity': 0.18,
            'channelAffinity': 0.15,
            'engagement': 0.12,
            'freshness': 0.08,
            'trending': 0.04,
            'watchCompletion': 0.04,
            'sessionBoost': 0.11,
            'penalty': 0.14,
            'knowledgeQuality': 0.00,
            'twoTowerAffinity': 0.14,
            'languageAffinity': 0.14,
          },
          'unexplored': {
            'topicAffinity': 0.11,
            'channelAffinity': 0.05,
            'engagement': 0.13,
            'freshness': 0.13,
            'trending': 0.08,
            'watchCompletion': 0.07,
            'sessionBoost': 0.09,
            'penalty': 0.05,
            'knowledgeQuality': 0.14,
            'twoTowerAffinity': 0.15,
            'languageAffinity': 0.15,
          },
        },
      };

  /// Dynamic in-memory weights loaded from GetStorage or Firestore
  final Map<String, Map<String, Map<String, double>>> _dynamicWeights = {};

  String _activeVersion = _currentVersion;

  String get activeVersion => _activeVersion;

  @override
  void onInit() {
    super.onInit();
    if (_enableStorage) {
      _loadFromLocalStorage();
      unawaited(fetchAndActivate());
    }
  }

  /// Get weight profile for a surface, prioritizing dynamically synced weights
  Map<String, double> getWeightProfile(RecommendationSurface surface) {
    // 1. Check dynamic remote weights
    if (_dynamicWeights.containsKey(_activeVersion)) {
      final surfaceWeights = _dynamicWeights[_activeVersion]?[surface.name];
      if (surfaceWeights != null && surfaceWeights.isNotEmpty) {
        return surfaceWeights;
      }
    }

    // 2. Check compiled versioned weights
    final versionWeights =
        _versionedWeights[_activeVersion] ??
        _versionedWeights[_currentVersion]!;
    return versionWeights[surface.name] ?? versionWeights['homeFeedAll']!;
  }

  /// Load cached weights from GetStorage for instant zero-latency startup
  void _loadFromLocalStorage() {
    try {
      final storage = _storage;
      if (storage == null) return;

      final cachedVersion = storage.read<String>(_cacheKeyVersion);
      final rawWeights = storage.read<Map>(_cacheKeyWeights);

      if (cachedVersion != null && rawWeights != null) {
        final parsed = _parseWeightsMap(rawWeights);
        if (parsed.isNotEmpty) {
          _dynamicWeights[cachedVersion] = parsed;
          _activeVersion = cachedVersion;
          debugPrint(
            '[AlgorithmRemoteConfig] Loaded cached algorithm weights: v$cachedVersion',
          );
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AlgorithmRemoteConfig._loadFromLocalStorage',
      );
    }
  }

  /// Asynchronously fetch latest weights from Firestore remote_config document.
  /// If fresh (< 12 hours) and not forced, skips network query.
  Future<bool> fetchAndActivate({bool forceRefresh = false}) async {
    final storage = _storage;
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastFetched = storage?.read<int>(_cacheKeyTimestamp) ?? 0;

    if (!forceRefresh && (now - lastFetched) < _cacheTtlMs && _dynamicWeights.isNotEmpty) {
      return true;
    }

    try {
      // Guard against uninitialized Firebase (e.g., test environments and early lifecycle)
      if (Firebase.apps.isEmpty) {
        return false;
      }

      final docSnap = await FirebaseFirestore.instance
          .collection('remote_config')
          .doc('algorithm_weights')
          .get()
          .timeout(const Duration(seconds: 8));

      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null) {
          final version = (data['version'] as String?) ?? 'v1';
          final rawWeights = data['weights'] as Map?;

          if (rawWeights != null) {
            final parsed = _parseWeightsMap(rawWeights);
            if (parsed.isNotEmpty) {
              _dynamicWeights[version] = parsed;
              _activeVersion = version;

              // Persist in local storage
              if (storage != null) {
                await storage.write(_cacheKeyVersion, version);
                await storage.write(_cacheKeyWeights, rawWeights);
                await storage.write(_cacheKeyTimestamp, now);
              }

              debugPrint(
                '[AlgorithmRemoteConfig] Activated remote algorithm weights: v$version',
              );
              return true;
            }
          }
        }
      }
    } catch (e, stackTrace) {
      if (e is TimeoutException) {
        debugPrint(
          '[AlgorithmRemoteConfig.fetchAndActivate] Cold-start remote fetch timed out; falling back to cached/default weights',
        );
      } else if (e is FirebaseException) {
        logger.warning(
          '[AlgorithmRemoteConfig] Remote algorithm config unavailable (${e.code}); using built-in v1 weights fallback.',
          tag: 'AlgorithmRemoteConfig',
        );
      } else {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'AlgorithmRemoteConfig.fetchAndActivate',
        );
      }
    }
    return false;
  }

  /// Parse a generic Map from JSON/Firestore into typed surface weights
  Map<String, Map<String, double>> _parseWeightsMap(Map raw) {
    final result = <String, Map<String, double>>{};
    raw.forEach((surfaceKey, surfaceData) {
      if (surfaceData is Map) {
        final innerMap = <String, double>{};
        surfaceData.forEach((sigKey, weightVal) {
          if (weightVal is num) {
            innerMap[sigKey.toString()] = weightVal.toDouble();
          }
        });
        if (innerMap.isNotEmpty) {
          result[surfaceKey.toString()] = innerMap;
        }
      }
    });
    return result;
  }

  /// Set active version explicitly (e.g. for testing or experimental cohort assignment)
  void setVersion(String version) {
    if (_dynamicWeights.containsKey(version) || _versionedWeights.containsKey(version)) {
      _activeVersion = version;
      debugPrint(
        '[AlgorithmRemoteConfig] Switched to algorithm version: $version',
      );
    }
  }

  static const bool _isStaging =
      String.fromEnvironment('FIREBASE_ENV') == 'staging';
  static const String _stagingProjectId = String.fromEnvironment(
    'STAGING_PROJECT_ID',
    defaultValue: 'truthworld-staging',
  );

  String _homeFeedEndpoint = const String.fromEnvironment(
    'TRUTHWORLD_HOME_FEED_ENDPOINT',
    defaultValue: _isStaging
        ? 'https://asia-south1-$_stagingProjectId.cloudfunctions.net/getHomeFeed'
        : 'https://asia-south1-truthworld-1.cloudfunctions.net/getHomeFeed',
  );
  String get homeFeedEndpoint => _homeFeedEndpoint;

  /// Update home feed server endpoint dynamically
  void setHomeFeedEndpoint(String endpoint) {
    _homeFeedEndpoint = endpoint.trim();
  }
}
