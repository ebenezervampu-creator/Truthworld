import {
  voiceMatcher,
  AGE_BUCKET_ANCHORS,
  normalizeElevenLabsAgeLabel,
  DiarizedSpeakerProfile,
} from "../../src/pipeline/services/voice-matcher";

describe("Speaker-to-Voice Matching Layer (Expanded Studio Catalog)", () => {
  const catalog = voiceMatcher.buildCalibratedFallbackCatalog();

  describe("Catalog and Normalization", () => {
    it("anchors age buckets to calibrated numerical years", () => {
      expect(AGE_BUCKET_ANCHORS.child).toBe(10);
      expect(AGE_BUCKET_ANCHORS.young).toBe(25);
      expect(AGE_BUCKET_ANCHORS.middle_aged).toBe(42);
      expect(AGE_BUCKET_ANCHORS.old).toBe(65);
    });

    it("normalizes ElevenLabs age labels accurately", () => {
      expect(normalizeElevenLabsAgeLabel("young")).toBe("young");
      expect(normalizeElevenLabsAgeLabel("youthful")).toBe("young");
      expect(normalizeElevenLabsAgeLabel("child")).toBe("child");
      expect(normalizeElevenLabsAgeLabel("kid")).toBe("child");
      expect(normalizeElevenLabsAgeLabel("senior")).toBe("old");
      expect(normalizeElevenLabsAgeLabel("old")).toBe("old");
      expect(normalizeElevenLabsAgeLabel("middle aged")).toBe("middle_aged");
      expect(normalizeElevenLabsAgeLabel("")).toBe("middle_aged");
    });

    it("includes all 29 male and 17 female studio presets in fallback catalog", () => {
      const voiceIds = new Set(catalog.map((c) => c.voiceId));
      expect(voiceIds.size).toBeGreaterThanOrEqual(46);

      // Male studio voices
      expect(voiceIds.has("TX3LPaxmHKxFdv7VOQHJ")).toBe(true); // Liam
      expect(voiceIds.has("g5CIjZEefAph4nQFvHAz")).toBe(true); // Ethan
      expect(voiceIds.has("SOYHLrjzK2X1ezoPC6cr")).toBe(true); // Harry
      expect(voiceIds.has("CYw3kZ02Hs0563khs1Fj")).toBe(true); // Dave
      expect(voiceIds.has("yoZ06aMxZJJ28mfd3POQ")).toBe(true); // Sam
      expect(voiceIds.has("GBv7mTt0atIp3Br8iCZE")).toBe(true); // Thomas
      expect(voiceIds.has("TxGEqnHWrfWFTfGW9XjX")).toBe(true); // Josh
      expect(voiceIds.has("zcAOhNBS3c14rBihAFp1")).toBe(true); // Giovanni
      expect(voiceIds.has("ErXwobaYiN019PkySvjV")).toBe(true); // Antoni
      expect(voiceIds.has("bVMeCyTHy58xNoL34h3p")).toBe(true); // Jeremy
      expect(voiceIds.has("iP95p4xoKVk53GoZ742B")).toBe(true); // Chris
      expect(voiceIds.has("IKne3meq5aSn9XLyUdCD")).toBe(true); // Charlie
      expect(voiceIds.has("29vD33N1CtxCmqQRPOHJ")).toBe(true); // Drew
      expect(voiceIds.has("N2lVS1w4EtoT3dr4eOWO")).toBe(true); // Callum
      expect(voiceIds.has("ODq5zmih8GrVes37Dizd")).toBe(true); // Patrick
      expect(voiceIds.has("Zlb1dXrM653N07WRdFW3")).toBe(true); // Joseph
      expect(voiceIds.has("JBFqnCBsd6RMkjVDRZzb")).toBe(true); // George
      expect(voiceIds.has("Yko7PKHZNXotIFUBG7I9")).toBe(true); // Matthew
      expect(voiceIds.has("pNInz6obpgDQGcFmaJgB")).toBe(true); // Adam
      expect(voiceIds.has("onwK4e9ZLuTAKqWW03F9")).toBe(true); // Daniel
      expect(voiceIds.has("nPczCjzI2devNBz1zQrb")).toBe(true); // Brian
      expect(voiceIds.has("5Q0t7uMcjvnagumLfvZi")).toBe(true); // Paul
      expect(voiceIds.has("2EiwWnXFnvU5JabPnv8n")).toBe(true); // Clyde
      expect(voiceIds.has("VR6AewLTigWG4xSOukaG")).toBe(true); // Arnold
      expect(voiceIds.has("pqHfZKP75CvOlQylNhV4")).toBe(true); // Bill
      expect(voiceIds.has("D38z5RcWu1voky8WS1ja")).toBe(true); // Fin
      expect(voiceIds.has("ZQe5CZNOzWyzPSCn5a3c")).toBe(true); // James
      expect(voiceIds.has("flq6f7yk4E4fJM5XTYuZ")).toBe(true); // Michael
      expect(voiceIds.has("t0jbNlBVZ17f02VDIeMI")).toBe(true); // Jessie

      // Female studio voices
      expect(voiceIds.has("jBpfuIE2acCO8z3wKNLl")).toBe(true); // Gigi
      expect(voiceIds.has("zrHiDhphv9ZnVXBqCLjz")).toBe(true); // Mimi
      expect(voiceIds.has("MF3mGyEYCl7XYWbV9V6O")).toBe(true); // Elli
      expect(voiceIds.has("EXAVITQu4vr4xnSDxMaL")).toBe(true); // Bella / Sarah
      expect(voiceIds.has("piTKgcLEGmPE4e6mEKli")).toBe(true); // Nicole
      expect(voiceIds.has("jsCqWAovK2LkecY7zXl4")).toBe(true); // Freya
      expect(voiceIds.has("21m00Tcm4TlvDq8ikWAM")).toBe(true); // Rachel
      expect(voiceIds.has("AZnzlk1XvdvUeBnXmlld")).toBe(true); // Domi
      expect(voiceIds.has("LcfcDJNUP1GQjkzn1xUU")).toBe(true); // Emily
      expect(voiceIds.has("XB0fDUnXU5powFXDhCwa")).toBe(true); // Charlotte
      expect(voiceIds.has("pMsXgVXv3BLzUgSXRplE")).toBe(true); // Serena
      expect(voiceIds.has("Xb7hH8MSUJpSbSDYk0k2")).toBe(true); // Alice
      expect(voiceIds.has("XrExE9yKIg1WjnnlVkGX")).toBe(true); // Matilda
      expect(voiceIds.has("ThT5KcBeYPX3keUQqHPh")).toBe(true); // Dorothy
      expect(voiceIds.has("pFZP5JQG7iQjIQuC4Bku")).toBe(true); // Lily
      expect(voiceIds.has("z9fAnlkpzviPz146aGWa")).toBe(true); // Glinda
      expect(voiceIds.has("oWAxZDx7w5VEj9dCyTzz")).toBe(true); // Grace
    });
  });

  describe("WhatsApp Debate Resolution (Order-Independent Matching)", () => {
    const speakerA: DiarizedSpeakerProfile = {
      speakerId: "speaker_A",
      estimatedAge: 23,
      ageBucket: "young",
      gender: "male",
      medianPitchHz: 130,
      timbreTags: ["energetic", "young", "creator", "vlog"],
      confidence: 0.95,
    };

    const speakerB: DiarizedSpeakerProfile = {
      speakerId: "speaker_B",
      estimatedAge: 45,
      ageBucket: "middle_aged",
      gender: "male",
      medianPitchHz: 100,
      timbreTags: ["authoritative", "deep", "debate"],
      confidence: 0.92,
    };

    it("matches younger debater (Speaker A) to Liam with lowest distance", () => {
      const matchA = voiceMatcher.selectNearestVoice(speakerA, catalog);
      const score = voiceMatcher.scoreCandidate(speakerA, matchA);

      expect(matchA.voiceId).toBe("TX3LPaxmHKxFdv7VOQHJ"); // Liam
      expect(matchA.name).toBe("Liam");
      expect(score).toBeLessThan(0.05);
    });

    it("matches bearded mature debater (Speaker B) to Adam with lowest distance", () => {
      const matchB = voiceMatcher.selectNearestVoice(speakerB, catalog);
      const score = voiceMatcher.scoreCandidate(speakerB, matchB);

      expect(matchB.voiceId).toBe("pNInz6obpgDQGcFmaJgB"); // Adam
      expect(matchB.name).toBe("Adam");
      expect(score).toBeLessThan(0.05);
    });

    it("guarantees correct voice assignment regardless of who speaks first", () => {
      // Scenario 1: A speaks first, then B
      const assigned1 = new Set<string>();
      const aFirst = voiceMatcher.selectNearestVoice(speakerA, catalog, assigned1);
      assigned1.add(aFirst.voiceId);
      const bSecond = voiceMatcher.selectNearestVoice(speakerB, catalog, assigned1);

      expect(aFirst.name).toBe("Liam");
      expect(bSecond.name).toBe("Adam");

      // Scenario 2: B speaks first, then A
      const assigned2 = new Set<string>();
      const bFirst = voiceMatcher.selectNearestVoice(speakerB, catalog, assigned2);
      assigned2.add(bFirst.voiceId);
      const aSecond = voiceMatcher.selectNearestVoice(speakerA, catalog, assigned2);

      expect(bFirst.name).toBe("Adam");
      expect(aSecond.name).toBe("Liam");
    });
  });

  describe("Same-Age Co-Hosts Uniqueness Lock (Expanded Palette)", () => {
    it("guarantees distinct voice allocation with fine-grained age precision", () => {
      const host1: DiarizedSpeakerProfile = {
        speakerId: "host_1",
        estimatedAge: 24,
        ageBucket: "young",
        gender: "male",
        medianPitchHz: 132,
        timbreTags: ["energetic", "articulate", "vlog"],
        confidence: 0.9,
      };

      const host2: DiarizedSpeakerProfile = {
        speakerId: "host_2",
        estimatedAge: 25,
        ageBucket: "young",
        gender: "male",
        medianPitchHz: 126,
        timbreTags: ["casual", "conversational"],
        confidence: 0.9,
      };

      const assigned = new Set<string>();

      // Host 1 selects Liam (24yo, 132Hz)
      const match1 = voiceMatcher.selectNearestVoice(host1, catalog, assigned);
      expect(match1.name).toBe("Liam");
      assigned.add(match1.voiceId);

      // Host 2 cannot pick Liam because of uniqueness lock -> selects nearest remaining young male (e.g. Dave 26yo or Harry 25yo)
      const match2 = voiceMatcher.selectNearestVoice(host2, catalog, assigned);
      expect(match2.voiceId).not.toBe(match1.voiceId);
      expect(match2.gender).toBe("male");
      expect(match2.ageBucket).toBe("young");
      expect(Math.abs(match2.representativeAge - host2.estimatedAge)).toBeLessThanOrEqual(2);
    });
  });

  describe("Female Voice Profiling (Expanded Roster)", () => {
    it("matches 18yo animated female to Gigi", () => {
      const profile: DiarizedSpeakerProfile = {
        speakerId: "spk_gigi",
        estimatedAge: 18,
        ageBucket: "young",
        gender: "female",
        medianPitchHz: 242,
        timbreTags: ["childish", "animated", "character"],
        confidence: 0.95,
      };
      const match = voiceMatcher.selectNearestVoice(profile, catalog);
      expect(match.name).toBe("Gigi");
      expect(match.voiceId).toBe("jBpfuIE2acCO8z3wKNLl");
    });

    it("matches 21yo energetic female to Elli", () => {
      const profile: DiarizedSpeakerProfile = {
        speakerId: "spk_elli",
        estimatedAge: 21,
        ageBucket: "young",
        gender: "female",
        medianPitchHz: 228,
        timbreTags: ["youthful", "emotional", "social"],
        confidence: 0.95,
      };
      const match = voiceMatcher.selectNearestVoice(profile, catalog);
      expect(match.name).toBe("Elli");
      expect(match.voiceId).toBe("MF3mGyEYCl7XYWbV9V6O");
    });

    it("matches 44yo mature female to Dorothy", () => {
      const profile: DiarizedSpeakerProfile = {
        speakerId: "spk_dorothy",
        estimatedAge: 44,
        ageBucket: "middle_aged",
        gender: "female",
        medianPitchHz: 192,
        timbreTags: ["calm", "storytelling", "british"],
        confidence: 0.92,
      };
      const match = voiceMatcher.selectNearestVoice(profile, catalog);
      expect(match.name).toBe("Dorothy");
      expect(match.voiceId).toBe("ThT5KcBeYPX3keUQqHPh");
    });

    it("matches 60yo senior female to Grace", () => {
      const profile: DiarizedSpeakerProfile = {
        speakerId: "spk_grace",
        estimatedAge: 60,
        ageBucket: "old",
        gender: "female",
        medianPitchHz: 175,
        timbreTags: ["gentle", "authoritative", "mature"],
        confidence: 0.9,
      };
      const match = voiceMatcher.selectNearestVoice(profile, catalog);
      expect(match.name).toBe("Grace");
      expect(match.voiceId).toBe("oWAxZDx7w5VEj9dCyTzz");
    });
  });

  describe("Senior Male Voice Profiling (Expanded Roster)", () => {
    it("matches 58yo raspy male to Arnold", () => {
      const profile: DiarizedSpeakerProfile = {
        speakerId: "spk_arnold",
        estimatedAge: 58,
        ageBucket: "old",
        gender: "male",
        medianPitchHz: 92,
        timbreTags: ["crisp", "gravelly", "authoritative"],
        confidence: 0.93,
      };
      const match = voiceMatcher.selectNearestVoice(profile, catalog);
      expect(match.name).toBe("Arnold");
      expect(match.voiceId).toBe("VR6AewLTigWG4xSOukaG");
    });

    it("matches 70yo elderly male to Jessie", () => {
      const profile: DiarizedSpeakerProfile = {
        speakerId: "spk_jessie",
        estimatedAge: 70,
        ageBucket: "old",
        gender: "male",
        medianPitchHz: 92,
        timbreTags: ["raspy", "elderly", "character"],
        confidence: 0.95,
      };
      const match = voiceMatcher.selectNearestVoice(profile, catalog);
      expect(match.name).toBe("Jessie");
      expect(match.voiceId).toBe("t0jbNlBVZ17f02VDIeMI");
    });
  });

  describe("ASMR / Theatrical Niche Quarantine & Indian Library Matching", () => {
    it("quarantines ASMR/theatrical voices (Ethan, Nicole, Glinda, Patrick) from standard conversational content", () => {
      const normalSpeaker: DiarizedSpeakerProfile = {
        speakerId: "normal_creator",
        estimatedAge: 24,
        ageBucket: "young",
        gender: "male",
        medianPitchHz: 135,
        timbreTags: ["conversational", "creator", "vlog"],
        confidence: 0.9,
      };
      const match = voiceMatcher.selectNearestVoice(normalSpeaker, catalog);
      // Ethan is 24yo, but carries "asmr" / "whisper" and must be quarantined for normal content
      expect(match.name).not.toBe("Ethan");
      expect(match.name).toBe("Liam");
    });

    it("matches curated Indian Library voices when Indian accent tag is requested", () => {
      const indianSpeaker: DiarizedSpeakerProfile = {
        speakerId: "indian_host",
        estimatedAge: 27,
        ageBucket: "young",
        gender: "male",
        medianPitchHz: 124,
        timbreTags: ["conversational", "creator", "indian"],
        confidence: 0.95,
      };
      const match = voiceMatcher.selectNearestVoice(indianSpeaker, catalog);
      expect(match.name).toBe("Aarav");
      expect(match.voiceId).toBe("s3PprVl6qK3x6V3a5nUq");
    });
  });
});
