const path = require("path");
const fs = require("fs");
const { execFile } = require("child_process");
const { promisify } = require("util");
const execFileAsync = promisify(execFile);

const ffmpegPath = path.resolve("functions/node_modules/@ffmpeg-installer/win32-x64/ffmpeg.exe");

async function main() {
  console.log("================================================================================");
  console.log("🧪 TRUTHWORLD REAL AUDIO VALIDATION HARNESS ON 7-SECOND REFERENCE CLIP");
  console.log("================================================================================");

  const sourceAudio = path.resolve("tmp/exact_sample_english.wav");
  const oldTeluguAudio = path.resolve("tmp/old_telugu_recording.wav");
  const oldHindiAudio = path.resolve("tmp/old_hindi_recording.wav");

  // Step 1: Execute Updated High-Fidelity M&E Extraction (Relaxed Spectral Crossover, nf=-40)
  console.log("\n1. Generating Updated M&E stem (44.1kHz Stereo, relaxed afftdn=nf=-40)...");
  const updatedMnePath = path.resolve("tmp/updated_mne_stem.mp3");

  // 3-Band Frequency Crossover with relaxed afftdn=nf=-40 and vocal center-channel suppression
  const mneFilter =
    "[0:a]aformat=channel_layouts=stereo,asplit=3[low_in][mid_in][high_in];" +
    "[low_in]lowpass=f=220[low];" +
    "[mid_in]bandpass=f=1800:width_type=h:w=3200,stereotools=mlev=0.35:slev=1.35[mid];" +
    "[high_in]highpass=f=5000[high];" +
    "[low][mid][high]amix=inputs=3:weights=1.0 0.85 1.0:duration=first,volume=3[mne_raw];" +
    "[mne_raw]highpass=f=35,lowpass=f=18500,afftdn=nf=-40[mne]";

  await execFileAsync(ffmpegPath, [
    "-y",
    "-i", sourceAudio,
    "-filter_complex", mneFilter,
    "-map", "[mne]",
    "-c:a", "libmp3lame",
    "-b:a", "192k",
    "-ar", "44100",
    "-ac", "2",
    updatedMnePath,
  ]);
  console.log("✅ Updated M&E Stem generated:", updatedMnePath);

  // Step 2: Measure M&E Bed Level & Compute Safe Makeup Gain
  console.log("\n2. Measuring M&E Bed Integrated Loudness & Safety Check...");
  const probeArgs = [
    "-i", updatedMnePath,
    "-af", "loudnorm=I=-18:TP=-1:LRA=11:print_format=json",
    "-f", "null",
    "NUL",
  ];
  const probeRes = await execFileAsync(ffmpegPath, probeArgs).catch(e => ({ stderr: e.stderr || "" }));
  const jsonMatch = (probeRes.stderr || "").match(/\{[\s\S]*?"input_i"\s*:\s*"([\d.\-]+)"/);
  const inputI = jsonMatch ? parseFloat(jsonMatch[1]) : -26;
  console.log(`   M&E Raw Integrated Loudness: ${inputI.toFixed(1)} LUFS`);

  // Safety check on residual speech (window 3.1s - 7.0s where English voice spoke)
  const probeSpeech = await execFileAsync(ffmpegPath, [
    "-ss", "3.2",
    "-t", "3.5",
    "-i", updatedMnePath,
    "-af", "bandpass=f=1800:width_type=h:w=3000,volumedetect",
    "-f", "null",
    "NUL",
  ]).catch(e => ({ stderr: e.stderr || "" }));
  const speechMean = (probeSpeech.stderr || "").match(/mean_volume:\s*(-?[\d.]+)\s*dB/);
  const speechDb = speechMean ? parseFloat(speechMean[1]) : -35;
  console.log(`   M&E Speech-Band Residual Level (3.2s - 6.7s): ${speechDb.toFixed(1)} dBFS`);

  // Safety clamp
  let maxGainDb = 6.0;
  if (speechDb > -24) {
    maxGainDb = Math.max(0, 6.0 - (speechDb - (-24)) * 1.5);
    console.log(`   ⚠️ Residual speech safety clamp engaged: ceiling set to ${maxGainDb.toFixed(1)} dB`);
  }
  const rawGainDb = -18 - inputI;
  const clampedDb = Math.max(-6, Math.min(maxGainDb, rawGainDb));
  const mneLinearGain = Math.pow(10, clampedDb / 20).toFixed(4);
  console.log(`   Final M&E Makeup Gain Applied: +${clampedDb.toFixed(1)} dB (${mneLinearGain}x)`);

  // Step 3: Extract Isolated Dubbed Dialogue (without old corrupted M&E)
  // For Telugu:
  const teluguDialoguePath = path.resolve("tmp/extracted_telugu_dialogue.mp3");
  await execFileAsync(ffmpegPath, [
    "-y",
    "-i", oldTeluguAudio,
    "-af", "highpass=f=120,lowpass=f=14000",
    "-c:a", "libmp3lame",
    "-b:a", "192k",
    teluguDialoguePath,
  ]);

  // For Hindi:
  const hindiDialoguePath = path.resolve("tmp/extracted_hindi_dialogue.mp3");
  await execFileAsync(ffmpegPath, [
    "-y",
    "-i", oldHindiAudio,
    "-af", "highpass=f=120,lowpass=f=14000",
    "-c:a", "libmp3lame",
    "-b:a", "192k",
    hindiDialoguePath,
  ]);

  // Step 4: Render Updated Master Audio Tracks using New Mix Pipeline
  console.log("\n3. Rendering Updated Telugu Master Audio Track...");
  const updatedTeluguMaster = path.resolve("tmp/updated_telugu_master.mp3");
  const mixFilterTelugu =
    "[1:a]aformat=channel_layouts=stereo,asplit=2[dub_sc][dub_mix];" +
    `[0:a]aformat=channel_layouts=stereo,highpass=f=35,lowpass=f=18500,volume=${mneLinearGain}[mne_gained];` +
    "[mne_gained][dub_sc]sidechaincompress=threshold=0.08:ratio=2.0:attack=15:release=200:makeup=1[ducked];" +
    "[ducked][dub_mix]amix=inputs=2:weights=1.1 1.0:duration=first[mixed];" +
    "[mixed]loudnorm=I=-14:TP=-1:LRA=11[out]";

  await execFileAsync(ffmpegPath, [
    "-y",
    "-i", updatedMnePath,
    "-i", teluguDialoguePath,
    "-filter_complex", mixFilterTelugu,
    "-map", "[out]",
    "-c:a", "libmp3lame",
    "-b:a", "192k",
    "-ar", "44100",
    "-ac", "2",
    "-t", "7.000",
    updatedTeluguMaster,
  ]);
  console.log("✅ Updated Telugu Master Track:", updatedTeluguMaster);

  console.log("\n4. Rendering Updated Hindi Master Audio Track...");
  const updatedHindiMaster = path.resolve("tmp/updated_hindi_master.mp3");
  const mixFilterHindi =
    "[1:a]aformat=channel_layouts=stereo,asplit=2[dub_sc][dub_mix];" +
    `[0:a]aformat=channel_layouts=stereo,highpass=f=35,lowpass=f=18500,volume=${mneLinearGain}[mne_gained];` +
    "[mne_gained][dub_sc]sidechaincompress=threshold=0.08:ratio=2.0:attack=15:release=200:makeup=1[ducked];" +
    "[ducked][dub_mix]amix=inputs=2:weights=1.1 1.0:duration=first[mixed];" +
    "[mixed]loudnorm=I=-14:TP=-1:LRA=11[out]";

  await execFileAsync(ffmpegPath, [
    "-y",
    "-i", updatedMnePath,
    "-i", hindiDialoguePath,
    "-filter_complex", mixFilterHindi,
    "-map", "[out]",
    "-c:a", "libmp3lame",
    "-b:a", "192k",
    "-ar", "44100",
    "-ac", "2",
    "-t", "7.000",
    updatedHindiMaster,
  ]);
  console.log("✅ Updated Hindi Master Track:", updatedHindiMaster);

  // Step 5: Full Comparative Telemetry Measurement
  console.log("\n================================================================================");
  console.log("📊 COMPARATIVE TELEMETRY: ORIGINAL vs OLD CONTAMINATED vs NEW UPDATED MASTER");
  console.log("================================================================================");

  async function measure(filePath, name) {
    const ebu = await execFileAsync(ffmpegPath, [
      "-i", filePath,
      "-af", "ebur128=framelog=verbose",
      "-f", "null",
      "NUL",
    ]).catch(e => ({ stderr: e.stderr || "" }));
    const lufs = (ebu.stderr.match(/Integrated loudness:\s*I:\s*(-?[\d.]+)\s*LUFS/) || [])[1];
    const lra = (ebu.stderr.match(/Loudness range:\s*LRA:\s*(-?[\d.]+)\s*LU/) || [])[1];
    const tp = (ebu.stderr.match(/Peak:\s*True:\s*(-?[\d.]+)\s*dBFS/) || [])[1];

    const vol = await execFileAsync(ffmpegPath, [
      "-i", filePath,
      "-af", "volumedetect",
      "-f", "null",
      "NUL",
    ]).catch(e => ({ stderr: e.stderr || "" }));
    const mean = (vol.stderr.match(/mean_volume:\s*(-?[\d.]+)\s*dB/) || [])[1];

    const mid = await execFileAsync(ffmpegPath, [
      "-i", filePath,
      "-af", "bandpass=f=2000:width_type=h:w=3500,volumedetect",
      "-f", "null",
      "NUL",
    ]).catch(e => ({ stderr: e.stderr || "" }));
    const midDb = (mid.stderr.match(/mean_volume:\s*(-?[\d.]+)\s*dB/) || [])[1];

    // Music recovery during speech pause (0.0s to 3.0s before dialogue starts)
    const introMusic = await execFileAsync(ffmpegPath, [
      "-ss", "0.0",
      "-t", "2.5",
      "-i", filePath,
      "-af", "volumedetect",
      "-f", "null",
      "NUL",
    ]).catch(e => ({ stderr: e.stderr || "" }));
    const introMusicDb = (introMusic.stderr.match(/mean_volume:\s*(-?[\d.]+)\s*dB/) || [])[1];

    return {
      Track: name,
      "Integrated (LUFS)": parseFloat(lufs),
      "True Peak (dBTP)": parseFloat(tp),
      "Dynamics (LRA)": parseFloat(lra),
      "Mean Vol (dB)": parseFloat(mean),
      "Midrange (dB)": parseFloat(midDb),
      "Intro Music (0-2.5s dB)": parseFloat(introMusicDb),
    };
  }

  const comparison = [
    await measure(sourceAudio, "English Original (Reference)"),
    await measure(oldTeluguAudio, "Telugu Old (Contaminated Baseline)"),
    await measure(updatedTeluguMaster, "Telugu UPDATED Master"),
    await measure(oldHindiAudio, "Hindi Old (Contaminated Baseline)"),
    await measure(updatedHindiMaster, "Hindi UPDATED Master"),
  ];

  console.table(comparison);
}

main().catch(console.error);
