/**
 * Where each group of Cloud Functions runs.
 *
 * Every group runs in asia-south1 (Mumbai), the same region as Firestore,
 * Cloud Storage and most users, so database reads, file transfers and
 * user-facing calls never cross an ocean. Gemini is reached through the
 * Vertex AI global endpoint, and ElevenLabs, AssemblyAI and the Demucs
 * worker are called over HTTPS, so none of them requires a US region.
 *
 * Move a group only with a measured reason: deploy the new region next to the
 * old one, compare job timings and cost, then switch the clients and delete
 * the old copies. Change the matching values in
 * lib/core/config/app_config.dart and admin-portal/src/firebase.js too.
 */
export const CORE_REGION = "asia-south1";

/** Dubbing, subtitles, transcription and the AssemblyAI webhook. */
export const DUBBING_REGION = "asia-south1";

/** Credibility, fact-checking, credibility chat and the appeals desk. */
export const CREDIBILITY_REGION = "asia-south1";
