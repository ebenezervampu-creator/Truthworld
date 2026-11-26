/**
 * User-facing dubbing status messages (CLAUDE.md: Zero Raw Developer Error Policy).
 *
 * Stage `error` fields (video_jobs.stages.*, dubbing_jobs.error, video_jobs.dubbingStatus.*.error) can be
 * shown in the app, so they get a plain sentence; the raw error stays in the logs. Refund wording says
 * "if you were charged", because free/admin orders have nothing to refund.
 */

const LANGUAGE_NAMES: Record<string, string> = {
  en: "English",
  te: "Telugu",
  hi: "Hindi",
  mr: "Marathi",
  ta: "Tamil",
  ml: "Malayalam",
  kn: "Kannada",
  bn: "Bengali",
  gu: "Gujarati",
  pa: "Punjabi",
  ur: "Urdu",
};

export function dubbingLanguageName(lang?: string): string {
  const base = String(lang || "").toLowerCase().split(/[-_]/)[0];
  return LANGUAGE_NAMES[base] || (base ? base.toUpperCase() : "this language");
}

const REFUND_NOTE = "If you were charged for it, the payment has been refunded.";

/** A friendly message for one language's dub that could not be delivered. */
export function friendlyDubbingError(lang: string | undefined, raw: unknown): string {
  const name = dubbingLanguageName(lang);
  const text = String(raw ?? "").toLowerCase();
  if (text.includes("no_native_voice") || text.includes("native voice")) {
    return `We don't have a ${name} voice that fits every speaker in this video yet. ${REFUND_NOTE}`;
  }
  if (text.includes("quota") || text.includes("credits remaining") || text.includes("rate limit") || text.includes("429")) {
    return `Our voice service is busy, so we couldn't finish the ${name} dub. ${REFUND_NOTE} Please try again later.`;
  }
  if (text.includes("timeout") || text.includes("timed out") || text.includes("deadline")) {
    return `The ${name} dub took too long to finish. ${REFUND_NOTE} Please try again later.`;
  }
  return `We couldn't finish the ${name} dub. ${REFUND_NOTE} Please try again later.`;
}

/** A friendly message when a language is blocked before TTS due to unresolved translation errors. */
export function blockedTranslationMessage(lang?: string): string {
  const name = dubbingLanguageName(lang);
  return `We couldn't produce a reliable ${name} translation for a few lines, so this language wasn't dubbed and you won't be charged for it.`;
}

/** A friendly message when the whole dubbing job stops. */
export function friendlyDubbingJobError(): string {
  return "We couldn't finish your dubs. Any language that wasn't delivered has been refunded if you were charged. Please try again later.";
}
