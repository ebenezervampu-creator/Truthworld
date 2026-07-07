const fs = require('fs');
const path = require('path');

const libDir = path.join(__dirname, 'lib');
const docsWidgetsDir = path.join(__dirname, 'docs', 'architecture', 'widgets');

function walkDir(dir, callback) {
    fs.readdirSync(dir).forEach(f => {
        let dirPath = path.join(dir, f);
        let isDirectory = fs.statSync(dirPath).isDirectory();
        isDirectory ? walkDir(dirPath, callback) : callback(path.join(dir, f));
    });
}

function extractClasses(content) {
    const classRegex = /class\s+([a-zA-Z0-9_]+)\s+extends\s+([a-zA-Z0-9_]+)/g;
    let match;
    const classes = [];
    while ((match = classRegex.exec(content)) !== null) {
        classes.push({
            name: match[1],
            extends: match[2]
        });
    }
    return classes;
}

if (!fs.existsSync(docsWidgetsDir)){
    fs.mkdirSync(docsWidgetsDir, { recursive: true });
}

let fileCount = 0;

walkDir(libDir, function(filePath) {
    // Check if the file is a dart file AND (is in a widgets folder OR has widget in the name)
    const relativePath = path.relative(libDir, filePath);
    const normalizedPath = relativePath.replace(/\\/g, '/');
    
    if (filePath.endsWith('.dart') && (normalizedPath.includes('/widgets/') || normalizedPath.endsWith('_widget.dart'))) {
        
        // Save relative to docs/architecture/widgets
        const targetPath = path.join(docsWidgetsDir, relativePath.replace('.dart', '_readme.md'));
        
        const targetDir = path.dirname(targetPath);
        if (!fs.existsSync(targetDir)){
            fs.mkdirSync(targetDir, { recursive: true });
        }

        const content = fs.readFileSync(filePath, 'utf8');
        const classes = extractClasses(content);
        
        const fileName = path.basename(filePath);
        
        let mdContent = `# Widget Documentation: ${fileName}\n\n`;
        mdContent += `## Overview\n`;
        mdContent += `This widget source file is located at \`lib/${normalizedPath}\`.\n\n`;
        
        if (classes.length > 0) {
            mdContent += `## UI Components (Classes)\n`;
            classes.forEach(c => {
                mdContent += `- **${c.name}** (Extends \`${c.extends}\`)\n`;
            });
            mdContent += `\n`;
        } else {
             mdContent += `*This file primarily contains UI utilities, extensions, or styles without explicit widget class definitions.*\n\n`;
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

console.log(`Successfully generated ${fileCount} Widget README files into docs/architecture/widgets/`);
