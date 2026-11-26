/**
 * SAMPLE — the Joseph clip (25.4 s, 2026-11-20) through Stage 4 address forms, English → Telugu.
 *
 * Inputs are the real clip: its 9 dubbing segments after diarization reconcile, the character →
 * label assignment the diarization check produced (C1→A, C2→B_3, C3→B_2, C4→B), and a creator cast
 * list + relationships by name. Gemini is replaced by a stand-in that writes each line with the
 * address form its prompt asks for, so the test shows exactly which instruction every line gets.
 *
 * Run: npx jest tests/pipeline/stage4_joseph_sample.test.ts --verbose
 * (prints a per-line table; the same request body works against a deployed triggerVideoAIFeatures —
 *  see tests/fixtures/stage4_joseph_request.json)
 */
import {
  bindCastGenders,
  bindRelationships,
  buildCastBinding,
  detectAddressPronoun,
  inferAddressees,
  parseCastList,
  parseCastRelationships,
  resolveRegisterDirective,
} from "../../src/pipeline/services/cast-list";
import { GeminiDubbingEditor, type EditorSegment } from "../../src/pipeline/services/geminiDubbingEditor";

// What the creator sends (same shape as the request body fixture).
const request = {
  castList: [
    { name: "Wise Men", gender: "male", description: "robed royal advisers" },
    { name: "Pharaoh", gender: "male", description: "king, gold headdress, deep voice" },
    { name: "Cupbearer", gender: "male", description: "young royal servant, kind" },
    { name: "Guard", gender: "male", description: "armoured soldier, harsh voice" },
    { name: "Joseph", gender: "male", description: "young prisoner (spoken to, does not speak here)" },
  ],
  relationships: [
    { from: "Wise Men", to: "Pharaoh", formality: "deferential" },
    { from: "Pharaoh", to: "GROUP", formality: "formal" },
    { from: "Cupbearer", to: "Joseph", formality: "peer", relationship: "friend" },
    { from: "Guard", to: "Joseph", formality: "informal", relationship: "stranger" },
  ],
};

// The clip's dubbing segments after diarization reconcile (labels from the real run).
const clip = [
  { start: 340, end: 2510, speaker: "A", text: "But we cannot interpret your dreams." },
  { start: 4780, end: 8140, speaker: "B_3", text: "Is there no one here who can interpret my dreams?" },
  { start: 11620, end: 12780, speaker: "B_2", text: "Don't worry, Joseph." },
  { start: 12840, end: 14800, speaker: "B_2", text: "I will remember you and speak to Pharaoh." },
  { start: 14800, end: 16560, speaker: "B_2", text: "I forgot about Joseph." },
  { start: 18340, end: 20100, speaker: "B", text: "God didn't protect you." },
  { start: 20100, end: 22000, speaker: "B", text: "He never protects you." },
  { start: 22000, end: 23600, speaker: "B", text: "Do not serve him anymore." },
  { start: 23600, end: 25379, speaker: "B", text: "Forsake him for letting you suffer." },
];
const characterLabels = new Map([["C1", "A"], ["C2", "B_3"], ["C3", "B_2"], ["C4", "B"]]);

// Telugu written by the stand-in, per level (what a correct dub looks like).
const TELUGU: Record<string, { formal: string; informal: string }> = {
  "But we cannot interpret your dreams.": { formal: "కానీ మీ కలలకు మేము అర్థం చెప్పలేము ప్రభూ.", informal: "కానీ నీ కలలకు మేము అర్థం చెప్పలేము." },
  "Is there no one here who can interpret my dreams?": { formal: "నా కలలకు అర్థం చెప్పగలవారు ఇక్కడ ఎవరూ లేరా?", informal: "నా కలలకు అర్థం చెప్పగలవారు ఇక్కడ ఎవరూ లేరా?" },
  "Don't worry, Joseph.": { formal: "మీరు చింతించకండి, యోసేపు గారు.", informal: "నువ్వు చింతించకు, యోసేపు." },
  "I will remember you and speak to Pharaoh.": { formal: "నేను మిమ్మల్ని గుర్తుంచుకొని ఫరోతో మాట్లాడతాను.", informal: "నేను నిన్ను గుర్తుంచుకొని ఫరోతో మాట్లాడతాను." },
  "I forgot about Joseph.": { formal: "నేను యోసేపును మరచిపోయాను.", informal: "నేను యోసేపును మరచిపోయాను." },
  "God didn't protect you.": { formal: "దేవుడు మిమ్మల్ని కాపాడలేదు.", informal: "దేవుడు నిన్ను కాపాడలేదు." },
  "He never protects you.": { formal: "ఆయన మిమ్మల్ని ఎప్పుడూ కాపాడడు.", informal: "ఆయన నిన్ను ఎప్పుడూ కాపాడడు." },
  "Do not serve him anymore.": { formal: "ఇకపై మీరు ఆయనను సేవించకండి.", informal: "ఇకపై నువ్వు ఆయనను సేవించకు." },
  "Forsake him for letting you suffer.": { formal: "మిమ్మల్ని బాధపెట్టినందుకు ఆయనను విడిచిపెట్టండి.", informal: "నిన్ను బాధపెట్టినందుకు ఆయనను విడిచిపెట్టు." },
};

describe("SAMPLE: Joseph clip, English → Telugu address forms", () => {
  test("every line gets the right address form, and it never flips within a speaker pair", async () => {
    // 1. Request → validated cast + relationships (pipelineTriggers.ts).
    const cast = parseCastList(request.castList);
    const relationships = parseCastRelationships(request.relationships);

    // 2. After the diarization check: bind names to labels (07-dubbing.ts).
    const binding = buildCastBinding(cast, characterLabels);
    const { bound, unresolved } = bindRelationships(relationships, binding, ["A", "B", "B_2", "B_3"], cast);
    expect(unresolved).toEqual([]);
    const speakerNames = Object.fromEntries(cast.filter((m) => binding[m.name.toLowerCase()]).map((m) => [binding[m.name.toLowerCase()], m.name]));
    expect(bindCastGenders(cast, binding)).toMatchObject({ A: "male", B_3: "male", B_2: "male", B: "male" });

    // 3. Translation: addressee per line, directive only where a relationship exists (translation.ts).
    const addressees = inferAddressees(clip, ["A", "B_3", "B_2", "B"], bound);
    const relMap = new Map(bound.map((r) => [`${r.fromSpeaker}->${r.toSpeaker}`, r]));
    const segs: EditorSegment[] = clip.map((c, i) => {
      const rel = relMap.get(`${c.speaker}->${addressees[i]}`);
      return {
        id: `L${i + 1}`,
        source: c.text,
        draft: TELUGU[c.text].formal, // a machine draft that defaults to మీరు everywhere
        speaker: c.speaker,
        addressedTo: addressees[i],
        ...(rel ? { registerDirective: resolveRegisterDirective("te", rel) } : {}),
      };
    });

    // 4. Gemini editor (stand-in obeys each line's register_directive).
    const editPrompts: any[] = [];
    const generate = jest.fn(async ({ prompt }: { prompt: string }) => {
      if (prompt.includes("Generate Localization Bible")) return { text: JSON.stringify({ locked_registers: [] }) };
      const p = JSON.parse(prompt);
      editPrompts.push(p);
      return {
        text: JSON.stringify({
          lines: p.lines.map((l: any) => {
            const source = clip[Number(l.id.slice(1)) - 1].text;
            const level = /^INFORMAL/.test(l.register_directive || "") ? "informal" : "formal";
            return { id: l.id, text: TELUGU[source][level] };
          }),
        }),
      };
    });
    const results = await new GeminiDubbingEditor(generate as any).editSegments(segs, {
      sourceLanguage: "en",
      targetLanguage: "te",
      speakerNames,
      relationships: bound,
      countSyllables: (t: string) => t.length,
      countGlossaryViolations: () => 0,
    } as any);

    const promptLines = editPrompts.flatMap((p) => p.lines);
    const rows = clip.map((c, i) => {
      const pl = promptLines.find((l: any) => l.id === `L${i + 1}`) || {};
      return {
        line: `L${i + 1}`,
        speaker: `${speakerNames[c.speaker]} (${c.speaker})`,
        to: addressees[i],
        directive: String(pl.register_directive || "").split(":")[0],
        english: c.text,
        telugu: results[i].text,
        pronoun: detectAddressPronoun(results[i].text, "te")?.pronoun ?? "—",
      };
    });
    // eslint-disable-next-line no-console
    console.table(rows);

    // Wise Men → Pharaoh: deferential మీ.
    expect(rows[0]).toMatchObject({ to: "B_3", directive: "DEFERENTIAL (relationship)" });
    expect(results[0].text).toContain("మీ");
    // Cupbearer → Joseph (friend): all three lines familiar నువ్వు/నిన్ను, no flip mid-turn.
    expect(rows.slice(2, 5).map((r) => r.to)).toEqual(["Joseph", "Joseph", "Joseph"]);
    expect(results[2].text).toContain("నువ్వు");
    expect(results[3].text).toContain("నిన్ను");
    expect(results[3].text).not.toContain("మిమ్మల్ని");
    // Guard → Joseph (contempt): every line familiar.
    for (const i of [5, 6, 7, 8]) {
      expect(rows[i]).toMatchObject({ to: "Joseph", directive: "INFORMAL (stranger)" });
      expect(results[i].text).not.toMatch(/మీరు|మిమ్మల్ని/);
    }
  });
});
