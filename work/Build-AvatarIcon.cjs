// Conversao de formato/tamanho do avatar fornecido, sem redesenhar a arte.
const fs = require('fs');
const sharp = require('sharp');
(async () => {
  const sizes=[16,24,32,48,64,128,256];
  const parts=[];
  for(const size of sizes) parts.push(await sharp(process.argv[2]).resize(size,size,{fit:'contain',background:{r:0,g:0,b:0,alpha:0}}).png().toBuffer());
  const header=Buffer.alloc(6+16*parts.length);header.writeUInt16LE(1,2);header.writeUInt16LE(parts.length,4);
  let offset=header.length;
  for(let i=0;i<parts.length;i++){
    const at=6+i*16;header[at]=sizes[i]===256?0:sizes[i];header[at+1]=header[at];
    header.writeUInt16LE(1,at+4);header.writeUInt16LE(32,at+6);header.writeUInt32LE(parts[i].length,at+8);header.writeUInt32LE(offset,at+12);offset+=parts[i].length;
  }
  fs.writeFileSync(process.argv[3],Buffer.concat([header,...parts]));
  console.log('ICO gerado com 7 tamanhos, mantendo a proporcao.');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
