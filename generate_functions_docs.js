const fs = require('fs');
const path = require('path');

const functionsDir = path.join(__dirname, 'functions');
const docsFunctionsDir = path.join(__dirname, 'docs', 'functions');

// Clear existing directory to avoid old function1.md mixing with 1)filename.md
if (fs.existsSync(docsFunctionsDir)) {
    fs.rmSync(docsFunctionsDir, { recursive: true, force: true });
}
fs.mkdirSync(docsFunctionsDir, { recursive: true });

function walkDir(dir, callback) {
    fs.readdirSync(dir).forEach(f => {
        let dirPath = path.join(dir, f);
        if (dirPath.includes('node_modules')) return;
        let isDirectory = fs.statSync(dirPath).isDirectory();
        isDirectory ? walkDir(dirPath, callback) : callback(path.join(dir, f));
    });
}

let fileCount = 1;

walkDir(functionsDir, function(filePath) {
    if (filePath.endsWith('.ts')) {
        const content = fs.readFileSync(filePath, 'utf8');
        const fileName = path.basename(filePath, '.ts');
        
        // 1) Extract JSDoc block for explanation
        let explanation = "*No documentation block found in the source file. This file likely handles internal utility routing.*";
        const docRegex = /\/\*\*([\s\S]*?)\*\//;
        const docMatch = docRegex.exec(content);
        if (docMatch) {
            // Clean up the comment formatting
            explanation = docMatch[1].replace(/\n\s*\*/g, '\n').trim();
        }

        // 2) Extract Imports for dependencies
        const importRegex = /import\s+.*?from\s+['"]([^'"]+)['"]/g;
        let importMatch;
        const dependencies = [];
        while ((importMatch = importRegex.exec(content)) !== null) {
            dependencies.push(importMatch[1]);
        }

        // 3) Extract Exports
        const exportRegex = /export\s+(?:const|let|var|function|class|interface|type)\s+([a-zA-Z0-9_]+)/g;
        let exportMatch;
        const exportsList = [];
        while ((exportMatch = exportRegex.exec(content)) !== null) {
            exportsList.push(exportMatch[1]);
        }

        const relativePath = path.relative(functionsDir, filePath).replace(/\\/g, '/');
        
        // Name format: 1)filename.md
        const targetPath = path.join(docsFunctionsDir, `${fileCount})${fileName}.md`);
        
        let mdContent = `# Cloud Function: ${fileName}.ts\n\n`;
        mdContent += `**Location:** \`functions/${relativePath}\`\n\n`;
        
        mdContent += `## 📖 What it does & How it works\n`;
        mdContent += `${explanation}\n\n`;
        
        mdContent += `## ⚙️ Exports / Primary Functions\n`;
        if (exportsList.length > 0) {
            exportsList.forEach(e => mdContent += `- **${e}**\n`);
        } else {
            mdContent += `*No explicit exports found.*\n`;
        }
        mdContent += `\n`;

        mdContent += `## 🔗 Dependencies (What it depends on to work)\n`;
        if (dependencies.length > 0) {
            dependencies.forEach(d => {
                // If it starts with ., it's an internal function dependency
                if (d.startsWith('.')) {
                    mdContent += `- 🔄 **Internal Dependency**: \`${d}\`\n`;
                } else {
                    mdContent += `- 📦 **External Package**: \`${d}\`\n`;
                }
            });
        } else {
            mdContent += `*No dependencies detected.*\n`;
        }
        
        fs.writeFileSync(targetPath, mdContent);
        fileCount++;
    }
});
console.log(`Successfully generated ${fileCount - 1} detailed Cloud Function README files!`);
