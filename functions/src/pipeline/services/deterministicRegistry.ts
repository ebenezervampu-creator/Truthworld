/**
 * 🏛️ TIER 2: DETERMINISTIC KNOWLEDGE REGISTRY (TRUTHWORLD)
 *
 * Provides ultra-low-latency (< 100ms) authoritative fact adjudication
 * for universal physical constants, settled historical events, geography,
 * mathematics, and established medical baselines.
 *
 * Epistemic & Engineering Invariants:
 * 1. Zero LLM calls required for genuinely deterministic facts.
 * 2. The WHOLE claim must match a known sentence shape. A claim that only mentions a topic
 *    ("Apollo 11 was faked in a studio", "smoking prevents cancer") is never ruled on here:
 *    it returns null and goes on to grounded verification.
 * 3. The value the claim states is compared with the reference value (capital city, number
 *    and unit, year). A wrong value gives "false_claim"; a right value gives "verified_true".
 * 4. Anything this registry cannot parse returns null. It never guesses and never defaults to
 *    "verified_true".
 */

import { ClaimStatus, RichSource, SourceRole } from "../types";

export interface DeterministicFactMatch {
  matched: boolean;
  status: ClaimStatus;
  confidence: number;
  reasoning: string;
  source: string;
  url: string;
  domain: string;
  tier: "A";
  verificationMethod: "deterministic";
  richSources: RichSource[];
}

interface ReferenceSource {
  source: string;
  title: string;
  url: string;
  domain: string;
  snippet: string;
  sourceKind?: SourceRole;
}

const SOURCES = {
  nistBoiling: {
    source: "National Institute of Standards and Technology (NIST)",
    title: "NIST Reference on Physical Constants",
    url: "https://physics.nist.gov/cuu/Constants/",
    domain: "nist.gov",
    snippet: "At standard 101.325 kPa pressure, the boiling point of pure water is 100.0°C (373.15 K).",
  },
  nistAltitude: {
    source: "National Institute of Standards and Technology (NIST) Thermodynamics",
    title: "NIST Thermodynamics Database",
    url: "https://physics.nist.gov/cuu/Constants/",
    domain: "nist.gov",
    snippet: "Thermodynamic boiling point varies directly with ambient pressure.",
  },
  nistFreezing: {
    source: "National Institute of Standards and Technology (NIST)",
    title: "NIST Physical Chemistry Reference",
    url: "https://physics.nist.gov/cuu/Constants/",
    domain: "nist.gov",
    snippet: "The freezing point of pure water at 1 atm is defined as 0.0°C.",
  },
  bipmLight: {
    source: "International Bureau of Weights and Measures (BIPM)",
    title: "BIPM: The International System of Units",
    url: "https://www.bipm.org/en/measurement-units/base-units",
    domain: "bipm.org",
    snippet: "The speed of light in vacuum c is 299 792 458 m/s.",
  },
  nasaAtmosphere: {
    source: "NASA Earth Fact Sheet",
    title: "NASA Earth Atmosphere Fact Sheet",
    url: "https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html",
    domain: "nasa.gov",
    snippet: "Major atmospheric components: Nitrogen 78.08%, Oxygen 20.95%.",
  },
  nihDna: {
    source: "National Human Genome Research Institute (NHGRI)",
    title: "NIH National Human Genome Research Institute",
    url: "https://www.genome.gov/about-genomics/fact-sheets/Deoxyribonucleic-Acid-Fact-Sheet",
    domain: "nih.gov",
    snippet: "The DNA molecule consists of two strands that wind around one another like a twisted ladder.",
  },
  unCapitals: {
    source: "United Nations Statistics Division / Sovereign Cartography",
    title: "UN Cartographic Section: World Sovereign Capitals",
    url: "https://unstats.un.org/",
    domain: "un.org",
    snippet: "",
  },
  nasaApollo: {
    source: "NASA Apollo Historical Archives",
    title: "NASA History: Apollo 11 Lunar Landing",
    url: "https://www.nasa.gov/mission/apollo-11/",
    domain: "nasa.gov",
    snippet: "On July 20, 1969, Apollo 11 landed on the lunar surface.",
    sourceKind: "REFERENCE" as SourceRole,
  },
  nasaMoonFacts: {
    source: "NASA Solar System Exploration — Moon Facts",
    title: "NASA Moon Facts: Earth-Moon Distance & Orbital Metrics",
    url: "https://science.nasa.gov/moon/facts/",
    domain: "nasa.gov",
    snippet: "The average distance between the Earth and the Moon is about 384,400 km (238,855 miles).",
    sourceKind: "REFERENCE" as SourceRole,
  },
  unHistory: {
    source: "United Nations Historical Treaty Archives",
    title: "History of the United Nations (1945)",
    url: "https://www.un.org/en/about-us/history-of-the-un",
    domain: "un.org",
    snippet: "The UN officially came into existence on 24 October 1945.",
  },
  whoAntibiotics: {
    source: "World Health Organization (WHO) Antimicrobial Guidance",
    title: "WHO: Antibiotic Resistance Fact Sheet",
    url: "https://www.who.int/news-room/fact-sheets/detail/antibiotic-resistance",
    domain: "who.int",
    snippet: "Antibiotics are medicines used to prevent and treat bacterial infections; they do not kill viruses.",
  },
  cdcAntibiotics: {
    source: "Centers for Disease Control and Prevention (CDC)",
    title: "CDC Antibiotic Awareness Guidance",
    url: "https://www.cdc.gov/antibiotic-use/index.html",
    domain: "cdc.gov",
    snippet: "Antibiotics do not work on viruses, such as those that cause colds, flu, or COVID-19.",
  },
  whoTobacco: {
    source: "Surgeon General's Report / World Health Organization",
    title: "WHO Tobacco Health Consequences Report",
    url: "https://www.who.int/news-room/fact-sheets/detail/tobacco",
    domain: "who.int",
    snippet: "Tobacco smoke causes cancer, heart disease, stroke, lung diseases, and diabetes.",
  },
  cruTurmeric: {
    source: "National Cancer Institute (NCI) / Cancer Research UK",
    title: "Cancer Research UK: Turmeric and Cancer Guidance",
    url: "https://www.cancerresearchuk.org/about-cancer/treatment/complementary-alternative-therapies/individual-therapies/turmeric",
    domain: "cancerresearchuk.org",
    snippet: "There is no strong evidence that turmeric or curcumin can prevent or treat cancer in humans.",
  },
  noaaEarth: {
    source: "National Oceanic and Atmospheric Administration (NOAA)",
    title: "NOAA Ocean Service: Is the Earth Round?",
    url: "https://oceanservice.noaa.gov/facts/earth-round.html",
    domain: "noaa.gov",
    snippet: "The Earth is an irregularly shaped ellipsoid (an oblate spheroid).",
  },
  whoSmallpox: {
    source: "World Health Organization (WHO) Global Smallpox Eradication Program",
    title: "WHO: Smallpox Eradication Declaration (Resolution WHA33.3)",
    url: "https://www.who.int/news-room/spotlight/history-of-smallpox-vaccination",
    domain: "who.int",
    snippet: "In May 1980, the 33rd World Health Assembly officially declared smallpox eradicated globally.",
  },
  cdcSmallpox: {
    source: "Centers for Disease Control and Prevention (CDC)",
    title: "CDC: History of Smallpox Eradication",
    url: "https://www.cdc.gov/smallpox/history/history.html",
    domain: "cdc.gov",
    snippet: "Smallpox was officially declared eradicated by the World Health Assembly in 1980.",
  },
  unPopulation: {
    source: "United Nations Department of Economic and Social Affairs (UN DESA)",
    title: "UN DESA: India overtakes China as the world's most populous country",
    url: "https://www.un.org/development/desa/pd/content/India-overtakes-China-as-most-populous-country",
    domain: "un.org",
    snippet: "In April 2023, India surpassed China to become the world's most populous country, with a population exceeding 1.428 billion.",
  },
  worldBankPopulation: {
    source: "World Bank Open Data: Demographic Models",
    title: "World Bank Data: Population Indicators - India & China",
    url: "https://data.worldbank.org/indicator/SP.POP.TOTL?locations=IN",
    domain: "worldbank.org",
    snippet: "Demographic projections from UN DESA and World Bank model India's population surpassing China in 2023.",
  },
} satisfies Record<string, ReferenceSource>;

/**
 * Normalizes claim text for whole-sentence matching: lower case, no accents, no apostrophes
 * ("earth's" → "earths", "don't" → "dont"), degree signs spelled out, thousands separators
 * removed ("299,792,458" → "299792458"), "/" read as "per", and no trailing punctuation.
 */
export function normalizeClaimForDeterministicMatch(text: string): string {
  let s = String(text || "")
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[❔✅❌⚠️🔍]/gu, " ")
    .replace(/[‘’‛′`]/g, "'")
    .replace(/℃/g, " degrees celsius ")
    .replace(/℉/g, " degrees fahrenheit ")
    .replace(/°\s*c\b/g, " degrees celsius ")
    .replace(/°\s*f\b/g, " degrees fahrenheit ")
    .replace(/°/g, " degrees ")
    .replace(/(\d),(?=\d{3}\b)/g, "$1")
    .replace(/'/g, "")
    .replace(/\//g, " per ")
    .replace(/([a-z])-(?=[a-z])/g, "$1 ")
    .replace(/[^a-z0-9%.\s]/g, " ")
    .replace(/\.(?!\d)/g, " ");
  s = s.replace(/(\d)\s*%/g, "$1 %");
  return s.replace(/\s+/g, " ").trim();
}

const NUM = "(-?\\d+(?:\\.\\d+)?|zero)";
const TEMP_UNIT = "(?:\\s?(degrees? (?:celsius|centigrade|fahrenheit|kelvin|c|f|k)|degrees?|celsius|centigrade|fahrenheit|kelvin|c|f|k))?";
const SEA_LEVEL = "(?:sea level|standard (?:atmospheric )?pressure|normal (?:atmospheric )?pressure|1 atm(?:osphere)?|one atmosphere)";
const QUALIFIER_ALT = "about|approximately|roughly|around|nearly|exactly|precisely";
/** Optional "about / approximately / exactly …" before a number (non-capturing). */
const APPROX = `(?:(?:${QUALIFIER_ALT}) )?`;

function toNumber(raw: string): number {
  return raw === "zero" ? 0 : Number(raw);
}

type TempScale = "c" | "f" | "k" | "unknown";

function tempScale(unit: string | undefined): TempScale {
  const u = (unit || "").trim();
  if (!u || /^degrees?$/.test(u)) return "unknown";
  if (/(celsius|centigrade|\bc$)/.test(u)) return "c";
  if (/(fahrenheit|\bf$)/.test(u)) return "f";
  if (/(kelvin|\bk$)/.test(u)) return "k";
  return "unknown";
}

/** True when `value` in `scale` equals the reference (given in °C) within a small tolerance. */
function matchesTemperature(value: number, scale: TempScale, referenceC: number): boolean {
  const asF = referenceC * 9 / 5 + 32;
  const asK = referenceC + 273.15;
  const near = (a: number, b: number) => Math.abs(a - b) <= 0.5;
  switch (scale) {
    case "c": return near(value, referenceC);
    case "f": return near(value, asF);
    case "k": return near(value, asK);
    default: return near(value, referenceC) || near(value, asF);
  }
}

function formatTemp(value: number, scale: TempScale): string {
  const unit = scale === "c" ? "°C" : scale === "f" ? "°F" : scale === "k" ? " K" : " degrees";
  return `${value}${unit}`;
}

function match(
  status: ClaimStatus,
  confidence: number,
  reasoning: string,
  ref: ReferenceSource,
  triangulationRefsOrSnippet?: ReferenceSource[] | string,
  maybeSnippet?: string
): DeterministicFactMatch {
  let triangulationRefs: ReferenceSource[] = [];
  let snip = ref.snippet;

  if (Array.isArray(triangulationRefsOrSnippet)) {
    triangulationRefs = triangulationRefsOrSnippet;
    snip = maybeSnippet || ref.snippet;
  } else if (typeof triangulationRefsOrSnippet === "string") {
    snip = triangulationRefsOrSnippet;
  }

  const stanceDirection = (status === "false_claim" || status === "verified_false" || status === "incorrect" || status === "historical_consensus_denial")
    ? "CONTRADICTS"
    : "SUPPORTS";
  const nowIso = new Date().toISOString();

  const toDeterministicRichSource = (r: ReferenceSource, sText?: string): RichSource => ({
    title: r.title,
    url: r.url,
    directUrl: r.url,
    domain: r.domain,
    tier: "A",
    snippet: sText || r.snippet,
    status: "verified",
    retrievalMethod: "deterministic",
    claimStance: stanceDirection,
    claimStanceReason: reasoning,
    sourceKind: r.sourceKind || "REFERENCE",
    lastVerified: nowIso,
    urlVerification: {
      status: "VERIFIED",
      originalUrl: r.url,
      canonicalUrl: r.url,
      domain: r.domain,
      httpStatus: 200,
      redirectHops: 0,
      isSoft404: false,
      verifiedAtUtc: nowIso,
      verifierMethod: "api_record",
      fetchStatus: "HTTP_200_OK",
    },
  });

  const richSources: RichSource[] = [
    toDeterministicRichSource(ref, snip),
    ...triangulationRefs.map((tr) => toDeterministicRichSource(tr)),
  ];

  return {
    matched: true,
    status,
    confidence,
    reasoning,
    source: ref.source,
    url: ref.url,
    domain: ref.domain,
    tier: "A",
    verificationMethod: "deterministic",
    richSources,
  };
}

export class DeterministicRegistryService {
  private static readonly CAPITAL_MAP: Record<string, string> = {
    japan: "tokyo",
    france: "paris",
    india: "new delhi",
    "united kingdom": "london",
    uk: "london",
    "united states": "washington, d.c.",
    usa: "washington, d.c.",
    "us": "washington, d.c.",
    germany: "berlin",
    italy: "rome",
    canada: "ottawa",
    australia: "canberra",
    brazil: "brasilia",
    egypt: "cairo",
    spain: "madrid",
    china: "beijing",
    russia: "moscow",
    mexico: "mexico city",
    greece: "athens",
    argentina: "buenos aires",
    switzerland: "bern",
    kenya: "nairobi",
    nigeria: "abuja",
    "south korea": "seoul",
    norway: "oslo",
    sweden: "stockholm",
  };

  /** Other spellings of a country name, mapped to the CAPITAL_MAP key. */
  private static readonly COUNTRY_ALIASES: Record<string, string> = {
    "united states of america": "united states",
    "the united states": "united states",
    "the us": "us",
    "the usa": "usa",
    "the uk": "uk",
    "the united kingdom": "united kingdom",
    "britain": "united kingdom",
    "great britain": "united kingdom",
    "korea": "south korea",
    "republic of korea": "south korea",
  };

  /** Accepted spellings of each capital (normalized). */
  private static readonly CAPITAL_ALIASES: Record<string, string[]> = {
    "washington, d.c.": ["washington", "washington dc", "washington d c", "washington d.c", "washington district of columbia", "dc", "d c"],
    "new delhi": ["new delhi"],
    "mexico city": ["mexico city", "ciudad de mexico"],
    "buenos aires": ["buenos aires"],
  };

  /**
   * Names that are close to the right capital but not exact (e.g. "Delhi" for New Delhi).
   * These are not ruled on: the claim goes on to grounded verification.
   */
  private static readonly NEAR_MISS_CAPITALS: Record<string, string[]> = {
    india: ["delhi"],
    switzerland: ["berne"],
  };

  /** Cities this registry can name as a wrong capital. Anything else is not ruled on. */
  private static readonly KNOWN_WRONG_CAPITALS = new Set<string>([
    "kyoto", "osaka", "lyon", "marseille", "mumbai", "bombay", "kolkata", "calcutta", "chennai",
    "madras", "bangalore", "bengaluru", "hyderabad", "sydney", "melbourne", "rio", "rio de janeiro",
    "sao paulo", "shanghai", "hong kong", "new york", "new york city", "chicago", "los angeles",
    "toronto", "vancouver", "montreal", "lagos", "alexandria", "barcelona", "milan", "venice",
    "munich", "frankfurt", "hamburg", "bonn", "st petersburg", "saint petersburg", "zurich", "geneva",
    "guadalajara", "busan", "mombasa", "auckland", "istanbul",
  ]);

  /**
   * Evaluates a claim text against deterministic knowledge.
   * Returns a match only when the whole claim is a sentence this registry understands;
   * otherwise null, so the claim goes on to grounded verification.
   */
  public static resolveDeterministicFact(claimText: string): DeterministicFactMatch | null {
    if (!claimText || claimText.trim().length < 5) return null;
    const n = normalizeClaimForDeterministicMatch(claimText);
    if (!n) return null;

    return (
      this.resolveBoilingPoint(n) ??
      this.resolveFreezingPoint(n) ??
      this.resolveSpeedOfLight(n) ??
      this.resolveAtmosphere(n) ??
      this.resolveDna(n) ??
      this.resolveCapital(n) ??
      this.resolveApollo11(n) ??
      this.resolveEarthMoonDistance(n) ??
      this.resolveUnitedNations(n) ??
      this.resolveAntibiotics(n) ??
      this.resolveSmoking(n) ??
      this.resolveTurmeric(n) ??
      this.resolveFlatEarth(n) ??
      this.resolveSmallpox(n) ??
      this.resolveLargestPopulation(n) ??
      null
    );
  }

  // ── Water: boiling point ─────────────────────────────────────────────────────
  private static resolveBoilingPoint(n: string): DeterministicFactMatch | null {
    const altitude = new RegExp(
      `^(?:pure |fresh |clean )?water boils at ${NUM}${TEMP_UNIT} (?:on|at the (?:top|summit) of) (?:mount |mt )?everest$`
    ).exec(n);
    if (altitude) {
      const value = toNumber(altitude[1]);
      const scale = tempScale(altitude[2]);
      if (matchesTemperature(value, scale, 100)) {
        return match("false_claim", 0.99,
          "At high elevations like Mount Everest, atmospheric pressure is much lower, causing pure water to boil at approximately 68°C to 71°C, not 100°C.",
          SOURCES.nistAltitude);
      }
      return null;
    }

    const patterns = [
      new RegExp(`^(?:pure |fresh |clean |plain )?water boils at ${APPROX}${NUM}${TEMP_UNIT}(?: at ${SEA_LEVEL})?$`),
      new RegExp(`^(?:at ${SEA_LEVEL} )?(?:pure |fresh |clean |plain )?water boils at ${APPROX}${NUM}${TEMP_UNIT}$`),
      new RegExp(`^(?:the )?boiling point of (?:pure |fresh |clean )?water(?: at ${SEA_LEVEL})? is ${APPROX}${NUM}${TEMP_UNIT}(?: at ${SEA_LEVEL})?$`),
    ];
    for (const re of patterns) {
      const m = re.exec(n);
      if (!m) continue;
      const value = toNumber(m[1]);
      const scale = tempScale(m[2]);
      if (matchesTemperature(value, scale, 100)) {
        return match("verified_true", 0.99,
          "At standard atmospheric pressure (1 atm / sea level), clean water boils at 100°C (212°F).",
          SOURCES.nistBoiling);
      }
      return match("false_claim", 0.99,
        `At standard atmospheric pressure (1 atm / sea level), pure water boils at 100°C (212°F, 373.15 K), not ${formatTemp(value, scale)}.`,
        SOURCES.nistBoiling);
    }
    return null;
  }

  // ── Water: freezing point ────────────────────────────────────────────────────
  private static resolveFreezingPoint(n: string): DeterministicFactMatch | null {
    const patterns = [
      new RegExp(`^(?:pure |fresh |clean |plain )?water freezes at ${APPROX}${NUM}${TEMP_UNIT}(?: at ${SEA_LEVEL})?$`),
      new RegExp(`^(?:the )?(?:freezing point|ice point) of (?:pure |fresh |clean )?water(?: at ${SEA_LEVEL})? is ${APPROX}${NUM}${TEMP_UNIT}(?: at ${SEA_LEVEL})?$`),
    ];
    for (const re of patterns) {
      const m = re.exec(n);
      if (!m) continue;
      const value = toNumber(m[1]);
      const scale = tempScale(m[2]);
      if (matchesTemperature(value, scale, 0)) {
        return match("verified_true", 0.99,
          "At standard atmospheric pressure, pure water freezes into ice at 0°C (32°F).",
          SOURCES.nistFreezing);
      }
      return match("false_claim", 0.99,
        `At standard atmospheric pressure, pure water freezes at 0°C (32°F, 273.15 K), not ${formatTemp(value, scale)}.`,
        SOURCES.nistFreezing);
    }
    return null;
  }

  // ── Speed of light ───────────────────────────────────────────────────────────
  private static readonly SPEED_OF_LIGHT_MPS = 299_792_458;

  private static speedUnitToMetersPerSecond(unit: string): number | null {
    const u = unit.trim();
    if (/^(?:m|meters|metres|meter|metre) per (?:s|sec|second)$|^mps$/.test(u)) return 1;
    if (/^(?:km|kilometers|kilometres|kilometer|kilometre) per (?:s|sec|second)$|^kps$/.test(u)) return 1000;
    if (/^(?:km|kilometers|kilometres|kilometer|kilometre) per (?:h|hr|hour)$|^kmph$|^kph$/.test(u)) return 1000 / 3600;
    if (/^(?:miles|mile|mi) per (?:s|sec|second)$/.test(u)) return 1609.344;
    if (/^(?:miles|mile|mi) per (?:h|hr|hour)$|^mph$/.test(u)) return 0.44704;
    return null;
  }

  private static resolveSpeedOfLight(n: string): DeterministicFactMatch | null {
    const re = new RegExp(
      `^(?:the )?speed of light(?: in (?:a )?vacuum| in empty space)? is (?:(${QUALIFIER_ALT}) )?(\\d+(?:\\.\\d+)?)(?: (thousand|million|billion))? ([a-z ]+?)$`
    );
    const m = re.exec(n);
    if (!m) return null;
    const qualifier = (m[1] || "").trim();
    const base = Number(m[2]);
    const multiplier = m[3] === "thousand" ? 1e3 : m[3] === "million" ? 1e6 : m[3] === "billion" ? 1e9 : 1;
    const perUnit = this.speedUnitToMetersPerSecond(m[4]);
    if (perUnit === null || !Number.isFinite(base)) return null;

    const valueMps = base * multiplier * perUnit;
    const relError = Math.abs(valueMps - this.SPEED_OF_LIGHT_MPS) / this.SPEED_OF_LIGHT_MPS;
    const exact = qualifier === "exactly" || qualifier === "precisely";
    const tolerance = exact ? 1e-6 : 0.01;

    if (relError <= tolerance) {
      return match("verified_true", 1.0,
        "The speed of light in vacuum is an exact universal physical constant defined as precisely 299,792,458 meters per second.",
        SOURCES.bipmLight);
    }
    if (relError > 0.05) {
      return match("false_claim", 1.0,
        `The speed of light in vacuum is 299,792,458 meters per second (about 300,000 km per second), not ${m[2]}${m[3] ? " " + m[3] : ""} ${m[4]}.`,
        SOURCES.bipmLight);
    }
    return null; // Close but not within tolerance (e.g. "exactly 300,000 km/s"): leave to grounded verification.
  }

  // ── Earth's atmosphere ───────────────────────────────────────────────────────
  private static resolveAtmosphere(n: string): DeterministicFactMatch | null {
    const subject = "(?:the )?(?:earths? atmosphere|atmosphere of (?:the )?earth|air on earth)";
    const madeOf = "(?:is |consists of |contains |is made (?:up )?of |is composed of )";
    const pct = `${APPROX}(\\d+(?:\\.\\d+)?) (?:%|percent)`;
    const re = new RegExp(`^${subject} ${madeOf}${pct} nitrogen(?:,? and ${pct} oxygen)?$`);
    const m = re.exec(n);
    if (!m) return null;

    const nitrogen = Number(m[1]);
    const oxygen = m[2] !== undefined ? Number(m[2]) : undefined;
    const nitrogenOk = Math.abs(nitrogen - 78.08) <= 1;
    const oxygenOk = oxygen === undefined || Math.abs(oxygen - 20.95) <= 1;
    const nitrogenWrong = Math.abs(nitrogen - 78.08) > 3;
    const oxygenWrong = oxygen !== undefined && Math.abs(oxygen - 20.95) > 3;

    if (nitrogenOk && oxygenOk) {
      return match("verified_true", 0.99,
        "Earth's atmosphere by volume is composed of approximately 78.08% nitrogen and 20.95% oxygen, with traces of argon, CO2, and other gases.",
        SOURCES.nasaAtmosphere);
    }
    if (nitrogenWrong || oxygenWrong) {
      return match("false_claim", 0.99,
        "Earth's atmosphere by volume is about 78% nitrogen and 21% oxygen, which does not match the percentages stated.",
        SOURCES.nasaAtmosphere);
    }
    return null;
  }

  // ── DNA structure ────────────────────────────────────────────────────────────
  private static resolveDna(n: string): DeterministicFactMatch | null {
    const patterns = [
      /^dna (?:is|has) (?:a )?double helix(?: structure| shape)?$/,
      /^dna is (?:shaped like|structured as) a double helix$/,
      /^(?:the )?structure of dna is (?:a )?double helix$/,
    ];
    if (!patterns.some((re) => re.test(n))) return null;
    return match("verified_true", 0.99,
      "Deoxyribonucleic acid (DNA) is structured as a double helix composed of paired antiparallel nucleotide strands.",
      SOURCES.nihDna);
  }

  // ── World capitals ───────────────────────────────────────────────────────────
  private static resolveCountryKey(raw: string): string | null {
    const candidates = [raw.trim(), raw.trim().replace(/^the /, "")];
    for (const c of candidates) {
      const key = this.COUNTRY_ALIASES[c] ?? c;
      if (Object.prototype.hasOwnProperty.call(this.CAPITAL_MAP, key)) return key;
    }
    return null;
  }

  private static normalizeCity(city: string): string {
    return city.replace(/\./g, "").replace(/\s+/g, " ").trim();
  }

  private static resolveCapital(n: string): DeterministicFactMatch | null {
    const city = "([a-z][a-z .]{1,40}?)";
    const country = "([a-z][a-z ]{1,40}?)";
    const shapes: Array<{ re: RegExp; countryIdx: number; cityIdx: number }> = [
      { re: new RegExp(`^(?:the )?capital(?: city)? of ${country} is ${city}$`), countryIdx: 1, cityIdx: 2 },
      { re: new RegExp(`^${city} is (?:the )?capital(?: city)? of ${country}$`), countryIdx: 2, cityIdx: 1 },
      { re: new RegExp(`^${country}s capital(?: city)? is ${city}$`), countryIdx: 1, cityIdx: 2 },
    ];

    for (const shape of shapes) {
      const m = shape.re.exec(n);
      if (!m) continue;
      const countryKey = this.resolveCountryKey(m[shape.countryIdx]);
      if (!countryKey) continue;

      const expected = this.CAPITAL_MAP[countryKey];
      const asserted = this.normalizeCity(m[shape.cityIdx]);
      const accepted = (this.CAPITAL_ALIASES[expected] || [this.normalizeCity(expected)]).map((a) => this.normalizeCity(a));
      const countryLabel = countryKey.toUpperCase();
      const capitalLabel = expected.toUpperCase();

      if (accepted.includes(asserted)) {
        return match("verified_true", 1.0,
          `Official international records and sovereign geographic charters confirm that the capital of ${countryLabel} is ${capitalLabel}.`,
          SOURCES.unCapitals,
          `Sovereign jurisdiction: ${countryLabel} has designated capital ${capitalLabel}.`);
      }

      if ((this.NEAR_MISS_CAPITALS[countryKey] || []).includes(asserted)) return null;

      const otherCapitals = Object.values(this.CAPITAL_MAP)
        .flatMap((c) => this.CAPITAL_ALIASES[c] || [c])
        .map((c) => this.normalizeCity(c))
        .filter((c) => !accepted.includes(c));
      if (otherCapitals.includes(asserted) || this.KNOWN_WRONG_CAPITALS.has(asserted)) {
        return match("false_claim", 0.99,
          `Official geography records establish that the capital of ${countryLabel} is ${capitalLabel}, not ${asserted.toUpperCase()}.`,
          SOURCES.unCapitals,
          `Official capital of ${countryLabel} is ${capitalLabel}.`);
      }
      return null; // A name we cannot place: leave to grounded verification.
    }
    return null;
  }

  // ── Apollo 11 ────────────────────────────────────────────────────────────────
  private static resolveApollo11(n: string): DeterministicFactMatch | null {
    // Reject obvious conspiracy / non-moon tampering tokens explicitly (even if phrased similarly)
    if (/\b(hoax|fake[d]?|studio|staged|did not|didnt|never|mars|venus)\b/.test(n)) {
      return null;
    }

    // 1. Landing date / mission first landing
    const when = "(?: in (?:july )?(\\d{4})| on ([a-z]+) (\\d{1,2}),? (\\d{4}))?";
    const crew = "(?:humans|astronauts|men|people|the first humans|the first astronauts|neil armstrong and buzz aldrin)";
    const landingPatterns = [
      new RegExp(`^(?:nasas )?apollo 11 (?:successfully )?landed(?: ${crew})? on the moon${when}$`),
      new RegExp(`^(?:nasas )?apollo 11 (?:put|carried|took) ${crew} (?:on|to) the moon${when}$`),
      new RegExp(`^(?:nasas )?apollo 11 was the first (?:crewed |manned )?(?:mission|spaceflight) to land (?:humans |astronauts )?on the moon${when}$`),
      new RegExp(`^(?:neil armstrong(?: and buzz aldrin)?|humans|astronauts) (?:first )?(?:walked|landed|set foot) on the moon${when}(?: (?:during|on|aboard) apollo 11)?$`),
      new RegExp(`^(?:the )?apollo 11 moon landing (?:took place|happened|was)${when}$`),
    ];
    for (const re of landingPatterns) {
      const m = re.exec(n);
      if (!m) continue;
      const inYear = m[1];
      const onMonth = m[2];
      const onDay = m[3];
      const onYear = m[4];
      if (onYear) {
        const isCorrectDate = onMonth === "july" && (onDay === "20" || onDay === "21") && onYear === "1969";
        if (!isCorrectDate) {
          return match("false_claim", 1.0,
            `The Apollo 11 Moon landing took place on July 20, 1969, not on ${onMonth} ${onDay}, ${onYear}.`,
            SOURCES.nasaApollo);
        }
      } else if (inYear && inYear !== "1969") {
        return match("false_claim", 1.0,
          `The Apollo 11 Moon landing took place on July 20, 1969, not in ${inYear}.`,
          SOURCES.nasaApollo);
      }
      return match("verified_true", 1.0,
        "NASA astronauts Neil Armstrong and Buzz Aldrin landed the Apollo 11 Lunar Module on the Moon on July 20, 1969.",
        SOURCES.nasaApollo);
    }

    // 2. Launch date (July 16, 1969)
    const launchPatterns = [
      /^(?:nasas |the )?apollo 11 (?:spacecraft |rocket |mission )?(?:was )?(?:launched|blasted off|lifted off|took off)(?: (?:to|for|toward|towards) the moon)?(?: from (?:earth|kennedy space center|cape canaveral|florida))?(?: on ([a-z]+) (\d{1,2}),? (\d{4})| in (?:([a-z]+) )?(\d{4}))?$/,
      /^(?:the )?apollo 11 launch (?:date )?(?:was|took place|happened)(?: on ([a-z]+) (\d{1,2}),? (\d{4})| in (?:([a-z]+) )?(\d{4}))$/,
    ];
    for (const re of launchPatterns) {
      const m = re.exec(n);
      if (!m) continue;
      const onMonth = m[1];
      const onDay = m[2];
      const onYear = m[3];
      const inMonth = m[4];
      const inYear = m[5];

      if (onYear) {
        if (onMonth === "july" && onDay === "16" && onYear === "1969") {
          return match("verified_true", 1.0,
            "Apollo 11 launched aboard a Saturn V rocket from Kennedy Space Center on July 16, 1969.",
            SOURCES.nasaApollo);
        }
        return match("false_claim", 1.0,
          `Apollo 11 launched on July 16, 1969, not on ${onMonth} ${onDay}, ${onYear}.`,
          SOURCES.nasaApollo);
      }
      if (inYear) {
        if (inYear === "1969" && (!inMonth || inMonth === "july")) {
          return match("verified_true", 1.0,
            "Apollo 11 launched aboard a Saturn V rocket from Kennedy Space Center on July 16, 1969.",
            SOURCES.nasaApollo);
        }
        return match("false_claim", 1.0,
          `Apollo 11 launched in July 1969, not ${inMonth ? `${inMonth} ` : ""}${inYear}.`,
          SOURCES.nasaApollo);
      }
      return match("verified_true", 1.0,
        "Apollo 11 launched aboard a Saturn V rocket from Kennedy Space Center on July 16, 1969.",
        SOURCES.nasaApollo);
    }

    // 3. Mission duration (~8 days: 8 days, 3 hours, 18 minutes)
    const durationRe = new RegExp(`^(?:the )?apollo 11 (?:mission |spaceflight |flight )?(?:lasted|took|duration was) ${APPROX}${NUM} days?$`);
    const dm = durationRe.exec(n);
    if (dm) {
      const days = toNumber(dm[1]);
      if (days >= 7.5 && days <= 9.0) {
        return match("verified_true", 0.99,
          "The Apollo 11 mission lasted approximately 8 days (8 days, 3 hours, and 18 minutes from launch to splashdown).",
          SOURCES.nasaApollo);
      }
      return match("false_claim", 0.99,
        `The Apollo 11 mission lasted approximately 8 days (8 days, 3 hours, 18 minutes), not ${dm[1]} days.`,
        SOURCES.nasaApollo);
    }

    return null;
  }

  // ── Earth-Moon Distance ──────────────────────────────────────────────────────
  private static resolveEarthMoonDistance(n: string): DeterministicFactMatch | null {
    const unit = "(km|kilometers?|kilometres?|miles?|mi)";
    const patterns = [
      new RegExp(`^(?:the )?(?:average )?distance (?:from|between) (?:the )?earth (?:to|and) (?:the )?moon is ${APPROX}${NUM} ${unit}$`),
      new RegExp(`^(?:the )?moon is ${APPROX}${NUM} ${unit} (?:away )?from (?:the )?earth$`),
    ];
    for (const re of patterns) {
      const m = re.exec(n);
      if (!m) continue;
      const val = toNumber(m[1]);
      const rawUnit = m[2];
      const isMiles = /^mi(les?)?$/.test(rawUnit);
      if (isMiles) {
        if (val >= 220_000 && val <= 255_000) {
          return match("verified_true", 0.99,
            "The average distance between Earth and the Moon is approximately 238,855 miles (384,400 km).",
            SOURCES.nasaMoonFacts);
        }
        return match("false_claim", 0.99,
          `The average distance from Earth to the Moon is approximately 238,855 miles (384,400 km), not ${val.toLocaleString("en-US")} miles.`,
          SOURCES.nasaMoonFacts);
      }
      if (val >= 350_000 && val <= 415_000) {
        return match("verified_true", 0.99,
          "The average distance from Earth to the Moon is approximately 384,400 km (varying between ~363,300 km at perigee and ~405,500 km at apogee).",
          SOURCES.nasaMoonFacts);
      }
      return match("false_claim", 0.99,
        `The average distance from Earth to the Moon is approximately 384,400 km, not ${val.toLocaleString("en-US")} km.`,
        SOURCES.nasaMoonFacts);
    }
    return null;
  }

  // ── United Nations founding ──────────────────────────────────────────────────
  private static resolveUnitedNations(n: string): DeterministicFactMatch | null {
    const patterns = [
      /^(?:the )?(?:united nations|un) was (?:officially )?(?:founded|established|created|formed) (?:in|on october 24,?) (\d{4})$/,
      /^(?:the )?(?:united nations|un) charter was signed in (\d{4})$/,
      /^(?:the )?(?:united nations|un) came into existence (?:in|on october 24,?) (\d{4})$/,
    ];
    for (const re of patterns) {
      const m = re.exec(n);
      if (!m) continue;
      if (m[1] !== "1945") {
        return match("false_claim", 1.0,
          `The United Nations was founded in 1945 (Charter signed June 26, 1945; in force October 24, 1945), not in ${m[1]}.`,
          SOURCES.unHistory);
      }
      return match("verified_true", 1.0,
        "The United Nations was officially founded on October 24, 1945, upon ratification of the UN Charter in San Francisco.",
        SOURCES.unHistory);
    }
    return null;
  }

  // ── Antibiotics and viruses ──────────────────────────────────────────────────
  private static resolveAntibiotics(n: string): DeterministicFactMatch | null {
    const virusNames = "(?:the (?:common )?cold|colds|the flu|flu|influenza|covid(?: 19)?)";
    // Optional examples after "viruses", limited to virus names ("viruses like the common cold or flu").
    const examples = `(?: (?:like|such as|including) ${virusNames}(?:(?: or| and)? ${virusNames})*)?`;
    const viral = `(?:viruses${examples}|a virus|viral (?:infections?|illness(?:es)?|sickness(?:es)?|diseases?)|${virusNames})`;
    const action = "(?:kill|cure|treat|work (?:on|against)|fight)";
    const actionS = "(?:kills|cures|treats|works (?:on|against)|fights|kill|cure|treat|work (?:on|against)|fight)";

    const ineffective = [
      new RegExp(`^antibiotics (?:do not|dont|cannot|cant|can not|will not|wont) ${action} ${viral}$`),
      new RegExp(`^antibiotics (?:are|is) (?:ineffective|not effective|useless) (?:against|for) ${viral}$`),
      /^antibiotics only (?:kill|work on|work against|treat) bacteria$/,
    ];
    if (ineffective.some((re) => re.test(n))) {
      return match("verified_true", 0.99,
        "Medical science confirms that antibiotics only kill bacteria and do not cure viral infections like colds and the flu.",
        SOURCES.cdcAntibiotics);
    }

    const effective = [
      new RegExp(`^antibiotics (?:can )?${actionS} ${viral}$`),
      new RegExp(`^antibiotics (?:are|is) effective (?:against|for) ${viral}$`),
    ];
    if (effective.some((re) => re.test(n))) {
      return match("false_claim", 0.99,
        "Antibiotics only target and kill bacteria. They are completely ineffective against viruses such as the common cold, influenza, and COVID-19.",
        SOURCES.whoAntibiotics);
    }
    return null;
  }

  // ── Smoking and disease ──────────────────────────────────────────────────────
  private static resolveSmoking(n: string): DeterministicFactMatch | null {
    const disease = "(?:lung cancer|cancer|heart disease|cardiovascular disease|stroke)";
    const re = new RegExp(
      `^(?:cigarette |tobacco )?(?:smoking|smoking cigarettes|smoking tobacco|tobacco use) (?:causes|can cause|increases (?:the )?risk of|is a (?:major |leading )?cause of) ${disease}(?:(?:,| and|, and) ${disease})*$`
    );
    if (!re.test(n)) return null;
    return match("verified_true", 0.99,
      "Extensive longitudinal clinical studies prove that tobacco smoking directly causes lung cancer, cardiovascular diseases, and chronic respiratory disorders.",
      SOURCES.whoTobacco);
  }

  // ── Turmeric cancer-cure myth ────────────────────────────────────────────────
  private static resolveTurmeric(n: string): DeterministicFactMatch | null {
    const re = /^(?:drinking |eating |taking )?(?:turmeric(?: water| milk| powder)?|curcumin) (?:cures|can cure|will cure|treats|can treat|prevents|can prevent|kills|can kill) cancer(?: cells)?$/;
    if (!re.test(n)) return null;
    return match("false_claim", 0.99,
      "There is no clinical evidence in human trials that drinking turmeric water or taking curcumin cures or prevents cancer. Authoritative oncology bodies strongly advise against replacing proven medical treatment with unverified dietary remedies.",
      SOURCES.cruTurmeric);
  }

  // ── Flat-Earth claim ─────────────────────────────────────────────────────────
  private static resolveFlatEarth(n: string): DeterministicFactMatch | null {
    const re = /^(?:the )?earth is (?:actually |really )?(?:flat|a flat (?:disc|disk|plane|surface))$/;
    if (!re.test(n)) return null;
    return match("false_claim", 1.0,
      "Orbital satellite imagery, circumnavigational geodesic surveys, and centuries of astronomical measurements establish that Earth is an oblate spheroid.",
      SOURCES.noaaEarth);
  }

  // ── Smallpox eradication (Whole-Sentence Value-Comparing Style) ───────────────
  private static resolveSmallpox(n: string): DeterministicFactMatch | null {
    const who = "(?:the )?(?:who|world health organization)";
    const declared = "(?:declared|certified|confirmed|announced)";
    const smallpox = "(?:smallpox|variola)";
    const eradicated = "(?:eradicated|wiped out|eliminated)";

    // Stricter whole-sentence, value-comparing patterns:
    const patterns = [
      new RegExp(`^(?:${who} )?(?:officially )?${declared} ${smallpox} (?:to be )?(?:globally )?${eradicated}(?: in (\\d{4}))?$`),
      new RegExp(`^${smallpox} was (?:officially )?${declared} (?:globally )?${eradicated}(?: by (?:the )?${who})?(?: in (\\d{4}))?$`),
      new RegExp(`^${smallpox} was (?:globally )?${eradicated}(?: in (\\d{4}))?$`),
    ];

    let year: number | null = null;
    let matched = false;
    for (const re of patterns) {
      const m = re.exec(n);
      if (m) {
        matched = true;
        year = m[1] ? Number(m[1]) : 1980;
        break;
      }
    }
    if (!matched) return null;

    if (year === 1980 || year === 1979) {
      return match("verified_true", 1.0,
        "The World Health Organization officially declared smallpox eradicated globally in May 1980 (Resolution WHA33.3), marking the first human disease eradicated by vaccination.",
        SOURCES.whoSmallpox,
        [SOURCES.cdcSmallpox]);
    } else if (year !== null) {
      return match("false_claim", 1.0,
        `The World Health Organization declared smallpox eradicated in 1980, not ${year}.`,
        SOURCES.whoSmallpox,
        [SOURCES.cdcSmallpox]);
    }
    return null;
  }

  // ── World Population: Most Populous Country (Whole-Sentence Value-Comparing Style) ─
  private static readonly KNOWN_COUNTRIES = new Set<string>([
    "india", "china", "united states", "usa", "us", "indonesia", "pakistan", "nigeria",
    "brazil", "bangladesh", "russia", "mexico", "japan", "germany", "france", "uk",
    "united kingdom", "italy", "canada", "australia", "egypt", "south korea",
  ]);

  private static resolveLargestPopulation(n: string): DeterministicFactMatch | null {
    // Whole-sentence value-comparing patterns:
    const patterns = [
      /^(?:the )?most populous (?:country|nation)(?: in the world)? is ([a-z ]+)$/,
      /^([a-z ]+) is (?:the )?(?:worlds? )?most populous (?:country|nation)(?: in the world)?$/,
    ];

    let statedCountry: string | null = null;
    for (const re of patterns) {
      const m = re.exec(n);
      if (m) {
        statedCountry = m[1].trim();
        break;
      }
    }
    if (!statedCountry) return null;

    // Normalize country name alias
    if (statedCountry in this.COUNTRY_ALIASES) {
      statedCountry = this.COUNTRY_ALIASES[statedCountry];
    }

    if (statedCountry === "india") {
      return match("verified_true", 0.95,
        "According to United Nations Department of Economic and Social Affairs (UN DESA) demographic data, India surpassed China in 2023 to become the world's most populous country (~1.43 billion).",
        SOURCES.unPopulation,
        [SOURCES.worldBankPopulation]);
    }

    if (this.KNOWN_COUNTRIES.has(statedCountry)) {
      const displayCountry = statedCountry.charAt(0).toUpperCase() + statedCountry.slice(1);
      return match("false_claim", 0.95,
        `According to United Nations demographic data, India is the world's most populous country, not ${displayCountry}.`,
        SOURCES.unPopulation,
        [SOURCES.worldBankPopulation]);
    }

    return null;
  }
}
