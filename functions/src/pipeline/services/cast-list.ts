/**
 * Creator cast list for dubbing (dependency-free, unit-tested).
 *
 * The cast list is optional: the speaking characters in the video, as the creator (or, for cinema,
 * the script/credits) names them. It is used in two places:
 *  1. AssemblyAI speaker count — the number of speaking characters becomes min_speakers_expected
 *     (assembly-speaker-options.ts), so similar voices are not merged into one label up front.
 *  2. Diarization check — the cast seeds Gemini's character roster with stable ids C1..Cn, so the
 *     same person keeps the same id in every window, and characters with a timestamp get a short
 *     reference clip (diarization-check.ts).
 *
 * The list counts SPEAKING characters only: AssemblyAI treats the minimum as a hard floor, so a
 * silent character on the list would force one real speaker to be split in two.
 */

import type { SpeakerCountHint } from "./assembly-speaker-options";
import * as crypto from "crypto";

export interface CastMember {
  name: string;
  gender?: "male" | "female";
  /** Short look + voice description, e.g. "older man, gold headdress, deep voice". */
  description?: string;
  /** A moment (seconds from the start) where this character is on screen and speaking. */
  appearsAtSec?: number;
}

export type FormalityLevel = "deferential" | "formal" | "peer" | "informal";

export type RelationType =
  | "elder_younger"
  | "younger_elder"
  | "parent_child"
  | "child_parent"
  | "stranger"
  | "colleague"
  | "friend"
  | "spouse"
  | "pastor_congregation"
  | "host_audience"
  | "teacher_student";

export interface CharacterRelationship {
  fromSpeaker: string; // e.g. "speaker_0"
  toSpeaker: string;   // e.g. "speaker_1" | "AUDIENCE" | "GROUP" | "SELF"
  formality: FormalityLevel;
  relationship?: RelationType;
  /** Optional explicit per-language override, e.g. { te: "మీరు (-ండి)", hi: "आप (-इए)" } */
  registerOverride?: Record<string, string>;
}

export interface CastMemberWithRelations extends CastMember {
  speakerId?: string; // Bound after Stage 1/3 diarization reconciliation
  role?: "host" | "guest" | "parent" | "child" | "expert" | "narrator" | "pastor" | "student";
  relationships?: CharacterRelationship[];
}

export interface LockedRegisterEntry {
  pairKey: string; // e.g., "speaker_0->speaker_1" or "speaker_0->AUDIENCE"
  formality: FormalityLevel;
  lockedPronoun: string; // e.g., "మీరు", "నువ్వు", "आप", "तुम"
  firstSeenSegmentId: string;
}

/** Pre-pass localization bible locking registers and context for parallel chunking */
export interface LocalizationBible {
  lockedRegisters: Record<string, FormalityLevel>;
  characterRoles?: Record<string, { role?: string; estimatedAge?: string; defaultAddressee?: string }>;
  keyTerminology?: Record<string, string>;
  visualSceneNotes?: string[];
  version: string;
}

/** Language codes with explicit address-form rules below. */
export const REGISTER_LANGUAGES = ["te", "hi", "ta", "kn", "ml", "mr", "bn", "gu", "pa", "ur", "es", "fr", "de"] as const;
type RegisterLanguage = (typeof REGISTER_LANGUAGES)[number];

/**
 * Address-form rules per language and level. Two-level languages (te, ta, kn, ml, mr, gu, pa, es,
 * fr, de) have no separate "peer" pronoun: a peer pair is resolved to formal or informal from the
 * relationship type (see effectiveFormality), so the prompt never gets an either/or instruction.
 * Three-level languages (hi, bn, ur) keep a distinct peer form (तुम / তুমি / تم).
 */
const REGISTER_DIRECTIVES: Record<RegisterLanguage, Partial<Record<FormalityLevel, string>>> = {
  te: {
    deferential: "Use respectful 'మీరు / మిమ్మల్ని / మీకు' with polite verb suffixes ('-ండి', '-తున్నారు', '-గారు'). Never use 'నువ్వు'.",
    formal: "Use polite 'మీరు / మిమ్మల్ని / మీకు' with '-ండి / -తున్నారు' verb endings (even when addressing one person).",
    informal: "Use familiar 'నువ్వు / నిన్ను / నీకు' with '-వు' verb endings (children, younger siblings, close friends).",
  },
  hi: {
    deferential: "Use honorific 'आप / आपको / आपका' with '-इए / हैं / जी' verb forms. Never slip into 'तुम' or 'तू'.",
    formal: "Use polite 'आप' with '-इए / हैं' agreement (elders, guests, professionals, colleagues, audience).",
    peer: "Use friendly 'तुम' with '-ओ / हो' agreement (friends, siblings, close peers).",
    informal: "Use 'तुम'; reserve 'तू' for young children or very intimate family when culturally natural.",
  },
  ta: {
    deferential: "Use 'நீங்கள் / தாங்கள்' with respectful '-ங்கள்' verb endings.",
    formal: "Use 'நீங்கள் / உங்களை / உங்களுக்கு' with polite '-ங்கள்' endings.",
    informal: "Use 'நீ / உன்னை / உனக்கு' with familiar verb endings.",
  },
  kn: {
    deferential: "Use respectful 'ನೀವು / ನಿಮ್ಮನ್ನು / ನಿಮಗೆ' with '-ರಿ' polite verb endings and honorifics ('-ಅವರೇ').",
    formal: "Use polite 'ನೀವು / ನಿಮ್ಮನ್ನು / ನಿಮಗೆ' with '-ರಿ' verb endings.",
    informal: "Use familiar 'ನೀನು / ನಿನ್ನನ್ನು / ನಿನಗೆ' with '-ಉ / -ಓ' verb endings.",
  },
  ml: {
    deferential: "Use respectful 'താങ്കൾ / താങ്കളെ / താങ്കൾക്ക്' (or 'സാർ / ചേട്ടാ' style address where natural).",
    formal: "Use polite 'നിങ്ങൾ / നിങ്ങളെ / നിങ്ങൾക്ക്'.",
    informal: "Use familiar 'നീ / നിന്നെ / നിനക്ക്'.",
  },
  mr: {
    deferential: "Use respectful 'आपण / आपल्याला' or 'तुम्ही' with '-आ / -ता' plural verb forms.",
    formal: "Use polite 'तुम्ही / तुम्हाला / तुमचा' with plural verb agreement.",
    informal: "Use familiar 'तू / तुला / तुझा' with singular verb agreement.",
  },
  bn: {
    deferential: "Use 'আপনি / আপনাকে / আপনার' with '-ন' verb endings.",
    formal: "Use 'আপনি / আপনাকে / আপনার' with '-ন' verb endings.",
    peer: "Use 'তুমি / তোমাকে / তোমার' with '-ও' verb endings.",
    informal: "Use 'তুই / তোকে / তোর' only for very close friends or young children; otherwise 'তুমি'.",
  },
  gu: {
    deferential: "Use respectful 'આપ / આપને / આપનું'.",
    formal: "Use polite 'તમે / તમને / તમારું' with plural verb agreement.",
    informal: "Use familiar 'તું / તને / તારું' with singular verb agreement.",
  },
  pa: {
    deferential: "Use respectful 'ਤੁਸੀਂ / ਤੁਹਾਨੂੰ / ਤੁਹਾਡਾ' with 'ਜੀ' where natural.",
    formal: "Use polite 'ਤੁਸੀਂ / ਤੁਹਾਨੂੰ / ਤੁਹਾਡਾ'.",
    informal: "Use familiar 'ਤੂੰ / ਤੈਨੂੰ / ਤੇਰਾ'.",
  },
  ur: {
    deferential: "Use honorific 'آپ / آپ کو / آپ کا' with '-یے / ہیں' verb forms.",
    formal: "Use polite 'آپ' with '-یے / ہیں' agreement.",
    peer: "Use friendly 'تم / تمہیں / تمہارا' with '-و / ہو' agreement.",
    informal: "Use 'تم'; reserve 'تُو / تجھے / تیرا' for young children or very intimate family.",
  },
  es: { deferential: "Use 'usted' (third-person singular formal conjugation).", formal: "Use 'usted'.", informal: "Use 'tú'." },
  fr: { deferential: "Use 'vous'.", formal: "Use 'vous'.", informal: "Use 'tu'." },
  de: { deferential: "Use 'Sie'.", formal: "Use 'Sie'.", informal: "Use 'du'." },
};

/** Close relationships use the familiar form for a peer pair; everything else stays polite. */
const CLOSE_RELATIONSHIPS = new Set<RelationType>(["friend", "spouse"]);

const baseLangOf = (lang: string) => (lang || "").toLowerCase().split(/[-_]/)[0];

/**
 * The level a line is actually written in. "peer" is only a level of its own in hi / bn / ur; in
 * two-level languages it becomes informal for friends/spouses and formal otherwise. In three-level
 * languages a colleague or stranger peer is formal (आप for a colleague, not तुम).
 */
export function effectiveFormality(targetLang: string, formality: FormalityLevel, relationship?: RelationType): FormalityLevel {
  if (formality !== "peer") return formality;
  const lang = baseLangOf(targetLang);
  const close = relationship ? CLOSE_RELATIONSHIPS.has(relationship) : false;
  const threeLevel = lang === "hi" || lang === "bn" || lang === "ur";
  if (threeLevel) return relationship === "colleague" || relationship === "stranger" ? "formal" : "peer";
  return close ? "informal" : "formal";
}

/** Returns precise register guidance for the prompt */
export function resolveRegisterDirective(
  targetLang: string,
  rel?: CharacterRelationship,
  defaultFormality: FormalityLevel | "casual" = "formal"
): string {
  const baseLang = baseLangOf(targetLang);
  const normalizedDefault: FormalityLevel = defaultFormality === "casual" ? "informal" : defaultFormality;
  const level = effectiveFormality(baseLang, rel?.formality ?? normalizedDefault, rel?.relationship);
  if (rel?.registerOverride?.[baseLang]) {
    return `${level.toUpperCase()}: ${rel.registerOverride[baseLang]}`;
  }
  const rules = (REGISTER_DIRECTIVES as Record<string, Partial<Record<FormalityLevel, string>>>)[baseLang];
  const rule = rules?.[level];
  const who = rel?.relationship ?? (rel ? "relationship" : "audience");
  if (rule) return `${level.toUpperCase()} (${who}): ${rule}`;
  // Every other language: still a concrete instruction, never a bare level word.
  const generic: Record<FormalityLevel, string> = {
    deferential: "Use the most respectful second-person forms and honorifics of the target language.",
    formal: "Use the polite/formal second-person forms of the target language consistently.",
    peer: "Use the friendly second-person forms used between equals, consistently.",
    informal: "Use the familiar second-person forms of the target language consistently.",
  };
  return `${level.toUpperCase()} (${who}): ${generic[level]}`;
}

const VALID_FORMALITIES = new Set<FormalityLevel>(["deferential", "formal", "peer", "informal"]);
const VALID_RELATIONSHIPS = new Set<RelationType>([
  "elder_younger", "younger_elder", "parent_child", "child_parent", "stranger", "colleague",
  "friend", "spouse", "pastor_congregation", "host_audience", "teacher_student",
]);
export const MAX_RELATIONSHIPS = 200;
const MAX_OVERRIDE_CHARS = 60;

/**
 * Validates an untrusted relationships array from a request body. Speakers are character names
 * from the cast list (or AUDIENCE / GROUP / SELF); bindRelationships maps them to diarization
 * labels. Overrides keep only known language codes with short string values; anything else is
 * dropped, so creator input cannot inject instructions into the Gemini prompt.
 */
export function parseCastRelationships(raw: unknown): CharacterRelationship[] {
  if (!Array.isArray(raw)) return [];
  const out: CharacterRelationship[] = [];
  const seen = new Set<string>();
  for (const item of raw) {
    if (out.length >= MAX_RELATIONSHIPS) break;
    if (!item || typeof item !== "object") continue;
    const r = item as Record<string, unknown>;
    const fromSpeaker = clean(r.fromSpeaker ?? r.from, MAX_NAME);
    const toSpeaker = clean(r.toSpeaker ?? r.to, MAX_NAME);
    if (!fromSpeaker || !toSpeaker) continue;
    const pairKey = `${fromSpeaker.toLowerCase()}->${toSpeaker.toLowerCase()}`;
    if (seen.has(pairKey)) continue;
    seen.add(pairKey);
    const formalityRaw = clean(r.formality, 20).toLowerCase() as FormalityLevel;
    const rel: CharacterRelationship = {
      fromSpeaker,
      toSpeaker,
      formality: VALID_FORMALITIES.has(formalityRaw) ? formalityRaw : "formal",
    };
    const relationship = clean(r.relationship, 40).toLowerCase() as RelationType;
    if (VALID_RELATIONSHIPS.has(relationship)) rel.relationship = relationship;
    if (r.registerOverride && typeof r.registerOverride === "object" && !Array.isArray(r.registerOverride)) {
      const override: Record<string, string> = {};
      for (const [lang, value] of Object.entries(r.registerOverride as Record<string, unknown>)) {
        const key = baseLangOf(lang);
        const text = clean(value, MAX_OVERRIDE_CHARS);
        if ((REGISTER_LANGUAGES as readonly string[]).includes(key) && text) override[key] = text;
      }
      if (Object.keys(override).length > 0) rel.registerOverride = override;
    }
    out.push(rel);
  }
  return out;
}

/** Second-person pronoun forms per language, grouped by the level they signal. */
const PRONOUN_FORMS: Partial<Record<RegisterLanguage, Array<{ formality: FormalityLevel; canonical: string; forms: string[] }>>> = {
  te: [
    { formality: "formal", canonical: "మీరు", forms: ["మీరు", "మిమ్మల్ని", "మీకు", "మీది", "మీ"] },
    { formality: "informal", canonical: "నువ్వు", forms: ["నువ్వు", "నీవు", "నిన్ను", "నీకు", "నీది", "నీ"] },
  ],
  hi: [
    { formality: "formal", canonical: "आप", forms: ["आप", "आपको", "आपका", "आपकी", "आपके", "आपसे", "आपने"] },
    { formality: "peer", canonical: "तुम", forms: ["तुम", "तुम्हें", "तुम्हारा", "तुम्हारी", "तुम्हारे", "तुमने", "तुमसे"] },
    { formality: "informal", canonical: "तू", forms: ["तू", "तुझे", "तेरा", "तेरी", "तेरे", "तूने", "तुझसे"] },
  ],
  ta: [
    { formality: "formal", canonical: "நீங்கள்", forms: ["நீங்கள்", "உங்களை", "உங்களுக்கு", "உங்கள்", "தாங்கள்"] },
    { formality: "informal", canonical: "நீ", forms: ["நீ", "உன்னை", "உனக்கு", "உன்"] },
  ],
  kn: [
    { formality: "formal", canonical: "ನೀವು", forms: ["ನೀವು", "ನಿಮ್ಮನ್ನು", "ನಿಮಗೆ", "ನಿಮ್ಮ"] },
    { formality: "informal", canonical: "ನೀನು", forms: ["ನೀನು", "ನಿನ್ನನ್ನು", "ನಿನಗೆ", "ನಿನ್ನ"] },
  ],
  ml: [
    { formality: "deferential", canonical: "താങ്കൾ", forms: ["താങ്കൾ", "താങ്കളെ", "താങ്കൾക്ക്", "താങ്കളുടെ"] },
    { formality: "formal", canonical: "നിങ്ങൾ", forms: ["നിങ്ങൾ", "നിങ്ങളെ", "നിങ്ങൾക്ക്", "നിങ്ങളുടെ"] },
    { formality: "informal", canonical: "നീ", forms: ["നീ", "നിന്നെ", "നിനക്ക്", "നിന്റെ"] },
  ],
  mr: [
    { formality: "formal", canonical: "तुम्ही", forms: ["तुम्ही", "तुम्हाला", "तुमचा", "तुमची", "तुमचे"] },
    { formality: "informal", canonical: "तू", forms: ["तू", "तुला", "तुझा", "तुझी", "तुझे"] },
  ],
  bn: [
    { formality: "formal", canonical: "আপনি", forms: ["আপনি", "আপনাকে", "আপনার"] },
    { formality: "peer", canonical: "তুমি", forms: ["তুমি", "তোমাকে", "তোমার"] },
    { formality: "informal", canonical: "তুই", forms: ["তুই", "তোকে", "তোর"] },
  ],
  gu: [
    { formality: "deferential", canonical: "આપ", forms: ["આપ", "આપને", "આપનું"] },
    { formality: "formal", canonical: "તમે", forms: ["તમે", "તમને", "તમારું", "તમારો", "તમારી"] },
    { formality: "informal", canonical: "તું", forms: ["તું", "તને", "તારું", "તારો", "તારી"] },
  ],
  pa: [
    { formality: "formal", canonical: "ਤੁਸੀਂ", forms: ["ਤੁਸੀਂ", "ਤੁਹਾਨੂੰ", "ਤੁਹਾਡਾ", "ਤੁਹਾਡੀ", "ਤੁਹਾਡੇ"] },
    { formality: "informal", canonical: "ਤੂੰ", forms: ["ਤੂੰ", "ਤੈਨੂੰ", "ਤੇਰਾ", "ਤੇਰੀ", "ਤੇਰੇ"] },
  ],
  ur: [
    { formality: "formal", canonical: "آپ", forms: ["آپ"] },
    { formality: "peer", canonical: "تم", forms: ["تم", "تمہیں", "تمہارا", "تمہاری", "تمہارے"] },
    // Not "تو": it is also the very common conjunction "then".
    { formality: "informal", canonical: "تُو", forms: ["تجھے", "تیرا", "تیری", "تیرے"] },
  ],
  es: [
    { formality: "formal", canonical: "usted", forms: ["usted", "ustedes"] },
    { formality: "informal", canonical: "tú", forms: ["tú", "te", "ti", "contigo"] },
  ],
  fr: [
    { formality: "formal", canonical: "vous", forms: ["vous"] },
    { formality: "informal", canonical: "tu", forms: ["tu", "toi", "te"] },
  ],
  de: [
    { formality: "formal", canonical: "Sie", forms: ["Sie", "Ihnen", "Ihr", "Ihre"] },
    { formality: "informal", canonical: "du", forms: ["du", "dich", "dir", "dein", "deine"] },
  ],
};

const escapeRe = (t: string) => t.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

/**
 * The address form a line uses, from its second-person pronouns (whole words only; Indic vowel
 * signs count as part of a word). Most formal form wins when a line mixes forms. Undefined when the
 * line has no second-person pronoun (e.g. pro-drop with verb endings only).
 */
export function detectAddressPronoun(text: string, targetLang: string): { pronoun: string; formality: FormalityLevel } | undefined {
  const groups = PRONOUN_FORMS[baseLangOf(targetLang) as RegisterLanguage];
  if (!groups || !text) return undefined;
  // German "Sie" is case-sensitive (sie = she/they); other languages match case-insensitively.
  const caseSensitive = baseLangOf(targetLang) === "de";
  for (const g of groups) {
    const alt = g.forms.map(escapeRe).join("|");
    const re = new RegExp(`(?<![\\p{L}\\p{M}])(?:${alt})(?![\\p{L}\\p{M}])`, caseSensitive ? "u" : "iu");
    if (re.test(text)) return { pronoun: g.canonical, formality: g.formality };
  }
  return undefined;
}

/** The level a known pronoun (canonical or any form) signals, or undefined. */
export function formalityOfPronoun(pronoun: string, targetLang: string): FormalityLevel | undefined {
  return detectAddressPronoun(pronoun, targetLang)?.formality;
}

// ─── Binding cast names to diarization labels ───────────────────────────────

/** Addressees that are not characters. */
export const NON_CHARACTER_ADDRESSEES = new Set(["AUDIENCE", "GROUP", "SELF"]);

/**
 * Cast name / cast id → diarization label (e.g. "pharaoh" → "B_3", "c2" → "B_3"), from the
 * diarization check's character → label assignments (diarization-reconcile.ts). Cast ids C1..Cn
 * follow cast-list order (castRoster). Keys are lower-case.
 */
export function buildCastBinding(
  cast: CastMember[],
  characterLabels: Map<string, string> | Record<string, string> | undefined
): Record<string, string> {
  const entries: Array<[string, string]> = characterLabels instanceof Map
    ? Array.from(characterLabels.entries())
    : Object.entries(characterLabels || {});
  const byId = new Map(entries.map(([id, label]) => [id.toUpperCase(), label]));
  const binding: Record<string, string> = {};
  cast.forEach((member, i) => {
    const id = `C${i + 1}`;
    const label = byId.get(id);
    if (label) {
      binding[member.name.toLowerCase()] = label;
      binding[id.toLowerCase()] = label;
    }
  });
  return binding;
}

/**
 * A relationship endpoint → the label the dubbing segments use. AUDIENCE / GROUP / SELF and
 * existing labels are kept; cast names map through the binding. A cast member with no voice in
 * the video (spoken TO, never speaking — e.g. Joseph in a scene where only others talk) is kept by
 * name, valid as an addressee only.
 */
function resolveEndpoint(
  endpoint: string,
  binding: Record<string, string>,
  knownLabels: Set<string>,
  castNames: Map<string, string>
): { id: string; speaks: boolean } | undefined {
  const upper = endpoint.toUpperCase();
  if (NON_CHARACTER_ADDRESSEES.has(upper)) return { id: upper, speaks: false };
  if (knownLabels.has(endpoint)) return { id: endpoint, speaks: true };
  const bound = binding[endpoint.toLowerCase()];
  if (bound) return { id: bound, speaks: true };
  const castName = castNames.get(endpoint.toLowerCase());
  return castName ? { id: castName, speaks: false } : undefined;
}

/**
 * Relationships written with cast names → the same relationships on diarization labels. Endpoints
 * that are already labels, or AUDIENCE / GROUP / SELF, are kept; unknown names are dropped and
 * reported, so the caller can log them.
 */
export function bindRelationships(
  relationships: CharacterRelationship[],
  binding: Record<string, string>,
  knownLabels: Iterable<string>,
  cast: CastMember[] = []
): { bound: CharacterRelationship[]; unresolved: string[] } {
  const labels = new Set(knownLabels);
  const castNames = new Map(cast.map((m) => [m.name.toLowerCase(), m.name]));
  const bound: CharacterRelationship[] = [];
  const unresolved = new Set<string>();
  for (const rel of relationships) {
    const from = resolveEndpoint(rel.fromSpeaker, binding, labels, castNames);
    const to = resolveEndpoint(rel.toSpeaker, binding, labels, castNames);
    // The speaker side must be a voice in the video; the addressee may be silent.
    if (!from || !from.speaks) unresolved.add(rel.fromSpeaker);
    if (!to) unresolved.add(rel.toSpeaker);
    if (from?.speaks && to) bound.push({ ...rel, fromSpeaker: from.id, toSpeaker: to.id });
  }
  return { bound, unresolved: Array.from(unresolved) };
}

/**
 * Who each line is said to (a speaker label, a silent cast member's name, or "AUDIENCE").
 * In order:
 *  1. An explicit `addressedTo` on the segment.
 *  2. A speaker continuing their own turn keeps the addressee of their previous line, so the
 *     address form cannot change mid-turn ("Don't worry, Joseph." / "I will remember you.").
 *  3. The creator's relationships for this speaker: the only one, or the one naming the previous
 *     different speaker, else the first. A creator's statement beats any turn-taking guess.
 *  4. One speaker in the video → the audience; two → the other speaker.
 *  5. Otherwise → the previous different speaker (a reply), else the audience.
 */
export function inferAddressees(
  segments: Array<{ speaker?: string; addressedTo?: string }>,
  uniqueSpeakers: string[],
  relationships: Array<{ fromSpeaker: string; toSpeaker: string }>
): Array<string | undefined> {
  const out: Array<string | undefined> = [];
  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i];
    if (seg.addressedTo) { out.push(seg.addressedTo); continue; }
    if (!seg.speaker) { out.push(undefined); continue; }
    const prev = i > 0 ? segments[i - 1] : undefined;
    if (prev && prev.speaker === seg.speaker && out[i - 1]) { out.push(out[i - 1]); continue; }
    let replyTo: string | undefined;
    for (let j = i - 1; j >= 0; j--) {
      const sp = segments[j].speaker;
      if (sp && sp !== seg.speaker) { replyTo = sp; break; }
    }
    const own = relationships.filter((r) => r.fromSpeaker === seg.speaker);
    if (own.length > 0) {
      out.push((own.find((r) => r.toSpeaker === replyTo) || own[0]).toSpeaker);
      continue;
    }
    if (uniqueSpeakers.length <= 1) { out.push("AUDIENCE"); continue; }
    if (uniqueSpeakers.length === 2) {
      out.push(uniqueSpeakers.find((spk) => spk !== seg.speaker) || "AUDIENCE");
      continue;
    }
    out.push(replyTo || "AUDIENCE");
  }
  return out;
}

/** Cast members with a gender, keyed by their diarization label (for the editor's agreement rules). */
export function bindCastGenders(cast: CastMember[], binding: Record<string, string>): Record<string, "male" | "female"> {
  const out: Record<string, "male" | "female"> = {};
  for (const m of cast) {
    const label = binding[m.name.toLowerCase()];
    if (label && m.gender) out[label] = m.gender;
  }
  return out;
}

/**
 * Tracks locked registers per speaker pair across sliding chunks to guarantee
 * zero honorific flip-flopping across 25-line boundaries.
 */
export class RollingHonorificCache {
  private readonly locks = new Map<string, LockedRegisterEntry>();
  private targetLang: string | undefined;

  constructor(targetLang?: string) {
    this.targetLang = targetLang ? baseLangOf(targetLang) : undefined;
  }

  seedFromRelationships(relationships: CharacterRelationship[], targetLang: string = "te"): void {
    const baseLang = baseLangOf(targetLang);
    this.targetLang = this.targetLang || baseLang;
    for (const rel of relationships) {
      const pairKey = `${rel.fromSpeaker}->${rel.toSpeaker}`;
      const level = effectiveFormality(baseLang, rel.formality, rel.relationship);
      const defaultPronoun = this.defaultPronounFor(baseLang, level);
      this.locks.set(pairKey, {
        pairKey,
        formality: level,
        lockedPronoun: rel.registerOverride?.[baseLang] ?? defaultPronoun,
        firstSeenSegmentId: "SEED_RELATION",
      });
    }
  }

  seedFromBible(bible: LocalizationBible, targetLang: string = "te"): void {
    const baseLang = baseLangOf(targetLang);
    this.targetLang = this.targetLang || baseLang;
    for (const [pairKey, rawFormality] of Object.entries(bible.lockedRegisters || {})) {
      const formality = effectiveFormality(baseLang, rawFormality);
      const defaultPronoun = this.defaultPronounFor(baseLang, formality);
      this.locks.set(pairKey, {
        pairKey,
        formality,
        lockedPronoun: defaultPronoun,
        firstSeenSegmentId: "LOCALIZATION_BIBLE",
      });
    }
  }

  recordIfUnset(
    fromSpeaker: string,
    toSpeaker: string,
    formality: FormalityLevel,
    pronoun: string = "NONE",
    segId: string = "L1"
  ): void {
    const pairKey = `${fromSpeaker}->${toSpeaker}`;
    if (!this.locks.has(pairKey) && pronoun && pronoun.trim() && pronoun !== "NONE") {
      // The pronoun decides the level: a lock on "నువ్వు" is informal whatever the caller passed.
      const level = (this.targetLang && formalityOfPronoun(pronoun.trim(), this.targetLang)) || formality;
      this.locks.set(pairKey, { pairKey, formality: level, lockedPronoun: pronoun.trim(), firstSeenSegmentId: segId });
    }
  }

  getLock(fromSpeaker: string, toSpeaker: string): LockedRegisterEntry | undefined {
    return this.locks.get(`${fromSpeaker}->${toSpeaker}`);
  }

  toPromptBlock(): string {
    if (this.locks.size === 0) return "(No locked pairs yet — establish and maintain consistency)";
    return Array.from(this.locks.values())
      .map((e) => `- ${e.pairKey}: LOCKED to ${e.formality.toUpperCase()} ("${e.lockedPronoun}")`)
      .join("\n");
  }

  private defaultPronounFor(baseLang: string, formality: FormalityLevel): string {
    const groups = PRONOUN_FORMS[baseLang as RegisterLanguage];
    if (!groups) return formality;
    const exact = groups.find((g) => g.formality === formality);
    if (exact) return exact.canonical;
    // deferential → the most formal form; peer in a two-level language → the formal form.
    if (formality === "deferential" || formality === "peer") return groups[0].canonical;
    return groups[groups.length - 1].canonical;
  }

}

/**
 * Computes a stable hash of cast list and relationships for cache key invalidation.
 * Bumping the version string (e.g., stage4_v2) ensures any schema change cleanly invalidates old caches.
 */
export function computeCastHash(castList?: unknown, relationships?: unknown, version = "stage4_v2"): string {
  const h = crypto.createHash("sha256");
  h.update(version);
  if (Array.isArray(castList) && castList.length > 0) {
    h.update(JSON.stringify(castList));
  }
  if (Array.isArray(relationships) && relationships.length > 0) {
    h.update(JSON.stringify(relationships));
  }
  return h.digest("hex").slice(0, 16);
}

export const MAX_CAST = 60;
const MAX_NAME = 60;
const MAX_DESCRIPTION = 200;

function clean(value: unknown, max: number): string {
  return typeof value === "string" ? value.replace(/\s+/g, " ").trim().slice(0, max) : "";
}

/**
 * Validates an untrusted cast list from a request body. Drops entries without a name, removes
 * duplicate names (case-insensitive), caps sizes, and returns [] for anything that is not a list.
 */
export function parseCastList(raw: unknown): CastMember[] {
  if (!Array.isArray(raw)) return [];
  const seen = new Set<string>();
  const out: CastMember[] = [];
  for (const item of raw) {
    if (out.length >= MAX_CAST) break;
    if (!item || typeof item !== "object") continue;
    const r = item as Record<string, unknown>;
    const name = clean(r.name, MAX_NAME);
    if (!name || seen.has(name.toLowerCase())) continue;
    seen.add(name.toLowerCase());
    const member: CastMember = { name };
    const gender = clean(r.gender, 10).toLowerCase();
    if (gender === "male" || gender === "female") member.gender = gender;
    const description = clean(r.description, MAX_DESCRIPTION);
    if (description) member.description = description;
    const at = Number(r.appearsAtSec);
    if (r.appearsAtSec !== undefined && r.appearsAtSec !== null && Number.isFinite(at) && at >= 0) {
      member.appearsAtSec = Math.round(at * 10) / 10;
    }
    out.push(member);
  }
  return out;
}

/**
 * Validates an untrusted speaker count from a request body: a number or { min, max }.
 * Returns undefined unless at least one whole number >= 1 is present.
 */
export function parseExpectedSpeakers(raw: unknown): SpeakerCountHint | undefined {
  const whole = (v: unknown) => {
    const n = Number(v);
    return v !== undefined && v !== null && v !== "" && Number.isInteger(n) && n >= 1 ? n : undefined;
  };
  if (typeof raw === "number" || typeof raw === "string") {
    const n = whole(raw);
    return n ? { min: n, max: n } : undefined;
  }
  if (!raw || typeof raw !== "object") return undefined;
  const r = raw as Record<string, unknown>;
  const min = whole(r.min);
  const max = whole(r.max);
  if (!min && !max) return undefined;
  const hint: SpeakerCountHint = {};
  if (min) hint.min = min;
  if (max) hint.max = min && max < min ? min : max;
  return hint;
}

/**
 * Speaker count for AssemblyAI: an explicit count from the creator wins; otherwise the number of
 * speaking characters on the cast list becomes the floor (assembly-speaker-options.ts adds headroom
 * to the cap). Undefined when neither is given — AssemblyAI then gets no floor, as before.
 */
export function speakerHintFor(
  explicit: SpeakerCountHint | undefined,
  cast: CastMember[] | undefined
): SpeakerCountHint | undefined {
  if (explicit && (explicit.min || explicit.max)) return explicit;
  if (cast && cast.length > 0) return { min: cast.length };
  return undefined;
}

/** One line per character for the Gemini prompt, with stable ids C1..Cn in list order. */
export function castRoster(cast: CastMember[]): Array<{ id: string; description: string; member: CastMember }> {
  return cast.map((member, i) => {
    const parts = [member.name];
    if (member.gender) parts.push(member.gender);
    if (member.description) parts.push(member.description);
    return { id: `C${i + 1}`, description: parts.join(" — "), member };
  });
}
