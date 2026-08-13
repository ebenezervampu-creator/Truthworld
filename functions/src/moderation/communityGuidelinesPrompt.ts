import type { ResponseSchema } from "@google-cloud/vertexai";

export const COMMUNITY_GUIDELINES_TEXT = `Review the provided content details for violations of the Truthworld Community Guidelines and Standards.

COMMUNITY GUIDELINES & STANDARDS:
1. No hate speech, harassment, cyberbullying, or discrimination of any kind.
2. No sexually explicit content, nudity, pornography, or sexually suggestive material.
3. No extreme violence, gore, self-harm, suicide encouragement, or dangerous/illegal activities.
4. No deceptive practices, spam, financial scams, phishing, or impersonation of known figures or brands.
5. No promotion of terrorism, hate groups, or violence.
6. No offensive language or profanity.
7. Content must not be misleading or make false claims.`;

export const MODERATION_RESPONSE_SCHEMA: ResponseSchema = {
  type: "OBJECT" as any,
  properties: {
    approved: {
      type: "BOOLEAN" as any,
      description: "True if content passes all community guidelines, false otherwise.",
    },
    reason: {
      type: "STRING" as any,
      description: "Explanation of the moderation decision. If rejected, specify which guideline was violated.",
    },
  },
  required: ["approved", "reason"],
};
