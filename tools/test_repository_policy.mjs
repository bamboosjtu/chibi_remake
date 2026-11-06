import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';

const root=process.cwd();
const sandbox=fs.mkdtempSync(path.join(os.tmpdir(),'chibi-source-policy-'));
const data=Buffer.from('runtime fixture');
const sha256=crypto.createHash('sha256').update(data).digest('hex');
function git(args,input) {
 const result=spawnSync('git',['-c','core.autocrlf=false',...args],{cwd:sandbox,input,encoding:'utf8'});
 assert.equal(result.status,0,result.stderr);
 return result.stdout;
}
function audit() {
 return spawnSync(process.execPath,[path.join(root,'tools/audit_clone_inputs.mjs'),'--index'],{cwd:sandbox,encoding:'utf8'});
}
function write(file,content='local fixture') {
 const target=path.join(sandbox,file);
 fs.mkdirSync(path.dirname(target),{recursive:true});
 fs.writeFileSync(target,content);
}
function pointer(file,hash=sha256) {
 const text=`version https://git-lfs.github.com/spec/v1\noid sha256:${hash}\nsize ${data.length}\n`;
 const id=git(['hash-object','-w','--stdin'],text).trim();
 git(['update-index','--add','--cacheinfo','100644',id,file]);
}
try {
 git(['init','--quiet']);
 for(const file of ['.gitignore','.gitattributes'])fs.copyFileSync(path.join(root,file),path.join(sandbox,file));
 const sources=['godot/chibi_remake/main.gd','godot/chibi_remake/main.gd.uid','godot/chibi_remake/art/full/team_color.gdshader','godot/chibi_remake/art/full/team_color.gdshader.uid','godot/chibi_remake/data/db/rules.json','godot/chibi_remake/art/production/catalog.json','research/units/data/units.json','docs/README.md','docs/assets/poster.jpg'];
 const local=['godot/chibi_remake/art/full/ui/hud.png','godot/chibi_remake/art/full/maps/chibic1_q0.png','godot/chibi_remake/art/full/terrain/unused.png','godot/chibi_remake/art/production/references/example.png','godot/chibi_remake/assets/fonts/font.otf','research/units/assets/reference.svg','research/units/assets/notes.md','docs/changes/draft.md'];
 const runtime=[['art/full/ui/hud_right-redraw-v2.png',['.import']],['art/full/ui/input/cursor-edges-hd-v1.svg',[]],['media/videos/START.AVI',['.uid']],['assets/fonts/NotoSansCJKsc-Regular.otf',[]],['addons/ffmpegplayer/win64/FFmpegPlayer.dll',[]]];
 for(const file of [...sources,...local])write(file);
 for(const [file,metadata] of runtime) {
  write('godot/chibi_remake/'+file,data);
  for(const suffix of metadata)write('godot/chibi_remake/'+file+suffix);
 }
 write('tools/inputs/runtime_assets.sha256',runtime.map(([file,metadata])=>[sha256,data.length,file,...(metadata.length?[metadata.join(',')]:[])].join('\t')).join('\n')+'\n');
 git(['add','--','.']);
 for(const [file] of runtime)if(!file.endsWith('.svg'))pointer('godot/chibi_remake/'+file);
 const tracked=new Set(git(['ls-files','-z']).split('\0').filter(Boolean));
 for(const file of sources)assert(tracked.has(file),'Missing source: '+file);
 for(const file of local)assert(!tracked.has(file),'Local asset tracked: '+file);
 let result=audit();assert.equal(result.status,0,result.stderr);
 assert(result.stdout.includes('RUNTIME INDEX PASS'));
 // Force-added production references must fail, even when they are valid images.
 git(['add','--force','--',local[0]]);
 result=audit();assert.notEqual(result.status,0);
 assert(result.stderr.includes('Local-only files still tracked'));
 git(['rm','--cached','--quiet','--',local[0]]);
 assert(fs.existsSync(path.join(sandbox,local[0])),'Index removal deleted the local asset');
 const metadata='godot/chibi_remake/art/full/ui/hud_right-redraw-v2.png.import';
 git(['rm','--cached','--quiet','--',metadata]);
 result=audit();assert.notEqual(result.status,0);assert(result.stderr.includes('Required runtime asset/metadata not tracked'));
 git(['add','--',metadata]);
 const extra='godot/chibi_remake/art/full/terrain_chunks/chibic1/unused.jpg';write(extra,data);git(['add','--force','--',extra]);
 result=audit();assert.notEqual(result.status,0);assert(/Derived terrain|Local-only files still tracked/.test(result.stderr));
 git(['rm','--cached','--force','--quiet','--',extra]);
 const first='godot/chibi_remake/'+runtime[0][0];pointer(first,'0'.repeat(64));
 result=audit();assert.notEqual(result.status,0);assert(result.stderr.includes('Staged LFS asset differs'));
 pointer(first);
 result=audit();assert.equal(result.status,0,result.stderr);
 console.log('REPOSITORY POLICY PASS declared runtime assets/LFS/metadata retained; references and unused bakes rejected; missing metadata and changed pointers rejected');
} finally {
 // Only the fresh fixture returned by mkdtemp is eligible for deletion.
 assert(path.dirname(sandbox)===os.tmpdir() && path.basename(sandbox).startsWith('chibi-source-policy-'));
 fs.rmSync(sandbox,{recursive:true,force:true});
}
