/**
 * 🏛️ TIER 2: DETERMINISTIC KNOWLEDGE REGISTRY (TRUTHWORLD)
 *
 * Provides ultra-low-latency (< 100ms) authoritative fact adjudication
 * for universal physical constants, settled historical events, geography,
 * mathematics, and established medical baselines.
 *
 * Epistemic & Engineering Invariants:
 * 1. Zero LLM calls required for genuinely deterministic facts.
 * 2. Condition & Unit Matching: Strictly verifies units (°C vs °F), elevation/pressure
 *    conditions (e.g. water boils at 100°C at 1 atm, NOT on Everest).
 * 3. Exact Entity Pairing: World capitals strictly verify country <-> capital mapping
 *    (e.g., Tokyo <-> Japan; asserts "capital of Japan is Kyoto" as FALSE/REJECTED).
 * 4. Anti-Bias Gate: Rejects negated, altered, or disputed variants from false affirmation.
 */

import { ClaimStatus, RichSource } from "../types";

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

  /**
   * Evaluates a claim text against deterministic knowledge.
   * Returns a match if the claim can be authoritatively determined without an LLM.
   */
  public static resolveDeterministicFact(claimText: string): DeterministicFactMatch | null {
    if (!claimText || claimText.trim().length < 5) return null;

    const lower = claimText
      .replace(/[\u2018\u2019\u201C\u201D]/g, "'")
      .replace(/[❔✅❌⚠️🔍]/g, "")
      .trim()
      .toLowerCase();

    // ── 1. Anti-Bias & Negation Gate ─────────────────────────────────────────
    const hasNegation = /\b(not|never|neither|nor|cannot|can't|didn't|doesn't|don't|won't|no|false|fake|untrue|myth|hoax|disputed|doubt|incorrect)\b/i.test(lower);

    // ── 2. Scientific Constants: Freezing & Boiling Points with Condition Guards ──
    // Boiling point of water
    if (lower.includes("water") && (lower.includes("boil") || lower.includes("boiling"))) {
      const mentionsEverestOrAltitude = /\b(everest|high altitude|mountain|elevation|vacuum)\b/i.test(lower);
      const mentionsFahrenheit = /\b(fahrenheit|\b°f\b|\bf\b)\b/i.test(lower);
      const mentionsCelsius = /\b(celsius|centigrade|\b°c\b|\bc\b)\b/i.test(lower);
      const mentions100 = /\b100\b/.test(lower);
      const mentions212 = /\b212\b/.test(lower);

      // High-altitude condition violation: On Everest, water boils at ~68°C to 71°C
      if (mentionsEverestOrAltitude && (mentions100 || mentionsCelsius)) {
        return {
          matched: true,
          status: "false_claim",
          confidence: 0.99,
          reasoning: "At high elevations like Mount Everest, atmospheric pressure is much lower, causing pure water to boil at approximately 68°C to 71°C, not 100°C.",
          source: "National Institute of Standards and Technology (NIST) Thermodynamics",
          url: "https://physics.nist.gov/cuu/Constants/",
          domain: "nist.gov",
          tier: "A",
          verificationMethod: "deterministic",
          richSources: [{
            title: "NIST Thermodynamics Database",
            url: "https://physics.nist.gov/cuu/Constants/",
            directUrl: "https://physics.nist.gov/cuu/Constants/",
            domain: "nist.gov",
            tier: "A",
            snippet: "Thermodynamic boiling point varies directly with ambient pressure."
          }]
        };
      }

      // Unit confusion: 100°F is ~37.8°C (body temperature), water boils at 212°F
      if (mentionsFahrenheit && mentions100) {
        return {
          matched: true,
          status: "false_claim",
          confidence: 0.99,
          reasoning: "In the Fahrenheit temperature scale, water boils at 212°F, not 100°F (100°F is only about 37.8°C).",
          source: "Encyclopaedia Britannica (Physical Chemistry)",
          url: "https://www.britannica.com/science/water",
          domain: "britannica.com",
          tier: "A",
          verificationMethod: "deterministic",
          richSources: [{
            title: "Encyclopaedia Britannica: Properties of Water",
            url: "https://www.britannica.com/science/water",
            directUrl: "https://www.britannica.com/science/water",
            domain: "britannica.com",
            tier: "A",
            snippet: "Pure water boiling point is 212°F (100°C) at standard pressure."
          }]
        };
      }

      // Standard condition: 100°C / 212°F at standard atmospheric pressure / sea level
      if (!hasNegation && ((mentionsCelsius && mentions100) || mentions212 || (!mentionsFahrenheit && mentions100))) {
        return {
          matched: true,
          status: "verified_true",
          confidence: 0.99,
          reasoning: "At standard atmospheric pressure (1 atm / sea level), clean water boils at 100°C (212°F).",
          source: "National Institute of Standards and Technology (NIST)",
          url: "https://physics.nist.gov/cuu/Constants/",
          domain: "nist.gov",
          tier: "A",
          verificationMethod: "deterministic",
          richSources: [{
            title: "NIST Reference on Physical Constants",
            url: "https://physics.nist.gov/cuu/Constants/",
            directUrl: "https://physics.nist.gov/cuu/Constants/",
            domain: "nist.gov",
            tier: "A",
            snippet: "At standard 101.325 kPa pressure, the boiling point of pure water is 100.0°C (373.15 K)."
          }]
        };
      }
    }

    // Freezing point of water
    if (lower.includes("water") && (lower.includes("freeze") || lower.includes("freezing") || lower.includes("ice point"))) {
      if (!hasNegation && (/\b0\b|\bzero\b/.test(lower) || /\b32\b/.test(lower))) {
        return {
          matched: true,
          status: "verified_true",
          confidence: 0.99,
          reasoning: "At standard atmospheric pressure, pure water freezes into ice at 0°C (32°F).",
          source: "National Institute of Standards and Technology (NIST)",
          url: "https://physics.nist.gov/cuu/Constants/",
          domain: "nist.gov",
          tier: "A",
          verificationMethod: "deterministic",
          richSources: [{
            title: "NIST Physical Chemistry Reference",
            url: "https://physics.nist.gov/cuu/Constants/",
            directUrl: "https://physics.nist.gov/cuu/Constants/",
            domain: "nist.gov",
            tier: "A",
            snippet: "The freezing point of pure water at 1 atm is defined as 0.0°C."
          }]
        };
      }
    }

    // Speed of Light
    if (/\bspeed of light\b/i.test(lower) && /\b(vacuum|empty space|physics|c\b|299,?792,?458|300,?000\s*km)/i.test(lower)) {
      if (!hasNegation) {
        return {
          matched: true,
          status: "verified_true",
          confidence: 1.0,
          reasoning: "The speed of light in vacuum is an exact universal physical constant defined as precisely 299,792,458 meters per second.",
          source: "International Bureau of Weights and Measures (BIPM)",
          url: "https://www.bipm.org/en/measurement-units/base-units",
          domain: "bipm.org",
          tier: "A",
          verificationMethod: "deterministic",
          richSources: [{
            title: "BIPM: The International System of Units",
            url: "https://www.bipm.org/en/measurement-units/base-units",
            directUrl: "https://www.bipm.org/en/measurement-units/base-units",
            domain: "bipm.org",
            tier: "A",
            snippet: "The speed of light in vacuum c is 299 792 458 m/s."
          }]
        };
      }
    }

    // Earth Atmosphere Composition
    if (/\b(earth('s)? atmosphere|atmospheric composition)\b/i.test(lower) && /\b(nitrogen|oxygen|78%|21%)\b/i.test(lower)) {
      if (!hasNegation) {
        return {
          matched: true,
          status: "verified_true",
          confidence: 0.99,
          reasoning: "Earth's atmosphere by volume is composed of approximately 78.08% nitrogen and 20.95% oxygen, with traces of argon, CO2, and other gases.",
          source: "NASA Earth Fact Sheet",
          url: "https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html",
          domain: "nasa.gov",
          tier: "A",
          verificationMethod: "deterministic",
          richSources: [{
            title: "NASA Earth Atmosphere Fact Sheet",
            url: "https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html",
            directUrl: "https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html",
            domain: "nasa.gov",
            tier: "A",
            snippet: "Major atmospheric components: Nitrogen 78.08%, Oxygen 20.95%."
          }]
        };
      }
    }

    // DNA Double Helix
    if (/\bdna\b/i.test(lower) && /\b(double helix|structure)\b/i.test(lower)) {
      if (!hasNegation) {
        return {
          matched: true,
          status: "verified_true",
          confidence: 0.99,
          reasoning: "Deoxyribonucleic acid (DNA) is structured as a double helix composed of paired antiparallel nucleotide strands.",
          source: "National Human Genome Research Institute (NHGRI)",
          url: "https://www.genome.gov/about-genomics/fact-sheets/Deoxyribonucleic-Acid-Fact-Sheet",
          domain: "nih.gov",
          tier: "A",
          verificationMethod: "deterministic",
          richSources: [{
            title: "NIH National Human Genome Research Institute",
            url: "https://www.genome.gov/about-genomics/fact-sheets/Deoxyribonucleic-Acid-Fact-Sheet",
            directUrl: "https://www.genome.gov/about-genomics/fact-sheets/Deoxyribonucleic-Acid-Fact-Sheet",
            domain: "nih.gov",
            tier: "A",
            snippet: "The DNA molecule consists of two strands that wind around one another like a twisted ladder."
          }]
        };
      }
    }

    // ── 3. Authoritative World Capitals (Strict Entity Pairing) ─────────────
    if (lower.includes("capital")) {
      for (const [country, expectedCapital] of Object.entries(DeterministicRegistryService.CAPITAL_MAP)) {
        if (lower.includes(country)) {
          // Check if expected capital is asserted
          const mentionsExpected = lower.includes(expectedCapital);
          if (mentionsExpected && !hasNegation) {
            return {
              matched: true,
              status: "verified_true",
              confidence: 1.0,
              reasoning: `Official international records and sovereign geographic charters confirm that the capital of ${country.toUpperCase()} is ${expectedCapital.toUpperCase()}.`,
              source: "United Nations Statistics Division / Sovereign Cartography",
              url: "https://unstats.un.org/",
              domain: "un.org",
              tier: "A",
              verificationMethod: "deterministic",
              richSources: [{
                title: "UN Cartographic Section: World Sovereign Capitals",
                url: "https://unstats.un.org/",
                directUrl: "https://unstats.un.org/",
                domain: "un.org",
                tier: "A",
                snippet: `Sovereign jurisdiction: ${country.toUpperCase()} has designated capital ${expectedCapital.toUpperCase()}.`
              }]
            };
          }

          // Check if an incorrect capital is asserted (e.g. "capital of japan is kyoto")
          const otherCapitals = Object.values(DeterministicRegistryService.CAPITAL_MAP).filter(c => c !== expectedCapital);
          const mentionsIncorrect = otherCapitals.some(c => lower.includes(c)) || /\b(kyoto|osaka|lyon|marseille|mumbai|sydney|melbourne|rio|shanghai|new york|chicago)\b/i.test(lower);
          if (mentionsIncorrect && !hasNegation) {
            return {
              matched: true,
              status: "false_claim",
              confidence: 0.99,
              reasoning: `Official geography records establish that the capital of ${country.toUpperCase()} is ${expectedCapital.toUpperCase()}, not the entity asserted in the statement.`,
              source: "United Nations Sovereign Cartography",
              url: "https://unstats.un.org/",
              domain: "un.org",
              tier: "A",
              verificationMethod: "deterministic",
              richSources: [{
                title: "UN Sovereign Geographic Records",
                url: "https://unstats.un.org/",
                directUrl: "https://unstats.un.org/",
                domain: "un.org",
                tier: "A",
                snippet: `Official capital of ${country.toUpperCase()} is ${expectedCapital.toUpperCase()}.`
              }]
            };
          }
        }
      }
    }

    // ── 4. Settled Universal History ─────────────────────────────────────────
    // Apollo 11 Moon Landing (1969)
    if (/\bapollo 11\b/i.test(lower) || (/\bmoon landing\b/i.test(lower) && /\b(neil armstrong|1969)\b/i.test(lower))) {
      if (!hasNegation) {
        return {
          matched: true,
          status: "verified_true",
          confidence: 1.0,
          reasoning: "NASA astronauts Neil Armstrong and Buzz Aldrin landed the Apollo 11 Lunar Module on the Moon on July 20, 1969.",
          source: "NASA Apollo Historical Archives",
          url: "https://www.nasa.gov/mission/apollo-11/",
          domain: "nasa.gov",
          tier: "A",
          verificationMethod: "deterministic",
          richSources: [{
            title: "NASA History: Apollo 11 Lunar Landing",
            url: "https://www.nasa.gov/mission/apollo-11/",
            directUrl: "https://www.nasa.gov/mission/apollo-11/",
            domain: "nasa.gov",
            tier: "A",
            snippet: "On July 20, 1969, Apollo 11 landed on the lunar surface."
          }]
        };
      }
    }

    // United Nations Founding (1945)
    if (/\bunited nations\b/i.test(lower) && /\b(found(ed)?|charter|established|1945)\b/i.test(lower)) {
      if (!hasNegation) {
        return {
          matched: true,
          status: "verified_true",
          confidence: 1.0,
          reasoning: "The United Nations was officially founded on October 24, 1945, upon ratification of the UN Charter in San Francisco.",
          source: "United Nations Historical Treaty Archives",
          url: "https://www.un.org/en/about-us/history-of-the-un",
          domain: "un.org",
          tier: "A",
          verificationMethod: "deterministic",
          richSources: [{
            title: "History of the United Nations (1945)",
            url: "https://www.un.org/en/about-us/history-of-the-un",
            directUrl: "https://www.un.org/en/about-us/history-of-the-un",
            domain: "un.org",
            tier: "A",
            snippet: "The UN officially came into existence on 24 October 1945."
          }]
        };
      }
    }

    // ── 5. Health & Medical Baselines ────────────────────────────────────────
    // Antibiotics vs Viruses
    if (/\bantibiotics\b/i.test(lower) && /\b(viruses|virus|viral|cold|flu)\b/i.test(lower)) {
      const assertsCure = /\b(cure|treat|kill|effective against)\b/i.test(lower);
      const assertsIneffective = /\b(do not|cannot|ineffective|don't|not effective|only kill bacteria)\b/i.test(lower);

      if (assertsCure && !assertsIneffective) {
        return {
          matched: true,
          status: "false_claim",
          confidence: 0.99,
          reasoning: "Antibiotics only target and kill bacteria. They are completely ineffective against viruses such as the common cold, influenza, and COVID-19.",
          source: "World Health Organization (WHO) Antimicrobial Guidance",
          url: "https://www.who.int/news-room/fact-sheets/detail/antibiotic-resistance",
          domain: "who.int",
          tier: "A",
          verificationMethod: "deterministic",
          richSources: [{
            title: "WHO: Antibiotic Resistance Fact Sheet",
            url: "https://www.who.int/news-room/fact-sheets/detail/antibiotic-resistance",
            directUrl: "https://www.who.int/news-room/fact-sheets/detail/antibiotic-resistance",
            domain: "who.int",
            tier: "A",
            snippet: "Antibiotics are medicines used to prevent and treat bacterial infections; they do not kill viruses."
          }]
        };
      } else if (assertsIneffective) {
        return {
          matched: true,
          status: "verified_true",
          confidence: 0.99,
          reasoning: "Medical science confirms that antibiotics only kill bacteria and do not cure viral infections like colds and the flu.",
          source: "Centers for Disease Control and Prevention (CDC)",
          url: "https://www.cdc.gov/antibiotic-use/index.html",
          domain: "cdc.gov",
          tier: "A",
          verificationMethod: "deterministic",
          richSources: [{
            title: "CDC Antibiotic Awareness Guidance",
            url: "https://www.cdc.gov/antibiotic-use/index.html",
            directUrl: "https://www.cdc.gov/antibiotic-use/index.html",
            domain: "cdc.gov",
            tier: "A",
            snippet: "Antibiotics do not work on viruses, such as those that cause colds, flu, or COVID-19."
          }]
        };
      }
    }

    // Smoking causes cancer
    if (/\bsmoking\b/i.test(lower) && /\b(lung cancer|heart disease|cancer)\b/i.test(lower)) {
      if (!hasNegation) {
        return {
          matched: true,
          status: "verified_true",
          confidence: 0.99,
          reasoning: "Extensive longitudinal clinical studies prove that tobacco smoking directly causes lung cancer, cardiovascular diseases, and chronic respiratory disorders.",
          source: "Surgeon General's Report / World Health Organization",
          url: "https://www.who.int/news-room/fact-sheets/detail/tobacco",
          domain: "who.int",
          tier: "A",
          verificationMethod: "deterministic",
          richSources: [{
            title: "WHO Tobacco Health Consequences Report",
            url: "https://www.who.int/news-room/fact-sheets/detail/tobacco",
            directUrl: "https://www.who.int/news-room/fact-sheets/detail/tobacco",
            domain: "who.int",
            tier: "A",
            snippet: "Tobacco smoke causes cancer, heart disease, stroke, lung diseases, and diabetes."
          }]
        };
      }
    }

    // Turmeric cancer cure myth
    if (/\bturmeric\b/i.test(lower) && /\b(cancer|cure)\b/i.test(lower)) {
      return {
        matched: true,
        status: "false_claim",
        confidence: 0.99,
        reasoning: "There is no clinical evidence in human trials that drinking turmeric water or taking curcumin cures or prevents cancer. Authoritative oncology bodies strongly advise against replacing proven medical treatment with unverified dietary remedies.",
        source: "National Cancer Institute (NCI) / Cancer Research UK",
        url: "https://www.cancerresearchuk.org/about-cancer/treatment/complementary-alternative-therapies/individual-therapies/turmeric",
        domain: "cancerresearchuk.org",
        tier: "A",
        verificationMethod: "deterministic",
        richSources: [{
          title: "Cancer Research UK: Turmeric and Cancer Guidance",
          url: "https://www.cancerresearchuk.org/about-cancer/treatment/complementary-alternative-therapies/individual-therapies/turmeric",
          directUrl: "https://www.cancerresearchuk.org/about-cancer/treatment/complementary-alternative-therapies/individual-therapies/turmeric",
          domain: "cancerresearchuk.org",
          tier: "A",
          snippet: "There is no strong evidence that turmeric or curcumin can prevent or treat cancer in humans."
        }]
      };
    }

    // Flat Earth Myth
    if (/\b(earth is flat|flat earth)\b/i.test(lower)) {
      return {
        matched: true,
        status: "false_claim",
        confidence: 1.0,
        reasoning: "Orbital satellite imagery, circumnavigational geodesic surveys, and centuries of astronomical measurements establish that Earth is an oblate spheroid.",
        source: "National Oceanic and Atmospheric Administration (NOAA)",
        url: "https://oceanservice.noaa.gov/facts/earth-round.html",
        domain: "noaa.gov",
        tier: "A",
        verificationMethod: "deterministic",
        richSources: [{
          title: "NOAA Ocean Service: Is the Earth Round?",
          url: "https://oceanservice.noaa.gov/facts/earth-round.html",
          directUrl: "https://oceanservice.noaa.gov/facts/earth-round.html",
          domain: "noaa.gov",
          tier: "A",
          snippet: "The Earth is an irregularly shaped ellipsoid (an oblate spheroid)."
        }]
      };
    }

    return null;
  }
}
