import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';

/// ⚡ PHASE 2: REACTIVE CLAIM STREAM CONTROLLER (TRUTHWORLD)
///
/// Subscribes to the real-time Firestore claims subcollection (`videos/{videoId}/claims`)
/// and streams individual claim verdicts directly to the UI as they resolve,
/// eliminating the wait for full report synthesis.
///
/// Epistemic & Engineering Guarantees:
/// 1. Single Source of Truth: Ingests documents verified by the backend Fused Grounding Engine.
/// 2. Deterministic Chronological Ordering: Claims are sorted by `start` timestamp ascending.
/// 3. Zero `setState`: 100% reactive GetX (`RxList<ClaimResult>`).
/// 4. Memory Safety: All stream subscriptions are auto-disposed via `trackSubscription`.
/// 5. Zero Raw Developer Errors: Translates connection hiccups into clean, friendly feedback.
class ClaimStreamController extends BaseController {
  ClaimStreamController({required this.videoId});

  final String videoId;

  /// Reactive list of claims streaming progressively from Firestore.
  final RxList<ClaimResult> claims = <ClaimResult>[].obs;

  /// True while initial snapshot connection is establishing.
  final RxBool isConnecting = true.obs;

  /// True if stream is live and receiving real-time claim updates.
  final RxBool isStreamingActive = false.obs;

  /// True if a connection or permission failure occurred.
  final RxBool hasStreamError = false.obs;

  /// Clean user-facing status indicator.
  final RxString statusMessage = 'Connecting to real-time verification...'.obs;

  /// Real-time ledger summary counts.
  final RxInt confirmedCount = 0.obs;
  final RxInt falseCount = 0.obs;
  final RxInt disputedCount = 0.obs;
  final RxInt unprovenCount = 0.obs;

  /// In-memory cache keyed by stable claim ID or occurrence hash to enforce monotonic progression.
  /// Prevents out-of-order network packets from regressing a FINALIZED verdict back to a loading state.
  final Map<String, ClaimResult> _claimsById = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  static ClaimStreamController getOrCreate(String videoId) {
    final tag = 'claim_stream_$videoId';
    if (Get.isRegistered<ClaimStreamController>(tag: tag)) {
      return Get.find<ClaimStreamController>(tag: tag);
    }
    return Get.put(ClaimStreamController(videoId: videoId), tag: tag);
  }

  @override
  void onInit() {
    super.onInit();
    _startClaimStream();
  }

  void _startClaimStream() {
    if (videoId.isEmpty) {
      isConnecting.value = false;
      statusMessage.value = 'No video reference provided.';
      return;
    }

    isConnecting.value = true;
    hasStreamError.value = false;

    try {
      final stream = FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .collection('claims')
          .snapshots();

      _subscription = trackSubscription(
        stream.listen(
          (snapshot) {
            isConnecting.value = false;
            isStreamingActive.value = true;
            hasStreamError.value = false;

            if (snapshot.docs.isEmpty) {
              _claimsById.clear();
              claims.clear();
              confirmedCount.value = 0;
              falseCount.value = 0;
              disputedCount.value = 0;
              unprovenCount.value = 0;
              statusMessage.value = 'Analyzing content for verifiable facts...';
              return;
            }

            final parsedClaims = <ClaimResult>[];
            final currentDocKeys = <String>{};
            var cCount = 0;
            var fCount = 0;
            var dCount = 0;
            var uCount = 0;

            for (final doc in snapshot.docs) {
              final data = doc.data();
              if (!data.containsKey('claimId') && doc.id.isNotEmpty) {
                data['claimId'] = doc.id;
              }
              final incoming = ClaimResult.fromMap(data);
              final claimKey = (incoming.claimId != null &&
                      incoming.claimId!.isNotEmpty)
                  ? incoming.claimId!
                  : '${incoming.text}_${(incoming.start ?? 0.0).toStringAsFixed(1)}';

              currentDocKeys.add(claimKey);

              final existing = _claimsById[claimKey];
              ClaimResult effectiveClaim = incoming;

              // Monotonic Guard: Prevent out-of-order packets from regressing
              // a higher state level back to an earlier one
              // (e.g. FINALIZED [3] -> DEEP_VERIFYING [2] / PROVISIONAL [1] / EXTRACTED [0]).
              if (existing != null && existing.stateLevel > incoming.stateLevel) {
                effectiveClaim = existing;
              } else {
                _claimsById[claimKey] = incoming;
              }

              parsedClaims.add(effectiveClaim);

              final vLower = effectiveClaim.verdict.toLowerCase();
              if (vLower == 'verified_true' ||
                  vLower == 'mostly_true' ||
                  vLower == 'true') {
                cCount++;
              } else if (vLower == 'false_claim' ||
                  vLower == 'false' ||
                  vLower == 'misleading') {
                fCount++;
              } else if (vLower == 'disputed' || vLower == 'inconclusive') {
                dCount++;
              } else if (vLower == 'unproven' || vLower == 'unverified') {
                uCount++;
              }
            }

            // Purge deleted/pruned claims from tracking map
            _claimsById.removeWhere((key, _) => !currentDocKeys.contains(key));

            // Deterministic timeline ordering: sort by start offset ascending
            parsedClaims.sort(
              (a, b) => (a.start ?? 0.0).compareTo(b.start ?? 0.0),
            );

            claims.assignAll(parsedClaims);
            confirmedCount.value = cCount;
            falseCount.value = fCount;
            disputedCount.value = dCount;
            unprovenCount.value = uCount;

            final total = parsedClaims.length;
            final inProgressCount =
                parsedClaims.where((c) => !c.isFinalized).length;

            if (inProgressCount > 0) {
              statusMessage.value = inProgressCount == 1
                  ? 'Verifying 1 claim in real time...'
                  : 'Verifying $inProgressCount claims in real time...';
            } else {
              statusMessage.value = total == 1
                  ? '1 claim monitored'
                  : '$total claims monitored';
            }
          },
          onError: (dynamic error, StackTrace stack) {
            isConnecting.value = false;
            isStreamingActive.value = false;
            hasStreamError.value = true;
            statusMessage.value = 'Live updates temporarily unavailable.';
            ErrorHandler.log(
              error,
              stackTrace: stack,
              tag: 'ClaimStreamController.stream',
            );
          },
        ),
      );
    } catch (e, stack) {
      isConnecting.value = false;
      isStreamingActive.value = false;
      hasStreamError.value = true;
      statusMessage.value = 'Unable to connect to live claim stream.';
      ErrorHandler.log(e, stackTrace: stack, tag: 'ClaimStreamController.init');
    }
  }

  /// Manually retry stream connection if dropped.
  void retryConnection() {
    _subscription?.cancel();
    _startClaimStream();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _claimsById.clear();
    super.onClose();
  }
}
