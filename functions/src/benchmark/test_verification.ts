import * as admin from "firebase-admin";

const mockFirestore = () => {
  const collectionMock = () => {
    return {
      doc: () => {
        return {
          get: async () => ({
            exists: false,
            data: () => null
          }),
          set: async () => {},
          update: async () => {},
          add: async () => {}
        };
      },
      add: async () => {}
    };
  };

  return {
    collection: collectionMock,
    doc: () => {
      return {
        get: async () => ({
          exists: false,
          data: () => null
        }),
        set: async () => {},
        update: async () => {},
        add: async () => {}
      };
    }
  } as any;
};

// Initialize Firebase Admin mock app and override firestore getter/method
admin.initializeApp({ projectId: "truthworld-mock-project" });
Object.defineProperty(admin, "firestore", {
  value: mockFirestore,
  configurable: true,
  writable: true
});

// Mock jest object for ts-node context
const jest = {
  fn: () => {
    let impl: any;
    const fnObj = Object.assign(
      async function(...args: any[]) {
        return impl(...args);
      },
      {
        mockImplementation: (i: any) => {
          impl = i;
          return fnObj;
        }
      }
    );
    return fnObj;
  }
};

import { ClaimVerificationService } from "../pipeline/services/claimVerification";
import { telemetryService } from "../pipeline/services/telemetry";
import { FilteredClaim } from "../pipeline/types";
import { VertexAI } from "@google-cloud/vertexai";

// 2. Monkeypatch VertexAI to return mock verification responses without network requests
const mockGenerateContent = jest.fn().mockImplementation(async (prompt: string) => {
  return {
    response: {
      candidates: [
        {
          content: {
            parts: [
              {
                text: JSON.stringify({
                  verifications: [
                    {
                      claimId: "claim_1",
                      claim: "India produces over 22% of the world's milk.",
                      claimType: "empirical",
                      label: "mostly_true",
                      evidenceLevel: "STRONG",
                      rating: 9,
                      confidence: 0.92,
                      freshness: "2026",
                      summary: "Verified true against official global statistics.",
                      verifiedFacts: ["Facts about milk"],
                      missingEvidence: [],
                      sourceConsensus: "consensus",
                      riskLevel: "low",
                      publicNote: "Verified",
                      recommendedAction: "none"
                    },
                    {
                      claimId: "claim_2",
                      claim: "India produces 70% of global spices.",
                      claimType: "empirical",
                      label: "false_claim",
                      evidenceLevel: "STRONG",
                      rating: 2,
                      confidence: 0.88,
                      freshness: "2026",
                      summary: "Incorrect. The real share is 40-50%.",
                      verifiedFacts: ["Real share of spices"],
                      missingEvidence: ["Official stats"],
                      sourceConsensus: "consensus",
                      riskLevel: "medium",
                      publicNote: "Exaggerated",
                      recommendedAction: "flag"
                    }
                  ]
                })
              }
            ]
          },
          groundingMetadata: {
            groundingSupports: [
              {
                segment: { text: "India produces over 22% of the world's milk." },
                groundingChunkIndices: [0]
              },
              {
                segment: { text: "India produces 70% of global spices." },
                groundingChunkIndices: [1]
              }
            ],
            groundingChunks: [
              { web: { uri: "https://example.com/milk", title: "Global Milk Production Stats" } },
              { web: { uri: "https://example.com/spices", title: "Spice Export Union" } }
            ]
          }
        }
      ]
    }
  };
});

// Mock getGenerativeModel
VertexAI.prototype.getGenerativeModel = function(config: any) {
  return {
    generateContent: mockGenerateContent
  } as any;
};

// Mock telemetry record to observe logged traces
const recordedTelemetry: any[] = [];
telemetryService.record = async (telemetry: any) => {
  recordedTelemetry.push(telemetry);
  console.log(`[MockTelemetry] Recorded: Claim ID: ${telemetry.claimId}, Outcome: ${telemetry.verificationOutcome}, Path: ${telemetry.verificationPath}, Cost: $${telemetry.costUsd}, CacheHit: ${telemetry.cacheHit}`);
};

// 3. Define test runner function
async function runTest() {
  const service = new ClaimVerificationService("mock-api-key");

  // Create duplicate claims to verify deduplication guard
  const testClaims: FilteredClaim[] = [
    {
      claimId: "claim_1",
      text: "India produces over 22% of the world's milk.",
      nature: "FACTUAL" as any,
      framing: "ASSERTIVE" as any,
      confidence: 0.9,
      importance: 0.8,
      chunkIndex: 0,
      start: 0,
      end: 10
    },
    {
      // Duplicate of claim_1
      claimId: "claim_1_dup",
      text: "India produces over 22% of the world's milk.",
      nature: "FACTUAL" as any,
      framing: "ASSERTIVE" as any,
      confidence: 0.9,
      importance: 0.8,
      chunkIndex: 0,
      start: 15,
      end: 25
    },
    {
      claimId: "claim_2",
      text: "India produces 70% of global spices.",
      nature: "FACTUAL" as any,
      framing: "ASSERTIVE" as any,
      confidence: 0.9,
      importance: 0.5,
      chunkIndex: 0,
      start: 30,
      end: 40
    }
  ];

  console.log("Starting verification execution...");
  
  const result = await service.verifyClaims(
    testClaims,
    10, // batch size
    2,  // concurrent
    "General",
    {
      groundingMode: "always",
      forcePro: false,
      minSourcesRequired: 1,
      sourceDiversityRequired: false,
      jobId: "job_test_123"
    }
  );

  console.log("\n--- VERIFICATION COMPLETED ---");
  console.log(`Input claims count: ${testClaims.length}`);
  console.log(`Returned claims count: ${result.claims.length}`);
  
  result.claims.forEach(c => {
    console.log(`- Claim [${c.claimId}] Status: ${c.status}, Method: ${c.verificationMethod}`);
    if (c.lineage) {
      console.log(`  Lineage Evidence ID: ${c.lineage.evidenceId}`);
      console.log(`  Lineage Source Graph: ${JSON.stringify(c.lineage.sourceGraph)}`);
      console.log(`  Lineage Model Version: ${c.lineage.modelVersion}`);
    }
  });

  console.log("\n--- TELEMETRY TRACES COLLECTED ---");
  console.log(`Total telemetry logged: ${recordedTelemetry.length}`);
  
  // Verify that we logged telemetry for both original and duplicate claims
  const hasOriginal = recordedTelemetry.some(t => t.claimId === "claim_1" && !t.cacheHit);
  const hasDuplicate = recordedTelemetry.some(t => t.claimId === "claim_1_dup" && t.cacheHit);
  const hasClaim2 = recordedTelemetry.some(t => t.claimId === "claim_2" && !t.cacheHit);

  if (hasOriginal && hasDuplicate && hasClaim2) {
    console.log("\n✅ SUCCESS: Deduplication and Telemetry logging verified successfully!");
  } else {
    console.error("\n❌ FAILURE: Missing telemetry records.");
    process.exit(1);
  }
}

runTest().catch(err => {
  console.error("Test execution failed:", err);
  process.exit(1);
});
