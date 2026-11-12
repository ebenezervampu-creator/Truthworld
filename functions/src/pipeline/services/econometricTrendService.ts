import { EconometricTrendAssessment, StructuralBreakEvent } from '../types';

/**
 * 📈 Advanced Econometric Trend & Statistical Volatility Service
 * 
 * Replaces naive flat-percentage heuristics with rigorous econometrics:
 * - Sample mean ($\mu$) and sample standard deviation ($s$) with sample-size corrections
 * - Formal 95% Confidence Interval for the mean: $CI_{95\%}(\mu) = [\mu \pm t_{\alpha/2, n-1} \cdot SE]$
 * - Formal 95% Prediction Interval for a single observation: $PI_{95\%}(X_{new}) = [\mu \pm t_{\alpha/2, n-1} \cdot s \cdot \sqrt{1 + 1/n}]$
 * - First-order serial autocorrelation coefficient ($r_1$) for time-series persistence
 * - Structural Break Registry (exogenous shocks, partition, regime shifts)
 * - Objective, non-judgmental anomaly classification: distinguishes documented structural
 *   breaks from secular baseline shifts without presuming deceptive intent.
 */
export class EconometricTrendService {
  /**
   * Authoritative Historical Structural Break Registry.
   * Documents known exogenous shocks, wars, famines, and regime shifts in South Asia & globally.
   */
  private static readonly STRUCTURAL_BREAK_REGISTRY: Record<string, Record<number, StructuralBreakEvent>> = {
    India: {
      1947: {
        year: 1947,
        event: 'Partition of British India & Independence',
        impactType: 'exogenous_shock',
        historicalMagnitude: -4.5,
        description: 'Mass displacement of 14 million people and severed agricultural-industrial supply chains.',
      },
      1965: {
        year: 1965,
        event: 'Bilateral War & Historic Consecutive Monsoon Drought',
        impactType: 'exogenous_shock',
        historicalMagnitude: -16.2,
        description: 'Severe agricultural contraction caused by the worst consecutive drought of the 20th century.',
      },
      1991: {
        year: 1991,
        event: 'Balance of Payments Crisis & Industrial Liberalization',
        impactType: 'policy_regime_shift',
        historicalMagnitude: 3.8,
        description: 'Dismantling of the License Raj and shift from import substitution to export-led market integration.',
      },
      2020: {
        year: 2020,
        event: 'COVID-19 Global Pandemic Lockdown',
        impactType: 'exogenous_shock',
        historicalMagnitude: -6.6,
        description: 'Nationwide economic lockdown precipitating quarterly contractions across manufacturing and services.',
      },
    },
    Pakistan: {
      1958: {
        year: 1958,
        event: 'Ayub Khan Martial Law & Favorable Monsoon Anomaly',
        impactType: 'exogenous_shock',
        historicalMagnitude: 7.4,
        description: 'Single-year agricultural rebound bumper crop following military takeover, diverging from the 3.1% decade trend.',
      },
      1971: {
        year: 1971,
        event: 'Liberation of Bangladesh & Partition of Pakistan',
        impactType: 'exogenous_shock',
        historicalMagnitude: -8.0,
        description: 'Secession of East Pakistan and loss of major export revenue base.',
      },
    },
  };

  /**
   * Student's t critical values for 95% two-tailed confidence ($\alpha = 0.05$)
   * by degrees of freedom ($df = n - 1$).
   */
  private static getStudentTCritical95(df: number): number {
    const tTable: Record<number, number> = {
      1: 12.706,
      2: 4.303,
      3: 3.182,
      4: 2.776,
      5: 2.571,
      6: 2.447,
      7: 2.365,
      8: 2.306,
      9: 2.262,
      10: 2.228,
      11: 2.201,
      12: 2.179,
      13: 2.160,
      14: 2.145,
      15: 2.131,
      16: 2.120,
      17: 2.110,
      18: 2.101,
      19: 2.093,
      20: 2.086,
      22: 2.074,
      24: 2.064,
      26: 2.056,
      28: 2.048,
      30: 2.042,
      40: 2.021,
      60: 2.000,
      120: 1.980,
    };

    if (df <= 0) return 1.96;
    if (tTable[df]) return tTable[df];
    if (df > 120) return 1.96;

    const keys = Object.keys(tTable).map(Number).sort((a, b) => a - b);
    for (let i = 0; i < keys.length - 1; i++) {
      if (df > keys[i] && df < keys[i + 1]) {
        return tTable[keys[i]];
      }
    }
    return 1.96;
  }

  /**
   * Evaluate whether a claimed statistic represents a structural shock, an outlier
   * requiring context, or a normal observation within historical volatility bounds.
   */
  public static evaluateEconometricTrend(
    entity: string,
    metric: string,
    targetYear: number,
    targetValue: number,
    historicalSeries: { year: number; value: number }[]
  ): EconometricTrendAssessment {
    // Sort chronologically for time-series analysis
    const sortedSeries = [...historicalSeries].sort((a, b) => a.year - b.year);
    const values = sortedSeries.map(s => s.value);
    const n = values.length;

    if (n < 3) {
      // Insufficient sample size for formal statistical modeling
      return {
        entity,
        metric,
        targetYear,
        targetValue,
        sampleMean: targetValue,
        sampleStandardDeviation: 0,
        standardErrorOfMean: 0,
        zScore: 0,
        degreesOfFreedom: Math.max(0, n - 1),
        meanConfidenceInterval95: [targetValue, targetValue],
        observationPredictionInterval95: [targetValue, targetValue],
        confidenceInterval95: [targetValue, targetValue],
        autocorrelationCoefficient: 0,
        isStatisticallyAnomalous: false,
        anomalyClassification: 'expected_historical_volatility',
        isCherryPickedAnomaly: false,
        rationale: 'Insufficient historical observation count (n < 3) to compute econometric volatility.',
      };
    }

    const df = n - 1;

    // 1. Calculate Sample Mean (\mu)
    const sum = values.reduce((acc, v) => acc + v, 0);
    const sampleMean = Number((sum / n).toFixed(3));

    // 2. Calculate Sample Standard Deviation (s) with Bessel's correction (n - 1)
    const varianceSum = values.reduce((acc, v) => acc + Math.pow(v - sampleMean, 2), 0);
    const sampleVariance = varianceSum / df;
    const sampleStandardDeviation = Number(Math.sqrt(sampleVariance).toFixed(3));

    // 3. Autocovariances & First-order serial autocorrelation coefficient (r_1)
    // Sample autocovariance at lag j: \hat{\gamma}_j = (1/n) \sum_{t=j+1}^n (x_t - \mu)(x_{t-j} - \mu)
    const gamma: number[] = [];
    const maxLag = Math.min(n - 1, 5);
    for (let j = 0; j <= maxLag; j++) {
      let cov = 0;
      for (let t = j; t < n; t++) {
        cov += (values[t] - sampleMean) * (values[t - j] - sampleMean);
      }
      gamma.push(cov / n);
    }
    const sampleVarianceGamma0 = gamma[0];
    const autocorrelationCoefficient = sampleVarianceGamma0 > 0
      ? Number((gamma[1] / sampleVarianceGamma0).toFixed(3))
      : 0;

    // 4. Formal Newey-West (1987) HAC Long-Run Variance Estimator
    // Lag truncation parameter: L = floor(4 * (n / 100)^(2/9))
    const L = Math.max(1, Math.min(n - 2, Math.floor(4 * Math.pow(n / 100, 2 / 9))));
    const bartlettWeights: number[] = [];
    let omegaHac = sampleVarianceGamma0;
    for (let j = 1; j <= L; j++) {
      const w_j = 1 - (j / (L + 1)); // Bartlett kernel weight
      bartlettWeights.push(Number(w_j.toFixed(4)));
      if (j < gamma.length) {
        omegaHac += 2 * w_j * gamma[j];
      }
    }
    // Guarantee positive semi-definiteness
    omegaHac = Math.max(0.001, Number(omegaHac.toFixed(4)));

    // HAC standard error: SE_HAC = sqrt(\Omega_HAC / n)
    const standardErrorHac = Number(Math.sqrt(omegaHac / n).toFixed(3));

    // AR(1) Effective Sample Size (Moran / Bayley-Hammersley): n_eff = n * (1 - r1) / (1 + r1)
    const isAutocorrelated = Math.abs(autocorrelationCoefficient) > 0.15;
    const effectiveSampleSizeAr1 = (isAutocorrelated && autocorrelationCoefficient > 0 && autocorrelationCoefficient < 0.95)
      ? Math.max(3, Number((n * ((1 - autocorrelationCoefficient) / (1 + autocorrelationCoefficient))).toFixed(2)))
      : n;
    const dfEff = Math.max(2, Math.floor(effectiveSampleSizeAr1 - 1));
    const tCritEff = this.getStudentTCritical95(dfEff);

    // Standard error for mean inference: uses Newey-West HAC standard error when autocorrelated
    const standardErrorOfMean = isAutocorrelated ? standardErrorHac : Number((sampleStandardDeviation / Math.sqrt(n)).toFixed(3));

    // 5. Formal 95% Confidence Interval for the Mean: \mu \pm t * SE_HAC
    const meanCiMargin = tCritEff * standardErrorOfMean;
    const meanConfidenceInterval95: [number, number] = [
      Number((sampleMean - meanCiMargin).toFixed(2)),
      Number((sampleMean + meanCiMargin).toFixed(2)),
    ];

    // 6. Formal 95% Prediction Interval for a Single Observation: incorporates long-run variance
    const piMargin = tCritEff * Math.sqrt(sampleVariance + (omegaHac / n));
    const observationPredictionInterval95: [number, number] = [
      Number((sampleMean - piMargin).toFixed(2)),
      Number((sampleMean + piMargin).toFixed(2)),
    ];

    // 7. Calculate z-score: (x - \mu) / s
    const zScore = sampleStandardDeviation > 0
      ? Number(((targetValue - sampleMean) / sampleStandardDeviation).toFixed(2))
      : 0;

    // 8. Statistical anomaly check: |z| >= 2.5
    const isStatisticallyAnomalous = Math.abs(zScore) >= 2.5;

    // 9. Cross-reference Structural Break Registry
    const structuralBreak = this.STRUCTURAL_BREAK_REGISTRY[entity]?.[targetYear];

    // 10. Non-judgmental Anomaly Classification
    let anomalyClassification: 'structural_break_event' | 'statistical_anomaly_requiring_context' | 'expected_historical_volatility';
    let isCherryPickedAnomaly = false;
    let rationale = '';

    const autoNote = isAutocorrelated
      ? ` (Serial persistence r1=${autocorrelationCoefficient} detected; Newey-West HAC SE=${standardErrorHac}, AR1 effective df adjusted from ${df} to ${dfEff})`
      : '';

    if (isStatisticallyAnomalous) {
      if (structuralBreak) {
        anomalyClassification = 'structural_break_event';
        isCherryPickedAnomaly = false; // Exogenous shock, not presumed deceptive intent
        rationale = `Documented Structural Break: Year ${targetYear} (${targetValue}%, z = ${zScore}) coincides with ${structuralBreak.event} (${structuralBreak.description}). This historical outlier represents an exogenous shock rather than secular economic performance; baseline trend mean is ${sampleMean}% (95% PI: [${observationPredictionInterval95[0]}%, ${observationPredictionInterval95[1]}%], serial r1: ${autocorrelationCoefficient})${autoNote}.`;
      } else {
        anomalyClassification = 'statistical_anomaly_requiring_context';
        isCherryPickedAnomaly = true; // Uncontextualized extreme divergence
        rationale = `Statistical Anomaly Requiring Context: Year ${targetYear} (${targetValue}%, z = ${zScore}) diverges significantly from historical baseline mean ${sampleMean}% and exceeds the 95% prediction interval [${observationPredictionInterval95[0]}%, ${observationPredictionInterval95[1]}%] (df=${dfEff}, r1=${autocorrelationCoefficient})${autoNote}. Requires explicit historical context.`;
      }
    } else {
      anomalyClassification = 'expected_historical_volatility';
      isCherryPickedAnomaly = false;
      rationale = `Observation falls within normal historical volatility bounds (mean: ${sampleMean}%, s: ${sampleStandardDeviation}%, z = ${zScore}, 95% PI: [${observationPredictionInterval95[0]}%, ${observationPredictionInterval95[1]}%]${autoNote}).`;
    }

    return {
      entity,
      metric,
      targetYear,
      targetValue,
      sampleMean,
      sampleStandardDeviation,
      standardErrorOfMean,
      zScore,
      degreesOfFreedom: df,
      meanConfidenceInterval95,
      observationPredictionInterval95,
      confidenceInterval95: observationPredictionInterval95, // Backward compatibility alias
      autocorrelationCoefficient,
      neweyWestHacDetails: {
        lagTruncation: L,
        bartlettWeights,
        autocovariances: gamma,
        longRunVarianceOmega: omegaHac,
        standardErrorHac,
        effectiveSampleSizeAr1,
      },
      isStatisticallyAnomalous,
      structuralBreakIdentified: structuralBreak,
      anomalyClassification,
      isCherryPickedAnomaly,
      rationale,
    };
  }
}
