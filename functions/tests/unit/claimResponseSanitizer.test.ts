import { sanitizeClaimResponse } from '../../src/pipeline/utils/claim-response-sanitizer';
import { formatOpinionReasoning } from '../../src/pipeline/utils/opinion-formatting';
import { registryService } from '../../src/pipeline/registry/RegistryService';
import { tier0KnowledgeService } from '../../src/pipeline/services/tier0Knowledge';

describe('Unit: Claim Response Sanitizer (10-year-old clarity, zero AI/meta jargon)', () => {
  it('rewrites legacy archive and institutional fallback messages into simple everyday language', () => {
    const archiveMsg = sanitizeClaimResponse(
      'Authoritative corroboration could not be recovered from indexed institutional public archives.',
      'unverified'
    );
    expect(archiveMsg).toBe(
      'No clear outside sources or news reports were found to back this up yet.'
    );
    expect(archiveMsg.toLowerCase()).not.toContain('archives');
    expect(archiveMsg.toLowerCase()).not.toContain('corroboration');
    expect(archiveMsg.toLowerCase()).not.toContain('this claim');

    const urlCheckMsg = sanitizeClaimResponse(
      'No accessible verified sources passed URL health checks to support this claim.',
      'unverified'
    );
    expect(urlCheckMsg).toBe("We couldn't find working, trusted links to back this up yet.");
    expect(urlCheckMsg.toLowerCase()).not.toContain('this claim');

    const lowAuthorityMsg = sanitizeClaimResponse(
      'Recovered sources did not meet institutional authority standards for factual verification.',
      'unverified'
    );
    expect(lowAuthorityMsg).toBe(
      'The links found were not from trusted news or official sources, so this cannot be confirmed yet.'
    );
  });

  it('removes "this claim", "this statement", and "from internal data" / memory phrases', () => {
    const internalAndClaim = sanitizeClaimResponse(
      'From internal data, this claim is wrong and medical studies contradict this claim.',
      'false_claim'
    );
    expect(internalAndClaim.toLowerCase()).not.toContain('internal data');
    expect(internalAndClaim.toLowerCase()).not.toContain('this claim');
    expect(internalAndClaim).toBe('It is wrong and medical studies contradict it.');

    const trainingData = sanitizeClaimResponse(
      'Based on internal training data, smoking damages the lungs.',
      'verified_true'
    );
    expect(trainingData.toLowerCase()).not.toContain('training data');
    expect(trainingData.toLowerCase()).not.toContain('internal');
    expect(trainingData).toBe('Smoking damages the lungs.');

    const firstPersonMemory = sanitizeClaimResponse(
      "I looked through all my stories and general knowledge. It's not something lots of people know about from my memory.",
      'unverified'
    );
    expect(firstPersonMemory.toLowerCase()).not.toContain('my stories');
    expect(firstPersonMemory.toLowerCase()).not.toContain('my memory');
    expect(firstPersonMemory).toBe(
      'No trusted news reports or official records have been found yet to back this up.'
    );
  });

  it('preserves short clean everyday explanations without overwriting them', () => {
    expect(sanitizeClaimResponse('[LLM] Smoking harms your lungs.')).toBe(
      'Smoking harms your lungs.'
    );
    expect(sanitizeClaimResponse('True fact.')).toBe('True fact.');
  });

  it('ensures Tier-0 canonical responses are kid-friendly without "this claim" or "internal data"', () => {
    const samples = [
      'The speed of light in a vacuum is 299,792,458 meters per second',
      'Pure water freezes at 0 degrees and boils at 100 degrees Celsius',
      'Vaccines work by stimulating the immune system to produce antibodies',
      'Antibiotics are effective against viral infections and the common cold',
    ];

    for (const sample of samples) {
      const match = tier0KnowledgeService.lookupPreIndexedFact(sample);
      expect(match).not.toBeNull();
      expect(match!.reasoning.toLowerCase()).not.toContain('this claim');
      expect(match!.reasoning.toLowerCase()).not.toContain('internal data');
      expect(match!.reasoning.toLowerCase()).not.toContain('archives');
    }
  });

  it('formats opinions and deterministic registry answers simply without "this claim" or "internal data"', () => {
    const opinion1 = formatOpinionReasoning('Chocolate ice cream is the best dessert.');
    expect(opinion1.toLowerCase()).not.toContain('this claim');
    expect(opinion1.toLowerCase()).not.toContain('internal data');
    expect(opinion1).toContain("speaker uses the word 'best'");

    const opinion2 = formatOpinionReasoning();
    expect(opinion2).toBe(
      "This is someone's personal opinion or feeling, not a fact you can test or prove right or wrong."
    );

    const reg = registryService.resolveTruthCheck('The speed of light in a vacuum is constant.');
    expect(reg).not.toBeNull();
    expect(reg!.reasoning).toBe(
      'Science textbooks and trusted physics agencies confirm this as a basic, proven science fact.'
    );
    expect(reg!.reasoning.toLowerCase()).not.toContain('deterministically');
    expect(reg!.reasoning.toLowerCase()).not.toContain('this claim');
  });
});
