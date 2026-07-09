import * as fs from "fs";
import * as path from "path";
import { execSync } from "child_process";

const INDEX_PATH = path.join(__dirname, "../index.ts");

function stripComments(content: string): string {
  // Strip multi-line comments
  let clean = content.replace(/\/\*[\s\S]*?\*\//g, "");
  // Strip single-line comments
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
      .map(n => n.trim().split(/\s+as\s+/).pop()?.trim()) // Handle "name as alias"
      .filter(Boolean) as string[];
    
    names.forEach(n => exports.add(n.toLowerCase()));
  }

  return exports;
}

function getDeployedServices(): string[] {
  console.log("Fetching deployed Cloud Run services from gcloud...");
  const output = execSync(
    'gcloud run services list --project=truthworld-1 --region=asia-south1 --format="value(name)"',
    { encoding: "utf-8" }
  );
  return output.split("\n").map(s => s.trim()).filter(Boolean);
}

async function run() {
  try {
    const localExports = getExportedFunctions();
    console.log(`Found ${localExports.size} functions exported in index.ts:`);
    console.log(Array.from(localExports).sort().join(", "));
    console.log();

    const deployedServices = getDeployedServices();
    console.log(`Found ${deployedServices.length} deployed services on Cloud Run.\n`);

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

    console.log(`⚠️ Found ${staleServices.length} stale/unwanted services on Cloud Run:`);
    console.log("----------------------------------------");
    for (const service of staleServices) {
      console.log(` - ${service}`);
    }
    console.log("----------------------------------------\n");

    console.log("To delete all of these stale services, run the following commands:");
    console.log("----------------------------------------");
    for (const service of staleServices) {
      console.log(`gcloud run services delete ${service} --project=truthworld-1 --region=asia-south1 --quiet`);
    }
    console.log("----------------------------------------");

  } catch (error) {
    console.error("Error finding stale services:", error);
  }
}

run();
