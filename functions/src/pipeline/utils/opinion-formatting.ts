/**
 * TruthWorld Opinion Formatting Utilities
 *
 * Explains clearly why our verification system configured a specific claim
 * as an opinion rather than a fact, in clear, objective, accessible language.
 */

export function formatOpinionReasoning(claimText?: string): string {
  if (claimText && claimText.trim().length > 0) {
    const lower = claimText.toLowerCase();

    const vitalMatch = /\b(vital|essential|important|crucial|matters most|matter most)\b/.exec(lower);
    if (vitalMatch) {
      const word = vitalMatch[1];
      return `This is a personal opinion because the speaker calls it '${word}'. Everyone decides what feels '${word}' to them, so science cannot measure it like a plain fact.`;
    }

    const bestMatch = /\b(best|worst|greatest|favorite|favourite|awesome|terrible|cool|boring)\b/.exec(lower);
    if (bestMatch) {
      const word = bestMatch[1];
      return `This is a personal opinion because the speaker uses the word '${word}'. Words like '${word}' describe personal taste — everyone likes different things, so no test can prove what is truly '${word}'.`;
    }

    const adviceMatch = /\b(should|must|ought to|need to)\b/.exec(lower);
    if (adviceMatch) {
      const word = adviceMatch[1];
      return `This is personal advice because the speaker says '${word}'. Advice depends on what one person thinks is a good idea, not a hard rule that works the same for everyone.`;
    }

    const thoughtMatch = /\b(feel|think|believe|prefer|love|hate|like)\b/.exec(lower);
    if (thoughtMatch) {
      const word = thoughtMatch[1];
      return `This is a personal opinion because the speaker is sharing what they ${word}. A personal feeling or thought belongs to that person, so it cannot be proved right or wrong.`;
    }
  }

  return "This is someone's personal opinion or feeling, not a fact you can test or prove right or wrong.";
}
