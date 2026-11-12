import { ClaimVerificationService } from '../../src/pipeline/services/claimVerification';
import { TemporalNormalizationService } from '../../src/pipeline/services/temporalNormalizationService';
import { ComparableMetric } from '../../src/pipeline/types';

describe('P2 Temporal Normalization & Comparative-Claim Verification Test Suite', () => {
  let service: ClaimVerificationService;

  beforeEach(() => {
    service = new ClaimVerificationService('mock-api-key');
  });

  // Acceptance Test 1
  it('1. Thailand 1950s vs Pakistan 1960s: Reject as a direct comparison', () => {
    const thailand: Partial<ComparableMetric> = {
      entity: 'Thailand',
      metric: 'GDP_GROWTH_RATE',
      value: 5.2,
      unit: '%',
      startYear: 1950,
      endYear: 1959,
      priceBasis: 'real',
      populationBasis: 'total',
      calendarVsFiscal: 'calendar',
    };

    const pakistan: Partial<ComparableMetric> = {
      entity: 'Pakistan',
      metric: 'GDP_GROWTH_RATE',
      value: 6.8,
      unit: '%',
      startYear: 1960,
      endYear: 1969,
      priceBasis: 'real',
      populationBasis: 'total',
      calendarVsFiscal: 'calendar',
    };

    const assessment = service.evaluateComparability([thailand, pakistan]);

    expect(assessment.isComparable).toBe(false);
    expect(assessment.compatiblePeriods).toBe(false);
    expect(assessment.reasons.length).toBeGreaterThan(0);
    expect(assessment.reasons.some(r => r.includes('Mismatched time periods') || r.includes('1950') && r.includes('1960'))).toBe(true);
  });

  // Acceptance Test 2
  it('2. India 1947–1964 vs Pakistan 1947–1964: Allow only if metric definitions are compatible', () => {
    const india: Partial<ComparableMetric> = {
      entity: 'India',
      metric: 'GDP_GROWTH_RATE',
      value: 3.9,
      unit: '%',
      startYear: 1947,
      endYear: 1964,
      priceBasis: 'real',
      populationBasis: 'total',
      calendarVsFiscal: 'calendar',
    };

    const pakistan: Partial<ComparableMetric> = {
      entity: 'Pakistan',
      metric: 'GDP_GROWTH_RATE',
      value: 3.8,
      unit: '%',
      startYear: 1947,
      endYear: 1964,
      priceBasis: 'real',
      populationBasis: 'total',
      calendarVsFiscal: 'calendar',
    };

    const assessment = service.evaluateComparability([india, pakistan]);

    expect(assessment.isComparable).toBe(true);
    expect(assessment.sameMetric).toBe(true);
    expect(assessment.sameUnit).toBe(true);
    expect(assessment.compatiblePeriods).toBe(true);
    expect(assessment.comparableDefinitions).toBe(true);
    expect(assessment.reasons.length).toBe(0);
  });

  // Acceptance Test 3
  it('3. Calendar year vs fiscal year: Flag incompatibility', () => {
    const indiaFiscal: Partial<ComparableMetric> = {
      entity: 'India',
      metric: 'GDP_GROWTH_RATE',
      value: 4.1,
      unit: '%',
      startYear: 1950,
      endYear: 1964,
      priceBasis: 'real',
      calendarVsFiscal: 'fiscal',
    };

    const thailandCalendar: Partial<ComparableMetric> = {
      entity: 'Thailand',
      metric: 'GDP_GROWTH_RATE',
      value: 5.2,
      unit: '%',
      startYear: 1950,
      endYear: 1964,
      priceBasis: 'real',
      calendarVsFiscal: 'calendar',
    };

    const assessment = service.evaluateComparability([indiaFiscal, thailandCalendar]);

    expect(assessment.isComparable).toBe(false);
    expect(assessment.compatiblePeriods).toBe(false);
    expect(assessment.reasons.some(r => r.includes('fiscal') && r.includes('calendar'))).toBe(true);
  });

  // Acceptance Test 4
  it('4. Real GDP vs nominal GDP: Reject direct comparison', () => {
    const indiaReal: Partial<ComparableMetric> = {
      entity: 'India',
      metric: 'GDP_GROWTH_RATE',
      value: 3.9,
      unit: '%',
      startYear: 1950,
      endYear: 1964,
      priceBasis: 'real',
    };

    const indiaNominal: Partial<ComparableMetric> = {
      entity: 'India (Nominal)',
      metric: 'GDP_GROWTH_RATE',
      value: 7.8,
      unit: '%',
      startYear: 1950,
      endYear: 1964,
      priceBasis: 'nominal',
    };

    const assessment = service.evaluateComparability([indiaReal, indiaNominal]);

    expect(assessment.isComparable).toBe(false);
    expect(assessment.comparableDefinitions).toBe(false);
    expect(assessment.reasons.some(r => r.includes('Price basis mismatch') && r.includes('real') && r.includes('nominal'))).toBe(true);
  });

  // Acceptance Test 5
  it('5. GDP vs GDP per capita: Reject direct comparison', () => {
    const gdpAggregate: Partial<ComparableMetric> = {
      entity: 'India',
      metric: 'GDP_GROWTH_RATE',
      value: 3.9,
      unit: '%',
      startYear: 1950,
      endYear: 1964,
      populationBasis: 'total',
    };

    const gdpPerCapita: Partial<ComparableMetric> = {
      entity: 'India',
      metric: 'GDP_PER_CAPITA_GROWTH',
      value: 1.8,
      unit: '%',
      startYear: 1950,
      endYear: 1964,
      populationBasis: 'per_capita',
    };

    const assessment = service.evaluateComparability([gdpAggregate, gdpPerCapita]);

    expect(assessment.isComparable).toBe(false);
    expect(assessment.sameMetric).toBe(false);
    expect(assessment.reasons.some(r => r.includes('metric types') || r.includes('per-capita'))).toBe(true);
  });

  // Acceptance Test 6
  it("6. Missing years in one country's dataset: Disclose coverage gap", () => {
    const indiaComplete: Partial<ComparableMetric> = {
      entity: 'India',
      metric: 'GDP_GROWTH_RATE',
      value: 3.9,
      unit: '%',
      startYear: 1947,
      endYear: 1964,
      coverageYears: [1947, 1948, 1949, 1950, 1951, 1952, 1953, 1954, 1955, 1956, 1957, 1958, 1959, 1960, 1961, 1962, 1963, 1964],
    };

    const pakistanWithGaps: Partial<ComparableMetric> = {
      entity: 'Pakistan',
      metric: 'GDP_GROWTH_RATE',
      value: 3.8,
      unit: '%',
      startYear: 1947,
      endYear: 1964,
      missingYears: [1948, 1949],
    };

    const assessment = service.evaluateComparability([indiaComplete, pakistanWithGaps]);

    expect(assessment.coverageGapNotice).toBeDefined();
    expect(assessment.coverageGapNotice).toContain('Pakistan');
    expect(assessment.coverageGapNotice).toContain('1948');
    expect(assessment.coverageGapNotice).toContain('1949');
  });

  // Acceptance Test 7
  it('7. Conflicting historical datasets: Preserve both and explain disagreement', () => {
    const maddisonEstimate: Partial<ComparableMetric> = {
      entity: 'India',
      metric: 'GDP_GROWTH_RATE',
      value: 3.9,
      unit: '%',
      startYear: 1950,
      endYear: 1964,
      sourceTitle: 'Angus Maddison (Historical Statistics of the World Economy)',
      priceBasis: 'real',
    };

    const sivasubramonianEstimate: Partial<ComparableMetric> = {
      entity: 'India',
      metric: 'GDP_GROWTH_RATE',
      value: 3.7,
      unit: '%',
      startYear: 1950,
      endYear: 1964,
      sourceTitle: 'Sivasubramonian (The National Income of India in the Twentieth Century)',
      priceBasis: 'real',
    };

    const assessment = service.evaluateComparability([maddisonEstimate, sivasubramonianEstimate]);

    expect(assessment.conflictingSources).toBeDefined();
    expect(assessment.conflictingSources!.length).toBe(2);
    expect(assessment.conflictingSources![0].sourceTitle).toContain('Maddison');
    expect(assessment.conflictingSources![1].sourceTitle).toContain('Sivasubramonian');
    expect(assessment.conflictingSources![1].varianceDescription).toContain('divergence');
  });

  // Acceptance Test 8
  it('8. Claim says "during Nehru\'s tenure": Resolve the event-defined period', () => {
    const text = 'India experienced an average growth rate of 3.9% during Nehru\'s tenure.';
    const constraints = service.extractTemporalConstraints(text);

    expect(constraints.length).toBeGreaterThan(0);
    const nehruConstraint = constraints.find(c => c.temporalPrecision === 'historical_period');
    expect(nehruConstraint).toBeDefined();
    expect(nehruConstraint!.referenceEvent).toContain('Jawaharlal Nehru');
    expect(nehruConstraint!.startYear).toBe(1947);
    expect(nehruConstraint!.endYear).toBe(1964);
    expect(nehruConstraint!.startDate).toBe('1947-08-15');
    expect(nehruConstraint!.endDate).toBe('1964-05-27');
    expect(nehruConstraint!.isExplicit).toBe(true);
  });

  // Acceptance Test 9
  it('9. Claim does not specify a period: Do not invent one', () => {
    const text = 'Socialism severely hurt private industrial manufacturing in India.';
    const constraints = service.extractTemporalConstraints(text);

    expect(constraints.length).toBe(1);
    expect(constraints[0].temporalPrecision).toBe('unspecified');
    expect(constraints[0].isExplicit).toBe(false);
    expect(constraints[0].startDate).toBeUndefined();
    expect(constraints[0].endDate).toBeUndefined();
    expect(constraints[0].startYear).toBeUndefined();
    expect(constraints[0].endYear).toBeUndefined();
  });

  // Acceptance Test 10
  it('10. Different reasonable date windows change the result: Report sensitivity', () => {
    const baseline = service.normalizeComparableMetric({
      entity: 'India',
      metric: 'GDP_GROWTH_RATE',
      value: 3.7,
      unit: '%',
      startYear: 1947,
      endYear: 1964,
      priceBasis: 'real',
    });

    const sensitivity = service.generateSensitivityAnalysis('India', baseline, [
      {
        windowDescription: 'Post-Constitution / First Five-Year Plan baseline (omitting 1947-1949 partition disruption)',
        startYear: 1950,
        endYear: 1964,
        alternativeRate: 4.1,
        verdictImpact: 'Increases average growth from 3.7% to 4.1%, narrowing gap with peer economies.',
      },
      {
        windowDescription: 'Second Five-Year Plan heavy industry phase',
        startYear: 1956,
        endYear: 1961,
        alternativeRate: 4.25,
        verdictImpact: 'Reflects higher public capital formation before 1962 China conflict and 1965 drought.',
      },
    ]);

    expect(sensitivity.length).toBe(2);
    expect(sensitivity[0].startYear).toBe(1950);
    expect(sensitivity[0].endYear).toBe(1964);
    expect(sensitivity[0].percentagePointsDiff).toBe(0.40);
    expect(sensitivity[0].resultSummary).toContain('+0.40 percentage points');
    expect(sensitivity[0].verdictImpact).toContain('narrowing gap');
    expect(sensitivity[0].verdictShiftType).toBe('changes_ranking');
    expect(sensitivity[1].startYear).toBe(1956);
    expect(sensitivity[1].endYear).toBe(1961);
  });

  // P2 Refinement B Test: Fiscal vs Calendar Normalization Triaging
  it('3b. Fiscal vs Calendar Year Normalization: Reconciles when quarterly data is documented', () => {
    const indiaFiscalQuarterly: Partial<ComparableMetric> = {
      entity: 'India',
      metric: 'GDP_GROWTH_RATE',
      value: 3.9,
      unit: '%',
      startYear: 1950,
      endYear: 1964,
      priceBasis: 'real',
      calendarVsFiscal: 'fiscal',
      accountingReconciliation: 'normalizable',
      methodology: 'quarterly_reconciliation',
    };

    const thailandCalendar: Partial<ComparableMetric> = {
      entity: 'Thailand',
      metric: 'GDP_GROWTH_RATE',
      value: 4.0,
      unit: '%',
      startYear: 1950,
      endYear: 1964,
      priceBasis: 'real',
      calendarVsFiscal: 'calendar',
    };

    const assessment = service.evaluateComparability([indiaFiscalQuarterly, thailandCalendar]);

    expect(assessment.isComparable).toBe(true);
    expect(assessment.accountingReconciliationStatus).toBe('normalizable');
    expect(assessment.reconciliationNotes).toBeDefined();
    expect(assessment.reconciliationNotes![0]).toContain('reconciled via quarterly national accounts');
  });

  // P2 Refinement C Test: CAGR vs Arithmetic Annual Mean Disqualification
  it('4b. CAGR vs Arithmetic Annual Mean: Rejects direct comparison due to compounding divergence', () => {
    const indiaCagr: Partial<ComparableMetric> = {
      entity: 'India',
      metric: 'GDP_GROWTH_RATE',
      value: 3.85,
      unit: '%',
      startYear: 1950,
      endYear: 1964,
      calculationMethod: 'cagr',
    };

    const peerArithmetic: Partial<ComparableMetric> = {
      entity: 'Peer Economy',
      metric: 'GDP_GROWTH_RATE',
      value: 4.20,
      unit: '%',
      startYear: 1950,
      endYear: 1964,
      calculationMethod: 'arithmetic_annual_mean',
    };

    const assessment = service.evaluateComparability([indiaCagr, peerArithmetic]);

    expect(assessment.isComparable).toBe(false);
    expect(assessment.comparableDefinitions).toBe(false);
    expect(assessment.reasons.some(r => r.includes('CAGR') && r.includes('arithmetic mean'))).toBe(true);
  });

  // Bonus Integration Test: Linguistic detection & automatic parsing of Claim #1
  it('11. Comparative Claim Parsing: Correctly detects comparative language and enforces hard gate on Nehru Claim #1', () => {
    const claim1 = 'Thailand and Pakistan grew at 5.2%, while India grew more slowly during Nehru\'s tenure.';

    expect(service.isComparativeClaim(claim1)).toBe(true);

    const thailandConstraint = TemporalNormalizationService.extractTemporalConstraints('Thailand grew at 5.2% in the 1950s')[0];
    const pakistanConstraint = TemporalNormalizationService.extractTemporalConstraints('Pakistan grew at 6.8% in the 1960s')[0];
    const nehruConstraint = TemporalNormalizationService.extractTemporalConstraints('India grew at 3.9% during Nehru\'s tenure')[0];

    const metrics = [
      service.normalizeComparableMetric({
        entity: 'Thailand',
        value: 5.2,
        startYear: thailandConstraint.startYear,
        endYear: thailandConstraint.endYear,
      }),
      service.normalizeComparableMetric({
        entity: 'Pakistan',
        value: 6.8,
        startYear: pakistanConstraint.startYear,
        endYear: pakistanConstraint.endYear,
      }),
      service.normalizeComparableMetric({
        entity: 'India',
        value: 3.9,
        startYear: nehruConstraint.startYear,
        endYear: nehruConstraint.endYear,
      }),
    ];

    const assessment = service.evaluateComparability(metrics);

    expect(assessment.isComparable).toBe(false);
    expect(assessment.compatiblePeriods).toBe(false);
    expect(assessment.reasons.length).toBeGreaterThan(0);
  });
});
