/**
 * Library voice fallbacks (dependency-free, unit-tested).
 *
 * Per-language dubbing may use ElevenLabs Voice Library voices directly by voice_id (not saved to the
 * account). If an owner withdraws one mid-job, synthesis switches that speaker to their preset voice
 * instead of failing the dub. jobId → (libraryVoiceId → fallbackVoiceId).
 */
const voiceFallbacksByJob = new Map<string, Map<string, string>>();
const MAX_FALLBACK_JOBS = 500;

export function registerVoiceFallbacks(jobId: string, fallbacks: Record<string, string>): void {
  if (!jobId || !fallbacks || Object.keys(fallbacks).length === 0) return;
  const existing = voiceFallbacksByJob.get(jobId) || new Map<string, string>();
  for (const [voiceId, fallback] of Object.entries(fallbacks)) {
    if (voiceId && fallback && voiceId !== fallback) existing.set(voiceId, fallback);
  }
  voiceFallbacksByJob.delete(jobId);
  voiceFallbacksByJob.set(jobId, existing);
  while (voiceFallbacksByJob.size > MAX_FALLBACK_JOBS) {
    const oldest = voiceFallbacksByJob.keys().next().value;
    if (oldest === undefined) break;
    voiceFallbacksByJob.delete(oldest);
  }
}

export function getVoiceFallback(jobId: string | undefined, voiceId: string | undefined): string | undefined {
  if (!jobId || !voiceId) return undefined;
  return voiceFallbacksByJob.get(jobId)?.get(voiceId);
}

/** True when ElevenLabs says the requested voice does not exist or is no longer shared. */
export function isVoiceUnavailableError(statusCode: number | undefined, errorBody: string): boolean {
  const body = (errorBody || "").toLowerCase();
  if (body.includes("voice_not_found") || body.includes("voice_does_not_exist") || body.includes("voice_not_available")) return true;
  return statusCode === 404 && body.includes("voice");
}

