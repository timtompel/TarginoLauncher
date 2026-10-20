const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const directory = process.argv[2];
(async () => {
  for (const file of fs.readdirSync(directory).filter(f => f.endsWith('.svg'))) {
    await sharp(path.join(directory, file), { density: 160 }).resize(240, 100, {fit:'inside',withoutEnlargement:false}).png().toFile(path.join(directory, file.replace(/\.svg$/, '.png')));
  }
  console.log('Clear logos convertidos para PNG transparente.');
})().catch(error => { console.error(error.message); process.exitCode=1; });
