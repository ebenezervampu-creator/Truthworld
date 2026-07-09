import * as fs from "fs";
import * as path from "path";
import { exec } from "child_process";
import { promisify } from "util";

const execPromise = promisify(exec);
const INDEX_PATH = path.join(__dirname, "../index.ts");

function stripComments(content: string): string {
  let clean = content.replace(/\/\*[\s\S]*?\*\//g, "");
  clean = clean.split("\n").map(line => {
    const idx = line.indexOf("//");
    if (idx !== -1) {
      return line.substring(0, idx);
    }
    return line;
  }).join("\n");
  return clean;
}

function getExportedFunctions(): Set<string> {
  const content = stripComments(fs.readFileSync(INDEX_PATH, "utf-8"));
  const exports = new Set<string>();

  // 1. Match "export const name = ..."
  const constRegex = /export\s+const\s+([a-zA-Z0-9_$]+)\s*=/g;
  let match;
  while ((match = constRegex.exec(content)) !== null) {
    exports.add(match[1].toLowerCase());
  }

  // 2. Match "export { name1, name2 } from ..." or just "export { name1, name2 }"
  const curlyRegex = /export\s+\{([^}]+)\}/g;
  while ((match = curlyRegex.exec(content)) !== null) {
    const names = match[1]
      .split(",")
      .map(n => n.trim().split(/\s+as\s+/).pop()?.trim())
      .filter(Boolean) as string[];
    
    names.forEach(n => exports.add(n.toLowerCase()));
  }

  return exports;
}

async function getDeployedServices(): Promise<string[]> {
  console.log("Fetching deployed Cloud Run services from gcloud...");
  const { stdout } = await execPromise(
    'gcloud run services list --project=truthworld-1 --region=asia-south1 --format="value(name)"'
  );
  return stdout.split("\n").map(s => s.trim()).filter(Boolean);
}

// Helper to limit concurrency
async function pLimit<T>(items: T[], limit: number, fn: (item: T) => Promise<void>) {
  const executing = new Set<Promise<void>>();
  for (const item of items) {
    const p = fn(item).then(() => {
      executing.delete(p);
    });
    executing.add(p);
    if (executing.size >= limit) {
      await Promise.race(executing);
    }
  }
  await Promise.all(executing);
}

async function run() {
  try {
    const localExports = getExportedFunctions();
    const deployedServices = await getDeployedServices();

    const staleServices: string[] = [];
    for (const service of deployedServices) {
      const normalizedService = service.toLowerCase().replace(/[^a-z0-9]/g, "");
      
      let isLocal = false;
      for (const localExp of localExports) {
        const normalizedLocal = localExp.toLowerCase().replace(/[^a-z0-9]/g, "");
        if (normalizedService === normalizedLocal) {
          isLocal = true;
          break;
        }
      }

      if (!isLocal) {
        staleServices.push(service);
      }
    }

    if (staleServices.length === 0) {
      console.log("✅ No stale services found! All deployed services match current index.ts exports.");
      return;
    }

    console.log(`Deleting ${staleServices.length} stale services in parallel (concurrency limit: 15)...`);
    
    let completedCount = 0;
    await pLimit(staleServices, 15, async (service) => {
      try {
        console.log(`[Start] Deleting service: ${service}`);
        await execPromise(`gcloud run services delete ${service} --project=truthworld-1 --region=asia-south1 --quiet`);
        completedCount++;
        console.log(`[Success] Deleted service: ${service} (${completedCount}/${staleServices.length})`);
      } catch (err: any) {
        console.error(`[Failed] Failed to delete service ${service}:`, err.message);
      }
    });

    console.log("\nCleanup complete!");

  } catch (error) {
    console.error("Cleanup error:", error);
  }
}

run();
