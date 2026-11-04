import { createHash } from 'crypto';

interface ExperimentVariant {
  variantId: string;
  name: string;
  trafficPercent: number; // 0-100
  isControl: boolean;
  weights: Record<string, number>;
}

interface VariantMetrics {
  variantId: string;
  sampleSize: number;
  impressions: number;
  clicks: number;
  ctr: number;
  totalWatchTimeSeconds: number;
  avgWatchTimeSeconds: number;
  completions: number;
  completionRate: number;
  likes: number;
  likeRate: number;
}

const Z_95 = 1.96; // 95% confidence standard score
const SIGNIFICANCE_THRESHOLD = 0.05; // p < 0.05

function computeBucket(userId: string, experimentId: string): number {
  const hash = createHash('sha256')
    .update(`${userId}:${experimentId}:truthworld`)
    .digest('hex');
  const num = parseInt(hash.substring(0, 8), 16);
  return num % 100;
}

function resolveVariant(bucket: number, variants: ExperimentVariant[]): ExperimentVariant | null {
  let cumulativePercent = 0;
  for (const variant of variants) {
    cumulativePercent += variant.trafficPercent;
    if (bucket < cumulativePercent) {
      return variant;
    }
  }
  return variants[variants.length - 1] || null;
}

function computeTwoProportionZTest(
  successA: number,
  totalA: number,
  successB: number,
  totalB: number
) {
  if (totalA === 0 || totalB === 0) {
    return { zScore: 0, pValue: 1.0, isSignificant: false };
  }
  const pA = successA / totalA;
  const pB = successB / totalB;
  const pooledP = (successA + successB) / (totalA + totalB);
  const se = Math.sqrt(pooledP * (1 - pooledP) * (1 / totalA + 1 / totalB));

  if (se === 0) {
    return { zScore: 0, pValue: 1.0, isSignificant: false };
  }

  const zScore = (pB - pA) / se;
  // Approximate two-tailed p-value using standard normal approximation
  const pValue = 2 * (1 - normalCdf(Math.abs(zScore)));
  const isSignificant = pValue < SIGNIFICANCE_THRESHOLD && Math.abs(zScore) >= Z_95;

  return { zScore, pValue, isSignificant, relativeImprovement: pA > 0 ? (pB - pA) / pA : 0 };
}

function normalCdf(x: number): number {
  const t = 1 / (1 + 0.2316419 * Math.abs(x));
  const d = 0.3989423 * Math.exp((-x * x) / 2);
  const prob = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.821256 + t * 1.330274))));
  return x > 0 ? 1 - prob : prob;
}

describe('A/B Testing Experiment Engine — Production Verification', () => {
  const experimentId = 'exp_two_tower_2026';

  const variants: ExperimentVariant[] = [
    {
      variantId: 'control',
      name: 'Control (Base Weights)',
      trafficPercent: 50,
      isControl: true,
      weights: { topicAffinity: 0.18, twoTowerAffinity: 0.12 },
    },
    {
      variantId: 'treatment_deep_vector',
      name: 'Treatment (Neural Heavy)',
      trafficPercent: 50,
      isControl: false,
      weights: { topicAffinity: 0.10, twoTowerAffinity: 0.25 },
    },
  ];

  describe('Deterministic User Bucketing', () => {
    it('always assigns the same bucket to a user across multiple sessions', () => {
      const userA = 'user_abc_123';
      const bucket1 = computeBucket(userA, experimentId);
      const bucket2 = computeBucket(userA, experimentId);
      const bucket3 = computeBucket(userA, experimentId);

      expect(bucket1).toBeGreaterThanOrEqual(0);
      expect(bucket1).toBeLessThan(100);
      expect(bucket1).toBe(bucket2);
      expect(bucket2).toBe(bucket3);
    });

    it('distributes buckets uniformly across 0-99 for 1,000 distinct users', () => {
      const bucketCounts = new Array(100).fill(0);
      const sampleSize = 1000;

      for (let i = 0; i < sampleSize; i++) {
        const uid = `user_${i}_benchmark_hash`;
        const bucket = computeBucket(uid, experimentId);
        bucketCounts[bucket]++;
      }

      // Check all 100 buckets get hit
      const populatedBuckets = bucketCounts.filter((c) => c > 0).length;
      expect(populatedBuckets).toBeGreaterThanOrEqual(95);

      // Expected ~10 per bucket; test that no bucket has extreme anomaly (>40)
      for (const count of bucketCounts) {
        expect(count).toBeLessThan(40);
      }
    });

    it('correctly maps 50/50 traffic splits to control vs treatment', () => {
      let controlCount = 0;
      let treatmentCount = 0;
      const totalUsers = 1000;

      for (let i = 0; i < totalUsers; i++) {
        const bucket = computeBucket(`viewer_${i}`, experimentId);
        const assigned = resolveVariant(bucket, variants);
        if (assigned?.variantId === 'control') {
          controlCount++;
        } else if (assigned?.variantId === 'treatment_deep_vector') {
          treatmentCount++;
        }
      }

      expect(controlCount + treatmentCount).toBe(totalUsers);
      // Roughly 50/50 split with +/- 7% variance
      expect(controlCount).toBeGreaterThanOrEqual(430);
      expect(controlCount).toBeLessThanOrEqual(570);
      expect(treatmentCount).toBeGreaterThanOrEqual(430);
      expect(treatmentCount).toBeLessThanOrEqual(570);
    });

    it('handles 3-way asymmetric traffic allocations (70/20/10)', () => {
      const threeWayVariants: ExperimentVariant[] = [
        { variantId: 'A', name: '70% Main', trafficPercent: 70, isControl: true, weights: {} },
        { variantId: 'B', name: '20% Secondary', trafficPercent: 20, isControl: false, weights: {} },
        { variantId: 'C', name: '10% Canary', trafficPercent: 10, isControl: false, weights: {} },
      ];

      expect(resolveVariant(0, threeWayVariants)?.variantId).toBe('A');
      expect(resolveVariant(69, threeWayVariants)?.variantId).toBe('A');
      expect(resolveVariant(70, threeWayVariants)?.variantId).toBe('B');
      expect(resolveVariant(89, threeWayVariants)?.variantId).toBe('B');
      expect(resolveVariant(90, threeWayVariants)?.variantId).toBe('C');
      expect(resolveVariant(99, threeWayVariants)?.variantId).toBe('C');
    });
  });

  describe('Statistical Significance & Conversion Hypothesis Testing', () => {
    it('detects a statistically significant CTR lift (Treatment > Control, p < 0.05)', () => {
      // Control: 500 clicks out of 10,000 impressions (CTR = 5.0%)
      // Treatment: 620 clicks out of 10,000 impressions (CTR = 6.2%, +24% lift)
      const result = computeTwoProportionZTest(500, 10000, 620, 10000);

      expect(result.isSignificant).toBe(true);
      expect(result.zScore).toBeGreaterThanOrEqual(1.96);
      expect(result.pValue).toBeLessThan(0.001);
      expect(result.relativeImprovement).toBeCloseTo(0.24, 2);
    });

    it('rejects insignificant noise (p >= 0.05, fails confidence threshold)', () => {
      // Control: 500 clicks out of 10,000 impressions (5.0%)
      // Treatment: 512 clicks out of 10,000 impressions (5.12%, +2.4% noise)
      const result = computeTwoProportionZTest(500, 10000, 512, 10000);

      expect(result.isSignificant).toBe(false);
      expect(result.zScore).toBeLessThan(1.96);
      expect(result.pValue).toBeGreaterThan(0.05);
    });

    it('detects significantly negative treatments to trigger automated kill-switch', () => {
      // Control: 500 clicks out of 10,000 impressions (5.0%)
      // Treatment: 380 clicks out of 10,000 impressions (3.8%, -24% drop)
      const result = computeTwoProportionZTest(500, 10000, 380, 10000);

      expect(result.isSignificant).toBe(true);
      expect(result.zScore).toBeLessThanOrEqual(-1.96);
      expect(result.relativeImprovement).toBeCloseTo(-0.24, 2);
    });

    it('fails closed gracefully with zero impressions or empty samples', () => {
      const result = computeTwoProportionZTest(0, 0, 0, 0);
      expect(result.isSignificant).toBe(false);
      expect(result.zScore).toBe(0);
      expect(result.pValue).toBe(1.0);
    });
  });
});
