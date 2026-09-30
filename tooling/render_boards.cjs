const fs=require('fs'); const path=require('path'); const sharp=require('/Users/juancarlos/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const dir='/Users/juancarlos/Downloads/jogo/Tower Defense/docs/ac1/assets/final';
(async()=>{for(const file of fs.readdirSync(dir).filter(x=>x.endsWith('.svg'))){await sharp(path.join(dir,file)).png().toFile(path.join(dir,file.replace('.svg','.png')));console.log(file);}})();
