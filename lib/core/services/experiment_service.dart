import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';

class ExperimentAssignment {
  final String experimentId;
  final String variantId;
  final int? bucketNumber;
  final dynamic weights;

  ExperimentAssignment({
    required this.experimentId,
    required this.variantId,
    this.bucketNumber,
    this.weights,
  });

  factory ExperimentAssignment.fromJson(Map<String, dynamic> json) {
    return ExperimentAssignment(
      experimentId: json['experimentId'] as String,
      variantId: json['variantId'] as String,
      bucketNumber: json['bucketNumber'] as int?,
      weights: json['weights'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'experimentId': experimentId,
      'variantId': variantId,
      'bucketNumber': bucketNumber,
      'weights': weights,
    };
  }
}

class MetricEvent {
  final String experimentId;
  final String variantId;
  final String metricType;
  final double value;
  final String? videoId;

  MetricEvent({
    required this.experimentId,
    required this.variantId,
    required this.metricType,
    required this.value,
    this.videoId,
  });

  Map<String, dynamic> toJson() {
    return {
      'experimentId': experimentId,
      'variantId': variantId,
      'metricType': metricType,
      'value': value,
      if (videoId != null) 'videoId': videoId,
    };
  }
}

class ExperimentService extends GetxService {
  static const String _baseUrl = 'https://asia-south1-truthworld-app.cloudfunctions.net';
  static const String _cacheKey = 'experiment_assignments_cache';
  
  late GetStorage _storage;
  final Map<String, ExperimentAssignment> _assignments = {};
  Timer? _refreshTimer;
  Timer? _batchTimer;
  
  final List<MetricEvent> _metricQueue = [];
  bool _isFlushing = false;

  /// Initialize on app start - fetch and cache experiment assignments
  Future<ExperimentService> init() async {
    try {
      _storage = GetStorage();
      _loadFromCache();
      await _fetchActiveExperiments();
      
      // Refresh experiments every 30 minutes while app is active
      _refreshTimer = Timer.periodic(const Duration(minutes: 30), (_) {
        _fetchActiveExperiments();
      });

      // Batch flush every 10 seconds
      _batchTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _flushMetrics();
      });
      
    } catch (e, s) {
      // Fail-open: handle errors gracefully and never expose to users
      ErrorHandler.log(e, stackTrace: s, tag: 'ExperimentService');
    }
    return this;
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    _batchTimer?.cancel();
    _flushMetrics();
    super.onClose();
  }

  void _loadFromCache() {
    try {
      final cacheString = _storage.read<String>(_cacheKey);
      if (cacheString != null) {
        final List<dynamic> jsonList = jsonDecode(cacheString);
        for (final item in jsonList) {
          final assignment = ExperimentAssignment.fromJson(item as Map<String, dynamic>);
          _assignments[assignment.experimentId] = assignment;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'ExperimentService');
    }
  }

  Future<void> _fetchActiveExperiments() async {
    try {
      String? userId;
      if (Get.isRegistered<AuthService>()) {
        final auth = Get.find<AuthService>();
        userId = auth.user?.uid;
      }
      
      if (userId == null) return;

      final response = await http
          .get(Uri.parse('$_baseUrl/getActiveExperiments?userId=$userId'))
          .timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final experimentsData = data['experiments'] as List<dynamic>?;
        
        if (experimentsData != null) {
          _assignments.clear();
          final cacheList = <Map<String, dynamic>>[];
          
          for (final item in experimentsData) {
            final map = item as Map<String, dynamic>;
            final assignment = ExperimentAssignment.fromJson(map);
            // using experimentId as the surface
            _assignments[assignment.experimentId] = assignment;
            cacheList.add(assignment.toJson());
          }
          
          await _storage.write(_cacheKey, jsonEncode(cacheList));
        }
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'ExperimentService');
    }
  }

  /// Get variant ID for a surface (returns null if no active experiment)
  String? getVariant(String surface) {
    return _assignments[surface]?.variantId;
  }

  /// Get experiment ID for a surface
  String? getExperimentId(String surface) {
    return _assignments[surface]?.experimentId;
  }

  /// Get full assignment for a surface
  ExperimentAssignment? getAssignment(String surface) {
    return _assignments[surface];
  }

  /// Record a metric event
  Future<void> recordMetric({
    required String metricType,
    required double value,
    String? videoId,
  }) async {
    try {
      // Record metric for all active experiments
      for (final assignment in _assignments.values) {
        _metricQueue.add(MetricEvent(
          experimentId: assignment.experimentId,
          variantId: assignment.variantId,
          metricType: metricType,
          value: value,
          videoId: videoId,
        ));
      }

      // Flush immediately if queue reaches 10 events
      if (_metricQueue.length >= 10) {
        await _flushMetrics();
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'ExperimentService');
    }
  }

  /// Record impression (convenience)
  Future<void> recordImpression({String? videoId}) async {
    await recordMetric(metricType: 'impression', value: 1.0, videoId: videoId);
  }

  /// Record click (convenience)
  Future<void> recordClick({String? videoId}) async {
    await recordMetric(metricType: 'click', value: 1.0, videoId: videoId);
  }

  /// Record watch time (convenience)
  Future<void> recordWatchTime(double seconds, {String? videoId}) async {
    await recordMetric(metricType: 'watch_time', value: seconds, videoId: videoId);
  }

  Future<void> _flushMetrics() async {
    if (_metricQueue.isEmpty || _isFlushing) return;
    
    _isFlushing = true;
    final batch = List<MetricEvent>.from(_metricQueue);
    _metricQueue.clear();

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      
      for (final event in batch) {
        await functions.httpsCallable('recordExperimentMetric').call(event.toJson());
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'ExperimentService');
      // On failure, re-add to queue if not too large to avoid memory leaks
      if (_metricQueue.length < 100) {
        _metricQueue.insertAll(0, batch);
      }
    } finally {
      _isFlushing = false;
    }
  }
}
