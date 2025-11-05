const fs = require('fs');

// Read the file
const content = fs.readFileSync('src/pages/Burn.tsx', 'utf8');

// Remove conflict markers and keep only the "Burn chances removed" version
const fixedContent = content
  .replace(/<<<<<<< Updated upstream[\s\S]*?=======\s*\n\s*\/\/ Burn chances removed - no need to load status\s*\n>>>>>>> Stashed changes/g, '  // Burn chances removed - no need to load status');

// Write the fixed content back
fs.writeFileSync('src/pages/Burn.tsx', fixedContent, 'utf8');

console.log('Fixed merge conflict in Burn.tsx');
