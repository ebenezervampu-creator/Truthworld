const path = require('path');
const fs = require('fs');

async function main() {
  try {
    const loader = require('./node_modules/firebase-functions/lib/runtime/loader.js');
    const manifest = require('./node_modules/firebase-functions/lib/runtime/manifest.js');
    const stack = await loader.loadStack(__dirname);
    const wireFormat = manifest.stackToWire(stack);
    const outputPath = path.join(__dirname, 'functions.yaml');
    fs.writeFileSync(outputPath, JSON.stringify(wireFormat, null, 2));
    console.log('[manifest] Successfully generated functions.yaml (' + Object.keys(wireFormat.endpoints || {}).length + ' endpoints)');
  } catch (err) {
    console.error('[manifest] Error generating functions.yaml:', err);
    process.exit(1);
  }
}

main();
