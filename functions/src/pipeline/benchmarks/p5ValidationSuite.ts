import { RichSource } from '../types';

/**
 * 🏛 P5 Independent Validation Benchmark Suite
 * 
 * Provides held-out, unseen adversarial test cases, real-world historical series,
 * retracted literature fixtures, and multimodal speech-graphic contrast cases.
 */
export const P5_HISTORICAL_GDP_SERIES = {
  india: [
    { year: 1947, value: -1.2 }, // Partition shock
    { year: 1948, value: 2.1 },
    { year: 1949, value: 2.5 },
    { year: 1950, value: 3.7 },
    { year: 1951, value: 4.0 },
    { year: 1952, value: 3.8 },
    { year: 1953, value: 4.1 },
    { year: 1954, value: 3.9 },
    { year: 1955, value: 4.2 },
    { year: 1956, value: 3.8 },
    { year: 1957, value: 3.7 },
    { year: 1958, value: 4.0 },
    { year: 1959, value: 3.9 },
    { year: 1960, value: 4.1 },
    { year: 1961, value: 3.8 },
    { year: 1962, value: 3.5 },
    { year: 1963, value: 4.2 },
    { year: 1964, value: 4.0 },
    { year: 1965, value: -3.8 }, // 1965 Bilateral war & historic drought shock
  ],
  pakistan: [
    { year: 1950, value: 2.9 },
    { year: 1951, value: 3.1 },
    { year: 1952, value: 3.0 },
    { year: 1953, value: 2.8 },
    { year: 1954, value: 3.2 },
    { year: 1955, value: 3.1 },
    { year: 1956, value: 3.3 },
    { year: 1957, value: 3.0 },
    { year: 1958, value: 7.4 }, // 1958 Martial Law bumper crop anomaly (|z| >= 2.5)
    { year: 1959, value: 3.2 },
    { year: 1960, value: 3.1 },
  ],
};

export const P5_RETRACTED_SOURCES: RichSource[] = [
  {
    title: 'MMR Vaccine and Autism Link (Wakefield et al.)',
    url: 'https://doi.org/10.1016/s0140-6736(97)11096-0',
    domain: 'thelancet.com',
    publisher: 'The Lancet',
    tier: 'B',
    snippet: 'doi:10.1016/S0140-6736(97)11096-0 asserted association between MMR immunization and intestinal bowel disease.',
  },
  {
    title: 'Surgisphere Hydroxychloroquine COVID Mortality Study',
    url: 'https://doi.org/10.1016/s0140-6736(20)31180-6',
    domain: 'thelancet.com',
    publisher: 'The Lancet',
    tier: 'B',
    snippet: 'doi:10.1016/S0140-6736(20)31180-6 claimed increased hospital mortality in COVID-19 patients treated with chloroquine.',
  },
];

export const P5_MULTIMODAL_FIXTURES = [
  {
    id: 'mm_001_deliberate_deception',
    audioTranscript: 'Our company grew revenue by a modest 3.2% this quarter.',
    ocrText: 'MASSIVE REVENUE EXPANSION: +85% QUARTERLY SURGE',
    expectedClassification: 'deliberate_deception',
    isPermissible: false,
  },
  {
    id: 'mm_002_self_correction',
    audioTranscript: 'India experienced 14.5% inflation in 1952, or rather, excuse me, 4.5% inflation.',
    ocrText: 'Annual Price Index: 4.5%',
    expectedClassification: 'speaker_self_correction',
    isPermissible: true,
  },
  {
    id: 'mm_003_contextual_contrast',
    audioTranscript: 'Look at this chart showing the projected 14% growth—our actual rate was only 3.8%.',
    ocrText: 'Projected Target: 14.0%',
    expectedClassification: 'contextual_contrast',
    isPermissible: true,
  },
  {
    id: 'mm_004_measurement_basis',
    audioTranscript: 'India averaged 4.0% real growth during the decade.',
    ocrText: 'Nominal Growth Rate: 8.5%',
    expectedClassification: 'measurement_basis_difference',
    isPermissible: true,
  },
];
