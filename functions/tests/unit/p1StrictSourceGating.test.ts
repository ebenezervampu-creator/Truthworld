import { ClaimVerificationService } from '../../src/pipeline/services/claimVerification';
import { RichSource, ClaimStatus, ClaimNature, EvidenceLevel, VerifiedClaim } from '../../src/pipeline/types';

describe('P1 Strict Source Gating Test Suite (Stage One & Stage Two Admission)', () => {
  let service: ClaimVerificationService;

  beforeEach(() => {
    service = new ClaimVerificationService('mock-api-key');
  });

  it('1. Reddit /comments/ URL: Rejected at Stage 1 as UGC forum content', () => {
    const res = service.validateSource(
      'https://www.reddit.com/r/india/comments/abc123/thoughts_on_1991_reforms/',
      'Reddit Discussion'
    );
    expect(res.isValid).toBe(false);
    expect(res.tier).toBe('E');
    expect(res.admissionPolicy).toBe('reject');
    expect(res.rejectionReason).toMatch(/Reddit|UGC/i);

    const richSource: RichSource = {
      title: 'Reddit Discussion',
      url: 'https://www.reddit.com/r/india/comments/abc123/thoughts_on_1991_reforms/',
      tier: res.tier,
      snippet: 'Someone in comments posted a claim.'
    };
    const assessment = service.evaluateDocumentEvidence(richSource, '1991 reforms claim');
    expect(assessment.admissionStatus).toBe('rejected');
  });

  it('2. Scribd document: Quarantined at Stage 1 with explicit reason', () => {
    const res = service.validateSource(
      'https://www.scribd.com/document/987654321/Indian-Economic-Planning-Notes',
      'Scribd Notes'
    );
    expect(res.isValid).toBe(false);
    expect(res.tier).toBe('E');
    expect(res.isScribd).toBe(true);
    expect(res.admissionPolicy).toBe('quarantine');
    expect(res.rejectionReason).toMatch(/Scribd/i);

    const richSource: RichSource = {
      title: 'Scribd Notes',
      url: 'https://www.scribd.com/document/987654321/Indian-Economic-Planning-Notes',
      domain: 'scribd.com',
      tier: res.tier,
      snippet: 'Unverified PDF uploaded by student.'
    };
    const assessment = service.evaluateDocumentEvidence(richSource, 'Economic planning in India');
    expect(assessment.admissionStatus).toBe('quarantined');
    expect(assessment.rejectionReason).toMatch(/Scribd/i);
  });

  it('3. WHO official report: Eligible at Stage 1 and Admitted at Stage 2 for health claim', () => {
    const url = 'https://www.who.int/news-room/fact-sheets/detail/measles';
    const title = 'WHO Measles Fact Sheet';
    const res = service.validateSource(url, title);

    expect(res.isValid).toBe(true);
    expect(res.tier).toBe('A');
    expect(res.admissionPolicy).toBe('eligible');

    const richSource: RichSource = {
      title,
      url,
      domain: 'who.int',
      publisher: 'World Health Organization',
      tier: res.tier,
      snippet: 'Measles vaccination prevented an estimated 57 million deaths between 2000 and 2022.'
    };

    const assessment = service.evaluateDocumentEvidence(
      richSource,
      'Measles vaccination campaigns prevent child mortality across populations.'
    );

    expect(assessment.admissionStatus).toBe('admitted');
    expect(assessment.claimRelevanceScore).toBeGreaterThanOrEqual(0.60);
    expect(assessment.directEvidenceScore).toBeGreaterThanOrEqual(0.70);
  });

  it('4. WHO page unrelated to claim: Stage 1 eligible, but Rejected at Stage 2 as off-topic', () => {
    const url = 'https://www.who.int/news-room/fact-sheets/detail/malaria';
    const title = 'WHO Malaria Fact Sheet';
    const res = service.validateSource(url, title);

    expect(res.isValid).toBe(true);
    expect(res.tier).toBe('A');

    const richSource: RichSource = {
      title,
      url,
      domain: 'who.int',
      publisher: 'World Health Organization',
      tier: res.tier,
      snippet: 'Malaria is a life-threatening disease spread by the bite of an infected female Anopheles mosquito.'
    };

    const assessment = service.evaluateDocumentEvidence(
      richSource,
      'In the 1950s, Jawaharlal Nehru established the First Five Year Plan prioritizing heavy steel industry and dams.'
    );

    expect(assessment.claimRelevanceScore).toBeLessThan(0.35);
    expect(assessment.admissionStatus).toBe('rejected');
    expect(assessment.rejectionReason).toBe('Document does not address the specific claim proposition');
  });

  it('5. Government statistical report: Eligible and Admitted as primary evidence', () => {
    const url = 'https://mospi.gov.in/press-release/gdp-estimates-2023-24';
    const title = 'MoSPI Provisional Estimates of GDP 2023-24';
    const res = service.validateSource(url, title);

    expect(res.isValid).toBe(true);
    expect(res.tier).toBe('A');

    const richSource: RichSource = {
      title,
      url,
      domain: 'mospi.gov.in',
      publisher: 'MoSPI',
      tier: 'A',
      snippet: 'Real GDP or GDP at Constant Prices in the year 2023-24 is estimated at ₹173.82 lakh crore, showing a growth rate of 8.2 percent.'
    };

    const assessment = service.evaluateDocumentEvidence(
      richSource,
      'India real GDP grew by 8.2 percent in the year 2023-24 according to official statistics.'
    );

    expect(assessment.admissionStatus).toBe('admitted');
    expect(assessment.isPrimaryEvidence).toBe(true);
    expect(assessment.claimRelevanceScore).toBeGreaterThanOrEqual(0.80);
    expect(assessment.directEvidenceScore).toBeGreaterThanOrEqual(0.80);
  });

  it('6. News article repeating another outlet (Wire Syndication): No independent-source credit', () => {
    const source1: RichSource = {
      title: 'India GDP accelerates to 8.2% in FY24 (Reuters)',
      url: 'https://www.reuters.com/world/india/india-gdp-growth-2024',
      domain: 'reuters.com',
      publisher: 'Reuters',
      tier: 'A',
      snippet: '(Reuters) - India economy expanded 8.2% in fiscal year 2023-24 according to official figures.'
    };

    const source2: RichSource = {
      title: 'India GDP surges past expectations (Reuters)',
      url: 'https://www.indiatoday.in/business/story/india-economy-gdp-expansion-2024',
      domain: 'indiatoday.in',
      publisher: 'India Today',
      tier: 'C',
      snippet: 'Reuters - India economy expanded 8.2% in fiscal year 2023-24 according to official data released Friday.'
    };

    const claimText = 'India GDP grew by 8.2% in 2023-24.';

    // Evaluate Source 1 (first appearance of Reuters wire)
    const assessment1 = service.evaluateDocumentEvidence(source1, claimText, 'Economy', []);
    source1.evidenceAssessment = assessment1;
    source1.wireOrigin = assessment1.wireOrigin;

    expect(assessment1.wireOrigin).toBe('reuters');
    expect(assessment1.isIndependent).toBe(true);

    // Evaluate Source 2 (syndicated reprint of Reuters wire)
    const assessment2 = service.evaluateDocumentEvidence(source2, claimText, 'Economy', [source1]);
    source2.evidenceAssessment = assessment2;
    source2.wireOrigin = assessment2.wireOrigin;

    expect(assessment2.wireOrigin).toBe('reuters');
    expect(assessment2.isIndependent).toBe(false);

    // When calculating evidence level, 2 syndicated copies from the same wire MUST NOT count as 2 independent publishers!
    const evidenceLevel = service.calculateEvidenceLevel([source1, source2]);
    expect(evidenceLevel.summary.independentPublishers).toBe(1);
  });

  it('7. Peer-reviewed research: Eligible and Admitted', () => {
    const url = 'https://www.nature.com/articles/nature12345';
    const title = 'A Programmable Dual-RNA-Guided DNA Endonuclease in Adaptive Bacterial Immunity';
    const res = service.validateSource(url, title);

    expect(res.isValid).toBe(true);
    expect(res.tier).toBe('A');

    const richSource: RichSource = {
      title,
      url,
      domain: 'nature.com',
      publisher: 'Nature',
      tier: 'A',
      snippet: 'Cas9 endonuclease generates double-strand breaks in target DNA guided by crRNA:tracrRNA duplexes.'
    };

    const assessment = service.evaluateDocumentEvidence(
      richSource,
      'Cas9 endonuclease produces targeted double-strand breaks in bacterial and mammalian DNA.'
    );

    expect(assessment.admissionStatus).toBe('admitted');
    expect(assessment.directEvidenceScore).toBeGreaterThanOrEqual(0.70);
  });

  it('8. Search snippet without accessible document: Quarantined for insufficient evidence', () => {
    const richSource: RichSource = {
      title: 'Economic Growth in 1950s',
      url: 'https://www.thehindu.com/news/national/article123.ece',
      domain: 'thehindu.com',
      publisher: 'The Hindu',
      tier: 'B',
      snippet: '' // Empty snippet / inaccessible document
    };

    const assessment = service.evaluateDocumentEvidence(
      richSource,
      'In the 1950s, Thailand GDP growth exceeded 5 percent annually.'
    );

    expect(assessment.admissionStatus).toBe('quarantined');
    expect(assessment.directEvidenceScore).toBeLessThan(0.30);
    expect(assessment.rejectionReason).toBe('Search snippet lacks accessible document substance to establish factual evidence');
  });

  it('9. Two contradictory government reports: Both retained for adjudication with contradictory flag', () => {
    const report1: RichSource = {
      title: 'Ministry of Jal Shakti - Rural Irrigation Allocations',
      url: 'https://jalshakti.gov.in/schemes/rural-canals',
      domain: 'jalshakti.gov.in',
      publisher: 'Ministry of Jal Shakti',
      tier: 'A',
      snippet: 'The government allocated 10,000 crores for rural canal irrigation infrastructure in FY22.'
    };

    const report2: RichSource = {
      title: 'CAG Performance Audit of Rural Irrigation Schemes',
      url: 'https://cag.gov.in/en/audit-report/details/rural-irrigation-audit',
      domain: 'cag.gov.in',
      publisher: 'Comptroller and Auditor General of India',
      tier: 'A',
      snippet: 'The CAG audit report refutes the claimed expenditure figures, finding no evidence of 10,000 crores spent.'
    };

    const claimText = 'The government allocated and successfully spent 10,000 crores on rural canal irrigation in FY22.';

    const assessment1 = service.evaluateDocumentEvidence(report1, claimText, 'Governance', []);
    report1.evidenceAssessment = assessment1;

    const assessment2 = service.evaluateDocumentEvidence(report2, claimText, 'Governance', [report1]);
    report2.evidenceAssessment = assessment2;
    if (assessment2.isContradictory) report2.isContradictory = true;

    // Both reports must be admitted to evidence!
    expect(assessment1.admissionStatus).toBe('admitted');
    expect(assessment2.admissionStatus).toBe('admitted');

    // Report 2 must be flagged as contradictory
    expect(report2.isContradictory).toBe(true);

    // Both reports are preserved for cross-examination and dialectical adjudication
    const admittedSources = [report1, report2];
    expect(admittedSources.length).toBe(2);
    expect(admittedSources.some(s => s.isContradictory)).toBe(true);
  });
});
