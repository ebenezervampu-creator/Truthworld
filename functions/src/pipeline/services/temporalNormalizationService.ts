import {
  ComparableMetric,
  ComparabilityAssessment,
  ConflictingHistoricalSource,
  HistoricalEventBoundary,
  SensitivityAnalysisItem,
  TemporalConstraint,
  AccountingReconciliationStatus,
  GrowthCalculationMethod,
} from '../types';

/**
 * 🏛 Registry of Authoritative Historical Event Boundaries
 * Defines precise institutional, governmental, and event boundary spans
 * to prevent conflation between tenure periods and statistical sample windows.
 */
export const HISTORICAL_EVENT_BOUNDARIES: HistoricalEventBoundary[] = [
  {
    eventId: 'nehru_pm_tenure',
    name: 'Jawaharlal Nehru Prime Ministerial Tenure',
    aliases: [
      "nehru's tenure",
      'nehru tenure',
      "during nehru's tenure",
      'nehru era',
      'nehru administration',
      'under nehru',
      'prime minister nehru',
      "jawaharlal nehru's term",
      "jawaharlal nehru's tenure",
      'nehru premiership',
    ],
    startDate: '1947-08-15',
    endDate: '1964-05-27',
    startYear: 1947,
    endYear: 1964,
    description:
      'Prime Ministership of Jawaharlal Nehru from Indian independence until his death on May 27, 1964.',
    region: 'India',
  },
  {
    eventId: 'rao_pm_tenure',
    name: 'P.V. Narasimha Rao Prime Ministerial Tenure',
    aliases: [
      "rao's tenure",
      'rao tenure',
      "during rao's tenure",
      'narasimha rao administration',
      'rao government',
      'pv narasimha rao',
      'p.v. narasimha rao',
      '1991 liberalization',
      '1991 economic reforms',
      'rao ministry',
    ],
    startDate: '1991-06-21',
    endDate: '1996-05-16',
    startYear: 1991,
    endYear: 1996,
    description:
      "Prime Ministership of P.V. Narasimha Rao, overseeing India's balance of payments crisis resolution and structural economic reforms.",
    region: 'India',
  },
  {
    eventId: 'indira_gandhi_first_tenure',
    name: 'Indira Gandhi First Prime Ministerial Tenure',
    aliases: [
      "indira gandhi's first term",
      'indira gandhi first tenure',
      "indira's first tenure",
      'indira gandhi first ministry',
    ],
    startDate: '1966-01-24',
    endDate: '1977-03-24',
    startYear: 1966,
    endYear: 1977,
    description:
      'First premiership of Indira Gandhi including bank nationalization, the 1971 war, and the Emergency.',
    region: 'India',
  },
  {
    eventId: 'indira_gandhi_second_tenure',
    name: 'Indira Gandhi Second Prime Ministerial Tenure',
    aliases: [
      "indira gandhi's second term",
      'indira gandhi second tenure',
      "indira's second tenure",
    ],
    startDate: '1980-01-14',
    endDate: '1984-10-31',
    startYear: 1980,
    endYear: 1984,
    description:
      'Second premiership of Indira Gandhi concluding with Operation Blue Star and her assassination.',
    region: 'India',
  },
  {
    eventId: 'india_first_fy_plan',
    name: 'First Five-Year Plan of India',
    aliases: [
      'first five year plan',
      '1st five year plan',
      'first 5-year plan',
      'first five-year plan',
    ],
    startDate: '1951-04-01',
    endDate: '1956-03-31',
    startYear: 1951,
    endYear: 1956,
    description:
      'First national economic plan of the Republic of India focusing on agriculture and irrigation.',
    region: 'India',
  },
  {
    eventId: 'india_second_fy_plan',
    name: 'Second Five-Year Plan of India',
    aliases: [
      'second five year plan',
      '2nd five year plan',
      'second 5-year plan',
      'second five-year plan',
      'mahalanobis plan',
    ],
    startDate: '1956-04-01',
    endDate: '1961-03-31',
    startYear: 1956,
    endYear: 1961,
    description:
      'Second national economic plan of India emphasizing heavy industrialization under the Mahalanobis strategy.',
    region: 'India',
  },
  {
    eventId: 'thailand_sarit_era',
    name: 'Sarit Thanarat Premiership (Thailand)',
    aliases: [
      'sarit thanarat regime',
      'sarit thanarat era',
      'sarit regime',
      'sarit era',
      'thailand 1950s',
    ],
    startDate: '1959-02-09',
    endDate: '1963-12-08',
    startYear: 1959,
    endYear: 1963,
    description:
      'Economic modernization regime in Thailand under Field Marshal Sarit Thanarat prioritizing private enterprise and infrastructure.',
    region: 'Thailand',
  },
  {
    eventId: 'pakistan_ayub_era',
    name: 'Ayub Khan Administration (Pakistan)',
    aliases: [
      'ayub khan era',
      'ayub khan regime',
      'ayub era',
      'pakistan 1960s',
      'decade of development pakistan',
    ],
    startDate: '1958-10-27',
    endDate: '1969-03-25',
    startYear: 1958,
    endYear: 1969,
    description:
      'Presidency of Field Marshal Ayub Khan in Pakistan characterized by rapid industrial growth and agricultural modernization.',
    region: 'Pakistan',
  },
  {
    eventId: 'great_depression',
    name: 'The Great Depression',
    aliases: ['great depression', 'the depression', '1929 stock market crash'],
    startDate: '1929-10-29',
    endDate: '1939-09-01',
    startYear: 1929,
    endYear: 1939,
    description:
      'Severe worldwide economic depression beginning with the Wall Street crash of October 1929.',
  },
  {
    eventId: 'world_war_two',
    name: 'World War II',
    aliases: [
      'world war ii',
      'world war 2',
      'wwii',
      'second world war',
      'the second world war',
    ],
    startDate: '1939-09-01',
    endDate: '1945-09-02',
    startYear: 1939,
    endYear: 1945,
    description:
      'Global war from the invasion of Poland to the unconditional surrender of Axis forces.',
  },
];

/**
 * 🏛 Temporal Normalization and Comparative-Claim Verification Service
 * Deterministic pipeline verifying temporal boundaries, metric compatibility,
 * and statistical integrity before comparative verdicts are adjudicated.
 */
export class TemporalNormalizationService {
  private static eventBoundaries: HistoricalEventBoundary[] = HISTORICAL_EVENT_BOUNDARIES;

  /**
   * Look up a historical event boundary by alias or name.
   */
  public static lookupEventBoundary(query: string): HistoricalEventBoundary | undefined {
    if (!query) return undefined;
    const qClean = query.trim().toLowerCase();

    for (const event of this.eventBoundaries) {
      if (event.name.toLowerCase() === qClean || event.eventId.toLowerCase() === qClean) {
        return event;
      }
      for (const alias of event.aliases) {
        if (qClean.includes(alias.toLowerCase()) || alias.toLowerCase().includes(qClean)) {
          return event;
        }
      }
    }
    return undefined;
  }

  /**
   * P2.1: Extract Temporal Constraints from claim text.
   * Distinguishes:
   * - Explicit periods (e.g. "1947–1964")
   * - Event-defined periods (e.g. "during Nehru's tenure")
   * - Approximate periods / Decades (e.g. "the 1950s", "1960s")
   * - Unspecified periods (strictly does NOT invent dates)
   */
  public static extractTemporalConstraints(claimText: string): TemporalConstraint[] {
    if (!claimText || typeof claimText !== 'string') {
      return [{ temporalPrecision: 'unspecified', isExplicit: false }];
    }

    const text = claimText.trim();
    const constraints: TemporalConstraint[] = [];

    // 1. Check for Event-defined periods
    for (const event of this.eventBoundaries) {
      for (const alias of event.aliases) {
        const regex = new RegExp(`\\b${alias.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&')}\\b`, 'i');
        if (regex.test(text)) {
          const allYears: number[] = [];
          for (let y = event.startYear; y <= event.endYear; y++) {
            allYears.push(y);
          }
          constraints.push({
            startDate: event.startDate,
            endDate: event.endDate,
            startYear: event.startYear,
            endYear: event.endYear,
            referenceEvent: event.name,
            temporalPrecision: 'historical_period',
            isExplicit: true,
            coverageYears: allYears,
            rawExpression: alias,
          });
          break; // Avoid duplicate triggers for the same event
        }
      }
    }

    // 2. Check for Explicit Year Ranges: "1947–1964", "1947-1964", "from 1947 to 1964", "between 1947 and 1964"
    const rangeRegex = /(?:between\s+|from\s+)?(1[789]\d\d|20\d\d)\s*(?:-|–|—|to|\s+to\s+)\s*(1[789]\d\d|20\d\d)/gi;
    let match: RegExpExecArray | null;
    while ((match = rangeRegex.exec(text)) !== null) {
      const y1 = parseInt(match[1], 10);
      const y2 = parseInt(match[2], 10);
      const startYear = Math.min(y1, y2);
      const endYear = Math.max(y1, y2);

      const allYears: number[] = [];
      for (let y = startYear; y <= endYear; y++) {
        allYears.push(y);
      }

      constraints.push({
        startDate: `${startYear}-01-01`,
        endDate: `${endYear}-12-31`,
        startYear,
        endYear,
        temporalPrecision: 'year',
        isExplicit: true,
        coverageYears: allYears,
        rawExpression: match[0],
      });
    }

    // 3. Check for Decades: "the 1950s", "1950s", "1960s", "the 60s"
    const decadeRegex = /\b(?:the\s+)?(1[789]\d0|20\d0)s\b/gi;
    while ((match = decadeRegex.exec(text)) !== null) {
      const baseYear = parseInt(match[1], 10);
      const endYear = baseYear + 9;

      const allYears: number[] = [];
      for (let y = baseYear; y <= endYear; y++) {
        allYears.push(y);
      }

      // Avoid adding if already part of an explicit range
      const alreadyCovered = constraints.some(
        c => c.temporalPrecision === 'year' && c.startYear === baseYear && c.endYear === endYear
      );
      if (!alreadyCovered) {
        constraints.push({
          startDate: `${baseYear}-01-01`,
          endDate: `${endYear}-12-31`,
          startYear: baseYear,
          endYear,
          temporalPrecision: 'decade',
          isExplicit: true,
          coverageYears: allYears,
          rawExpression: match[0],
        });
      }
    }

    // 4. Check for Single Explicit Year: "in 1991", "1947"
    if (constraints.length === 0) {
      const singleYearRegex = /\b(1[789]\d\d|20\d\d)\b/g;
      const singleMatches = [...text.matchAll(singleYearRegex)];
      if (singleMatches.length === 1) {
        const y = parseInt(singleMatches[0][1], 10);
        constraints.push({
          startDate: `${y}-01-01`,
          endDate: `${y}-12-31`,
          startYear: y,
          endYear: y,
          temporalPrecision: 'year',
          isExplicit: true,
          coverageYears: [y],
          rawExpression: singleMatches[0][0],
        });
      }
    }

    // 5. Unspecified fallback: If no explicit or event temporal constraint is found,
    // NEVER invent one. Return explicit marker indicating unspecified period.
    if (constraints.length === 0) {
      return [
        {
          temporalPrecision: 'unspecified',
          isExplicit: false,
        },
      ];
    }

    return constraints;
  }

  /**
   * P2.2: Metric and Unit Normalization
   * Canonicalizes metric definitions, price basis, population basis,
   * accounting conventions (calendar vs fiscal), and annualization flags.
   */
  public static normalizeMetric(raw: Partial<ComparableMetric>): ComparableMetric {
    const entity = (raw.entity || 'Unknown Entity').trim();
    const rawMetric = (raw.metric || 'GDP_GROWTH_RATE').trim();
    const rawText = `${rawMetric} ${raw.methodology || ''} ${raw.sourceTitle || ''}`.toLowerCase();

    // Canonicalize Metric Name
    let canonicalMetric = rawMetric;
    if (
      rawText.includes('per capita') ||
      rawText.includes('per person') ||
      rawText.includes('per head')
    ) {
      canonicalMetric = rawText.includes('growth')
        ? 'GDP_PER_CAPITA_GROWTH'
        : 'GDP_PER_CAPITA_LEVEL';
    } else if (
      rawText.includes('gdp growth') ||
      rawText.includes('economic growth') ||
      rawText.includes('growth rate')
    ) {
      canonicalMetric = 'GDP_GROWTH_RATE';
    } else if (
      rawText.includes('inflation') ||
      rawText.includes('cpi')
    ) {
      canonicalMetric = 'INFLATION_RATE';
    } else if (
      rawText.includes('gdp level') ||
      rawText.includes('gross domestic product') ||
      rawText.includes('economic output')
    ) {
      canonicalMetric = 'GDP_LEVEL';
    }

    // Price Basis: Real vs Nominal
    let priceBasis: 'real' | 'nominal' | 'constant_price' | 'current_price' | 'unspecified' =
      raw.priceBasis || 'unspecified';
    if (priceBasis === 'unspecified') {
      if (
        rawText.includes('real') ||
        rawText.includes('constant price') ||
        rawText.includes('constant prices') ||
        rawText.includes('inflation-adjusted') ||
        rawText.includes('geary-khamis')
      ) {
        priceBasis = 'real';
      } else if (
        rawText.includes('nominal') ||
        rawText.includes('current price') ||
        rawText.includes('current prices')
      ) {
        priceBasis = 'nominal';
      }
    }

    // Population Basis: Total vs Per Capita
    let populationBasis: 'total' | 'per_capita' | 'unspecified' =
      raw.populationBasis || 'unspecified';
    if (populationBasis === 'unspecified') {
      if (
        canonicalMetric.includes('PER_CAPITA') ||
        rawText.includes('per capita') ||
        rawText.includes('per person')
      ) {
        populationBasis = 'per_capita';
      } else {
        populationBasis = 'total';
      }
    }

    // Accounting Convention: Calendar vs Fiscal
    let calendarVsFiscal: 'calendar' | 'fiscal' | 'unspecified' =
      raw.calendarVsFiscal || 'unspecified';
    if (calendarVsFiscal === 'unspecified') {
      if (
        rawText.includes('fiscal') ||
        rawText.includes('financial year') ||
        rawText.includes('fy') ||
        rawText.includes('april-march')
      ) {
        calendarVsFiscal = 'fiscal';
      } else if (
        rawText.includes('calendar') ||
        rawText.includes('cy') ||
        rawText.includes('jan-dec')
      ) {
        calendarVsFiscal = 'calendar';
      } else {
        calendarVsFiscal = 'calendar'; // Default baseline
      }
    }

    // Annualization
    const annualized =
      raw.annualized !== undefined
        ? raw.annualized
        : canonicalMetric.includes('GROWTH') || canonicalMetric.includes('RATE');

    // Temporal Alignment
    let startYear = raw.startYear;
    let endYear = raw.endYear;
    if (startYear === undefined && raw.startDate) {
      const match = raw.startDate.match(/(1[789]\d\d|20\d\d)/);
      if (match) startYear = parseInt(match[1], 10);
    }
    if (endYear === undefined && raw.endDate) {
      const match = raw.endDate.match(/(1[789]\d\d|20\d\d)/);
      if (match) endYear = parseInt(match[1], 10);
    }

    // Coverage & Missing Years
    let coverageYears = raw.coverageYears;
    let missingYears = raw.missingYears;

    if (startYear !== undefined && endYear !== undefined && startYear <= endYear) {
      const fullRange: number[] = [];
      for (let y = startYear; y <= endYear; y++) {
        fullRange.push(y);
      }

      if (coverageYears && !missingYears) {
        missingYears = fullRange.filter(y => !coverageYears!.includes(y));
      } else if (missingYears && !coverageYears) {
        coverageYears = fullRange.filter(y => !missingYears!.includes(y));
      } else if (!coverageYears && !missingYears) {
        coverageYears = fullRange;
        missingYears = [];
      }
    }

    // Calculation Method (CAGR vs Arithmetic Annual Mean)
    let calculationMethod: GrowthCalculationMethod = raw.calculationMethod || 'unspecified';
    if (calculationMethod === 'unspecified') {
      if (rawText.includes('cagr') || rawText.includes('compound annual') || rawText.includes('geometric')) {
        calculationMethod = 'cagr';
      } else if (rawText.includes('arithmetic') || rawText.includes('average annual') || rawText.includes('mean annual')) {
        calculationMethod = 'arithmetic_annual_mean';
      } else if (startYear !== undefined && endYear !== undefined && startYear === endYear) {
        calculationMethod = 'single_year';
      }
    }

    // Accounting Reconciliation Status
    const accountingReconciliation: AccountingReconciliationStatus =
      raw.accountingReconciliation || (raw.calendarVsFiscal ? 'compatible' : 'compatible');

    return {
      entity,
      metric: canonicalMetric,
      value: raw.value ?? 0,
      unit: raw.unit || '%',
      startDate: raw.startDate || (startYear ? `${startYear}-01-01` : undefined),
      endDate: raw.endDate || (endYear ? `${endYear}-12-31` : undefined),
      startYear,
      endYear,
      methodology: raw.methodology,
      sourceId: raw.sourceId,
      sourceTitle: raw.sourceTitle,
      priceBasis,
      populationBasis,
      calendarVsFiscal,
      accountingReconciliation,
      calculationMethod,
      annualized,
      coverageYears,
      missingYears,
      rawObservations: raw.rawObservations,
    };
  }

  /**
   * P2.3: Comparability Assessment & Hard Gate
   * Blocks invalid comparative claims when metrics differ across:
   * 1. Metric Type (GDP Level vs GDP per capita, etc.)
   * 2. Unit of measurement
   * 3. Temporal period (Mismatched decades, disjoint spans, calendar vs fiscal)
   * 4. Price basis (Real vs Nominal)
   * 5. Population basis (Aggregate Total vs Per Capita)
   */
  public static evaluateComparability(rawMetrics: Partial<ComparableMetric>[]): ComparabilityAssessment {
    if (!rawMetrics || rawMetrics.length < 2) {
      return {
        sameMetric: true,
        sameUnit: true,
        compatiblePeriods: true,
        compatibleMethodology: true,
        comparableDefinitions: true,
        isComparable: true,
        reasons: [],
        normalizedMetrics: rawMetrics ? rawMetrics.map(m => this.normalizeMetric(m)) : [],
      };
    }

    const metrics = rawMetrics.map(m => this.normalizeMetric(m));
    const reasons: string[] = [];
    const conflictingSources: ConflictingHistoricalSource[] = [];
    let accountingReconciliationStatus: AccountingReconciliationStatus = 'compatible';
    const reconciliationNotes: string[] = [];

    const base = metrics[0];
    let sameMetric = true;
    let sameUnit = true;
    let compatiblePeriods = true;
    let compatibleMethodology = true;
    let comparableDefinitions = true;

    for (let i = 1; i < metrics.length; i++) {
      const target = metrics[i];

      // 1. Check Metric Identity
      if (base.metric !== target.metric) {
        sameMetric = false;
        reasons.push(
          `Incompatible metric types: '${base.entity}' measures '${base.metric}' while '${target.entity}' measures '${target.metric}'. An aggregate total cannot be directly compared with a per-capita or different indicator.`
        );
      }

      // 2. Check Unit
      if (base.unit.trim().toLowerCase() !== target.unit.trim().toLowerCase()) {
        sameUnit = false;
        reasons.push(
          `Unit mismatch: '${base.entity}' is measured in '${base.unit}' while '${target.entity}' is measured in '${target.unit}'. Direct comparison requires standardized units.`
        );
      }

      // 3. Check Price Basis (Real vs Nominal)
      if (
        base.priceBasis !== 'unspecified' &&
        target.priceBasis !== 'unspecified' &&
        base.priceBasis !== target.priceBasis
      ) {
        comparableDefinitions = false;
        reasons.push(
          `Price basis mismatch: '${base.entity}' is measured in ${base.priceBasis} prices while '${target.entity}' is measured in ${target.priceBasis} prices. Real growth (inflation-adjusted) cannot be directly compared with nominal growth.`
        );
      }

      // 4. Check Population Basis (Total vs Per Capita)
      if (
        base.populationBasis !== 'unspecified' &&
        target.populationBasis !== 'unspecified' &&
        base.populationBasis !== target.populationBasis
      ) {
        comparableDefinitions = false;
        reasons.push(
          `Population basis mismatch: '${base.entity}' is measured on a ${base.populationBasis} basis while '${target.entity}' is measured on a ${target.populationBasis} basis.`
        );
      }

      // 5. Check Accounting Period (Calendar Year vs Fiscal Year)
      // Refinement B: Triaging into compatible, normalizable, or incompatible
      if (
        base.calendarVsFiscal !== 'unspecified' &&
        target.calendarVsFiscal !== 'unspecified' &&
        base.calendarVsFiscal !== target.calendarVsFiscal
      ) {
        const isNormalizable =
          base.accountingReconciliation === 'normalizable' ||
          target.accountingReconciliation === 'normalizable' ||
          base.methodology?.includes('quarterly_reconciliation') ||
          target.methodology?.includes('quarterly_reconciliation');

        if (isNormalizable) {
          accountingReconciliationStatus = 'normalizable';
          reconciliationNotes.push(
            `Documented accounting reconciliation: '${base.entity}' (${base.calendarVsFiscal} year) and '${target.entity}' (${target.calendarVsFiscal} year) reconciled via quarterly national accounts data.`
          );
        } else {
          compatiblePeriods = false;
          comparableDefinitions = false;
          accountingReconciliationStatus = 'incompatible';
          reasons.push(
            `Accounting convention mismatch: '${base.entity}' uses a ${base.calendarVsFiscal} year baseline while '${target.entity}' uses a ${target.calendarVsFiscal} year baseline without documented quarterly reconciliation. Direct statistical comparison requires calendar-fiscal alignment.`
          );
        }
      }

      // Refinement C: Calculation Method Compatibility (CAGR vs Arithmetic Annual Mean)
      if (
        base.calculationMethod !== 'unspecified' &&
        target.calculationMethod !== 'unspecified' &&
        base.calculationMethod !== target.calculationMethod
      ) {
        if (
          (base.calculationMethod === 'cagr' && target.calculationMethod === 'arithmetic_annual_mean') ||
          (base.calculationMethod === 'arithmetic_annual_mean' && target.calculationMethod === 'cagr')
        ) {
          comparableDefinitions = false;
          compatibleMethodology = false;
          reasons.push(
            `Calculation methodology mismatch: '${base.entity}' uses CAGR (geometric compound growth) while '${target.entity}' uses arithmetic mean of annual growth rates. During economic volatility or structural disruption, arithmetic and geometric means diverge significantly.`
          );
        }
      }

      // 6. Check Temporal Overlap / Period Compatibility & Observation Coverage
      if (
        base.startYear !== undefined &&
        base.endYear !== undefined &&
        target.startYear !== undefined &&
        target.endYear !== undefined
      ) {
        // Refinement A: Actual Observation Coverage Verification
        if (base.startYear === target.startYear && base.endYear === target.endYear) {
          const baseMissing = base.missingYears || [];
          const targetMissing = target.missingYears || [];
          if (baseMissing.length > 0 || targetMissing.length > 0) {
            compatiblePeriods = false;
            reasons.push(
              `Observation coverage mismatch: While start and end years appear aligned (${base.startYear}–${base.endYear}), actual observation coverage is incomplete. One or more datasets contain missing years without verified historical interpolation.`
            );
          }
        }

        const overlapStart = Math.max(base.startYear, target.startYear);
        const overlapEnd = Math.min(base.endYear, target.endYear);
        const overlapYears = Math.max(0, overlapEnd - overlapStart + 1);

        const baseSpan = base.endYear - base.startYear + 1;
        const targetSpan = target.endYear - target.startYear + 1;

        // Disjoint or severely mismatched spans
        if (overlapYears === 0) {
          compatiblePeriods = false;
          reasons.push(
            `Mismatched time periods: '${base.entity}' (${base.startYear}–${base.endYear}) cannot be directly compared with '${target.entity}' (${target.startYear}–${target.endYear}). Non-overlapping temporal windows produce spurious comparisons.`
          );
        } else if (
          overlapYears < Math.min(baseSpan, targetSpan) * 0.7 &&
          Math.abs(baseSpan - targetSpan) > 3
        ) {
          compatiblePeriods = false;
          reasons.push(
            `Asymmetrical time periods: '${base.entity}' covers ${baseSpan} years (${base.startYear}–${base.endYear}) while '${target.entity}' covers ${targetSpan} years (${target.startYear}–${target.endYear}) with only ${overlapYears} years overlapping.`
          );
        }
      } else if (
        (base.startYear !== undefined && target.startYear === undefined) ||
        (base.startYear === undefined && target.startYear !== undefined)
      ) {
        compatiblePeriods = false;
        reasons.push(
          `Indeterminate temporal baseline: One entity specifies a bounded period while the other has an unspecified temporal scope.`
        );
      }

      // 7. Check Methodology
      if (
        base.methodology &&
        target.methodology &&
        base.methodology.toLowerCase() !== target.methodology.toLowerCase()
      ) {
        if (
          (base.methodology.includes('SNA 1968') && target.methodology.includes('SNA 2008')) ||
          (base.methodology.includes('cash_basis') && target.methodology.includes('accrual_basis'))
        ) {
          compatibleMethodology = false;
          reasons.push(
            `Statistical methodology divergence: '${base.entity}' uses '${base.methodology}' while '${target.entity}' uses '${target.methodology}'.`
          );
        }
      }
    }

    // P2.5: Coverage & Missing Data Analysis
    let coverageGapNotice: string | undefined;
    const entitiesWithGaps = metrics.filter(m => m.missingYears && m.missingYears.length > 0);
    if (entitiesWithGaps.length > 0) {
      const notices = entitiesWithGaps.map(
        m => `'${m.entity}' is missing data for ${m.missingYears!.length} year(s) (${m.missingYears!.join(', ')}) during the ${m.startYear}–${m.endYear} observation window.`
      );
      coverageGapNotice = `Historical data coverage gap: ${notices.join(' ')}`;
    }

    // Conflicting Historical Datasets Detection
    for (let i = 0; i < metrics.length; i++) {
      for (let j = i + 1; j < metrics.length; j++) {
        const m1 = metrics[i];
        const m2 = metrics[j];
        if (
          m1.entity.toLowerCase() === m2.entity.toLowerCase() &&
          m1.metric === m2.metric &&
          m1.startYear === m2.startYear &&
          m1.endYear === m2.endYear &&
          Math.abs(m1.value - m2.value) > 0.05
        ) {
          conflictingSources.push({
            sourceTitle: m1.sourceTitle || `${m1.entity} Source A`,
            sourceId: m1.sourceId,
            metricValue: m1.value,
            unit: m1.unit,
            varianceDescription: `Estimates ${m1.value}${m1.unit} for ${m1.entity} (${m1.startYear}–${m1.endYear}).`,
          });
          conflictingSources.push({
            sourceTitle: m2.sourceTitle || `${m2.entity} Source B`,
            sourceId: m2.sourceId,
            metricValue: m2.value,
            unit: m2.unit,
            varianceDescription: `Estimates ${m2.value}${m2.unit} for ${m2.entity} (${m2.startYear}–${m2.endYear}), reflecting historical dataset divergence.`,
          });
        }
      }
    }

    const isComparable =
      sameMetric &&
      sameUnit &&
      compatiblePeriods &&
      comparableDefinitions &&
      compatibleMethodology;

    return {
      sameMetric,
      sameUnit,
      compatiblePeriods,
      compatibleMethodology,
      comparableDefinitions,
      isComparable,
      accountingReconciliationStatus,
      reconciliationNotes: reconciliationNotes.length > 0 ? reconciliationNotes : undefined,
      reasons,
      coverageGapNotice,
      conflictingSources: conflictingSources.length > 0 ? conflictingSources : undefined,
      normalizedMetrics: metrics,
    };
  }

  /**
   * P2.5: Generate Sensitivity Analysis for Alternative Time Windows
   * Demonstrates whether comparative findings or rankings shift when
   * evaluating reasonable alternative temporal baselines.
   * Uses precise percentage points (pp) terminology and tracks verdict shifts.
   */
  public static generateSensitivityAnalysis(
    entity: string,
    baselineMetric: ComparableMetric,
    alternativeWindows: {
      windowDescription: string;
      startYear: number;
      endYear: number;
      alternativeRate: number;
      verdictImpact: string;
      verdictShiftType?: 'flips_verdict' | 'changes_ranking' | 'alters_magnitude_only' | 'no_effect';
    }[]
  ): SensitivityAnalysisItem[] {
    const results: SensitivityAnalysisItem[] = [];

    for (const alt of alternativeWindows) {
      const diff = alt.alternativeRate - baselineMetric.value;
      const ppDiff = Math.abs(diff);
      const diffSign = diff >= 0 ? '+' : '-';
      const ppStr = `${diffSign}${ppDiff.toFixed(2)} percentage points`;

      const shiftType = alt.verdictShiftType || (
        alt.verdictImpact.toLowerCase().includes('flip') || alt.verdictImpact.toLowerCase().includes('revers')
          ? 'flips_verdict'
          : alt.verdictImpact.toLowerCase().includes('rank') || alt.verdictImpact.toLowerCase().includes('gap')
          ? 'changes_ranking'
          : 'alters_magnitude_only'
      );

      results.push({
        windowDescription: alt.windowDescription,
        startYear: alt.startYear,
        endYear: alt.endYear,
        percentagePointsDiff: Number(ppDiff.toFixed(2)),
        verdictImpact: alt.verdictImpact,
        verdictShiftType: shiftType,
        resultSummary: `Evaluating '${entity}' over ${alt.startYear}–${alt.endYear} yields ${alt.alternativeRate.toFixed(2)}% (${ppStr} vs ${baselineMetric.startYear}–${baselineMetric.endYear} baseline). Impact on comparative verdict: ${alt.verdictImpact} (classification: ${shiftType}).`,
      });
    }

    return results;
  }

  /**
   * Linguistic detection of comparative claims in text.
   */
  public static isComparativeClaim(claimText: string): boolean {
    if (!claimText || typeof claimText !== 'string') return false;
    const lower = claimText.toLowerCase();

    const comparativePhrases = [
      /\b(faster|slower|higher|lower|greater|smaller|better|worse)\s+than\b/,
      /\b(outperformed|underperformed|lagged behind|exceeded|surpassed)\b/,
      /\b(compared to|compared with|in comparison to|in comparison with)\b/,
      /\b(versus|\bvs\.?\b|while\s+.*\s+grew\s+at)\b/,
      /\b(more than|less than|as fast as)\b/,
      /\bwhereas\b/,
    ];

    if (comparativePhrases.some(p => p.test(lower))) {
      return true;
    }

    // Also check for multiple country entities with percentage figures
    const countries = ['india', 'pakistan', 'thailand', 'china', 'south korea', 'japan', 'taiwan', 'usa', 'united states'];
    const mentionedCountries = countries.filter(c => lower.includes(c));
    const percentageMatches = lower.match(/\b\d+(\.\d+)?%/g);

    if (mentionedCountries.length >= 2 && percentageMatches && percentageMatches.length >= 1) {
      return true;
    }

    return false;
  }

  /**
   * Helper to parse explicit comparative claims into structured ComparableMetric items.
   * Useful for claims like:
   * "Thailand and Pakistan grew at 5.2%, while India grew more slowly during Nehru's tenure."
   */
  public static parseComparativeMetricsFromText(
    claimText: string,
    options?: {
      defaultMetric?: string;
      defaultUnit?: string;
    }
  ): ComparableMetric[] {
    const metrics: ComparableMetric[] = [];
    const text = claimText.trim();
    const metricName = options?.defaultMetric || 'GDP_GROWTH_RATE';
    const unit = options?.defaultUnit || '%';

    // Check known entities
    const knownEntities = [
      { name: 'India', regex: /\bindia\b/i },
      { name: 'Thailand', regex: /\bthailand\b/i },
      { name: 'Pakistan', regex: /\bpakistan\b/i },
      { name: 'China', regex: /\bchina\b/i },
      { name: 'South Korea', regex: /\bsouth korea\b/i },
      { name: 'Japan', regex: /\bjapan\b/i },
    ];

    for (const ent of knownEntities) {
      if (ent.regex.test(text)) {
        // Extract context surrounding this entity
        const entIndex = text.search(ent.regex);
        const snippet = text.substring(Math.max(0, entIndex - 30), Math.min(text.length, entIndex + 80));

        // Find value near entity
        const valMatch = snippet.match(/(\d+(?:\.\d+)?)\s*%/);
        const val = valMatch ? parseFloat(valMatch[1]) : 0;

        // Check if there is a specific temporal constraint for this snippet
        const constraints = this.extractTemporalConstraints(snippet);
        let startYear: number | undefined;
        let endYear: number | undefined;

        if (constraints.length > 0 && constraints[0].isExplicit) {
          startYear = constraints[0].startYear;
          endYear = constraints[0].endYear;
        } else {
          // Fall back to claim-wide constraints
          const globalConstraints = this.extractTemporalConstraints(text);
          const firstExplicit = globalConstraints.find(c => c.isExplicit);
          if (firstExplicit) {
            startYear = firstExplicit.startYear;
            endYear = firstExplicit.endYear;
          }
        }

        metrics.push(
          this.normalizeMetric({
            entity: ent.name,
            metric: metricName,
            value: val,
            unit,
            startYear,
            endYear,
            priceBasis: snippet.toLowerCase().includes('nominal') ? 'nominal' : 'real',
            calendarVsFiscal: snippet.toLowerCase().includes('fiscal') ? 'fiscal' : 'calendar',
          })
        );
      }
    }

    return metrics;
  }
}
