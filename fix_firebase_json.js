const fs = require('fs');

try {
    const content = fs.readFileSync('firebase.json', 'utf8');
    // Attempt to parse, but it might fail if already broken.
    // If broken, we might need manual fix, but let's try to fix trailing commas if that's the issue?
    // No, the previous tool broke it. 

    // If I cannot parse it, I can't fix it easily with JSON.parse.
    // But wait, if I use a permissive parser or just Regex?

    // Let's TRY to parse. If it fails, I might have to use regex to remove the trailing comma.
    // The error was "Unexpected token ]". This usually means ", ]".

    // Regex to fix trailing commas before ] or }
    const fixedContent = content.replace(/,(\s*[\]}])/g, '$1');

    const data = JSON.parse(fixedContent);

    // Now ensure predeploy is gone
    if (data.functions) {
        if (Array.isArray(data.functions)) {
            data.functions.forEach(f => delete f.predeploy);
        } else {
            delete data.functions.predeploy;
        }
    }

    fs.writeFileSync('firebase.json', JSON.stringify(data, null, 2));
    console.log('Fixed firebase.json');

} catch (e) {
    console.error('Error fixing firebase.json:', e);
    process.exit(1);
}
