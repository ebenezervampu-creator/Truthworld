import { Type } from "@google/genai";

export const COMMUNITY_GUIDELINES_TEXT = `Review the provided content details for violations of the Truthworld Community Guidelines and Standards.

COMMUNITY GUIDELINES & STANDARDS:
1. No hate speech, harassment, cyberbullying, or discrimination of any kind.
2. No sexually explicit content, nudity, pornography, or sexually suggestive material.
3. No extreme violence, gore, self-harm, suicide encouragement, or dangerous/illegal activities.
4. No deceptive practices, spam, financial scams, phishing, or impersonation of known figures or brands.
5. No promotion of terrorism, hate groups, or violence.
6. No offensive language or profanity.
7. Do NOT reject content for controversial opinions, political or historical debate, or unverified factual claims (TruthWorld's Credibility System evaluates truth and accuracy separately); only reject for delivery violations, scams/impersonation, or unsafe content listed above.`;

export const MODERATION_RESPONSE_SCHEMA = {
  type: Type.OBJECT,
  properties: {
    approved: {
      type: Type.BOOLEAN,
      description: "True if content passes all community guidelines, false otherwise.",
    },
    reason: {
      type: Type.STRING,
      description: "Explanation of the moderation decision. If rejected, specify which guideline was violated.",
    },
  },
  required: ["approved", "reason"],
};
