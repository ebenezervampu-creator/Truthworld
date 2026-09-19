import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_colors.dart';

enum DisputeConsensusStatus {
  pendingRatings,
  consensusAchieved,
  rejectedPolarized,
  brigadeFlagged,
}

/// Contributor rating on an active community dispute or note.
class ContributorDisputeRating {
  const ContributorDisputeRating({
    required this.ratingId,
    required this.contributorId,
    required this.isHelpful,
    required this.contributorPolarity,
    required this.contributorReputationTier,
    required this.timestamp,
    this.ratingReason,
  });

  factory ContributorDisputeRating.fromMap(Map<String, dynamic> map) {
    return ContributorDisputeRating(
      ratingId: (map['ratingId'] ?? '').toString(),
      contributorId: (map['contributorId'] ?? '').toString(),
      isHelpful: map['isHelpful'] == true,
      ratingReason: map['ratingReason']?.toString(),
      contributorPolarity: ((map['contributorPolarity'] ?? 0.0) as num).toDouble(),
      contributorReputationTier: (map['contributorReputationTier'] ?? 'Unverified').toString(),
      timestamp: (map['timestamp'] is num)
          ? (map['timestamp'] as num).toInt()
          : DateTime.now().millisecondsSinceEpoch,
    );
  }

  final String ratingId;
  final String contributorId;
  final bool isHelpful;
  final String? ratingReason;
  final double contributorPolarity; // -1.0 to 1.0
  final String contributorReputationTier;
  final int timestamp;

  Map<String, dynamic> toMap() {
    return {
      'ratingId': ratingId,
      'contributorId': contributorId,
      'isHelpful': isHelpful,
      if (ratingReason != null) 'ratingReason': ratingReason,
      'contributorPolarity': contributorPolarity,
      'contributorReputationTier': contributorReputationTier,
      'timestamp': timestamp,
    };
  }
}

/// Evaluation result of community dispute consensus using Birdwatch-style bridging.
class BridgingEvaluation {
  const BridgingEvaluation({
    required this.disputeId,
    required this.totalRatings,
    required this.status,
    required this.bridgingScore,
    required this.perspectiveDivergence,
    required this.leftHelpfulRate,
    required this.rightHelpfulRate,
    required this.centerHelpfulRate,
    required this.isBrigadeSuspected,
    required this.confidenceScore,
    this.brigadeReason,
  });

  final String disputeId;
  final int totalRatings;
  final DisputeConsensusStatus status;
  final double bridgingScore; // 0.0 to 1.0
  final double perspectiveDivergence; // 0.0 to 1.0
  final double leftHelpfulRate;
  final double rightHelpfulRate;
  final double centerHelpfulRate;
  final bool isBrigadeSuspected;
  final double confidenceScore;
  final String? brigadeReason;

  bool get isConsensusAchieved => status == DisputeConsensusStatus.consensusAchieved;
  bool get isPolarized => status == DisputeConsensusStatus.rejectedPolarized;

  String get statusLabel {
    switch (status) {
      case DisputeConsensusStatus.consensusAchieved:
        return 'Consensus Corroborated';
      case DisputeConsensusStatus.rejectedPolarized:
        return 'Split Without Consensus';
      case DisputeConsensusStatus.brigadeFlagged:
        return 'Coordinated Activity Detected';
      case DisputeConsensusStatus.pendingRatings:
        return 'Awaiting Cross-Perspective Review';
    }
  }

  Color get statusColor {
    switch (status) {
      case DisputeConsensusStatus.consensusAchieved:
        return AppColors.success;
      case DisputeConsensusStatus.rejectedPolarized:
        return AppColors.warning;
      case DisputeConsensusStatus.brigadeFlagged:
        return AppColors.error;
      case DisputeConsensusStatus.pendingRatings:
        return AppColors.textTertiary;
    }
  }

  String get plainExplanation {
    if (isBrigadeSuspected) {
      return 'Sudden burst of ratings detected from a single group. Ratings quarantined to prevent brigading.';
    }
    if (status == DisputeConsensusStatus.consensusAchieved) {
      return 'Corroborated across diverse contributor viewpoints with verified source documentation.';
    }
    if (status == DisputeConsensusStatus.rejectedPolarized) {
      return 'Dispute does not have cross-perspective support. Evaluated as polarized along factional lines.';
    }
    return 'Currently gathering reviews from contributors across different perspective clusters.';
  }
}

/// Client-side mathematical bridging engine for computing and simulating consensus.
class BridgingConsensusEngine {
  BridgingConsensusEngine._();

  static const int minRatings = 5;
  static const double bridgingThreshold = 0.60;
  static const double polarizedRejectThreshold = 0.35;
  static const int burstWindowMs = 60000;
  static const int burstMaxCount = 5;

  static BridgingEvaluation evaluate(
    String disputeId,
    List<ContributorDisputeRating> ratings,
  ) {
    if (ratings.isEmpty) {
      return BridgingEvaluation(
        disputeId: disputeId,
        totalRatings: 0,
        status: DisputeConsensusStatus.pendingRatings,
        bridgingScore: 0.0,
        perspectiveDivergence: 0.0,
        leftHelpfulRate: 0.0,
        rightHelpfulRate: 0.0,
        centerHelpfulRate: 0.0,
        isBrigadeSuspected: false,
        confidenceScore: 0.0,
      );
    }

    // 1. Detect velocity bursts (anti-brigading)
    final quarantined = <String>{};
    var isBrigaded = false;
    String? brigadeReason;

    if (ratings.length >= burstMaxCount) {
      final sorted = [...ratings]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      for (var i = 0; i <= sorted.length - burstMaxCount; i++) {
        final window = sorted.sublist(i, i + burstMaxCount);
        final start = window.first.timestamp;
        final end = window.last.timestamp;

        if (end - start <= burstWindowMs) {
          final polarities = window.map((r) => r.contributorPolarity).toList();
          final allPositive = polarities.every((p) => p > 0.1);
          final allNegative = polarities.every((p) => p < -0.1);

          if (allPositive || allNegative) {
            isBrigaded = true;
            brigadeReason = 'Coordinated voting velocity burst detected.';
            for (final r in window) {
              quarantined.add(r.ratingId);
            }
            break;
          }
        }
      }
    }

    final validRatings = isBrigaded
        ? ratings.where((r) => !quarantined.contains(r.ratingId)).toList()
        : ratings;

    // 2. Partition into clusters
    final left = <ContributorDisputeRating>[];
    final center = <ContributorDisputeRating>[];
    final right = <ContributorDisputeRating>[];

    for (final r in validRatings) {
      if (r.contributorPolarity <= -0.2) {
        left.add(r);
      } else if (r.contributorPolarity >= 0.2) {
        right.add(r);
      } else {
        center.add(r);
      }
    }

    // 3. Compute weighted rates
    final leftRate = _computeWeightedRate(left);
    final rightRate = _computeWeightedRate(right);
    final centerRate = _computeWeightedRate(center);

    // 4. Perspective Divergence (Normalized Entropy)
    final divergence = _computeDivergence(left.length, center.length, right.length, validRatings.length);

    // 5. Harmonic Bridging Score
    final bridgingScore = _computeHarmonicScore(leftRate, rightRate, centerRate, left.isNotEmpty, right.isNotEmpty);

    // 6. Status determination
    var status = DisputeConsensusStatus.pendingRatings;
    if (isBrigaded && validRatings.length < minRatings) {
      status = DisputeConsensusStatus.brigadeFlagged;
    } else if (validRatings.length >= minRatings) {
      final hasOpposing = left.isNotEmpty && right.isNotEmpty;
      if (hasOpposing && bridgingScore >= bridgingThreshold) {
        status = DisputeConsensusStatus.consensusAchieved;
      } else if (hasOpposing && bridgingScore < polarizedRejectThreshold) {
        status = DisputeConsensusStatus.rejectedPolarized;
      } else {
        status = DisputeConsensusStatus.pendingRatings;
      }
    }

    final confidence = math.min(1.0, validRatings.length / 10.0) * divergence;

    return BridgingEvaluation(
      disputeId: disputeId,
      totalRatings: validRatings.length,
      status: status,
      bridgingScore: (bridgingScore * 1000).round() / 1000,
      perspectiveDivergence: (divergence * 1000).round() / 1000,
      leftHelpfulRate: (leftRate * 1000).round() / 1000,
      rightHelpfulRate: (rightRate * 1000).round() / 1000,
      centerHelpfulRate: (centerRate * 1000).round() / 1000,
      isBrigadeSuspected: isBrigaded,
      brigadeReason: brigadeReason,
      confidenceScore: (confidence * 1000).round() / 1000,
    );
  }

  static double _computeWeightedRate(List<ContributorDisputeRating> list) {
    if (list.isEmpty) return 0.5;

    var weightedHelpful = 0.0;
    var totalWeight = 0.0;

    for (final r in list) {
      var weight = 1.0;
      if (r.contributorReputationTier == 'Trusted') {
        weight = 1.8;
      } else if (r.contributorReputationTier == 'Active') {
        weight = 1.2;
      } else if (r.contributorReputationTier == 'Unverified') {
        weight = 0.6;
      }

      if (r.isHelpful) {
        weightedHelpful += weight;
      }
      totalWeight += weight;
    }

    return totalWeight > 0 ? (weightedHelpful / totalWeight) : 0.5;
  }

  static double _computeHarmonicScore(
    double left,
    double right,
    double center,
    bool hasLeft,
    bool hasRight,
  ) {
    if (!hasLeft || !hasRight) {
      return (left + right + center) / 3 * 0.4;
    }
    const eps = 0.001;
    final harmonicOpposing = (2 * left * right) / (left + right + eps);
    return 0.8 * harmonicOpposing + 0.2 * center;
  }

  static double _computeDivergence(int left, int center, int right, int total) {
    if (total == 0) return 0.0;
    final pL = left / total;
    final pC = center / total;
    final pR = right / total;

    var entropy = 0.0;
    if (pL > 0) entropy -= pL * (math.log(pL) / math.ln2);
    if (pC > 0) entropy -= pC * (math.log(pC) / math.ln2);
    if (pR > 0) entropy -= pR * (math.log(pR) / math.ln2);

    final maxEntropy = math.log(3) / math.ln2;
    return (entropy / maxEntropy).clamp(0.0, 1.0);
  }
}
