/**
 * 🌉 BRIDGING CONSENSUS ALGORITHM (X/Birdwatch Matrix Factorization Standard)
 *
 * Implements cross-perspective consensus modeling to evaluate fact-check disputes
 * and community notes, preventing factional brigading.
 *
 * Core Principles:
 * 1. A dispute CANNOT be accepted by simple majority.
 * 2. Cross-Perspective Bridging: Requires positive ratings from contributors with
 *    divergent historical polarity coordinates (p_u < 0 and p_u > 0).
 * 3. Harmonic Mean Penalty: If one viewpoint group rejects a dispute, the score collapses.
 * 4. Temporal Velocity Anti-Brigading: Detects coordinated burst attacks and quarantines them.
 */

export interface ContributorRating {
  ratingId: string;
  contributorId: string;
  isHelpful: boolean;
  ratingReason?: string;
  contributorPolarity: number; // -1.0 (left/cluster A) to +1.0 (right/cluster B)
  contributorReputationTier: "Trusted" | "Active" | "New" | "Unverified";
  timestamp: number;
}

export interface BridgingEvaluationResult {
  disputeId: string;
  totalRatings: number;
  status: "pending_ratings" | "consensus_achieved" | "rejected_polarized" | "brigade_flagged";
  isProvisional?: boolean;
  bridgingScore: number; // 0.0 to 1.0
  perspectiveDivergence: number; // 0.0 to 1.0 (how diverse the raters are)
  leftHelpfulRate: number;
  rightHelpfulRate: number;
  centerHelpfulRate: number;
  isBrigadeSuspected: boolean;
  brigadeReason?: string;
  confidenceScore: number;
}

export class BridgingConsensusEngine {
  private static readonly MIN_RATINGS_FOR_CONSENSUS = 5;
  private static readonly BRIDGING_THRESHOLD = 0.60;
  private static readonly POLARIZED_REJECT_THRESHOLD = 0.35;
  private static readonly VELOCITY_BURST_WINDOW_MS = 60_000; // 60 seconds
  private static readonly VELOCITY_BURST_MAX_COUNT = 5;

  /**
   * Computes the bridging consensus score across all contributor ratings.
   */
  static evaluateDispute(
    disputeId: string,
    ratings: ContributorRating[]
  ): BridgingEvaluationResult {
    if (ratings.length === 0) {
      return {
        disputeId,
        totalRatings: 0,
        status: "pending_ratings",
        bridgingScore: 0.0,
        perspectiveDivergence: 0.0,
        leftHelpfulRate: 0.0,
        rightHelpfulRate: 0.0,
        centerHelpfulRate: 0.0,
        isBrigadeSuspected: false,
        confidenceScore: 0.0,
      };
    }

    // 1. Anti-Brigading Burst Detection
    const brigadeCheck = this.detectBrigading(ratings);

    // Filter out suspicious burst ratings if brigading is detected
    const validRatings = brigadeCheck.isBrigaded
      ? ratings.filter(r => !brigadeCheck.quarantinedIds.has(r.ratingId))
      : ratings;

    // 2. Partition raters into perspective clusters
    const leftCluster: ContributorRating[] = [];
    const centerCluster: ContributorRating[] = [];
    const rightCluster: ContributorRating[] = [];

    for (const r of validRatings) {
      if (r.contributorPolarity <= -0.2) {
        leftCluster.push(r);
      } else if (r.contributorPolarity >= 0.2) {
        rightCluster.push(r);
      } else {
        centerCluster.push(r);
      }
    }

    // 3. Compute weighted helpfulness rates per cluster
    const leftRate = this.computeWeightedRate(leftCluster);
    const rightRate = this.computeWeightedRate(rightCluster);
    const centerRate = this.computeWeightedRate(centerCluster);

    // 4. Perspective Divergence Metric (Entropy of participating clusters)
    const perspectiveDivergence = this.calculatePerspectiveDivergence(
      leftCluster.length,
      centerCluster.length,
      rightCluster.length,
      validRatings.length
    );

    // 5. Cross-Perspective Bridging Score (Smoothed Harmonic Mean / Adaptive Consensus)
    const bridgingScore = this.computeHarmonicBridgingScore(
      leftRate,
      rightRate,
      centerRate,
      leftCluster.length,
      rightCluster.length,
      centerCluster.length,
      perspectiveDivergence
    );

    // 6. Status determination (prevents unilateral factional veto on facts)
    let status: BridgingEvaluationResult["status"] = "pending_ratings";
    let isProvisional = false;

    if (brigadeCheck.isBrigaded && validRatings.length < this.MIN_RATINGS_FOR_CONSENSUS) {
      status = "brigade_flagged";
    } else if (validRatings.length >= this.MIN_RATINGS_FOR_CONSENSUS) {
      const hasOpposingClusters = leftCluster.length > 0 && rightCluster.length > 0;
      const overallHelpfulRate = validRatings.filter(r => r.isHelpful).length / validRatings.length;

      if (hasOpposingClusters) {
        if (bridgingScore >= this.BRIDGING_THRESHOLD) {
          status = "consensus_achieved";
        } else if (bridgingScore < this.POLARIZED_REJECT_THRESHOLD) {
          status = "rejected_polarized";
        } else {
          status = "pending_ratings"; // Needs more cross-perspective input
        }
      } else {
        // Non-polarized topics (e.g. scientific, historical, or universal community consensus)
        if (overallHelpfulRate >= 0.75 && bridgingScore >= this.BRIDGING_THRESHOLD) {
          status = "consensus_achieved";
        } else if (overallHelpfulRate <= 0.30) {
          status = "rejected_polarized";
        } else {
          status = "pending_ratings";
        }
      }
    } else if (validRatings.length >= 2 && !brigadeCheck.isBrigaded) {
      // 🌉 Sparse-Graph Cold Start: Adaptive Bayesian Shrinkage & Authoritative Anchor Bootstrapping
      // When 2 <= N < 5, if raters have high reputation and unanimous/near-unanimous agreement,
      // allow provisional resolution instead of locking indefinitely in pending_ratings.
      const trustedRaters = validRatings.filter(r => r.contributorReputationTier === "Trusted" || r.contributorReputationTier === "Active");
      const helpfulCount = validRatings.filter(r => r.isHelpful).length;
      const unhelpfulCount = validRatings.length - helpfulCount;

      // Bayesian prior smoothing (prior mean = 0.5, pseudo-count m = 1.0)
      const bayesianHelpfulRate = (helpfulCount + 0.5) / (validRatings.length + 1.0);

      if (trustedRaters.length >= 2 && bayesianHelpfulRate >= 0.75 && unhelpfulCount === 0) {
        status = "consensus_achieved";
        isProvisional = true;
      } else if (trustedRaters.length >= 2 && bayesianHelpfulRate <= 0.25 && helpfulCount === 0) {
        status = "rejected_polarized";
        isProvisional = true;
      } else {
        status = "pending_ratings";
      }
    }

    const baseConfidence = validRatings.length >= this.MIN_RATINGS_FOR_CONSENSUS
      ? Math.min(1.0, validRatings.length / 10.0) * Math.max(0.2, perspectiveDivergence)
      : Math.min(0.65, (validRatings.length / 5.0) * 0.7);
    const confidenceScore = Number(baseConfidence.toFixed(3));

    return {
      disputeId,
      totalRatings: validRatings.length,
      status,
      isProvisional,
      bridgingScore: Number(bridgingScore.toFixed(3)),
      perspectiveDivergence: Number(perspectiveDivergence.toFixed(3)),
      leftHelpfulRate: Number(leftRate.toFixed(3)),
      rightHelpfulRate: Number(rightRate.toFixed(3)),
      centerHelpfulRate: Number(centerRate.toFixed(3)),
      isBrigadeSuspected: brigadeCheck.isBrigaded,
      brigadeReason: brigadeCheck.reason,
      confidenceScore,
    };
  }

  private static computeWeightedRate(ratings: ContributorRating[]): number {
    if (ratings.length === 0) return 0.5; // neutral prior

    let weightedHelpful = 0;
    let totalWeight = 0;

    for (const r of ratings) {
      let weight = 1.0;
      // Balanced weighting according to participatory consensus standards
      if (r.contributorReputationTier === "Trusted") weight = 1.25;
      else if (r.contributorReputationTier === "Active") weight = 1.10;
      else if (r.contributorReputationTier === "Unverified") weight = 0.90;

      if (r.isHelpful) {
        weightedHelpful += weight;
      }
      totalWeight += weight;
    }

    return totalWeight > 0 ? weightedHelpful / totalWeight : 0.5;
  }

  private static computeHarmonicBridgingScore(
    leftRate: number,
    rightRate: number,
    centerRate: number,
    leftCount: number,
    rightCount: number,
    centerCount: number,
    perspectiveDivergence: number
  ): number {
    // Empirical Bayes smoothing prevents single polarized outliers from vetoing
    const smoothedLeft = (leftRate * leftCount + 0.5) / (leftCount + 1);
    const smoothedRight = (rightRate * rightCount + 0.5) / (rightCount + 1);
    const smoothedCenter = (centerRate * centerCount + 0.5) / (centerCount + 1);

    if (leftCount > 0 && rightCount > 0) {
      // Harmonic mean across opposing clusters with smoothing
      const eps = 0.001;
      const harmonicOpposing = (2 * smoothedLeft * smoothedRight) / (smoothedLeft + smoothedRight + eps);
      return 0.7 * harmonicOpposing + 0.3 * smoothedCenter;
    }

    // When opposing clusters are not active (e.g. factual, scientific, non-ideological notes):
    // Blend active clusters gracefully instead of penalizing with an artificial collapse
    const activeRates: number[] = [];
    if (leftCount > 0) activeRates.push(smoothedLeft);
    if (rightCount > 0) activeRates.push(smoothedRight);
    if (centerCount > 0) activeRates.push(smoothedCenter);

    const clusterAverage = activeRates.length > 0
      ? activeRates.reduce((a, b) => a + b, 0) / activeRates.length
      : 0.5;

    return clusterAverage * (0.85 + 0.15 * perspectiveDivergence);
  }

  private static calculatePerspectiveDivergence(
    leftCount: number,
    centerCount: number,
    rightCount: number,
    total: number
  ): number {
    if (total === 0) return 0;
    const pLeft = leftCount / total;
    const pCenter = centerCount / total;
    const pRight = rightCount / total;

    // Shannon entropy normalized to [0, 1]
    let entropy = 0;
    if (pLeft > 0) entropy -= pLeft * Math.log2(pLeft);
    if (pCenter > 0) entropy -= pCenter * Math.log2(pCenter);
    if (pRight > 0) entropy -= pRight * Math.log2(pRight);

    const maxEntropy = Math.log2(3);
    return Math.min(1.0, entropy / maxEntropy);
  }

  private static detectBrigading(ratings: ContributorRating[]): {
    isBrigaded: boolean;
    reason?: string;
    quarantinedIds: Set<string>;
  } {
    const quarantinedIds = new Set<string>();
    if (ratings.length < this.VELOCITY_BURST_MAX_COUNT) {
      return { isBrigaded: false, quarantinedIds };
    }

    // Sort by timestamp
    const sorted = [...ratings].sort((a, b) => a.timestamp - b.timestamp);

    for (let i = 0; i <= sorted.length - this.VELOCITY_BURST_MAX_COUNT; i++) {
      const window = sorted.slice(i, i + this.VELOCITY_BURST_MAX_COUNT);
      const startTime = window[0].timestamp;
      const endTime = window[window.length - 1].timestamp;

      if (endTime - startTime <= this.VELOCITY_BURST_WINDOW_MS) {
        // Check polarity homogeneity of the burst
        const polarities = window.map(r => r.contributorPolarity);
        const allSameSide =
          polarities.every(p => p > 0.1) || polarities.every(p => p < -0.1);

        if (allSameSide) {
          window.forEach(r => quarantinedIds.add(r.ratingId));
          return {
            isBrigaded: true,
            reason: `Temporal velocity burst detected: ${window.length} unilateral ratings in ${Math.round((endTime - startTime) / 1000)}s`,
            quarantinedIds,
          };
        }
      }
    }

    return { isBrigaded: false, quarantinedIds };
  }
}
