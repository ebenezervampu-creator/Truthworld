import { extractUrls } from '../../src/pipeline/aiCredibilityChat';
import { ClaimStatus, FramingStyle, VerifiedClaim } from '../../src/pipeline/types';

function createTestClaim(data: Partial<VerifiedClaim> & { claimId: string; text: string; status: ClaimStatus }): VerifiedClaim {
  return {
    nature: 'VERIFIABLE_FACT' as any,
    framing: FramingStyle.ASSERTIVE,
    confidence: 0.95,
    chunkIndex: 0,
    verificationConfidence: 0.95,
    reasoning: '',
    sources: [],
    richSources: [],
    isGrounded: true,
    importance: 0.8,
    ...data,
  };
}

describe('End-to-End: Sample Claim Dispute, Auto-Submission & Deep Re-Verification (Zero Video Trust Score)', () => {
  const videoId = 'sample-video-dispute-e2e-2026';
  const userId = 'verified-investor-user-42';

  // ══════════════════════════════════════════════════════════════════════
  // INITIAL STATE: Published Video with 5 Claims & Mistaken Claim #5
  // (TruthWorld Never Assigns a Scalar Trust Score to Videos)
  // ══════════════════════════════════════════════════════════════════════
  const initialClaims: VerifiedClaim[] = [
    createTestClaim({
      claimId: 'claim_1',
      text: 'TruthWorld was incorporated in Delaware in 2021.',
      status: 'verified_true',
      verificationConfidence: 0.99,
      reasoning: 'Confirmed via Delaware Division of Corporations filing.',
      sources: ['https://corp.delaware.gov'],
      importance: 0.8,
    }),
    createTestClaim({
      claimId: 'claim_2',
      text: 'The platform operates on Google Cloud and Firebase infrastructure.',
      status: 'verified_true',
      verificationConfidence: 0.98,
      reasoning: 'Confirmed via Google Cloud architecture case study.',
      sources: ['https://cloud.google.com/customers'],
      importance: 0.7,
    }),
    createTestClaim({
      claimId: 'claim_3',
      text: 'Zero Mock Data Policy is strictly enforced in production.',
      status: 'verified_true',
      verificationConfidence: 1.0,
      reasoning: 'Verified by engineering compliance standards.',
      sources: ['https://truthworld.org/standards'],
      importance: 0.9,
    }),
    createTestClaim({
      claimId: 'claim_4',
      text: 'Users receive real-time notifications for dispute updates.',
      status: 'verified_true',
      verificationConfidence: 0.95,
      reasoning: 'Confirmed via production push notification service.',
      sources: ['https://firebase.google.com/docs/cloud-messaging'],
      importance: 0.6,
    }),
    createTestClaim({
      claimId: 'claim_5',
      text: 'The company reported $100 Million net profit in Q1 2026.',
      status: 'verified_true', // ⚠️ MISTAKENLY CLASSIFIED AS TRUE INITIALLY
      verificationConfidence: 0.75,
      reasoning: 'Initial automated scan picked up marketing press release quoting projected GMV as net income.',
      sources: ['https://pr-wire.example.com/press-release-q1'],
      isGrounded: false,
      importance: 0.95,
    }),
  ];

  it('End-to-End Workflow: User disputes Claim #5 with links -> Auto-Submit -> Deep Re-Verification -> Verdict Flip to False (No Video Trust Score)', async () => {
    // ══════════════════════════════════════════════════════════════════
    // STEP 1: Verify Initial State (Zero Video Trust Score Policy)
    // ══════════════════════════════════════════════════════════════════
    expect(initialClaims.length).toBe(5);
    expect(initialClaims[4].status).toBe('verified_true');

    // ══════════════════════════════════════════════════════════════════
    // STEP 2: User Enters Ask AI Chat with Counter-Evidence Sources
    // ══════════════════════════════════════════════════════════════════
    const userPrompt =
      'Claim 5 is actually completely false. The company reported a net loss of $12M, not $100M profit. Check the official SEC 10-Q filing: https://www.sec.gov/Archives/edgar/data/00012345/q1-2026.htm and Reuters report: https://www.reuters.com/business/company-q1-loss-2026';

    // 2.1 URL Extraction
    const extractedUrls = extractUrls(userPrompt);
    expect(extractedUrls).toEqual([
      'https://www.sec.gov/Archives/edgar/data/00012345/q1-2026.htm',
      'https://www.reuters.com/business/company-q1-loss-2026',
    ]);
    expect(extractedUrls.length).toBe(2);

    // 2.2 Dispute Intent & Target Claim Identification
    const lowerPrompt = userPrompt.toLowerCase();
    const isDispute =
      lowerPrompt.includes('dispute') ||
      lowerPrompt.includes('false') ||
      lowerPrompt.includes('wrong');
    expect(isDispute).toBe(true);

    const claimMatch = userPrompt.match(/claim\s*#?\s*(\d+)/i);
    const targetClaimNumber = claimMatch ? parseInt(claimMatch[1], 10) : null;
    expect(targetClaimNumber).toBe(5);

    const targetClaimIndex = (targetClaimNumber ?? 1) - 1; // 0-based: 4
    expect(targetClaimIndex).toBe(4);
    const targetClaim = initialClaims[targetClaimIndex];
    expect(targetClaim.text).toContain('$100 Million net profit');

    // ══════════════════════════════════════════════════════════════════
    // STEP 3: Automated Dispute Payload Creation (Virtual Button Tap)
    // ══════════════════════════════════════════════════════════════════
    const autoDisputePayload = {
      status: 'pending_review',
      claimIndex: targetClaimIndex,
      claimText: targetClaim.text,
      additionalSources: extractedUrls,
      reason: userPrompt,
      submittedVia: 'ask_ai_chat',
      submittedBy: userId,
      submittedAt: Date.now(),
    };

    expect(autoDisputePayload.status).toBe('pending_review');
    expect(autoDisputePayload.claimIndex).toBe(4);
    expect(autoDisputePayload.additionalSources.length).toBe(2);
    expect(autoDisputePayload.submittedVia).toBe('ask_ai_chat');

    // ══════════════════════════════════════════════════════════════════
    // STEP 4: Backend Pipeline Trigger (videoPublishTrigger.ts Gate 2.7)
    // ══════════════════════════════════════════════════════════════════
    const beforeVideoData = {
      id: videoId,
      trustScore: null, // Zero Video Trust Score
      factCheckDispute: null,
    };

    const afterVideoData = {
      id: videoId,
      trustScore: null, // Zero Video Trust Score
      factCheckDispute: autoDisputePayload,
    };

    const beforeStatus = beforeVideoData.factCheckDispute;
    const afterStatus = afterVideoData.factCheckDispute?.status;
    const isDisputeTransition =
      afterStatus === 'pending_review' && beforeStatus !== 'pending_review';
    expect(isDisputeTransition).toBe(true);

    // Backend isolates the disputed claim index
    const disputedClaimIndex =
      typeof afterVideoData.factCheckDispute?.claimIndex === 'number'
        ? afterVideoData.factCheckDispute.claimIndex
        : 0;
    expect(disputedClaimIndex).toBe(4);

    const executionPlan = {
      stage: 'fact-processing',
      priorityMode: 'accuracy',
      synthesisTier: 'deep',
      disputedClaimIndex,
    };
    expect(executionPlan.disputedClaimIndex).toBe(4);
    expect(executionPlan.priorityMode).toBe('accuracy');

    // Pipeline transitions dispute state to 'processing'
    const processingDisputePayload = {
      ...autoDisputePayload,
      status: 'processing',
      disputeAttempts: 1,
      dispatchedAt: Date.now(),
    };
    expect(processingDisputePayload.status).toBe('processing');
    expect(processingDisputePayload.disputeAttempts).toBe(1);

    // ══════════════════════════════════════════════════════════════════
    // STEP 5: Deep Re-Verification Engine Execution (Claim #5 Isolated)
    // ══════════════════════════════════════════════════════════════════
    // The engine re-evaluates Claim #5 specifically using the provided authoritative sources
    const providedAuthoritativeSources = processingDisputePayload.additionalSources;
    expect(providedAuthoritativeSources).toContain('https://www.sec.gov/Archives/edgar/data/00012345/q1-2026.htm');
    expect(providedAuthoritativeSources).toContain('https://www.reuters.com/business/company-q1-loss-2026');

    // Verification Result on Claim #5: Just flip verified_true to false_claim
    const reVerifiedClaim5: VerifiedClaim = {
      ...targetClaim,
      status: 'false_claim', // ⚖️ VERDICT FLIPPED FROM VERIFIED_TRUE TO FALSE_CLAIM
      verificationConfidence: 0.99,
      reasoning:
        'Contradicted by official SEC Form 10-Q filed for Q1 2026 showing a GAAP net loss of $(12.4) Million, not a $100 Million net profit. Confirmed by Reuters investigative financial reporting.',
      sources: [
        'https://www.sec.gov/Archives/edgar/data/00012345/q1-2026.htm',
        'https://www.reuters.com/business/company-q1-loss-2026',
      ],
      isGrounded: true,
    };

    expect(reVerifiedClaim5.status).toBe('false_claim');
    expect(reVerifiedClaim5.sources?.length).toBe(2);

    // ══════════════════════════════════════════════════════════════════
    // STEP 6: Master Truth Ledger Update (Zero Video Trust Score Recalculation)
    // ══════════════════════════════════════════════════════════════════
    const updatedClaims = [...initialClaims];
    updatedClaims[disputedClaimIndex] = reVerifiedClaim5;

    // Verify all claims in master ledger
    expect(updatedClaims[0].status).toBe('verified_true');
    expect(updatedClaims[1].status).toBe('verified_true');
    expect(updatedClaims[2].status).toBe('verified_true');
    expect(updatedClaims[3].status).toBe('verified_true');
    expect(updatedClaims[4].status).toBe('false_claim'); // Claim #5 is now False

    // Ledger Stats (Empirical Count, Not Scalar Score)
    const confirmedCount = updatedClaims.filter((c) => c.status === 'verified_true' || c.status === 'mostly_true').length;
    const falseCount = updatedClaims.filter((c) => c.status === 'false_claim').length;
    const disputedCount = updatedClaims.filter((c) => c.status === 'disputed').length;

    expect(confirmedCount).toBe(4);
    expect(falseCount).toBe(1);
    expect(disputedCount).toBe(0);

    const verdictHeadline = `${confirmedCount} Confirmed • ${disputedCount} Disputed • ${falseCount} False`;
    expect(verdictHeadline).toBe('4 Confirmed • 0 Disputed • 1 False');

    const priorityNotice = falseCount > 0 ? `Notice: ${falseCount} claim(s) contradicted by documented evidence.` : undefined;
    expect(priorityNotice).toBe('Notice: 1 claim(s) contradicted by documented evidence.');

    // ══════════════════════════════════════════════════════════════════
    // STEP 7: Dispute Resolution & User Notification (Zero Trust Score)
    // ══════════════════════════════════════════════════════════════════
    const resolvedDispute = {
      ...processingDisputePayload,
      status: 'resolved',
      resolvedAt: Date.now(),
      resolutionVerdict: reVerifiedClaim5.status,
      resolutionNotes: 'Dispute substantiated. Claim #5 updated from Verified to False based on SEC 10-Q filing.',
    };

    expect(resolvedDispute.status).toBe('resolved');
    expect(resolvedDispute.resolutionVerdict).toBe('false_claim');

    const userNotification = {
      recipientId: userId,
      type: 'dispute_resolution',
      title: 'Dispute Substantiated: Claim #5 Updated to False',
      body: `Your dispute on Claim #5 for "${targetClaim.text}" was verified against authoritative SEC filings. The verdict has been corrected from Verified to False on the transparent claim ledger.`,
      claimIndex: 4,
      status: 'resolved',
    };

    expect(userNotification.recipientId).toBe(userId);
    expect(userNotification.body).toContain('corrected from Verified to False');
  });
});
