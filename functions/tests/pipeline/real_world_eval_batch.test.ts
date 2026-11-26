/**
 * Real-World Evaluation Batch (25 Mixed Realistic Claims)
 *
 * Verifies that the hardened credibility engine (Patch 1 + Patch 2) behaves correctly
 * across live-world scenarios:
 *
 * 1. Breaking News & Uncorroborated Rumors
 * 2. Government Press Releases vs Primary Records vs Announcement Meta-Claims
 * 3. Syndication & Wire Service Deduplication (Reuters/AP/PTI, length guards, quote overlap)
 * 4. Medical/Scientific Fact-Checking vs Debunked Rumors
 * 5. Institutional Tiers, Spoofing & Domain Boundary Defenses (.ac, mil.com, title spoofing, fox.com)
 * 6. Disputed Claims & Symmetric Contradiction
 * 7. URL Health, Soft 404s, and Unverified Links
 */

import {
  decidePublicVerdict,
  applyVerdictGateToClaim,
  meetsStrongEvidenceBar,
  areSyndicatedCopies,
  countIndependentPublisherClusters,
  resolveEffectiveSourceKind,
  CONFLICTING_EVIDENCE_MESSAGE,
} from "../../src/pipeline/services/verdictGate";
import {
  sourceTrustService,
  classifyInstitutionalHost,
  isUgcHost,
} from "../../src/pipeline/services/sourceTrustService";

const liveRecord = (url: string, opts: { httpStatus?: number; isSoft404?: boolean; evidenceText?: string } = {}) => ({
  status: opts.httpStatus && opts.httpStatus >= 400 ? "FAILED" : "VERIFIED",
  httpStatus: opts.httpStatus ?? 200,
  isSoft404: opts.isSoft404 ?? false,
  originalUrl: url,
  canonicalUrl: url,
  redirectHops: 0,
  ...(opts.evidenceText ? { evidenceText: opts.evidenceText } : {}),
});

const makeSource = (
  domain: string,
  tier: string,
  claimStance: any = "SUPPORTS",
  sourceKind?: any,
  opts: {
    path?: string;
    text?: string;
    snippet?: string;
    unverified?: boolean;
    httpStatus?: number;
    isSoft404?: boolean;
    title?: string;
  } = {}
) => {
  const url = `https://${domain}${opts.path ?? "/article"}`;
  return {
    title: opts.title ?? domain,
    url,
    directUrl: url,
    domain,
    tier,
    ...(claimStance ? { claimStance } : {}),
    ...(sourceKind ? { sourceKind } : {}),
    ...(opts.snippet ? { snippet: opts.snippet } : {}),
    ...(opts.unverified
      ? {}
      : {
          urlVerification: liveRecord(url, {
            httpStatus: opts.httpStatus,
            isSoft404: opts.isSoft404,
            evidenceText: opts.text,
          }),
        }),
  };
};

describe("Real-World Evaluation Batch (25 Mixed Scenarios)", () => {
  // =========================================================================
  // 1. Breaking News & Uncorroborated Rumors
  // =========================================================================
  describe("Category 1: Breaking News & Uncorroborated Rumors", () => {
    it("Claim 1: Breaking news corroborated by 2 independent Tier A wire/news desks verifies", () => {
      const claim = "Magnitude 7.1 earthquake strikes off Sendai, Japan";
      const sources = [
        makeSource("reuters.com", "A", "SUPPORTS", "INDEPENDENT_REPORTING", {
          text: "A magnitude 7.1 earthquake struck off the coast of Sendai, triggering localized tsunami warnings, Japan Meteorological Agency said.",
        }),
        makeSource("apnews.com", "A", "SUPPORTS", "INDEPENDENT_REPORTING", {
          text: "Strong shaking was felt across northern Japanese prefectures following an offshore tremor registered at magnitude 7.1 on Saturday.",
        }),
      ];

      expect(meetsStrongEvidenceBar(sources as any, "SUPPORTS", claim)).toBe(true);
      const verdict = decidePublicVerdict({ status: "verified_true", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("VERIFIED");
      expect(verdict.demoted).toBeFalsy();
    });

    it("Claim 2: Viral rumor from a single unvetted blog demotes to UNPROVEN", () => {
      const claim = "Prime Minister secretly hospitalized following health scare";
      const sources = [
        makeSource("breakingwiretoday.net", "D", "SUPPORTS", "OTHER", {
          text: "Reports circulating on private channels allege that the leader was quietly transported to an undisclosed hospital facility.",
        }),
      ];

      expect(meetsStrongEvidenceBar(sources as any, "SUPPORTS", claim)).toBe(false);
      const verdict = decidePublicVerdict({ status: "verified_true", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("UNPROVEN");
      expect(verdict.demoted).toBe(true);
    });

    it("Claim 3: Celebrity arrest rumor supported by 2 unvetted blogs demotes to UNPROVEN", () => {
      const claim = "Famous Hollywood actor arrested at JFK airport";
      const sources = [
        makeSource("celebgossip24.com", "D", "SUPPORTS", "OTHER", {
          text: "Airport witnesses reported seeing the star led away in handcuffs early Sunday morning.",
        }),
        makeSource("hollywoodleakz.org", "D", "SUPPORTS", "OTHER", {
          text: "Law enforcement sources allegedly confirmed the custody of the acclaimed celebrity following a customs incident.",
        }),
      ];

      expect(meetsStrongEvidenceBar(sources as any, "SUPPORTS", claim)).toBe(false);
      const verdict = decidePublicVerdict({ status: "verified_true", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("UNPROVEN");
      expect(verdict.demoted).toBe(true);
    });
  });

  // =========================================================================
  // 2. Government Statements vs Primary Records vs Announcement Meta-Claims
  // =========================================================================
  describe("Category 2: Government Press Releases vs Primary Records vs Meta-Claims", () => {
    it("Claim 4: Self-serving official empirical claim without independent corroboration demotes to UNPROVEN", () => {
      const claim = "State transport corporation reduced annual operating deficit by 85%";
      const sources = [
        makeSource("transport.gov.state.in", "A", "SUPPORTS", "OFFICIAL_STATEMENT", {
          text: "The Transport Department announced today that sweeping administrative reforms reduced the annual operational deficit by 85%.",
        }),
      ];

      expect(meetsStrongEvidenceBar(sources as any, "SUPPORTS", claim)).toBe(false);
      const verdict = decidePublicVerdict({ status: "verified_true", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("UNPROVEN");
      expect(verdict.demoted).toBe(true);
    });

    it("Claim 5: Official empirical claim corroborated by Tier B financial press verifies", () => {
      const claim = "State transport corporation reduced annual operating deficit by 85%";
      const sources = [
        makeSource("transport.gov.state.in", "A", "SUPPORTS", "OFFICIAL_STATEMENT", {
          text: "The Transport Department announced today that sweeping administrative reforms reduced the annual operational deficit by 85%.",
        }),
        makeSource("financialexpress.com", "B", "SUPPORTS", "INDEPENDENT_REPORTING", {
          text: "Audit records confirmed that operational losses narrowed dramatically following route restructuring and fleet modernization.",
        }),
      ];

      expect(meetsStrongEvidenceBar(sources as any, "SUPPORTS", claim)).toBe(true);
      const verdict = decidePublicVerdict({ status: "verified_true", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("VERIFIED");
    });

    it("Claim 6: Announcement meta-claim is verified by the official issuing agency alone", () => {
      const claim = "Ministry of Education announced new scholarship guidelines on Monday";
      const sources = [
        makeSource("education.gov.in", "A", "SUPPORTS", "OFFICIAL_STATEMENT", {
          text: "The Ministry of Education has officially released updated criteria for merit-cum-means national scholarships.",
        }),
      ];

      expect(meetsStrongEvidenceBar(sources as any, "SUPPORTS", claim)).toBe(true);
      const verdict = decidePublicVerdict({ status: "verified_true", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("VERIFIED");
    });

    it("Claim 7: Official PRIMARY_RECORD (court order / gazette) verifies alone without secondary corroboration", () => {
      const claim = "High Court quashed preventive detention order in State v. Kumar";
      const sources = [
        makeSource("delhihighcourt.nic.in", "A", "SUPPORTS", "PRIMARY_RECORD", {
          text: "IN THE HIGH COURT OF DELHI: Writ Petition (Crl) No. 402/2026. The impugned detention order dated 14.01.2026 is hereby quashed and set aside.",
        }),
      ];

      expect(meetsStrongEvidenceBar(sources as any, "SUPPORTS", claim)).toBe(true);
      const verdict = decidePublicVerdict({ status: "verified_true", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("VERIFIED");
    });

    it("Claim 8: Single government denial press release cannot mark a claim FALSE alone (symmetric guard)", () => {
      const claim = "Industrial park released untreated chemical effluent into local reservoir";
      // Official press release denies wrongdoing
      const sources = [
        makeSource("industry.gov.in", "A", "REFUTES", "OFFICIAL_STATEMENT", {
          text: "The Industrial Development Board vehemently denies allegations of toxic discharge, asserting all treatment protocols were adhered to.",
        }),
      ];

      expect(meetsStrongEvidenceBar(sources as any, "CONTRADICTS", claim)).toBe(false);
      const verdict = decidePublicVerdict({ status: "verified_false", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("UNPROVEN");
      expect(verdict.demoted).toBe(true);
    });

    it("Claim 9: Government denial accompanied by independent technical laboratory report verifies as FALSE", () => {
      const claim = "Industrial park released untreated chemical effluent into local reservoir";
      const sources = [
        makeSource("industry.gov.in", "A", "CONTRADICTS", "OFFICIAL_STATEMENT", {
          text: "The Industrial Development Board denied allegations of toxic discharge.",
        }),
        makeSource("cpcb.nic.in", "A", "CONTRADICTS", "PRIMARY_RECORD", {
          text: "Water quality analysis by Central Pollution Control Board certified biological oxygen demand (BOD) and heavy metal parameters within permissible thresholds.",
        }),
      ];

      expect(meetsStrongEvidenceBar(sources as any, "CONTRADICTS", claim)).toBe(true);
      const verdict = decidePublicVerdict({ status: "verified_false", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("FALSE");
    });

    it("Claim 10: Unset sourceKind on .gov domain fails closed to OFFICIAL_STATEMENT", () => {
      const claim = "Government achieved 100% target in solar rural electrification";
      const sources = [
        makeSource("pib.gov.in", "A", "SUPPORTS", undefined, {
          text: "Press Information Bureau: The ambitious solar electrification milestone of 100% coverage was accomplished ahead of schedule.",
        }),
      ];

      expect(resolveEffectiveSourceKind(sources[0] as any)).toBe("OFFICIAL_STATEMENT");
      expect(meetsStrongEvidenceBar(sources as any, "SUPPORTS", claim)).toBe(false);
      const verdict = decidePublicVerdict({ status: "verified_true", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("UNPROVEN");
    });
  });

  // =========================================================================
  // 3. Syndication & Wire Service Deduplication
  // =========================================================================
  describe("Category 3: Syndication & Wire Service Deduplication", () => {
    it("Claim 11: Identical syndicated wire dispatch across 3 news sites collapses to 1 cluster (UNPROVEN for C/D)", () => {
      const wireDispatch = `SRIHARIKOTA (PTI): The Indian Space Research Organisation on Wednesday successfully launched the advanced earth observation satellite EOS-09 into sun-synchronous polar orbit. The PSLV-C62 rocket lifted off from the first launch pad at 10:15 AM, placing the primary payload with pinpoint orbital precision.`;

      const sources = [
        makeSource("deccanherald.com", "C", "SUPPORTS", "INDEPENDENT_REPORTING", { text: wireDispatch }),
        makeSource("tribuneindia.com", "C", "SUPPORTS", "INDEPENDENT_REPORTING", { text: wireDispatch }),
        makeSource("northeastpost.in", "D", "SUPPORTS", "INDEPENDENT_REPORTING", { text: wireDispatch }),
      ];

      expect(countIndependentPublisherClusters(sources as any)).toBe(1);
      // Because Deccan Herald is Tier C, 1 cluster is not enough for C/D (needs >= 2 independent clusters)
      expect(meetsStrongEvidenceBar(sources as any, "SUPPORTS")).toBe(false);
    });

    it("Claim 12: Genuinely independent reports on the same launch form 2 clusters and verify", () => {
      const theHinduReport = `SRIHARIKOTA: In a textbook mission, ISRO's dependable workhorse PSLV-C62 injected earth observation satellite EOS-09 into a 505-km sun-synchronous orbit on Wednesday. Mission directors at the Satish Dhawan Space Centre confirmed all ground telemetry parameters were nominal during payload separation.`;
      const bbcReport = `India has launched a new Earth observation satellite from Sriharikota spaceport, bolstering its disaster monitoring capabilities. Space agency officials confirmed the spacecraft separated successfully after an eighteen-minute ascent, expanding coverage across flood-prone river valleys.`;

      expect(areSyndicatedCopies(theHinduReport, bbcReport)).toBe(false);

      const sources = [
        makeSource("thehindu.com", "B", "SUPPORTS", "INDEPENDENT_REPORTING", { text: theHinduReport }),
        makeSource("bbc.com", "A", "SUPPORTS", "INDEPENDENT_REPORTING", { text: bbcReport }),
      ];

      expect(countIndependentPublisherClusters(sources as any)).toBe(2);
      expect(meetsStrongEvidenceBar(sources as any, "SUPPORTS")).toBe(true);
    });

    it("Claim 13: Shared 7-word verbatim quote does not collapse independent articles into syndication", () => {
      const quote = `we will never compromise on consumer safety protocols`;
      const articleA = `Addressing the annual technology summit in Bengaluru on Tuesday, the regulatory commissioner declared that "${quote}". The agency announced comprehensive algorithmic auditing frameworks slated for enforcement next quarter across major e-commerce platforms.`;
      const articleB = `In stern remarks during his keynote address, the chief data officer warned tech giants that "${quote}". Industry analysts noted the statement coincided with heightened scrutiny over international cross-border data transfer policies.`;

      expect(areSyndicatedCopies(articleA, articleB)).toBe(false);
    });

    it("Claim 14: Wire byline with moderate overlap correctly detects syndication despite localized intro", () => {
      const reutersBaseA = `LONDON (Reuters) - European gas storage sites reached 95 percent of capacity well ahead of winter targets, official infrastructure data revealed on Thursday, easing immediate price volatility fears across major manufacturing hubs.`;
      const reutersBaseB = `BERLIN (Reuters) - European gas storage sites reached 95 percent of capacity well ahead of winter targets, easing immediate price volatility fears across major industrial hubs, European energy authorities confirmed on Thursday.`;

      expect(areSyndicatedCopies(reutersBaseA, reutersBaseB)).toBe(true);
    });
  });

  // =========================================================================
  // 4. Medical & Scientific Fact-Checking vs Debunked Rumors
  // =========================================================================
  describe("Category 4: Medical & Scientific Fact-Checking vs Debunked Rumors", () => {
    it("Claim 15: Viral home-cure myth refuted by authoritative health bodies is marked FALSE", () => {
      const claim = "Inhaling steam with clove oil cures respiratory viral infections in 24 hours";
      const sources = [
        makeSource("who.int", "A", "CONTRADICTS", "REFERENCE", {
          text: "There is no scientific evidence that inhaling steam, essential oils, or clove extracts eliminates viral pathogens. Such practices may cause severe mucosal burns.",
        }),
        makeSource("cdc.gov", "A", "CONTRADICTS", "PRIMARY_RECORD", {
          text: "Clinical evaluations confirm inhalation remedies do not alter viral replication dynamics and carry inhalation thermal injury risks.",
        }),
      ];

      expect(meetsStrongEvidenceBar(sources as any, "CONTRADICTS", claim)).toBe(true);
      const verdict = decidePublicVerdict({ status: "verified_false", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("FALSE");
    });

    it("Claim 16: Two unvetted alternative medicine blogs promoting myth are demoted to UNPROVEN", () => {
      const claim = "Inhaling steam with clove oil cures respiratory viral infections in 24 hours";
      const sources = [
        makeSource("naturalcurestoday.org", "D", "SUPPORTS", "OTHER", {
          text: "Ancient remedies show miraculous results when inhaling hot clove steam twice daily.",
        }),
        makeSource("herbalwellnesssecrets.net", "D", "SUPPORTS", "OTHER", {
          text: "Clear your respiratory tract of all viruses within 24 hours using herbal steam distillation.",
        }),
      ];

      expect(meetsStrongEvidenceBar(sources as any, "SUPPORTS", claim)).toBe(false);
      const verdict = decidePublicVerdict({ status: "verified_true", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("UNPROVEN");
    });

    it("Claim 17: Peer-reviewed clinical trial in The Lancet satisfies strong evidence bar", () => {
      const claim = "R21/Matrix-M malaria vaccine demonstrated 77% efficacy in phase 2b trial";
      const sources = [
        makeSource("thelancet.com", "B", "SUPPORTS", "PRIMARY_RECORD", {
          text: "In this double-blind randomized controlled trial, the R21/Matrix-M candidate vaccine demonstrated high-level 77% efficacy over 12 months of follow-up.",
        }),
      ];

      expect(meetsStrongEvidenceBar(sources as any, "SUPPORTS", claim)).toBe(true);
      const verdict = decidePublicVerdict({ status: "verified_true", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("VERIFIED");
    });
  });

  // =========================================================================
  // 5. Institutional Tiers, Spoofing & Domain Boundary Defenses
  // =========================================================================
  describe("Category 5: Institutional Tiers, Spoofing & Domain Boundaries", () => {
    it("Claim 18: Commercial .ac domain (truthnews.ac) does not inherit academic Tier B", () => {
      expect(classifyInstitutionalHost("truthnews.ac")).toBeNull();
      const trust = sourceTrustService.resolveSourceTrust("https://truthnews.ac/story", "General", "Academic Research");
      expect(trust.tier).toBe("D");
      expect(trust.isVetted).toBe(false);
    });

    it("Claim 19: mil.com and go.com do not inherit military or government Tier A", () => {
      expect(classifyInstitutionalHost("mil.com")).toBeNull();
      expect(classifyInstitutionalHost("go.com")).toBeNull();
      expect(classifyInstitutionalHost("gov.co")).toBe("gov"); // Colombia government ccTLD
      expect(classifyInstitutionalHost("dod.mil")).toBe("gov"); // US Department of Defense
    });

    it("Claim 20: Bogus blog with 'cdc.gov' in title does not get promoted to Tier A", () => {
      const blogUrl = "https://conspiracywire.info/article";
      const trust = sourceTrustService.resolveSourceTrust(blogUrl, "General", "cdc.gov admits data hidden in report");
      expect(trust.tier).toBe("D");
      expect(trust.domain).toBe("conspiracywire.info");
      expect(trust.isVetted).toBe(false);
    });

    it("Claim 21: Legitimate news host fox.com is not blocked by x.com regex", () => {
      expect(isUgcHost("fox.com")).toBe(false);
      expect(isUgcHost("netflix.com")).toBe(false);
      expect(isUgcHost("box.com")).toBe(false);
      expect(isUgcHost("x.com")).toBe(true);
      expect(isUgcHost("mobile.twitter.com")).toBe(true);
    });

    it("Claim 22: UGC platform source (x.com) is Tier E and carries zero weight", () => {
      const claim = "Celebrity announces retirement on social media";
      const sources = [
        makeSource("x.com", "E", "SUPPORTS", "OTHER", {
          text: "Announcement post from personal handle.",
        }),
      ];

      expect(meetsStrongEvidenceBar(sources as any, "SUPPORTS", claim)).toBe(false);
      const verdict = decidePublicVerdict({ status: "verified_true", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("UNPROVEN");
    });
  });

  // =========================================================================
  // 6. Disputed Claims & Symmetric Contradiction
  // =========================================================================
  describe("Category 6: Disputed Claims & Symmetric Contradiction", () => {
    it("Claim 23: Conflicting Tier A/B sources route to CAUTION (DISPUTED), not VERIFIED or FALSE", () => {
      const claim = "New bilateral trade agreement will increase national exports by $10B";
      const sources = [
        makeSource("thehindu.com", "B", "SUPPORTS", "INDEPENDENT_REPORTING", {
          text: "Trade analysis indicates bilateral export volumes will expand by $10 billion within three fiscal cycles.",
        }),
        makeSource("reuters.com", "A", "CONTRADICTS", "INDEPENDENT_REPORTING", {
          text: "Independent trade economists dispute the projections, estimating net export gains will remain negligible under existing tariff schedules.",
        }),
      ];

      const verdict = decidePublicVerdict({ status: "verified_true", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("CAUTION");
      expect(verdict.cautionType).toBe("DISPUTED");

      const gatedClaim = applyVerdictGateToClaim({ status: "verified_true", richSources: sources, claimText: claim });
      expect(gatedClaim.publicVerdict).toBe("CAUTION");
      expect(gatedClaim.explanation).toBe(CONFLICTING_EVIDENCE_MESSAGE);
    });

    it("Claim 24: Fringe Tier D blog refuting a Tier A primary record does not displace VERIFIED", () => {
      const claim = "Spacecraft successfully landed in lunar south pole region";
      const sources = [
        makeSource("isro.gov.in", "A", "SUPPORTS", "PRIMARY_RECORD", {
          text: "Official telemetry confirms soft landing touchdown at designated lunar coordinates.",
        }),
        makeSource("conspiracyrealm.net", "D", "CONTRADICTS", "OTHER", {
          text: "Claims that the lunar landing footage was staged on a soundstage in Rajasthan.",
        }),
      ];

      const verdict = decidePublicVerdict({ status: "verified_true", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("VERIFIED");
    });
  });

  // =========================================================================
  // 7. URL Health, Soft 404s, and Unverified Links
  // =========================================================================
  describe("Category 7: URL Health, Soft 404s, and Unverified Links", () => {
    it("Claim 25: Link returning 404 or soft 404 fails closed to UNPROVEN", () => {
      const claim = "New government portal open for registrations";
      const sources = [
        makeSource("portal.gov.in", "A", "SUPPORTS", "PRIMARY_RECORD", {
          httpStatus: 404,
          isSoft404: true,
        }),
      ];

      // Live sources must exclude failed/soft-404 verification records
      const verdict = decidePublicVerdict({ status: "verified_true", richSources: sources, claimText: claim });
      expect(verdict.publicVerdict).toBe("UNPROVEN");
    });
  });
});
