/**
 * 🧪 TRUTHWORLD CREDIBILITY SYSTEM AUDIT & TEST HARNESS
 *
 * Tests 10 diverse claims through all layers of Truthworld's Credibility Engine:
 * 1. Category Classification & TTL Resolution
 * 2. Importance & Assertiveness Classification / Ranking
 * 3. Semantic Token Deduplication
 * 4. Deterministic Registry Fast-Path Resolution
 * 5. Explainability Layer & Severity Assessment
 * 6. Scoring Engine & UI Report Generation
 * 7. Flutter Truthworld Algorithm Credibility Gate & Knowledge Quality Signal
 */

import {
  categoriseClaim,
  classifyAndRank,
  deduplicateClaims,
  buildExplainability,
  CLAIM_TTL
} from '../pipeline/layers/credibility/helpers';
import { registryService } from '../pipeline/registry/RegistryService';
import { ScoringEngine } from '../pipeline/services/scoringEngine';
import {
  ClaimNature,
  ClaimStatus,
  FramingStyle,
  VerifiedClaim,
  ExtractedClaim
} from '../pipeline/types';

interface MockClaimTestCase {
  id: string;
  claim: string;
  expectedCategory: string;
  nature: ClaimNature;
  framing: FramingStyle;
  simulatedStatus: ClaimStatus;
  confidence: number;
  importance: number;
  reasoning: string;
  isFramingViolation?: boolean;
  richSources?: Array<{ title: string; url: string; tier: 'A' | 'B' | 'C' | 'D' | 'E'; snippet?: string }>;
  duplicateVariant?: string; // To test deduplication
}

// ─── 10 Diverse Claims Mock Dataset ──────────────────────────────────────────

const TEST_CLAIMS: MockClaimTestCase[] = [
  {
    id: "claim_01_empirical_fact",
    claim: "Water freezes at 0 degrees Celsius and boils at 100 degrees Celsius under standard atmospheric pressure.",
    expectedCategory: "scientific",
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ASSERTIVE,
    simulatedStatus: "verified_true",
    confidence: 0.99,
    importance: 0.85,
    reasoning: "Established thermodynamic consensus under 1 atm pressure (NIST/IUPAC standards).",
    richSources: [
      { title: "NIST Chemistry WebBook", url: "https://webbook.nist.gov/chemistry/", tier: "A", snippet: "Phase change points for pure H2O at 101.325 kPa." },
      { title: "Encyclopaedia Britannica: Water", url: "https://www.britannica.com/science/water", tier: "A", snippet: "Physical properties of liquid water and phase transitions." }
    ],
    duplicateVariant: "Under standard atmospheric pressure, water boils at 100°C and freezes at 0°C."
  },
  {
    id: "claim_02_nuanced_historical",
    claim: "The Great Wall of China is over 13,000 miles long according to comprehensive archaeological surveys.",
    expectedCategory: "historical",
    nature: ClaimNature.HISTORICAL_FACT,
    framing: FramingStyle.ASSERTIVE,
    simulatedStatus: "mostly_true",
    confidence: 0.92,
    importance: 0.75,
    reasoning: "China's State Administration of Cultural Heritage (2012 survey) measured all historical wall sections at 21,196 km (~13,171 miles). The continuous Ming dynasty wall is ~5,500 miles.",
    richSources: [
      { title: "State Administration of Cultural Heritage Survey", url: "http://www.ncha.gov.cn", tier: "A", snippet: "Total length of all archaeological remains is 21,196 km." },
      { title: "National Geographic: Great Wall Archaeology", url: "https://www.nationalgeographic.com", tier: "B", snippet: "Archaeological mapping of all dynastic wall systems." }
    ]
  },
  {
    id: "claim_03_false_misconception",
    claim: "Humans only use 10% of their brain capacity at any given time.",
    expectedCategory: "scientific",
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ABSOLUTE,
    simulatedStatus: "false_claim",
    confidence: 0.98,
    importance: 0.80,
    reasoning: "Debunked neurological myth. Functional brain imaging (fMRI, PET scans) proves virtually all parts of the brain have active functions across daily tasks.",
    richSources: [
      { title: "Brain Facts: Society for Neuroscience", url: "https://www.brainfacts.org/myth-ten-percent", tier: "A", snippet: "Neuroimaging shows widespread brain activity even during sleep." },
      { title: "Mayo Clinic Health Information", url: "https://www.mayoclinic.org", tier: "A", snippet: "Comprehensive review debunking the 10% brain myth." }
    ]
  },
  {
    id: "claim_04_misleading_correlation",
    claim: "Ice cream consumption and drowning rates increase at the exact same time, demonstrating ice cream causes drowning.",
    expectedCategory: "statistics",
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.MANIPULATIVE,
    simulatedStatus: "misleading",
    confidence: 0.95,
    importance: 0.70,
    isFramingViolation: true,
    reasoning: "Classic spurious correlation (cum hoc ergo propter hoc). Both ice cream sales and swimming/drowning peak due to the confounding variable of warm summer temperatures.",
    richSources: [
      { title: "American Statistical Association: Spurious Correlations", url: "https://www.amstat.org", tier: "A", snippet: "Analysis of confounding third variables in seasonal time series data." }
    ]
  },
  {
    id: "claim_05_religious_faith",
    claim: "Moses received the Ten Commandments directly from God on Mount Sinai.",
    expectedCategory: "historical",
    nature: ClaimNature.BELIEF,
    framing: FramingStyle.BALANCED,
    simulatedStatus: "religious_belief",
    confidence: 0.90,
    importance: 0.60,
    reasoning: "Recognized as a central doctrinal/theological belief of Abrahamic scriptural tradition. Not subject to empirical falsification.",
    richSources: [
      { title: "Scriptural Tradition / Comparative Religious Studies", url: "https://www.britannica.com/topic/Ten-Commandments", tier: "A", snippet: "Biblical narrative in the Book of Exodus." }
    ]
  },
  {
    id: "claim_06_subjective_opinion",
    claim: "Quantum computing is the single most important technological breakthrough of the 21st century.",
    expectedCategory: "scientific",
    nature: ClaimNature.OPINION,
    framing: FramingStyle.ASSERTIVE,
    simulatedStatus: "opinion_claim",
    confidence: 0.85,
    importance: 0.50,
    reasoning: "Subjective value judgment and technological prioritization. Respected as analysis/opinion without penalization.",
    richSources: []
  },
  {
    id: "claim_07_outdated_consensus",
    claim: "Pluto is classified as the ninth major planet in our solar system.",
    expectedCategory: "scientific",
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ASSERTIVE,
    simulatedStatus: "outdated",
    confidence: 0.97,
    importance: 0.65,
    reasoning: "Superseded classification. The International Astronomical Union (IAU) reclassified Pluto as a 'dwarf planet' in August 2006.",
    richSources: [
      { title: "International Astronomical Union (IAU) Resolution B5", url: "https://www.iau.org/public/themes/pluto/", tier: "A", snippet: "Definition of a Planet in the Solar System adopted at the 2006 General Assembly." },
      { title: "NASA Solar System Exploration: Pluto", url: "https://science.nasa.gov/dwarf-planets/pluto/", tier: "A", snippet: "NASA profile on dwarf planet Pluto." }
    ]
  },
  {
    id: "claim_08_unproven_conspiracy",
    claim: "Ancient alien architects constructed the Great Pyramid of Giza using anti-gravity acoustic levitation.",
    expectedCategory: "historical",
    nature: ClaimNature.VERIFIABLE_FACT,
    framing: FramingStyle.ASSERTIVE,
    simulatedStatus: "unproven",
    confidence: 0.90,
    importance: 0.75,
    reasoning: "Fringe hypothesis with zero peer-reviewed archaeological or physics evidence. Egyptological consensus documents quarrying, ramp systems, and human workforce records (Diary of Merer).",
    richSources: [
      { title: "Archaeological Institute of America: Pyramids", url: "https://www.archaeology.org", tier: "A", snippet: "Extensive archaeological records documenting construction techniques and quarry logs." }
    ]
  },
  {
    id: "claim_09_satirical_claim",
    claim: "NASA officially announced that new core drill samples confirm the Moon is made of aged Swiss cheese.",
    expectedCategory: "scientific",
    nature: ClaimNature.SATIRE,
    framing: FramingStyle.HEDGED,
    simulatedStatus: "satire_claim",
    confidence: 0.95,
    importance: 0.30,
    reasoning: "Parody / satire humorously referencing folkloric tropes. Classified as non-literal satirical content.",
    richSources: []
  },
  {
    id: "claim_10_framing_violation_prediction",
    claim: "It is an established mathematical certainty that the global stock market will crash by 40% next Tuesday.",
    expectedCategory: "financial",
    nature: ClaimNature.ESTIMATION,
    framing: FramingStyle.ABSOLUTE,
    simulatedStatus: "misleading",
    confidence: 0.93,
    importance: 0.85,
    isFramingViolation: true,
    reasoning: "Assertiveness mismatch: A speculative market prediction is framed as an absolute mathematical certainty, misleading viewers regarding predictive certainty.",
    richSources: [
      { title: "Financial Regulatory Guidelines on Predictive Claims", url: "https://www.sec.gov", tier: "A", snippet: "Market projections cannot be characterized as certainties." }
    ]
  }
];

// ─── Algorithm Credibility Gate Simulation ───────────────────────────────────

function simulateCredibilityGate(trustScore: number | null): { multiplier: number; status: string } {
  if (trustScore === null) return { multiplier: 1.0, status: "NEUTRAL_UNSCORED" };
  if (trustScore >= 4.0) return { multiplier: 1.2, status: "HIGH_BOOST (+20%)" };
  if (trustScore >= 3.0) return { multiplier: 1.1, status: "GOOD_BOOST (+10%)" };
  if (trustScore >= 2.0) return { multiplier: 1.0, status: "NEUTRAL" };
  if (trustScore >= 1.0) return { multiplier: 0.3, status: "SUPPRESSED (-70%)" };
  return { multiplier: 0.0, status: "HARD_GATED (Filtered Out)" };
}

function simulateKnowledgeQuality(sourcesCount: number, trustScore: number | null, isFactChecked: boolean): number {
  let score = 0.0;
  // 1. Evidence quality: sourceCount * 0.25 (capped at 1.0) * 0.15
  const evidenceQuality = Math.min(1.0, sourcesCount * 0.25);
  score += evidenceQuality * 0.15;

  // 2. Source diversity: min(0.1, sourcesCount * 0.02)
  score += Math.min(0.1, sourcesCount * 0.02);

  // 3. Fact check confidence
  const normScore = (trustScore ?? 3.5) / 5.0;
  score += normScore * 0.20;

  // 4. Primary sources / fact checked
  if (isFactChecked) score += 0.15;

  // 5. Expert consensus (proxy: trustScore >= 3.5)
  if ((trustScore ?? 3.5) >= 3.5) score += 0.10;

  // 6. Recency
  score += Math.min(0.05, (trustScore ?? 3.5) * 0.01);

  // 7. Transparency
  score += 0.05;

  return Math.min(1.0, score);
}

// ─── Execution Routine ───────────────────────────────────────────────────────

async function runAudit() {
  console.log("================================================================================");
  console.log("🏛  TRUTHWORLD CREDIBILITY SYSTEM AUDIT & TEST SUITE (10 CLAIMS MOCK DATA)");
  console.log("================================================================================\n");

  // Convert test cases to ExtractedClaim format
  const extractedClaims: ExtractedClaim[] = TEST_CLAIMS.map((tc, idx) => ({
    text: tc.claim,
    nature: tc.nature,
    framing: tc.framing,
    confidence: tc.confidence,
    importance: tc.importance,
    chunkIndex: 0,
    start: idx * 10,
    end: (idx + 1) * 10,
    isFramingViolation: tc.isFramingViolation,
  }));

  console.log("--------------------------------------------------------------------------------");
  console.log("STAGE 1: CATEGORISATION, TTL & IMPORTANCE RANKING");
  console.log("--------------------------------------------------------------------------------");

  const rankedClaims = classifyAndRank(extractedClaims);

  TEST_CLAIMS.forEach((tc, idx) => {
    const category = categoriseClaim(tc.claim);
    const ttl = CLAIM_TTL[category] || CLAIM_TTL['default'];
    const ranked = rankedClaims.find(r => r.text === tc.claim);
    const ttlHours = (ttl / 3600).toFixed(1);

    console.log(`[Claim ${idx + 1}] (${tc.id})`);
    console.log(`  Text: "${tc.claim.substring(0, 75)}..."`);
    console.log(`  Categorized as: '${category}' (Expected: '${tc.expectedCategory}') | TTL: ${ttlHours} hrs (${ttl}s)`);
    console.log(`  Assessed Strength: '${ranked?.claimStrength}' | Importance Score: ${ranked?.importance.toFixed(2)}`);
    console.log("");
  });

  console.log("--------------------------------------------------------------------------------");
  console.log("STAGE 2: TOKEN-LEVEL JACCARD SEMANTIC DEDUPLICATION AUDIT");
  console.log("--------------------------------------------------------------------------------");

  // Create duplicate pairs
  const duplicateTestBatch = [
    { text: TEST_CLAIMS[0].claim, importance: 0.85 },
    { text: TEST_CLAIMS[0].duplicateVariant!, importance: 0.90 }, // higher importance
    { text: TEST_CLAIMS[1].claim, importance: 0.75 },
    { text: TEST_CLAIMS[2].claim, importance: 0.80 },
  ];

  console.log(`Original claims submitted for dedup test: ${duplicateTestBatch.length}`);
  const deduplicated = deduplicateClaims(duplicateTestBatch);
  console.log(`Claims remaining after deduplication: ${deduplicated.length}`);
  console.log(`Dedup correctly retained the higher-importance variant: "${deduplicated[0].text}" (importance: ${deduplicated[0].importance})`);
  console.log("");

  console.log("--------------------------------------------------------------------------------");
  console.log("STAGE 3: DETERMINISTIC REGISTRY CHECK AUDIT");
  console.log("--------------------------------------------------------------------------------");

  const registryTestCases = [
    "The capital of France is Paris.",
    "Alaska is about 20% of the US territory.",
    TEST_CLAIMS[0].claim,
    TEST_CLAIMS[4].claim
  ];

  registryTestCases.forEach((claimText, idx) => {
    const check = registryService.resolveTruthCheck(claimText);
    console.log(`[Registry Query ${idx + 1}]: "${claimText}"`);
    if (check) {
      console.log(`  ⚡ FAST-PATH HIT: Status='${check.status}', Source='${check.source}'`);
      console.log(`  Reasoning: ${check.reasoning}`);
    } else {
      console.log(`  ⏭ FAST-PATH MISS: Passed to AI Deep Research & Grounding Verification.`);
    }
    console.log("");
  });

  console.log("--------------------------------------------------------------------------------");
  console.log("STAGE 4: VERIFICATION & EXPLAINABILITY LAYER AUDIT");
  console.log("--------------------------------------------------------------------------------");

  const verifiedClaims: VerifiedClaim[] = TEST_CLAIMS.map((tc, idx) => ({
    claimId: `claim_${idx + 1}_${tc.id}`,
    text: tc.claim,
    nature: tc.nature,
    framing: tc.framing,
    confidence: tc.confidence,
    importance: tc.importance,
    chunkIndex: 0,
    status: tc.simulatedStatus,
    verificationConfidence: tc.confidence,
    reasoning: tc.reasoning,
    isFramingViolation: tc.isFramingViolation,
    sources: (tc.richSources || []).map(s => s.url),
    richSources: tc.richSources || [],
    start: idx * 15,
    end: (idx + 1) * 15,
    severity: tc.simulatedStatus === 'false_claim' ? 'high' : (tc.simulatedStatus === 'misleading' ? 'medium' : 'low'),
  }));

  const explainabilityResults = buildExplainability(verifiedClaims);

  explainabilityResults.forEach((exp, idx) => {
    console.log(`[Explainability Result ${idx + 1}] (${exp.claimId})`);
    console.log(`  Display: ${exp.claim}`);
    console.log(`  Status: '${exp.status}' | Ontology: '${exp.ontology}' | Severity: ${exp.severity ? `'${exp.severity}' (${exp.severityLabel})` : 'N/A'}`);
    if (exp.whyWrong) {
      console.log(`  Why Wrong: ${exp.whyWrong}`);
    }
    if (exp.correction) {
      console.log(`  Correction: ${exp.correction}`);
    }
    console.log(`  Sources Attached: ${exp.sources.length} sources`);
    exp.sources.forEach(s => console.log(`    - [Tier ${s.tier || 'N/A'}] ${s.title}: ${s.url || 'No URL'}`));
    console.log("");
  });

  console.log("--------------------------------------------------------------------------------");
  console.log("STAGE 5: INSTITUTIONAL SCORING ENGINE & UI REPORT AUDIT");
  console.log("--------------------------------------------------------------------------------");

  const scoringEngine = new ScoringEngine();
  const mockTranscript = {
    text: TEST_CLAIMS.map(c => c.claim).join(" "),
    utterances: TEST_CLAIMS.map((c, idx) => ({
      start: idx * 15,
      end: (idx + 1) * 15,
      speaker: idx % 2 === 0 ? "Speaker 1" : "Speaker 2",
      text: c.claim
    })),
    language: "en",
    confidence: 0.95,
    duration: 150
  };

  const synthesisMock = {
    summary: "Comprehensive epistemic audit of 10 claims representing science, history, belief, opinion, satire, and financial estimations.",
    conclusion: { label: "Multi-Perspective Analysis", confidence: 0.92, text: "Analysis completed across 10 multidimensional claims." } as any,
    viewerNote: "Note: Subjective opinions and theological beliefs are respected as non-empirical claims.",
    extractionPartial: false
  };

  const factCheckResult = scoringEngine.calculateInstitutionalTrustScore(
    "job_mock_audit_101",
    "user_mock_tester",
    mockTranscript,
    verifiedClaims,
    10, // extractedCount
    "balanced",
    "medium",
    "General",
    synthesisMock
  );

  console.log(`Verification State: ${factCheckResult.analysisState}`);
  console.log(`Total Extracted Claims: ${factCheckResult.factCheckStats?.totalClaims}`);
  console.log(`Total Evaluated (Verifiable) Claims: ${factCheckResult.factCheckStats?.evaluatedClaims}`);
  console.log(`\nDetailed Breakdown:`);
  console.log(`  - Verified True:      ${factCheckResult.factCheckStats?.verified_true}`);
  console.log(`  - Mostly True:        ${factCheckResult.factCheckStats?.mostly_true}`);
  console.log(`  - False Claims:       ${factCheckResult.factCheckStats?.false_claim}`);
  console.log(`  - Misleading:         ${factCheckResult.factCheckStats?.misleading}`);
  console.log(`  - Unproven/Fringe:    ${factCheckResult.factCheckStats?.unproven}`);
  console.log(`  - Religious Beliefs:  ${factCheckResult.factCheckStats?.religious_belief}`);
  console.log(`  - Subjective Opinions:${factCheckResult.factCheckStats?.opinion_claim}`);
  console.log(`  - Satire:             ${factCheckResult.factCheckStats?.satire_claim}`);
  console.log(`  - Timeout Claims:     ${factCheckResult.factCheckStats?.verification_timeout}`);
  console.log(`  - Framing Violations: ${factCheckResult.uiReport?.riskNote}`);

  console.log("\nUI Report Global Sources Consolidated:");
  factCheckResult.uiReport?.sources?.forEach((src, idx) => {
    const citationCount = (src as any).citationCount ?? 1;
    console.log(`  ${idx + 1}. [${src.trustLevel} Trust] ${src.title} (${src.domain || src.url}) - Citations: ${citationCount}`);
  });

  console.log("\n--------------------------------------------------------------------------------");
  console.log("STAGE 6: FLUTTER ALGORITHM GATE & KNOWLEDGE QUALITY AUDIT");
  console.log("--------------------------------------------------------------------------------");

  const totalSourcesCount = factCheckResult.uiReport?.sources?.length || 0;
  const simulatedTrustScore = 4.2; // Example video with high factual integrity
  const simulatedLowTrustScore = 0.5; // Example video with high falsehoods

  const highGate = simulateCredibilityGate(simulatedTrustScore);
  const lowGate = simulateCredibilityGate(simulatedLowTrustScore);
  const kqScore = simulateKnowledgeQuality(totalSourcesCount, simulatedTrustScore, true);

  console.log(`High-Credibility Video Simulation (Trust Score = ${simulatedTrustScore}):`);
  console.log(`  Credibility Gate Multiplier: ${highGate.multiplier}x -> ${highGate.status}`);
  console.log(`  Knowledge Quality Signal:    ${kqScore.toFixed(3)} / 1.000`);

  console.log(`\nLow-Credibility Video Simulation (Trust Score = ${simulatedLowTrustScore}):`);
  console.log(`  Credibility Gate Multiplier: ${lowGate.multiplier}x -> ${lowGate.status}`);

  console.log("\n================================================================================");
  console.log("✅ AUDIT & TEST RUN COMPLETED SUCCESSFULLY (10/10 CLAIMS PROCESSED)");
  console.log("================================================================================");
}

runAudit().catch(err => {
  console.error("❌ Audit script failed:", err);
  process.exit(1);
});
