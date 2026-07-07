const fs = require('fs');
const path = require('path');

const libDir = path.join(__dirname, 'lib');
const docsDir = path.join(__dirname, 'docs', 'codebase');

function walkDir(dir, callback) {
    fs.readdirSync(dir).forEach(f => {
        let dirPath = path.join(dir, f);
        let isDirectory = fs.statSync(dirPath).isDirectory();
        isDirectory ? walkDir(dirPath, callback) : callback(path.join(dir, f));
    });
}

function extractClasses(content) {
    const classRegex = /class\s+([a-zA-Z0-9_]+)/g;
    let match;
    const classes = [];
    while ((match = classRegex.exec(content)) !== null) {
        classes.push(match[1]);
    }
    return classes;
}

function extractMethods(content) {
    // Rough regex for methods/functions
    const methodRegex = /(?:Future<[^>]+>|void|String|int|bool|Widget|Stream<[^>]+>)\s+([a-zA-Z0-9_]+)\s*\(/g;
    let match;
    const methods = [];
    while ((match = methodRegex.exec(content)) !== null) {
        if (!['if', 'switch', 'catch', 'while', 'for'].includes(match[1])) {
             methods.push(match[1]);
        }
    }
    return methods;
}

if (!fs.existsSync(docsDir)){
    fs.mkdirSync(docsDir, { recursive: true });
}

let fileCount = 0;

walkDir(libDir, function(filePath) {
    if (filePath.endsWith('.dart')) {
        const relativePath = path.relative(libDir, filePath);
        const targetPath = path.join(docsDir, relativePath.replace('.dart', '_readme.md'));
        
        const targetDir = path.dirname(targetPath);
        if (!fs.existsSync(targetDir)){
            fs.mkdirSync(targetDir, { recursive: true });
        }

        const content = fs.readFileSync(filePath, 'utf8');
        const classes = extractClasses(content);
        // const methods = extractMethods(content);
        
        const fileName = path.basename(filePath);
        
        let mdContent = `# Codebase: ${fileName}\n\n`;
        mdContent += `## Overview\n`;
        mdContent += `This file is located at \`lib/${relativePath}\`.\n\n`;
        
        if (classes.length > 0) {
            mdContent += `## Classes\n`;
            classes.forEach(c => {
                mdContent += `- **${c}**\n`;
            });
            mdContent += `\n`;
        } else {
             mdContent += `*This file primarily contains utilities, variables, or procedural code without explicit class definitions.*\n\n`;
        }

        mdContent += `## Dependencies & Imports\n`;
        const importRegex = /import\s+'([^']+)';/g;
        let importMatch;
        let hasImports = false;
        while ((importMatch = importRegex.exec(content)) !== null) {
            hasImports = true;
            mdContent += `- \`${importMatch[1]}\`\n`;
        }
        if (!hasImports) mdContent += `*No external imports detected.*\n`;
        
        fs.writeFileSync(targetPath, mdContent);
        fileCount++;
    }
});

console.log(`Successfully generated ${fileCount} README files into docs/codebase/`);
