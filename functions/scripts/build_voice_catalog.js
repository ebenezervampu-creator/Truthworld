#!/usr/bin/env node
/**
 * Builds the per-language ElevenLabs Voice Library catalog used for dubbing:
 *   src/pipeline/registry/library_voice_catalog.json
 *
 * Voices are NOT saved to the ElevenLabs account. Paid plans can use Voice Library voices directly by
 * voice_id, so this avoids the monthly voice-operations quota (Pro: 290, Scale/Business: 1,040) and
 * keeps the account clean. The pipeline picks native voices per language from this file and falls back
 * to the multilingual presets for anything missing or later withdrawn by its owner.
 *
 * Usage (from functions/):
 *   npm run voices:library                         # all 73 dubbing languages, 5 female + 5 male each
 *   npm run voices:library -- --languages te,hi    # only these (others in the file are kept)
 *   npm run voices:library -- --per-gender 8       # more per gender
 *   npm run voices:library -- --dry-run            # print, don't write the file
 * Then review the file (preview URLs), commit it, and deploy functions.
 *
 * Reads ELEVENLABS_API_KEY from the environment or functions/.env. Uses only GET /v1/shared-voices.
 *
 * Selection per language × gender:
 *   - no custom price (rate ≤ 1, no fiat_rate), not live-moderated,
 *   - speaks the language (library language or a verified language),
 *   - verified for the language first, then longest owner notice period (less likely to vanish
 *     suddenly), then most used in the last year,
 *   - spread across ages (young / middle_aged / old).
 */
const fs = require("fs");
const path = require("path");

const API = "https://api.elevenlabs.io";
const CATALOG_PATH = path.join(__dirname, "..", "src", "pipeline", "registry", "library_voice_catalog.json");

/** TruthWorld dubbing languages covering all 85 V4_PREMIUM_80_LANGUAGES list (tl is sent as fil). */
const DUBBING_LANGUAGES = (
  "te hi ta kn ml bn mr gu pa or as ur sa ks sd ne " +
  "en es fr de it pt nl ru pl sv no da fi cs sk el hu ro bg hr sr uk sl lt lv et ga cy ca gl eu is sq mk bs " +
  "zh ja ko id ms vi th fil my km lo ka hy az kk uz mn si " +
  "ar he fa tr ku ps " +
  "sw af zu xh ha yo ig am so"
).split(" ");
const AGES = ["child", "young", "middle_aged", "old"];

const INDIC_LANGS = new Set([
  "te", "hi", "ta", "kn", "ml", "bn", "mr", "gu", "pa", "or", "as", "ur", "sa", "ks", "sd", "ne"
]);

const WESTERN_FOREIGN_ACCENTS = /american|british|australian|irish|scottish|canadian|transatlantic|southern|latin\s*american|mexican|spanish|french|german|italian|russian|swedish/i;

function speaksLanguage(voice, lang) {
  if ((voice.language || "").toLowerCase() === lang) return true;
  return (voice.verified_languages || []).some((v) => (v.language || "").toLowerCase() === lang);
}

function isVerifiedFor(voice, lang) {
  return (voice.verified_languages || []).some((v) => (v.language || "").toLowerCase() === lang);
}

function isAffordableAndStable(voice) {
  const rate = typeof voice.rate === "number" ? voice.rate : 1;
  return rate <= 1 && (voice.fiat_rate === null || voice.fiat_rate === undefined) && !voice.live_moderation_enabled;
}

function isAccentCompatible(voice, lang) {
  const accent = (voice.accent || "").toLowerCase().trim();
  const vLang = (voice.language || "").toLowerCase().trim();

  if (INDIC_LANGS.has(lang)) {
    // Indic languages MUST NOT have any Western or Foreign accent
    if (WESTERN_FOREIGN_ACCENTS.test(accent)) return false;
    // Standard or unspecified accent is accepted if the voice is an Indic voice
    if (!accent || accent === "standard") {
      return vLang === lang || INDIC_LANGS.has(vLang);
    }
    return true;
  }

  if (lang === "en") {
    return !accent || accent === "standard" || /american|british|australian|irish|scottish|canadian|transatlantic|southern|english|indian/.test(accent);
  }

  // Non-Indic, non-English (es, fr, de, ja, zh, etc.): reject English accents
  if (/american|british|australian|irish|scottish|canadian|transatlantic|southern/.test(accent)) {
    return false;
  }
  if (!accent || accent === "standard") {
    return vLang === lang;
  }
  return true;
}

function getCandidateAge(v) {
  const raw = (v.age || "").toLowerCase();
  if (raw === "child" || raw === "kid") return "child";
  if (raw === "young") return "young";
  if (raw === "old" || raw === "senior") return "old";
  return "middle_aged";
}

/** Pure selection, exported for tests. */
function selectVoices(candidates, lang, gender, count, alreadyChosen = new Set()) {
  const eligible = candidates
    .filter((v) => (v.gender || "").toLowerCase() === gender)
    .filter((v) => !alreadyChosen.has(v.voice_id))
    .filter(isAffordableAndStable)
    .filter((v) => speaksLanguage(v, lang))
    .filter((v) => isAccentCompatible(v, lang))
    .sort(
      (a, b) =>
        Number((b.language || "").toLowerCase() === lang) - Number((a.language || "").toLowerCase() === lang) ||
        Number(isVerifiedFor(b, lang)) - Number(isVerifiedFor(a, lang)) ||
        (b.notice_period || 0) - (a.notice_period || 0) ||
        (b.usage_character_count_1y || 0) - (a.usage_character_count_1y || 0)
    );

  const byAge = new Map(AGES.map((a) => [a, eligible.filter((v) => getCandidateAge(v) === a)]));
  const picked = [];
  const names = new Set();
  const take = (v) => {
    const key = (v.name || "").toLowerCase();
    if (picked.includes(v) || names.has(key)) return false;
    picked.push(v);
    names.add(key);
    return true;
  };
  let progress = true;
  while (picked.length < count && progress) {
    progress = false;
    for (const age of AGES) {
      if (picked.length >= count) break;
      const list = byAge.get(age);
      while (list.length) {
        if (take(list.shift())) {
          progress = true;
          break;
        }
      }
    }
  }
  for (const v of eligible) {
    if (picked.length >= count) break;
    take(v);
  }
  return picked;
}

/** Catalog entry shape read by src/pipeline/services/library-voice-catalog.ts. */
function toCatalogEntry(v, lang) {
  return {
    voiceId: v.voice_id,
    publicOwnerId: v.public_owner_id,
    name: v.name,
    gender: (v.gender || "").toLowerCase(),
    age: getCandidateAge(v),
    accent: v.accent || undefined,
    verifiedForLanguage: isVerifiedFor(v, lang),
    noticePeriodDays: v.notice_period || 0,
    previewUrl: v.preview_url || undefined,
    // Timbre words for matching the original speaker (library-voice-catalog.ts → timbreTags).
    descriptive: v.descriptive || undefined,
    useCase: v.use_case || undefined,
  };
}

function parseArgs(argv) {
  const get = (flag) => {
    const i = argv.findIndex((a) => a === flag || a.startsWith(`${flag}=`));
    if (i < 0) return undefined;
    return argv[i].includes("=") ? argv[i].split("=").slice(1).join("=") : argv[i + 1];
  };
  const langs = get("--languages");
  return {
    languages: langs ? langs.split(",").map((l) => l.trim().toLowerCase()).filter(Boolean) : DUBBING_LANGUAGES,
    perGender: Math.max(1, Number(get("--per-gender")) || 5),
    dryRun: argv.includes("--dry-run"),
  };
}

async function getJson(key, url) {
  const res = await fetch(`${API}${url}`, { headers: { "xi-api-key": key } });
  const text = await res.text();
  if (!res.ok) throw new Error(`GET ${url} → HTTP ${res.status}: ${text.slice(0, 300)}`);
  return JSON.parse(text);
}

async function fetchCandidates(key, lang, gender) {
  const all = [];
  for (let page = 0; page < 3; page++) {
    const q = new URLSearchParams({
      page_size: "100",
      page: String(page),
      language: lang,
      gender,
      sort: "usage_character_count_1y",
      include_custom_rates: "false",
      include_live_moderated: "false",
    });
    const res = await getJson(key, `/v1/shared-voices?${q}`);
    all.push(...(res.voices || []));
    if (!res.has_more) break;
    await new Promise((r) => setTimeout(r, 150));
  }
  return all;
}

function readCatalog() {
  try {
    return JSON.parse(fs.readFileSync(CATALOG_PATH, "utf8"));
  } catch {
    return { version: 1, generatedAt: null, languages: {} };
  }
}

async function main() {
  const { languages, perGender, dryRun } = parseArgs(process.argv.slice(2));
  try {
    require("dotenv").config({ path: path.join(__dirname, "..", ".env") });
    require("dotenv").config({ path: path.join(__dirname, "..", ".env.local"), override: true });
  } catch (_) {}
  const key = process.env.ELEVENLABS_API_KEY;
  if (!key) {
    console.error("ELEVENLABS_API_KEY is not set (environment or functions/.env).");
    process.exit(1);
  }

  const catalog = readCatalog();
  catalog.languages = catalog.languages || {};
  const summary = [];
  for (const lang of languages) {
    const chosen = new Set();
    const entries = [];
    for (const gender of ["female", "male"]) {
      try {
        const candidates = await fetchCandidates(key, lang, gender);
        const picked = selectVoices(candidates, lang, gender, perGender, chosen);
        picked.forEach((v) => chosen.add(v.voice_id));
        entries.push(...picked.map((v) => toCatalogEntry(v, lang)));
      } catch (e) {
        console.log(`  ${lang} ${gender}: search failed (${e.message}) — keeping previous entries for this language`);
      }
    }
    const f = entries.filter((e) => e.gender === "female").length;
    const m = entries.filter((e) => e.gender === "male").length;
    summary.push({ lang, female: f, male: m });
    console.log(`${lang.padEnd(4)} female ${f}/${perGender}  male ${m}/${perGender}`);
    if (entries.length > 0) catalog.languages[lang] = entries;
  }

  const thin = summary.filter((s) => s.female < perGender || s.male < perGender);
  console.log(`\n${summary.length} languages searched; ${thin.length} have fewer than ${perGender} per gender (those use the multilingual presets for the rest).`);

  catalog.version = 1;
  catalog.generatedAt = new Date().toISOString();
  catalog.note = "Built by scripts/build_voice_catalog.js from GET /v1/shared-voices. Voices are used by voice_id without saving them to the account.";
  if (dryRun) {
    console.log("\nDry run — catalog not written.");
    return;
  }
  fs.writeFileSync(CATALOG_PATH, JSON.stringify(catalog, null, 2) + "\n");
  console.log(`\nWrote ${CATALOG_PATH}. Review the preview URLs, commit the file, then build & deploy functions.`);
}

module.exports = { selectVoices, toCatalogEntry, parseArgs, isAffordableAndStable, speaksLanguage, isAccentCompatible, DUBBING_LANGUAGES, AGES, getCandidateAge };

if (require.main === module) {
  main().catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}
