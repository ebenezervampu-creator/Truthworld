import fs from "fs";
import path from "path";

let isFontConfigInitialized = false;

/**
 * Standardized high-fidelity font stack for social preview cards (SVG -> Sharp PNG).
 * Prioritizes multilingual Noto Sans families for full coverage of Indic scripts
 * (Telugu, Devanagari/Hindi, Tamil, Bengali) along with Latin and numerals,
 * eliminating missing glyphs / tofu boxes on headless servers and social crawlers.
 */
export const TW_PREVIEW_FONT_FAMILY =
  "'TruthWorld Sans', 'Noto Sans', 'Noto Sans Telugu', 'Noto Sans Devanagari', 'Noto Sans Tamil', 'Noto Sans Bengali', Roboto, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";

/**
 * Resolves the absolute directory containing TruthWorld's embedded preview fonts.
 */
export function resolveFontsDirectory(): string | null {
  const candidates = [
    path.resolve(__dirname, "../../../fonts"),
    path.resolve(__dirname, "../../fonts"),
    path.resolve(__dirname, "../fonts"),
    path.resolve(process.cwd(), "fonts"),
    path.resolve(process.cwd(), "functions/fonts"),
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate) && fs.existsSync(path.join(candidate, "NotoSansTelugu-Regular.ttf"))) {
      return candidate;
    }
  }

  // Fallback: any candidate that exists
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }

  return null;
}

/**
 * Configures Fontconfig so that libvips / librsvg / Pango can locate and load
 * all multilingual Noto Sans fonts (including Telugu, Tamil, Devanagari, Bengali)
 * in headless serverless runtimes (Cloud Functions, Docker, Lambda).
 */
export function initSeoFontConfig(): void {
  if (isFontConfigInitialized) return;

  try {
    const fontsDir = resolveFontsDirectory();
    if (!fontsDir) {
      console.warn("[FontConfig] Warning: No fonts directory found. Font fallback may use OS defaults.");
      isFontConfigInitialized = true;
      return;
    }

    const cacheDir = path.join(fontsDir, ".cache");
    if (!fs.existsSync(cacheDir)) {
      try {
        fs.mkdirSync(cacheDir, { recursive: true });
      } catch (_) {
        // In read-only serverless filesystems, fall back to /tmp
      }
    }

    const effectiveCacheDir = fs.existsSync(cacheDir) ? cacheDir : "/tmp/tw-fonts-cache";
    if (!fs.existsSync(effectiveCacheDir)) {
      try {
        fs.mkdirSync(effectiveCacheDir, { recursive: true });
      } catch (_) {}
    }

    const normalizedFontsDir = fontsDir.replace(/\\/g, "/");
    const normalizedCacheDir = effectiveCacheDir.replace(/\\/g, "/");

    const fontsConfContent = `<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir>${normalizedFontsDir}</dir>
  <cachedir>${normalizedCacheDir}</cachedir>

  <!-- Generic sans-serif preference order for Indian & International text -->
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>TruthWorld Sans</family>
      <family>Noto Sans</family>
      <family>Noto Sans Telugu</family>
      <family>Noto Sans Devanagari</family>
      <family>Noto Sans Tamil</family>
      <family>Noto Sans Bengali</family>
      <family>Roboto</family>
    </prefer>
  </alias>

  <!-- Fallback aliases for system font names -->
  <alias>
    <family>-apple-system</family>
    <prefer>
      <family>TruthWorld Sans</family>
      <family>Noto Sans</family>
      <family>Noto Sans Telugu</family>
      <family>Noto Sans Devanagari</family>
      <family>Noto Sans Tamil</family>
      <family>Noto Sans Bengali</family>
      <family>Roboto</family>
    </prefer>
  </alias>

  <alias>
    <family>BlinkMacSystemFont</family>
    <prefer>
      <family>TruthWorld Sans</family>
      <family>Noto Sans</family>
      <family>Noto Sans Telugu</family>
      <family>Noto Sans Devanagari</family>
      <family>Noto Sans Tamil</family>
      <family>Noto Sans Bengali</family>
      <family>Roboto</family>
    </prefer>
  </alias>

  <alias>
    <family>Segoe UI</family>
    <prefer>
      <family>TruthWorld Sans</family>
      <family>Noto Sans</family>
      <family>Noto Sans Telugu</family>
      <family>Noto Sans Devanagari</family>
      <family>Noto Sans Tamil</family>
      <family>Noto Sans Bengali</family>
      <family>Roboto</family>
    </prefer>
  </alias>

  <alias>
    <family>Roboto</family>
    <prefer>
      <family>Roboto</family>
      <family>TruthWorld Sans</family>
      <family>Noto Sans</family>
      <family>Noto Sans Telugu</family>
      <family>Noto Sans Devanagari</family>
      <family>Noto Sans Tamil</family>
      <family>Noto Sans Bengali</family>
    </prefer>
  </alias>
</fontconfig>
`;

    const confPath = path.join(fontsDir, "fonts.conf");
    try {
      fs.writeFileSync(confPath, fontsConfContent, "utf8");
    } catch (_) {
      // In read-only filesystems, write to /tmp
      const fallbackConf = path.join(effectiveCacheDir, "fonts.conf");
      fs.writeFileSync(fallbackConf, fontsConfContent, "utf8");
      process.env.FONTCONFIG_FILE = fallbackConf;
    }

    process.env.FONTCONFIG_PATH = fontsDir;
    if (!process.env.FONTCONFIG_FILE) {
      process.env.FONTCONFIG_FILE = confPath;
    }

    isFontConfigInitialized = true;
  } catch (err) {
    console.error("[FontConfig] Failed to initialize Fontconfig for SEO renderers:", err);
    isFontConfigInitialized = true;
  }
}
