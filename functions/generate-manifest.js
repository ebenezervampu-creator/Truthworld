const path = require('path');
const fs = require('fs');

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'truthworld-1';
process.env.PROJECT_ID = process.env.PROJECT_ID || 'truthworld-1';

async function main() {
  try {
    const loader = require('./node_modules/firebase-functions/lib/runtime/loader.js');
    const manifest = require('./node_modules/firebase-functions/lib/runtime/manifest.js');
    const stack = await loader.loadStack(__dirname);
    const wireFormat = manifest.stackToWire(stack);
    const outputPath = path.join(__dirname, 'functions.yaml');
    const content = JSON.stringify(wireFormat, null, 2);
    let written = false;
    for (let i = 0; i < 5; i++) {
      try {
        fs.writeFileSync(outputPath, content);
        written = true;
        break;
      } catch (writeErr) {
        const waitMs = 300 * (i + 1);
        Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, waitMs);
      }
    }
    if (!written) {
      fs.writeFileSync(outputPath, content);
    }
    console.log('[manifest] Successfully generated functions.yaml (' + Object.keys(wireFormat.endpoints || {}).length + ' endpoints)');
    process.exit(0);
  } catch (err) {
    console.error('[manifest] Error generating functions.yaml:', err);
    process.exit(1);
  }
}

main();
