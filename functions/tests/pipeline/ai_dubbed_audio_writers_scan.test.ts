import * as fs from "fs";
import * as path from "path";

describe("aiDubbedAudio server writers source-scan verification", () => {
  const rootSrc = path.resolve(__dirname, "../../src");

  it("07-dubbing.ts: propagateAudioTrack and delivery write aiDubbedAudio alongside audioTracks", () => {
    const file = path.join(rootSrc, "pipeline/layers/07-dubbing.ts");
    expect(fs.existsSync(file)).toBe(true);
    const content = fs.readFileSync(file, "utf8");

    // propagateAudioTrack
    const pStart = content.indexOf("async propagateAudioTrack(");
    const pEnd = content.indexOf("private async processLanguage(", pStart);
    const pBody = content.slice(pStart, pEnd);

    expect(pBody).toContain("aiDubbedAudio: {");
    expect(pBody).toContain("[targetLang]: directAudioUrl");
    expect(pBody).not.toContain("[`aiDubbedAudio.${targetLang}`]");
    expect(pBody).not.toContain("dotAudioUpdates[`aiDubbedAudio.");

    // processLanguage delivery
    const dStart = content.indexOf("private async processLanguage(");
    const dEnd = content.indexOf("loadSpeakerVoiceProfile(", dStart);
    const dBody = content.slice(dStart, dEnd);

    expect(dBody).toContain("videoDocUpdate.aiDubbedAudio = {");
    expect(dBody).not.toContain("videoDocUpdate[`aiDubbedAudio.");

    // Assemble step
    const aStart = content.indexOf('filterVideoIds(\n        meta.videoId ? [meta.videoId] : [],\n        "[Dubbing:Assemble]"');
    const aBody = aStart > -1 ? content.slice(aStart, aStart + 600) : content.slice(content.lastIndexOf("[Dubbing:Assemble]"), content.lastIndexOf("[Dubbing:Assemble]") + 600);
    expect(aBody).toContain("aiDubbedAudio: { [targetLang]: directAudioUrl }");
    expect(aBody).not.toContain("[`aiDubbedAudio.${targetLang}`]");
  });

  it("09-aggregation.ts: writes aiDubbedAudio for merged dubbing outputs", () => {
    const file = path.join(rootSrc, "pipeline/layers/09-aggregation.ts");
    expect(fs.existsSync(file)).toBe(true);
    const content = fs.readFileSync(file, "utf8");

    // Finalizer write around line 1400
    expect(content).toContain("aiDubbedAudio: mergedAiDubbedAudio");
    expect(content).toContain("aiDubbedUpdates[lang] = url;");

    // Early propagation batch write around line 1610 (batch.update uses dotted FieldPath)
    expect(content).toContain("updateData[`aiDubbedAudio.${lang}`] = url;");
  });

  it("pipelineTriggers.ts: writes aiDubbedAudio in onDubbingResultWritten using nested map", () => {
    const file = path.join(rootSrc, "pipeline/pipelineTriggers.ts");
    expect(fs.existsSync(file)).toBe(true);
    const content = fs.readFileSync(file, "utf8");

    expect(content).toContain("vDocUpdate.aiDubbedAudio = audioUpdates;");
    expect(content).not.toContain("vDocUpdate[`aiDubbedAudio.");
  });

  it("dubbingEditorService.ts: updates aiDubbedAudio using nested map", () => {
    const file = path.join(rootSrc, "pipeline/services/dubbingEditorService.ts");
    expect(fs.existsSync(file)).toBe(true);
    const content = fs.readFileSync(file, "utf8");

    expect(content).toContain("aiDubbedAudio: { [normLang]: directAudioUrl }");
    expect(content).not.toContain("[`aiDubbedAudio.");
  });

  it("ensures no set() call across pipeline server writers writes a literal 'aiDubbedAudio.' dotted key", () => {
    const filesToCheck = [
      "pipeline/layers/07-dubbing.ts",
      "pipeline/pipelineTriggers.ts",
      "pipeline/services/dubbingEditorService.ts",
      "pipeline/layers/09-aggregation.ts",
      "ads/adPipeline.ts",
    ];

    for (const relPath of filesToCheck) {
      const fullPath = path.join(rootSrc, relPath);
      const content = fs.readFileSync(fullPath, "utf8");

      // Match any literal dotted key assignment or property like `aiDubbedAudio.` or "aiDubbedAudio." or 'aiDubbedAudio.'
      const literalDottedKeyMatches = content.match(/[`'"]aiDubbedAudio\.[^`'"]+[`'"]/g) || [];

      // Dotted keys are ONLY allowed if specifically part of batch.update(...) or .update(...) calls.
      // In set(...) calls, they must NEVER occur.
      for (const m of literalDottedKeyMatches) {
        const idx = content.indexOf(m);
        // Find the nearest enclosing or subsequent db call
        const surrounding = content.slice(Math.max(0, idx - 400), Math.min(content.length, idx + 400));
        expect(surrounding).not.toMatch(/\.set\s*\([^)]*merge:\s*true/);
      }
    }
  });

  it("adPipeline.ts: writes aiDubbedAudio only for AI TTS generated ad audio", () => {
    const file = path.join(rootSrc, "ads/adPipeline.ts");
    expect(fs.existsSync(file)).toBe(true);
    const content = fs.readFileSync(file, "utf8");

    expect(content).toContain("aiDubbedAudio:");
  });
});
