import * as fs from "fs";
import * as path from "path";

describe("propagateAudioTrack and dubbing delivery audioTrackSources Verification", () => {
  const dubbingLayerFilePath = path.resolve(__dirname, "../../src/pipeline/layers/07-dubbing.ts");

  it("reads propagateAudioTrack source and verifies every audioTracks write has a matching audioTrackSources write", () => {
    expect(fs.existsSync(dubbingLayerFilePath)).toBe(true);
    const content = fs.readFileSync(dubbingLayerFilePath, "utf8");

    // Extract the propagateAudioTrack method block
    const methodStart = content.indexOf("async propagateAudioTrack(");
    expect(methodStart).toBeGreaterThan(-1);

    // Method ends before processLanguage
    const methodEnd = content.indexOf("private async processLanguage(", methodStart);
    expect(methodEnd).toBeGreaterThan(methodStart);

    const methodBody = content.slice(methodStart, methodEnd);

    // 1. dotAudioUpdates must define audioTrackSources with 'ai_dub'
    expect(methodBody).toContain("audioTrackSources: {");
    expect(methodBody).toContain("[targetLang]: \"ai_dub\"");
    expect(methodBody).toContain("media: {");
    expect(methodBody).toContain("audioTracks: {");
    expect(methodBody).toContain("audioTrackSources: {");

    // 2. Dotted property writes on dotAudioUpdates
    expect(methodBody).toContain("[`audioTracks.${targetLang}`]: directAudioUrl");
    expect(methodBody).toContain("[`audioTrackSources.${targetLang}`]: \"ai_dub\"");
    expect(methodBody).toContain("[`media.audioTracks.${targetLang}`]: directAudioUrl");
    expect(methodBody).toContain("[`media.audioTrackSources.${targetLang}`]: \"ai_dub\"");

    // 3. Raw target lang handling in dotAudioUpdates
    expect(methodBody).toContain("dotAudioUpdates[`audioTracks.${rawTargetLang}`] = directAudioUrl;");
    expect(methodBody).toContain("dotAudioUpdates[`audioTrackSources.${rawTargetLang}`] = \"ai_dub\";");
    expect(methodBody).toContain("dotAudioUpdates[`media.audioTracks.${rawTargetLang}`] = directAudioUrl;");
    expect(methodBody).toContain("dotAudioUpdates[`media.audioTrackSources.${rawTargetLang}`] = \"ai_dub\";");

    // 4. locAudioUpdates for videos/{vid}/media/localization
    expect(methodBody).toContain("const locAudioUpdates: Record<string, any> = {");
    expect(methodBody).toContain("locAudioUpdates[`audioTracks.${rawTargetLang}`] = directAudioUrl;");
    expect(methodBody).toContain("locAudioUpdates[`audioTrackSources.${rawTargetLang}`] = \"ai_dub\";");
    expect(methodBody).toContain("[`audioTrackSources.${targetLang}`]: \"ai_dub\"");

    // 5. Check ratio of audioTracks to audioTrackSources writes
    const audioTracksMatches = methodBody.match(/audioTracks/g) || [];
    const audioTrackSourcesMatches = methodBody.match(/audioTrackSources/g) || [];

    // Ensure audioTrackSources is written consistently alongside audioTracks
    expect(audioTrackSourcesMatches.length).toBeGreaterThanOrEqual(10);
    expect(audioTrackSourcesMatches.length).toBeGreaterThanOrEqual(audioTracksMatches.length - 6);
  });

  it("verifies processLanguage dubbing delivery writes audioTrackSources alongside audioTracks", () => {
    const content = fs.readFileSync(dubbingLayerFilePath, "utf8");

    const processStart = content.indexOf("private async processLanguage(");
    expect(processStart).toBeGreaterThan(-1);

    const processEnd = content.indexOf("loadSpeakerVoiceProfile(", processStart);
    expect(processEnd).toBeGreaterThan(processStart);

    const processBody = content.slice(processStart, processEnd);

    expect(processBody).toContain("videoDocUpdate[`audioTrackSources.${targetLang}`] = \"ai_dub\";");
    expect(processBody).toContain("videoDocUpdate[`media.audioTrackSources.${targetLang}`] = \"ai_dub\";");
    expect(processBody).toContain("locDocUpdate[`audioTrackSources.${targetLang}`] = \"ai_dub\";");
    expect(processBody).toContain("videoDocUpdate[`audioTrackSources.${rawTargetLang}`] = \"ai_dub\";");
    expect(processBody).toContain("videoDocUpdate[`media.audioTrackSources.${rawTargetLang}`] = \"ai_dub\";");
    expect(processBody).toContain("locDocUpdate[`audioTrackSources.${rawTargetLang}`] = \"ai_dub\";");
  });
});
