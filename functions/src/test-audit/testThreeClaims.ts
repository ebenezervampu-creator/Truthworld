import {
  categoriseClaim,
  buildExplainability,
  CLAIM_TTL
} from '../pipeline/layers/credibility/helpers';
import { ScoringEngine } from '../pipeline/services/scoringEngine';
import {
  ClaimNature,
  ClaimStatus,
  FramingStyle,
  VerifiedClaim
} from '../pipeline/types';

interface ClaimCase {
  id: string;
  claim: string;
  nature: ClaimNature;
  framing: FramingStyle;
  status: ClaimStatus;
  confidence: number;
  importance: number;
  reasoning: string;
  richSources: Array<{ title: string; url: string; tier: 'A' | 'B' | 'C' | 'D' | 'E'; snippet?: string }>;
}

const THREE_CLAIMS: ClaimCase[] = [
  {
    id: "claim_01_jesus_walked_on_water",
    claim: "Jesus walked on water.",
    nature: ClaimNature.BELIEF,
    framing: FramingStyle.BALANCED,
    status: "religious_belief",
    confidence: 0.95,
    importance: 0.70,
    reasoning: "Classified as a core doctrinal/theological belief of Christian scriptural tradition (Matthew 14:22-33). Under Truthworld Path 1 Rational Neutrality rules, theological miracles are respected as faith claims and are not subjected to empirical falsification or creator penalties.",
    richSources: [
      {
        title: "Encyclopaedia Britannica: Jesus & Christian Scriptural Traditions",
        url: "https://www.britannica.com/biography/Jesus",
        tier: "A",
        snippet: "Gospel accounts of Jesus of Nazareth and miraculous narratives."
      },
      {
        title: "Oxford Classical Dictionary: Christianity & Gospel Narratives",
        url: "https://oxfordre.com/classics",
        tier: "A",
        snippet: "Analysis of early Christian scriptural traditions."
      }
    ]
  },
  {
    id: "claim_02_rama_sethu_has_proofs",
    claim: "Rama Sethu has proofs (archaeological, geological, and historical evidence).",
    nature: ClaimNature.HISTORICAL_FACT,
    framing: FramingStyle.ASSERTIVE,
    status: "needs_context",
    confidence: 0.90,
    importance: 0.80,
    reasoning: "Needs Context: The physical existence of the 48 km limestone shoal chain between India and Sri Lanka is a verified geological reality (NASA imagery, Geological Survey of India). However, whether it is an ancient human-engineered bridge or a natural tombolo/sedimentary formation is a contested interpretation between geological consensus and cultural/archaeological research.",
    richSources: [
      {
        title: "Geological Survey of India (GSI) Special Publication on Adam's Bridge / Ram Setu",
        url: "https://www.gsi.gov.in",
        tier: "A",
        snippet: "Geological surveys of coastal shoals, coral reef formations, and marine sedimentation."
      },
      {
        title: "NASA Earth Observatory: Adam's Bridge Shoals",
        url: "https://earthobservatory.nasa.gov",
        tier: "A",
        snippet: "Satellite imagery documenting the chain of limestone shoals between Rameswaram and Mannar."
      },
      {
        title: "Indian Council of Historical Research (ICHR) Marine Studies",
        url: "https://ichr.ac.in",
        tier: "A",
        snippet: "Underwater archaeological exploration and scriptural cross-referencing."
      }
    ]
  },
  {
    id: "claim_03_krishna_real_character",
    claim: "Krishna is a real historical character.",
    nature: ClaimNature.HISTORICAL_FACT,
    framing: FramingStyle.ASSERTIVE,
    status: "mostly_true",
    confidence: 0.88,
    importance: 0.85,
    reasoning: "Mostly True / Historical Tradition: Academic historians and marine archaeologists (ASI, Dr. S.R. Rao at Dwarka, Prof. B.B. Lal) document strong historical, epigraphical (Heliodorus Pillar c. 113 BCE, Agathocles coins), and archaeological evidence for a historical chieftain/philosopher-teacher of the Vrishni/Yadava clan around whom Mahabharata traditions and theological veneration developed.",
    richSources: [
      {
        title: "Archaeological Survey of India (ASI): Marine Archaeology of Dwarka",
        url: "https://asi.nic.in",
        tier: "A",
        snippet: "Underwater archaeological excavations revealing submerged fortified city structures off Gujarat coast."
      },
      {
        title: "Heliodorus Pillar Inscription (Besnagar, 2nd Century BCE)",
        url: "https://www.britannica.com/topic/Vasudeva",
        tier: "A",
        snippet: "Epigraphical record identifying Vasudeva-Krishna as Devadeva (God of Gods)."
      },
      {
        title: "Oxford Centre for Hindu Studies: Historicity & Tradition of Krishna",
        url: "https://ochs.org.uk",
        tier: "A",
        snippet: "Scholarly evaluation of text-historical and archaeological layers of Krishna."
      }
    ]
  }
];

async function runThreeClaimsTest() {
  console.log("================================================================================");
  console.log("🧪 TRUTHWORLD CREDIBILITY AUDIT: 3 CUSTOM CLAIMS TEST");
  console.log("================================================================================\n");

  console.log("--------------------------------------------------------------------------------");
  console.log("1. CATEGORISATION & TTL MAPPING");
  console.log("--------------------------------------------------------------------------------");
  THREE_CLAIMS.forEach((c, idx) => {
    const category = categoriseClaim(c.claim);
    const ttl = CLAIM_TTL[category] || CLAIM_TTL['default'];
    console.log(`[Claim ${idx + 1}] "${c.claim}"`);
    console.log(`  Category: '${category}' | TTL: ${(ttl / (24 * 3600)).toFixed(0)} days (${ttl}s)`);
    console.log(`  Epistemic Nature: '${c.nature}' | Framing: '${c.framing}'\n`);
  });

  console.log("--------------------------------------------------------------------------------");
  console.log("2. EXPLAINABILITY & CLINICAL LABEL MAPPING");
  console.log("--------------------------------------------------------------------------------");
  const verified: VerifiedClaim[] = THREE_CLAIMS.map((c, idx) => ({
    claimId: c.id,
    text: c.claim,
    nature: c.nature,
    framing: c.framing,
    confidence: c.confidence,
    importance: c.importance,
    chunkIndex: 0,
    status: c.status,
    verificationConfidence: c.confidence,
    reasoning: c.reasoning,
    sources: c.richSources.map(s => s.url),
    richSources: c.richSources,
    start: idx * 10,
    end: (idx + 1) * 10,
    severity: 'low',
  }));

  const explainability = buildExplainability(verified);
  explainability.forEach((exp, idx) => {
    console.log(`[Explainability Item ${idx + 1}]`);
    console.log(`  Display: ${exp.claim}`);
    console.log(`  Status: '${exp.status}' | Ontology: '${exp.ontology}'`);
    console.log(`  Reasoning & Synthesis: ${exp.whyWrong || verified[idx].reasoning}`);
    console.log(`  Citations Attached (${exp.sources.length}):`);
    exp.sources.forEach(s => {
      console.log(`    - [Tier ${s.tier || 'A'}] ${s.title}`);
      console.log(`      URL: ${s.url}`);
    });
    console.log("");
  });

  console.log("--------------------------------------------------------------------------------");
  console.log("3. INSTITUTIONAL SCORING ENGINE AGGREGATION");
  console.log("--------------------------------------------------------------------------------");
  const scoringEngine = new ScoringEngine();
  const transcriptMock = {
    text: THREE_CLAIMS.map(c => c.claim).join(" "),
    utterances: THREE_CLAIMS.map((c, idx) => ({
      start: idx * 10,
      end: (idx + 1) * 10,
      text: c.claim
    })),
    language: "en",
    confidence: 0.95,
    duration: 30
  };

  const synthesisMock = {
    summary: "Epistemic evaluation of theological, archaeological, and historical claims concerning Jesus, Ram Setu, and Krishna.",
    conclusion: { label: "Multi-Perspective Analysis", confidence: 0.92, text: "Analysis completed across religious and historical domains." } as any,
    viewerNote: "Note: Scriptural faith is distinguished from empirical/archaeological claims without penalizing subjective belief.",
    extractionPartial: false
  };

  const result = scoringEngine.calculateInstitutionalTrustScore(
    "job_user_custom_claims_102",
    "user_tester",
    transcriptMock,
    verified,
    3,
    "balanced",
    "medium",
    "General",
    synthesisMock
  );

  console.log(`Verification State: ${result.analysisState}`);
  console.log(`Extracted Claims:   ${result.factCheckStats?.extractedClaims}`);
  console.log(`Evaluated Claims:   ${result.factCheckStats?.evaluatedClaims}`);
  console.log(`\nBucket Breakdown:`);
  console.log(`  - Mostly True (Historical Evidence): ${result.factCheckStats?.mostly_true}`);
  console.log(`  - Needs Context (Contested Science): ${result.factCheckStats?.misleading}`);
  console.log(`  - Religious Belief (Faith Respected):${result.factCheckStats?.religious_belief}`);
  console.log(`  - False Claims:                      ${result.factCheckStats?.false_claim}`);
  console.log(`  - Framing Risk:                      ${result.uiReport?.riskNote}`);

  console.log("\nConsolidated Global Sources in Truth Report:");
  result.uiReport?.sources?.forEach((src, idx) => {
    console.log(`  ${idx + 1}. [${src.trustLevel} Trust] ${src.title}`);
  });

  console.log("\n================================================================================");
  console.log("✅ 3 CLAIMS TEST COMPLETE");
  console.log("================================================================================");
}

runThreeClaimsTest().catch(console.error);
