const { execFile } = require("child_process");
const { promisify } = require("util");
const path = require("path");
const execFileAsync = promisify(execFile);

const ffmpegPath = path.resolve("functions/node_modules/@ffmpeg-installer/win32-x64/ffmpeg.exe");

async function probeAudio(filePath, label) {
  // 1. Integrated Loudness, LRA, True Peak via ebur128
  const ebuRes = await execFileAsync(ffmpegPath, [
    "-i", filePath,
    "-af", "ebur128=framelog=verbose",
    "-f", "null",
    "NUL",
  ]).catch(e => ({ stderr: e.stderr || "" }));
  const ebuText = ebuRes.stderr || "";

  const lufsMatch = ebuText.match(/Integrated loudness:\s*I:\s*(-?[\d.]+)\s*LUFS/);
  const lraMatch = ebuText.match(/Loudness range:\s*LRA:\s*(-?[\d.]+)\s*LU/);
  const tpMatch = ebuText.match(/Peak:\s*True:\s*(-?[\d.]+)\s*dBFS/);

  // 2. Mean volume & Max volume
  const volRes = await execFileAsync(ffmpegPath, [
    "-i", filePath,
    "-af", "volumedetect",
    "-f", "null",
    "NUL",
  ]).catch(e => ({ stderr: e.stderr || "" }));
  const volText = volRes.stderr || "";
  const meanMatch = volText.match(/mean_volume:\s*(-?[\d.]+)\s*dB/);
  const maxMatch = volText.match(/max_volume:\s*(-?[\d.]+)\s*dB/);

  // 3. Midrange energy (250Hz - 3800Hz)
  const midRes = await execFileAsync(ffmpegPath, [
    "-i", filePath,
    "-af", "bandpass=f=2000:width_type=h:w=3500,volumedetect",
    "-f", "null",
    "NUL",
  ]).catch(e => ({ stderr: e.stderr || "" }));
  const midMeanMatch = (midRes.stderr || "").match(/mean_volume:\s*(-?[\d.]+)\s*dB/);

  // 4. Pause / Tail energy (last 2.0 seconds: 5.0s to 7.0s)
  const tailRes = await execFileAsync(ffmpegPath, [
    "-ss", "5.0",
    "-t", "2.0",
    "-i", filePath,
    "-af", "volumedetect",
    "-f", "null",
    "NUL",
  ]).catch(e => ({ stderr: e.stderr || "" }));
  const tailMeanMatch = (tailRes.stderr || "").match(/mean_volume:\s*(-?[\d.]+)\s*dB/);

  return {
    label,
    integratedLufs: lufsMatch ? parseFloat(lufsMatch[1]) : null,
    truePeakDb: tpMatch ? parseFloat(tpMatch[1]) : null,
    loudnessRangeLra: lraMatch ? parseFloat(lraMatch[1]) : null,
    meanVolumeDb: meanMatch ? parseFloat(meanMatch[1]) : null,
    maxVolumeDb: maxMatch ? parseFloat(maxMatch[1]) : null,
    midrangeEnergyDb: midMeanMatch ? parseFloat(midMeanMatch[1]) : null,
    pauseTailVolumeDb: tailMeanMatch ? parseFloat(tailMeanMatch[1]) : null,
  };
}

async function main() {
  console.log("Analyzing audio tracks...");
  const files = [
    { path: path.resolve("tmp/exact_sample_english.wav"), label: "English (Reference Source)" },
    { path: path.resolve("tmp/old_telugu_recording.wav"), label: "Telugu (Old Baseline - Contaminated)" },
    { path: path.resolve("tmp/old_hindi_recording.wav"), label: "Hindi (Old Baseline - Contaminated)" },
  ];

  const results = [];
  for (const f of files) {
    const data = await probeAudio(f.path, f.label);
    results.push(data);
  }

  console.table(results);
}

main().catch(console.error);
