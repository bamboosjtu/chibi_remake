import fs from 'node:fs';
import path from 'node:path';
const source='godot/chibi_remake';
const stage=process.argv[2];
const terrainArg=process.argv.indexOf('--terrain-root');
const terrainRoot=terrainArg<0?'_work/terrain/current':process.argv[terrainArg+1];
const resolveInput=file=>file.startsWith('art/full/terrain_chunks/')?path.join(terrainRoot,file):path.join(source,file);
// Public mode excludes original video/audio; procedural BGM and SFX remain available.
const noOriginalMedia=process.env.CHIBI_NO_ORIGINAL_MEDIA==='1'||process.argv.includes('--no-original-media');
if(!stage||fs.existsSync(stage))throw new Error('Use a new staging directory.');
const selected=new Set();
function add(file){
  file=file.replace(/^res:\/\//,'');
  if(file.includes('..')||path.isAbsolute(file))throw new Error('Unsafe resource path: '+file);
  if(!fs.existsSync(resolveInput(file)))throw new Error('Missing required resource: '+file);
  selected.add(file);
}
// ⚠️ 必须排除点开头的东西：/\\.(gd|tscn|godot)$/ 的本意是匹配 project.godot，
// 但它**也匹配目录 `.godot`** —— 于是 staging 会对一个目录做 copyFileSync，报 EPERM。
// 这个坑平时不显形，因为 `.godot`（导入缓存）不存在时 readdir 里根本没有它。
// 2026-10-17（structure-refine-plan P4 前置）：改为**递归枚举**——目录迁移
// （simulation/、presentation/ 等嵌套脚本）必须进入打包，否则 PCK 缺脚本。
function walkScripts(dir, prefix) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.')) continue;
    const rel = prefix ? prefix + '/' + entry.name : entry.name;
    if (entry.isDirectory()) { walkScripts(dir + '/' + entry.name, rel); continue; }
    if (/\.(gd|tscn|godot|gdextension)$/.test(entry.name)) add(rel);
  }
}
walkScripts(source, '');
const full=JSON.parse(fs.readFileSync(source+'/art/full/manifest.json'));
add('art/full/manifest.json');add('art/full/team_palette.json');add('art/full/team_color.gdshader');add('art/full/gate_apertures.gdshader');add('art/full/gate_wood.gdshader');
for(const entry of Object.values(full.runtimeAssets||{}))if(entry.texture)add(entry.texture);
const gateTerrain='art/full/gate_terrain/manifest.json';
add(gateTerrain);
for(const entries of Object.values(JSON.parse(fs.readFileSync(source+'/'+gateTerrain)).maps))for(const entry of entries){add(entry.texture);add(entry.roadTexture);}
for(const entries of [full.atlases,full.officers,full.backgrounds])for(const entry of Object.values(entries)){
  add(entry.texture);for(const frame of entry.frames||[])if(frame.texture)add(frame.texture);
}
// 正式 HUD 只打包正在引用的手绘母版。旧 BMP 提取图保留在研究参考目录。
const runtimeUi=['hud_right-redraw-v2.png','hud_banner-redraw-v2.png','hud-ornate-frame-v3.png','hud-horizontal-bands-v4.png','cmd-icons-redraw-v3.png','command-attack-v4.png','resource-icons-redraw-v3.png','resource-decor-redraw-v1.png','left-controls-redraw-v4.png'];
for(const file of runtimeUi)add('art/full/ui/'+file);
for(const file of ['command-form-hd-v2.png','command-join-hd-v2.png'])add('art/full/ui/'+file);
// Researched software cursor sheets and command strips include their own states.
for(const file of ['cursor-hd-v1.png','cursor-edges-hd-v1.svg'])add('art/full/ui/input/'+file);
// 内置中文字体（Noto Sans CJK SC / SIL OFL）与程序图标：不能依赖玩家系统字体回退。
for(const file of ['assets/fonts/NotoSansCJKsc-Regular.otf','assets/fonts/OFL.txt','assets/icon.png','assets/icon.ico'])add(file);
for(const file of fs.readdirSync(source+'/data/db').filter(x=>x.endsWith('.json')))add('data/db/'+file);
const events=JSON.parse(fs.readFileSync(source+'/data/db/events.json'));
for(const event of Object.values(events.events))if(event.video&&!noOriginalMedia)add(event.video);
// Direct playback uses the supplied AVI bytes and the native decoder, never OGV derivatives.
if(!noOriginalMedia)for(const file of fs.readdirSync(source+'/media/videos'))if(/\.avi$/i.test(file))add('media/videos/'+file);
// Music WAVs exist only as the source for the shipped OGG tracks; no runtime path
// loads them. Keep the OGG playback set in the package and leave the masters local.
const audioIndex=JSON.parse(fs.readFileSync(source+'/data/db/audio_index.json'));
const musicMasters=new Set(Object.values(audioIndex.entries).filter(entry=>entry.kind==='music').map(entry=>path.basename(entry.file)));
musicMasters.add('vend.wav');
for(const dir of ['media/sfx','media/music']){
  if(noOriginalMedia)continue;
  const p=source+'/'+dir;
  if(fs.existsSync(p))for(const file of fs.readdirSync(p))if(/\.(wav|ogg)$/i.test(file)&&!(file.endsWith('.wav')&&musicMasters.has(file)))add(dir+'/'+file);
}
// Godot may create ~FFmpegPlayer.dll while importing; package declared dependencies only.
const decoderConfig=fs.readFileSync(source+'/addons/ffmpegplayer/FFmpegPlayer.gdextension','utf8');
for(const file of new Set(decoderConfig.match(/res:\/\/addons\/ffmpegplayer\/win64\/[^"\s]+\.dll/g)||[]))add(file);
for(const file of fs.readdirSync(source+'/addons/ffmpegplayer'))if(/\.(txt|json)$/.test(file))add('addons/ffmpegplayer/'+file);
add('art/full/terrain_events/manifest.json');
for(const entry of Object.values(JSON.parse(fs.readFileSync(source+'/art/full/terrain_events/manifest.json'))))add(entry.texture);
for(const filename of fs.readdirSync(source+'/data').filter(x=>x.startsWith('chibi')&&x.endsWith('.json'))){
  const level=JSON.parse(fs.readFileSync(source+'/data/'+filename));
  if(level.artMode !== 'hd-catalog')throw new Error('Re-export HD metadata: '+filename);
  add('data/'+filename);
  const chunkPath='art/full/terrain_chunks/'+filename.slice(0,-5)+'/manifest.json';add(chunkPath);
  const chunks=JSON.parse(fs.readFileSync(resolveInput(chunkPath)));
  for(const chunk of chunks.chunks)for(const lod of Object.values(chunk.lods))add(lod.texture);
}
if(process.argv.includes('--list-inputs')){console.log(JSON.stringify([...selected].sort()));process.exit(0);}
fs.mkdirSync(stage,{recursive:true});
for(const file of selected){

  const target=path.join(stage,file);fs.mkdirSync(path.dirname(target),{recursive:true});
  if(/\.(png|jpg|ogv|bin)$/.test(file)){
    // 已选定的二进制素材只读；同卷构建链接避免数万文件的重复复制。
    // 正式交付是独立打包的 PCK，不依赖这些构建链接。
    try{fs.linkSync(resolveInput(file),target);}catch{fs.copyFileSync(resolveInput(file),target);}
  }else fs.copyFileSync(resolveInput(file),target);
  // Import configuration is source metadata; compiled caches remain isolated.
  if(fs.existsSync(source+'/'+file+'.import'))fs.copyFileSync(source+'/'+file+'.import',target+'.import');
  if(fs.existsSync(source+'/'+file+'.uid'))fs.copyFileSync(source+'/'+file+'.uid',target+'.uid');

}

let cfg=fs.readFileSync(source+'/export_presets.cfg','utf8').replace(/include_filter="[^"]*"/g,'include_filter="*.json,*.txt,*.otf,*.bin,*.AVI"');
fs.writeFileSync(stage+'/export_presets.cfg',cfg);
const bytes=[...selected].reduce((sum,file)=>sum+fs.statSync(resolveInput(file)).size,0);
const runtimeFiles=[...selected].map(file=>file.startsWith('art/full/terrain_chunks/')&&file.endsWith('.jpg')?file.replace(/\.jpg$/,'.bin'):file);
fs.writeFileSync(stage+'/release_inputs.json',JSON.stringify({schemaVersion:1,originalMedia:!noOriginalMedia,files:runtimeFiles.sort(),sourceFiles:[...selected].sort(),sourceBytes:bytes,budgets:{terrainResidentBytes:402653184}},null,2));
console.log('Staged only declared runtime resources:',selected.size,'source GiB',(bytes/2**30).toFixed(2));
