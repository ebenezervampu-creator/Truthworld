/**
 * TruthWorld Opinion Formatting Utilities
 *
 * Explains clearly why our verification system configured a specific claim
 * as an opinion rather than a fact, in language a 10-year-old child can easily grasp.
 */

export function formatOpinionReasoning(claimText?: string): string {
  if (claimText && claimText.trim().length > 0) {
    const lower = claimText.toLowerCase();

    const vitalMatch = /\b(vital|essential|important|crucial|matters most|matter most)\b/.exec(lower);
    if (vitalMatch) {
      const word = vitalMatch[1];
      return `Classified as an opinion because the speaker describes this as '${word}'. While science can measure real facts like nutrients or numbers, deciding that something is '${word}' is a personal value judgment, not a measurable fact.`;
    }

    const bestMatch = /\b(best|worst|greatest|favorite|favourite|awesome|terrible|cool|boring)\b/.exec(lower);
    if (bestMatch) {
      const word = bestMatch[1];
      return `Classified as an opinion because the speaker uses the word '${word}'. Words like '${word}' describe personal taste — everyone likes different things, and no science test can prove what is truly '${word}'.`;
    }

    const adviceMatch = /\b(should|must|ought to|need to)\b/.exec(lower);
    if (adviceMatch) {
      const word = adviceMatch[1];
      return `Classified as an opinion because the speaker is giving personal advice ('${word}'). Advice depends on what someone personally recommends, not an absolute rule that can be proven true or false.`;
    }

    const thoughtMatch = /\b(feel|think|believe|prefer|love|hate|like)\b/.exec(lower);
    if (thoughtMatch) {
      const word = thoughtMatch[1];
      return `Classified as an opinion because the speaker shares what they personally ${word}. A personal perspective belongs to the speaker, so it cannot be tested or proven wrong from the outside.`;
    }
  }

  return "Classified as an opinion because this statement shares a personal viewpoint or feeling rather than a measurable fact that can be proven true or false.";
}
