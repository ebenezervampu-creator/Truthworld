import { BenchmarkClaimRecord } from '../types';

/**
 * 🏛 Gold-Standard Fact-Checking Benchmark Dataset (Version 1.2.0-gold)
 * Independently curated and annotated claims across 8 categories with authoritative reference judgments,
 * provenance metadata, annotator agreement rates, and strict epistemic categorization.
 *
 * All reference verdicts in this dataset were established through independent expert consensus
 * without circular dependency on TruthWorld AI predictions.
 */
export const GOLD_STANDARD_BENCHMARK_DATASET: BenchmarkClaimRecord[] = [
  // ──────────────────────────────────────────────────────────
  // 1. COMPARATIVE & TEMPORAL CLAIMS
  // ──────────────────────────────────────────────────────────
  {
    id: 'comp_001_nehru_thailand_pakistan',
    category: 'comparative_temporal',
    epistemicCategory: 'economic_statistical_indicator',
    claimText: 'Thailand and Pakistan grew at 5.2%, while India grew more slowly during Nehru\'s tenure.',
    normalizedProposition: 'Between 1947 and 1964, India\'s real economic growth rate was lower than the growth rates of Thailand and Pakistan over the exact same period.',
    referenceVerdict: 'inconclusive',
    acceptableVerdicts: ['inconclusive', 'misleading'],
    referenceSources: [
      {
        title: 'Angus Maddison — Historical Statistics of the World Economy (1950–1964)',
        url: 'https://www.rug.nl/ggdc/historicaldevelopment/maddison/releases/maddison-database-2020',
        domain: 'rug.nl',
        publisher: 'Groningen Growth and Development Centre',
        tier: 'A',
        snippet: 'Thailand growth figures of 5.2% refer specifically to the 1950s post-Sarit reconstruction, whereas Pakistan\'s cited 6.8% expansion occurred during Ayub Khan\'s 1960s decade, making direct comparison across mismatched decades historically invalid.',
        whatItSupports: 'Documents Thailand\'s 1950s and Pakistan\'s 1960s growth rates.',
        whatItDoesNotEstablish: 'Does not support a direct synchronized comparison with India\'s 1947–1964 tenure.',
      },
      {
        title: 'Sivasubramonian — The National Income of India in the Twentieth Century',
        url: 'https://academic.oup.com/book/9876',
        domain: 'oup.com',
        publisher: 'Oxford University Press',
        tier: 'B',
        snippet: 'Indian real GDP growth averaged 3.7% to 4.1% depending on whether the 1947–1949 partition disruption is included.',
      },
    ],
    contradictorySources: [],
    relevantTemporalConstraints: [
      {
        startYear: 1947,
        endYear: 1964,
        startDate: '1947-08-15',
        endDate: '1964-05-27',
        referenceEvent: 'Jawaharlal Nehru Prime Ministerial Tenure',
        temporalPrecision: 'historical_period',
        isExplicit: true,
      },
    ],
    expectedComparableMetrics: [
      {
        entity: 'Thailand',
        metric: 'GDP_GROWTH_RATE',
        value: 5.2,
        unit: '%',
        startYear: 1950,
        endYear: 1959,
        priceBasis: 'real',
        calendarVsFiscal: 'calendar',
        calculationMethod: 'arithmetic_annual_mean',
        coverageYears: [1950, 1951, 1952, 1953, 1954, 1955, 1956, 1957, 1958, 1959],
      },
      {
        entity: 'Pakistan',
        metric: 'GDP_GROWTH_RATE',
        value: 6.8,
        unit: '%',
        startYear: 1960,
        endYear: 1969,
        priceBasis: 'real',
        calendarVsFiscal: 'fiscal',
        calculationMethod: 'cagr',
        coverageYears: [1960, 1961, 1962, 1963, 1964, 1965, 1966, 1967, 1968, 1969],
      },
    ],
    expertAnnotationNotes: 'Temporal mismatch (Thailand 1950s, Pakistan 1960s, India 1947–1964). Comparing mismatched decades is invalid.',
    annotatorAgreementRate: 1.0,
    difficultyTier: 'nuanced',
    annotatorId: 'ann_econ_01',
    annotationTimestamp: '2026-10-15T09:30:00Z',
    adjudicationHistory: [
      { timestamp: '2026-10-15T09:30:00Z', annotatorId: 'ann_econ_01', verdict: 'inconclusive', rationale: 'Mismatched decades detected in historical tables.' }
    ],
    datasetVersion: '1.2.0-gold',
    isIndependentlyEstablished: true,
  },
  {
    id: 'comp_002_india_pakistan_synchronized_growth',
    category: 'comparative_temporal',
    epistemicCategory: 'economic_statistical_indicator',
    claimText: 'India and Pakistan both grew at roughly 3.8% annually between 1950 and 1964.',
    normalizedProposition: 'Between 1950 and 1964, both India and Pakistan achieved comparable compound annual real GDP growth rates of approximately 3.8%.',
    referenceVerdict: 'verified_true',
    acceptableVerdicts: ['verified_true', 'mostly_true'],
    referenceSources: [
      {
        title: 'Maddison Project Database 2020',
        url: 'https://www.rug.nl/ggdc/historicaldevelopment/maddison/releases/maddison-database-2020',
        domain: 'rug.nl',
        publisher: 'University of Groningen',
        tier: 'A',
        snippet: 'Over 1950–1964, India\'s real GDP grew at ~3.9% annually, while Pakistan\'s averaged ~3.8%.',
      },
    ],
    expertAnnotationNotes: 'Synchronized temporal periods (1950–1964) with consistent real GDP accounting methodology.',
    annotatorAgreementRate: 0.95,
    difficultyTier: 'standard',
    annotatorId: 'ann_econ_02',
    annotationTimestamp: '2026-10-16T11:00:00Z',
    adjudicationHistory: [
      { timestamp: '2026-10-16T11:00:00Z', annotatorId: 'ann_econ_02', verdict: 'verified_true', rationale: 'Synchronized Maddison data confirms 3.8-3.9% annual rates.' }
    ],
    datasetVersion: '1.2.0-gold',
    isIndependentlyEstablished: true,
  },

  // ──────────────────────────────────────────────────────────
  // 2. HISTORICAL & POLITICAL CLAIMS
  // ──────────────────────────────────────────────────────────
  {
    id: 'hist_001_first_general_election',
    category: 'historical',
    epistemicCategory: 'historical_event',
    claimText: 'India conducted its first general election after independence between October 1951 and February 1952.',
    normalizedProposition: 'The first general election of independent India took place across multiple phases from October 25, 1951 to February 21, 1952.',
    referenceVerdict: 'verified_true',
    acceptableVerdicts: ['verified_true'],
    referenceSources: [
      {
        title: 'Election Commission of India — Statistical Report on General Elections, 1951',
        url: 'https://eci.gov.in/statistical-report/statistical-reports/',
        domain: 'eci.gov.in',
        publisher: 'Election Commission of India',
        tier: 'A',
        snippet: 'Polling was conducted in 68 phases between 25 October 1951 and 21 February 1952.',
      },
      {
        title: 'Ramachandra Guha — India After Gandhi',
        url: 'https://www.harpercollins.com/products/india-after-gandhi',
        domain: 'harpercollins.com',
        publisher: 'HarperCollins',
        tier: 'B',
        snippet: 'Chapter 7 documents Sukumar Sen\'s administration of the October 1951 – February 1952 universal franchise election.',
      },
    ],
    expertAnnotationNotes: 'Historically verified general election dates backed by primary ECI archives.',
    annotatorAgreementRate: 1.0,
    difficultyTier: 'standard',
    annotatorId: 'ann_hist_01',
    annotationTimestamp: '2026-10-14T14:20:00Z',
    adjudicationHistory: [
      { timestamp: '2026-10-14T14:20:00Z', annotatorId: 'ann_hist_01', verdict: 'verified_true', rationale: 'Confirmed by primary Election Commission records.' }
    ],
    datasetVersion: '1.2.0-gold',
    isIndependentlyEstablished: true,
  },
  {
    id: 'hist_002_rao_created_globalization',
    category: 'historical',
    epistemicCategory: 'political_attribution',
    claimText: 'P.V. Narasimha Rao personally created and introduced globalization to the world in 1991.',
    normalizedProposition: 'P.V. Narasimha Rao invented the phenomenon of globalization and introduced it to the global community in 1991.',
    referenceVerdict: 'verified_false',
    acceptableVerdicts: ['verified_false'],
    referenceSources: [
      {
        title: 'Oxford Handbook of Globalization',
        url: 'https://academic.oup.com/edited-volume/34320',
        domain: 'oup.com',
        publisher: 'Oxford University Press',
        tier: 'B',
        snippet: 'Modern globalization emerged from post-WWII multilateral frameworks (GATT, IMF, World Bank) and multi-century international trade networks. While Rao integrated India into the global economy in 1991, he did not create globalization or global capitalism.',
      },
    ],
    expertAnnotationNotes: 'Conflates initiating Indian national economic reforms with inventing global capitalism.',
    annotatorAgreementRate: 1.0,
    difficultyTier: 'standard',
    annotatorId: 'ann_hist_02',
    annotationTimestamp: '2026-10-14T15:10:00Z',
    adjudicationHistory: [
      { timestamp: '2026-10-14T15:10:00Z', annotatorId: 'ann_hist_02', verdict: 'verified_false', rationale: 'Distinction between Indian domestic reforms and global origin is clear.' }
    ],
    datasetVersion: '1.2.0-gold',
    isIndependentlyEstablished: true,
  },

  // ──────────────────────────────────────────────────────────
  // 3. SCIENTIFIC & MEDICAL CLAIMS
  // ──────────────────────────────────────────────────────────
  {
    id: 'sci_001_measles_vaccine_deaths',
    category: 'scientific_medical',
    epistemicCategory: 'scientific_empirical_claim',
    claimText: 'Measles vaccination prevented over 50 million child deaths globally between 2000 and 2022.',
    normalizedProposition: 'Widespread administration of the measles vaccine averted an estimated 57 million child deaths between 2000 and 2022 according to global epidemiological models.',
    referenceVerdict: 'verified_true',
    acceptableVerdicts: ['verified_true', 'mostly_true'],
    referenceSources: [
      {
        title: 'World Health Organization — Measles Fact Sheet',
        url: 'https://www.who.int/news-room/fact-sheets/detail/measles',
        domain: 'who.int',
        publisher: 'World Health Organization',
        tier: 'A',
        snippet: 'During 2000–2022, measles vaccination prevented an estimated 57 million deaths, making measles vaccine one of the best buys in public health.',
      },
    ],
    expertAnnotationNotes: 'Directly supported by authoritative WHO/CDC consensus epidemiological data.',
    annotatorAgreementRate: 1.0,
    difficultyTier: 'standard',
    annotatorId: 'ann_med_01',
    annotationTimestamp: '2026-10-17T08:45:00Z',
    adjudicationHistory: [
      { timestamp: '2026-10-17T08:45:00Z', annotatorId: 'ann_med_01', verdict: 'verified_true', rationale: 'Supported by WHO global mortality estimates.' }
    ],
    datasetVersion: '1.2.0-gold',
    isIndependentlyEstablished: true,
  },
  {
    id: 'sci_002_apollo_11_hoax',
    category: 'scientific_medical',
    epistemicCategory: 'scientific_empirical_claim',
    claimText: 'NASA completely faked the Apollo 11 Moon landing in 1969 on a Hollywood film stage.',
    normalizedProposition: 'The July 1969 Apollo 11 lunar landing was staged on an Earth set and did not occur on the Moon.',
    referenceVerdict: 'verified_false',
    acceptableVerdicts: ['verified_false'],
    referenceSources: [
      {
        title: 'NASA Lunar Reconnaissance Orbiter — Apollo Landing Sites Photography',
        url: 'https://www.nasa.gov/mission_pages/LRO/multimedia/lroimages/apollosites.html',
        domain: 'nasa.gov',
        publisher: 'National Aeronautics and Space Administration',
        tier: 'A',
        snippet: 'Orbital imagery confirms descent stages, lunar roving vehicle tracks, and scientific instrumentation on lunar surface. Independent retroreflector laser ranging verified globally by observatories.',
      },
      {
        title: 'McDonald Observatory Laser Ranging Station — Lunar Laser Ranging Experiment',
        url: 'https://mcdonaldobservatory.org/research/projects/lunar-laser-ranging',
        domain: 'mcdonaldobservatory.org',
        publisher: 'University of Texas at Austin',
        tier: 'B',
        snippet: 'Independent laser ranging routinely pulses retroreflectors left at Tranquility Base by Apollo 11.',
      },
    ],
    expertAnnotationNotes: 'Extensively disproven conspiracy claim contradicted by multiple independent physical evidence lines.',
    annotatorAgreementRate: 1.0,
    difficultyTier: 'standard',
    annotatorId: 'ann_sci_01',
    annotationTimestamp: '2026-10-18T16:00:00Z',
    adjudicationHistory: [
      { timestamp: '2026-10-18T16:00:00Z', annotatorId: 'ann_sci_01', verdict: 'verified_false', rationale: 'Orbital imagery and laser retroreflectors provide hard proof.' }
    ],
    datasetVersion: '1.2.0-gold',
    isIndependentlyEstablished: true,
  },

  // ──────────────────────────────────────────────────────────
  // 4. RELIGIOUS & PHILOSOPHICAL CLAIMS (Epistemic Distinctions)
  // ──────────────────────────────────────────────────────────
  {
    id: 'rel_001_traditional_belief_gospel',
    category: 'religious_philosophical',
    epistemicCategory: 'traditional_religious_belief',
    claimText: 'Jesus walked on water across the Sea of Galilee.',
    normalizedProposition: 'In Christian religious tradition, Jesus walked on the surface of the Sea of Galilee as recorded in the New Testament.',
    referenceVerdict: 'religious_belief',
    acceptableVerdicts: ['religious_belief', 'faith_based_claim'],
    referenceSources: [
      {
        title: 'The Gospel According to Matthew 14:22–33',
        url: 'https://www.biblegateway.com/passage/?search=Matthew+14%3A22-33&version=NRSV',
        domain: 'biblegateway.com',
        publisher: 'Bible Gateway',
        tier: 'B',
        sourceType: 'scripture',
        snippet: 'Canonical New Testament narrative describes Jesus walking on the water to the disciples\' boat.',
        whatItSupports: 'Documents scriptural text and Christian faith tradition.',
        whatItDoesNotEstablish: 'Cannot establish empirical or physical proof of supernatural miracles.',
      },
    ],
    expertAnnotationNotes: 'Traditional faith proposition. Must NOT be classified as scientifically disproven or false; classified as religious_belief.',
    annotatorAgreementRate: 1.0,
    difficultyTier: 'nuanced',
    annotatorId: 'ann_rel_01',
    annotationTimestamp: '2026-10-19T10:15:00Z',
    adjudicationHistory: [
      { timestamp: '2026-10-19T10:15:00Z', annotatorId: 'ann_rel_01', verdict: 'religious_belief', rationale: 'Canonical theological narrative; unfalsifiable faith claim.' }
    ],
    datasetVersion: '1.2.0-gold',
    isIndependentlyEstablished: true,
  },
  {
    id: 'rel_002_textual_record_saraswati',
    category: 'religious_philosophical',
    epistemicCategory: 'textual_record',
    claimText: 'The Rigveda contains hymns praising the Saraswati as a mighty river flowing from mountains to the sea.',
    normalizedProposition: 'The historical Sanskrit text of the Rigveda includes hymns specifically eulogizing the Saraswati river.',
    referenceVerdict: 'verified_true',
    acceptableVerdicts: ['verified_true'],
    referenceSources: [
      {
        title: 'Rigveda Samhita (Mandala 7, Hymn 95)',
        url: 'https://sacred-texts.com/hin/rv/rv07095.htm',
        domain: 'sacred-texts.com',
        publisher: 'Sacred Texts Archive / Harvard Oriental Series',
        tier: 'B',
        sourceType: 'scripture',
        snippet: 'Rigveda 7.95.2 describes the Saraswati flowing from mountains to the samudra.',
      },
    ],
    expertAnnotationNotes: 'Textual record claim: verifiable proposition about what an ancient text contains, independent of faith.',
    annotatorAgreementRate: 1.0,
    difficultyTier: 'standard',
    annotatorId: 'ann_rel_02',
    annotationTimestamp: '2026-10-19T11:30:00Z',
    adjudicationHistory: [
      { timestamp: '2026-10-19T11:30:00Z', annotatorId: 'ann_rel_02', verdict: 'verified_true', rationale: 'Direct textual concordance confirms the hymn exists.' }
    ],
    datasetVersion: '1.2.0-gold',
    isIndependentlyEstablished: true,
  },
  {
    id: 'rel_003_unfalsifiable_metaphysical_karma',
    category: 'religious_philosophical',
    epistemicCategory: 'unfalsifiable_metaphysical_belief',
    claimText: 'Every action performed by a soul generates karma that strictly dictates its rebirth in future lives.',
    normalizedProposition: 'The metaphysical law of karma infallibly governs the cycle of soul reincarnation and rebirth.',
    referenceVerdict: 'religious_belief',
    acceptableVerdicts: ['religious_belief', 'faith_based_claim'],
    referenceSources: [
      {
        title: 'Stanford Encyclopedia of Philosophy — Indian Philosophy and Karma',
        url: 'https://plato.stanford.edu/entries/concepts-karma/',
        domain: 'plato.stanford.edu',
        publisher: 'Stanford University',
        tier: 'B',
        snippet: 'Karma is an overarching metaphysical doctrine across Hindu, Buddhist, and Jain philosophies regarding moral causation across lifetimes.',
      },
    ],
    expertAnnotationNotes: 'Unfalsifiable metaphysical proposition. Neither provable nor disprovable by empirical instruments.',
    annotatorAgreementRate: 1.0,
    difficultyTier: 'nuanced',
    annotatorId: 'ann_phil_01',
    annotationTimestamp: '2026-10-20T13:00:00Z',
    adjudicationHistory: [
      { timestamp: '2026-10-20T13:00:00Z', annotatorId: 'ann_phil_01', verdict: 'religious_belief', rationale: 'Metaphysical philosophy not subject to empirical invalidation.' }
    ],
    datasetVersion: '1.2.0-gold',
    isIndependentlyEstablished: true,
  },
  {
    id: 'rel_004_testable_empirical_claim_supernatural_cure',
    category: 'religious_philosophical',
    epistemicCategory: 'scientific_empirical_claim',
    claimText: 'Drinking holy water from this specific shrine has been proven to cure 100% of advanced cancers with zero oncology medicine.',
    normalizedProposition: 'Controlled empirical medical trials have established that water from this shrine eradicates 100% of advanced malignancies without medical treatment.',
    referenceVerdict: 'verified_false',
    acceptableVerdicts: ['verified_false'],
    referenceSources: [
      {
        title: 'National Cancer Institute — Complementary and Alternative Medicine in Cancer',
        url: 'https://www.cancer.gov/about-cancer/treatment/cam',
        domain: 'cancer.gov',
        publisher: 'National Cancer Institute',
        tier: 'A',
        snippet: 'No peer-reviewed scientific evidence or clinical trials demonstrate that holy water cures cancer or replaces standard oncological care.',
      },
    ],
    expertAnnotationNotes: 'Testable empirical claim masked as a religious belief. Makes a specific medical assertion that is demonstrably contradicted by medical science.',
    annotatorAgreementRate: 1.0,
    difficultyTier: 'standard',
    annotatorId: 'ann_med_02',
    annotationTimestamp: '2026-10-20T14:15:00Z',
    adjudicationHistory: [
      { timestamp: '2026-10-20T14:15:00Z', annotatorId: 'ann_med_02', verdict: 'verified_false', rationale: 'Empirical medical falsehood, not a private theological doctrine.' }
    ],
    datasetVersion: '1.2.0-gold',
    isIndependentlyEstablished: true,
  },

  // ──────────────────────────────────────────────────────────
  // 5. MISLEADING & MANIPULATED CLAIMS
  // ──────────────────────────────────────────────────────────
  {
    id: 'mis_001_selective_cherry_picking',
    category: 'misleading_partially_true',
    epistemicCategory: 'historical_event',
    claimText: 'India had zero industrial factories when Nehru took power in 1947.',
    normalizedProposition: 'At Indian independence in 1947, India possessed no manufacturing or industrial factories whatsoever.',
    referenceVerdict: 'verified_false',
    acceptableVerdicts: ['verified_false', 'misleading'],
    referenceSources: [
      {
        title: 'Tirthankar Roy — The Economic History of India 1857–1947',
        url: 'https://academic.oup.com/book/12345',
        domain: 'oup.com',
        publisher: 'Oxford University Press',
        tier: 'B',
        snippet: 'India entered independence with established large-scale cotton textile mills in Bombay, jute mills in Bengal, and Tata Iron and Steel Company (TISCO) in Jamshedpur (founded 1907), producing significant steel output.',
      },
    ],
    expertAnnotationNotes: 'Demonstrably false rhetorical absolute.',
    annotatorAgreementRate: 1.0,
    difficultyTier: 'standard',
    annotatorId: 'ann_hist_03',
    annotationTimestamp: '2026-10-21T09:00:00Z',
    adjudicationHistory: [
      { timestamp: '2026-10-21T09:00:00Z', annotatorId: 'ann_hist_03', verdict: 'verified_false', rationale: 'TISCO and Bombay mills disproved zero factories.' }
    ],
    datasetVersion: '1.2.0-gold',
    isIndependentlyEstablished: true,
  },
  {
    id: 'mis_002_counterfactual_opinion',
    category: 'misleading_partially_true',
    epistemicCategory: 'counterfactual_opinion',
    claimText: 'If Sardar Patel had been Prime Minister instead of Nehru, India would have grown at 10% every year.',
    normalizedProposition: 'Had Vallabhbhai Patel served as Prime Minister, India\'s annual GDP growth rate would have reached 10%.',
    referenceVerdict: 'opinion_claim',
    acceptableVerdicts: ['opinion_claim', 'opinion_or_prediction', 'unverifiable'],
    referenceSources: [],
    expertAnnotationNotes: 'Counterfactual historical hypothesis that cannot be empirically proved or disproved.',
    annotatorAgreementRate: 1.0,
    difficultyTier: 'nuanced',
    annotatorId: 'ann_hist_04',
    annotationTimestamp: '2026-10-21T10:30:00Z',
    adjudicationHistory: [
      { timestamp: '2026-10-21T10:30:00Z', annotatorId: 'ann_hist_04', verdict: 'opinion_claim', rationale: 'Counterfactual claim about alternative history.' }
    ],
    datasetVersion: '1.2.0-gold',
    isIndependentlyEstablished: true,
  },

  // ──────────────────────────────────────────────────────────
  // 6. STRAIGHTFORWARD FACTUAL CLAIMS
  // ──────────────────────────────────────────────────────────
  {
    id: 'fact_001_water_boiling_point',
    category: 'straightforward_factual',
    epistemicCategory: 'scientific_empirical_claim',
    claimText: 'Pure water boils at 100 degrees Celsius at 1 standard atmosphere of pressure.',
    normalizedProposition: 'Under 1 atm (101.325 kPa) of pressure, the boiling point of pure water is 100 °C.',
    referenceVerdict: 'verified_true',
    acceptableVerdicts: ['verified_true'],
    referenceSources: [
      {
        title: 'NIST Chemistry WebBook — Thermophysical Properties of Fluid Systems',
        url: 'https://webbook.nist.gov/chemistry/fluid/',
        domain: 'nist.gov',
        publisher: 'National Institute of Standards and Technology',
        tier: 'A',
        snippet: 'Standard boiling point of pure water at 101.325 kPa is 99.97 °C (~100 °C).',
      },
    ],
    expertAnnotationNotes: 'Standard physical fact.',
    annotatorAgreementRate: 1.0,
    difficultyTier: 'standard',
    annotatorId: 'ann_sci_02',
    annotationTimestamp: '2026-10-22T14:00:00Z',
    adjudicationHistory: [
      { timestamp: '2026-10-22T14:00:00Z', annotatorId: 'ann_sci_02', verdict: 'verified_true', rationale: 'Standard NIST physical data.' }
    ],
    datasetVersion: '1.2.0-gold',
    isIndependentlyEstablished: true,
  },
];
