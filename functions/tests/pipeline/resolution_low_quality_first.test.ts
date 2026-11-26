/**
 * "Low quality first" upload order (2026-11-21).
 *
 * A new upload becomes playable at 360p within seconds, like YouTube, instead of
 * waiting for 1080p/1440p. Then 720p and up are made (lowest first), and the other
 * low qualities are downscaled later from the finished 720p file.
 */

import * as fs from "fs";
import * as path from "path";
import {
  planUploadBatches,
  variantShortSide,
} from "../../src/resolution/resolutionPlanning";
import { STANDARD_RESOLUTION_LADDER } from "../../src/resolution/resolution";

type Tier = { label: string; width: number; height: number };

const landscape = (labels: string[]): Tier[] =>
  STANDARD_RESOLUTION_LADDER
    .filter((r) => labels.includes(r.label))
    .map((r) => ({ label: r.label, width: r.width, height: r.height }));

const portrait = (labels: string[]): Tier[] =>
  landscape(labels).map((t) => ({ ...t, width: t.height, height: t.width }));

const labelsOf = (tiers: Tier[]) => tiers.map((t) => t.label);

describe("planUploadBatches", () => {
  it("1080p source: 360p first, then 720p and 1080p; the rest later from 720p", () => {
    const plan = planUploadBatches(landscape(["1080p", "720p", "480p", "360p", "240p", "144p"]));
    expect(labelsOf(plan.primary)).toEqual(["360p", "720p", "1080p"]);
    expect(labelsOf(plan.secondary)).toEqual(["144p", "240p", "480p"]);
  });

  it("1440p source: high qualities go lowest first", () => {
    const plan = planUploadBatches(landscape(["1440p", "1080p", "720p", "480p", "360p", "240p", "144p"]));
    expect(labelsOf(plan.primary)).toEqual(["360p", "720p", "1080p", "1440p"]);
  });

  it("source below 720p: one batch from the original, 360p first", () => {
    const plan = planUploadBatches(landscape(["480p", "360p", "240p", "144p"]));
    expect(labelsOf(plan.primary)).toEqual(["360p", "144p", "240p", "480p"]);
    expect(plan.secondary).toEqual([]);
  });

  it("tiny source without 360p: its largest quality below 360p goes first", () => {
    const plan = planUploadBatches(landscape(["240p", "144p"]));
    expect(labelsOf(plan.primary)).toEqual(["240p", "144p"]);
  });

  it("portrait 1080x1920: classified by the shorter side, same order as landscape", () => {
    const plan = planUploadBatches(portrait(["1080p", "720p", "480p", "360p", "240p", "144p"]));
    expect(labelsOf(plan.primary)).toEqual(["360p", "720p", "1080p"]);
    // 480p portrait is 480x854: still a low quality, made from the 720p file
    expect(labelsOf(plan.secondary)).toEqual(["144p", "240p", "480p"]);
  });

  it("every quality is planned exactly once", () => {
    const all = landscape(["1440p", "1080p", "720p", "480p", "360p", "240p", "144p"]);
    const plan = planUploadBatches(all);
    expect([...labelsOf(plan.primary), ...labelsOf(plan.secondary)].sort()).toEqual(labelsOf(all).sort());
  });

  it("does not mutate the input order", () => {
    const all = landscape(["1080p", "720p", "360p"]);
    const before = labelsOf(all);
    planUploadBatches(all);
    expect(labelsOf(all)).toEqual(before);
  });
});

describe("variantShortSide", () => {
  it("uses the shorter side, so portrait tiers keep their quality class", () => {
    expect(variantShortSide({ width: 1920, height: 1080 })).toBe(1080);
    expect(variantShortSide({ width: 480, height: 854 })).toBe(480);
    expect(variantShortSide({ height: 720 })).toBe(720);
  });
});

describe("Wiring in resolution.ts", () => {
  const src = fs.readFileSync(path.resolve(__dirname, "../../src/resolution/resolution.ts"), "utf8");

  it("the upload trigger publishes the planned primary batch", () => {
    expect(src).toContain("const primaryBatch = planUploadBatches(applicableResolutions).primary;");
    expect(src).not.toContain("applicableResolutions.filter((r) => r.height >= 720)");
  });

  it("the worker classifies tiers by shorter side (portrait-safe)", () => {
    expect(src).toContain("variantsToProcess.every((v) => variantShortSide(v) <= 480)");
    expect(src).toContain("const isHighTier = variantShortSide(targetVariant) >= 720;");
  });
});
