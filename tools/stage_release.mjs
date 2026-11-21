import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync, spawnSync} from 'node:child_process';
import {copyAcceptanceScripts, copyReleaseInput, isReleaseScript, readReleaseSnapshot} from './lib/release_source.mjs';
import {assertRulesManifest, manifestPath, rulesManifestText} from './rules_manifest.mjs';
const source='godot/chibi_remake';
const stage=process.argv[2];
const option=(name,fallback)=>{
  const index=process.argv.indexOf(name);
  if(index<0)return fallback;
  const value=process.argv[index+1];
  if(!value||value.startsWith('--'))throw Error('Missing argument for '+name);
  return value;
};
const terrainRoot=option('--terrain-root','_work/terrain/current');
const commit=option('--source-commit',null);
const acceptanceDir=option('--acceptance-dir',null);
const listInputs=process.argv.includes('--list-inputs');
const omitGeneratedTerrain=listInputs&&process.argv.includes('--omit-generated-terrain');
const snapshot=commit?readReleaseSnapshot(commit):null;
const generated=file=>file.startsWith('art/full/terrain_chunks/');
const resolveInput=file=>path.join(generated(file)?terrainRoot:source,file);
const hasSource=file=>snapshot?snapshot.has(file):fs.existsSync(path.join(source,file));
const readSource=file=>{
  if(!snapshot)return fs.readFileSync(path.join(source,file),'utf8');
  if(!snapshot.has(file))throw Error('Release input is not tracked at the build commit: '+file);
  return snapshot.get(file).toString('utf8');
};
if(snapshot){
  const simulationFiles=[...snapshot.keys()].filter(file=>file.startsWith('simulation/')&&file.endsWith('.gd'));
  const nativeSource=execFileSync('git',['show',commit+':tools/native/sim_math/sim_math.cpp'],{encoding:'utf8'});
  assertRulesManifest(rulesManifestText(simulationFiles,readSource,nativeSource),readSource(manifestPath));
}else{
  const rulesCheck=spawnSync(process.execPath,['tools/rules_manifest.mjs','--check'],{encoding:'utf8'});
  if(rulesCheck.status!==0)throw Error(rulesCheck.stderr||rulesCheck.stdout);
}
const listSource=directory=>{
  if(!snapshot){
    const location=path.join(source,directory);
    return fs.existsSync(location)?fs.readdirSync(location):[];
  }
  const prefix=directory+'/';
  return [...snapshot.keys()].filter(file=>file.startsWith(prefix)).map(file=>file.slice(prefix.length)).filter(file=>!file.includes('/'));
};
// Public mode excludes original video/audio; procedural BGM and SFX remain available.
const noOriginalMedia=process.env.CHIBI_NO_ORIGINAL_MEDIA==='1'||process.argv.includes('--no-original-media');
const includeLocalCampaign=!noOriginalMedia&&process.argv.includes('--include-local-campaign-media');
const localCampaign=new Set();
if(!stage||fs.existsSync(stage))throw new Error('Use a new staging directory.');
const selected=new Set();
function add(file){
  file=file.replace(/^res:\/\//,'');
  if(file.includes('..')||path.isAbsolute(file))throw new Error('Unsafe resource path: '+file);
  if(!(generated(file)?fs.existsSync(resolveInput(file)):hasSource(file)))throw new Error('Missing required resource: '+file);
  selected.add(file);
}
// ⚠️ 必须排除点开头的东西：/\\.(gd|tscn|godot)$/ 的本意是匹配 project.godot，
// 但它**也匹配目录 `.godot`** —— 于是 staging 会对一个目录做 copyFileSync，报 EPERM。
// 这个坑平时不显形，因为 `.godot`（导入缓存）不存在时 readdir 里根本没有它。
// 2026-10-17（structure-refine-plan P4 前置）：改为**递归枚举**——目录迁移
// （simulation/、presentation/ 等嵌套脚本）必须进入打包，否则 PCK 缺脚本。
function walkScripts(dir, prefix) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.') || (!prefix && entry.name === 'testing')) continue;
    const rel = prefix ? prefix + '/' + entry.name : entry.name;
    if (entry.isDirectory()) { walkScripts(dir + '/' + entry.name, rel); continue; }
    if (isReleaseScript(rel)) add(rel);
  }
}
if(snapshot){
  for(const file of snapshot.keys())if(isReleaseScript(file))add(file);
}else{
  walkScripts(source, '');
}
add('simulation/native/bin/ChibiSimulationMath.dll');add('simulation/native/LICENSE-godot-cpp.txt');
const full=JSON.parse(readSource('art/full/manifest.json'));
add('art/full/manifest.json');add('art/full/team_palette.json');add('art/full/team_color.gdshader');add('art/full/gate_apertures.gdshader');add('art/full/gate_wood.gdshader');
for(const entry of Object.values(full.runtimeAssets||{}))if(entry.texture)add(entry.texture);
const gateTerrain='art/full/gate_terrain/manifest.json';
add(gateTerrain);
for(const entries of Object.values(JSON.parse(readSource(gateTerrain)).maps))for(const entry of entries){add(entry.texture);add(entry.roadTexture);}
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
for(const file of listSource('data/db').filter(x=>x.endsWith('.json')))add('data/db/'+file);
const events=JSON.parse(readSource('data/db/events.json'));
for(const event of Object.values(events.events))if(event.video&&!noOriginalMedia)add(event.video);
// Shared originals may be exported. The campaign remaster is local-only unless a
// private staging run explicitly opts in; NoOriginalMedia vetoes both.
const videoCatalog=JSON.parse(readSource('data/db/video_catalog.json')).files;
for(const [name,entry] of Object.entries(videoCatalog)){
  if(!/^(?:[A-Z0-9]+\.AVI|(?:CAO|LIU)[0-9]+[A-Z]?\.mp4)$/.test(name)||entry.path!=='res://media/videos/'+name)throw Error('Invalid video catalog path: '+name);
  if((entry.localOnly===true)!==name.endsWith('.mp4'))throw Error('Invalid campaign media classification: '+name);
  if(noOriginalMedia)continue;
  if(!entry.localOnly){add(entry.path);continue;}
  if(!includeLocalCampaign)continue;
  const file='media/videos/'+name, bytes=fs.readFileSync(resolveInput(file));
  if(bytes.length!==entry.bytes||createHash('sha256').update(bytes).digest('hex')!==entry.sha256)throw Error('Local campaign media differs from catalog: '+name);
  localCampaign.add(file);selected.add(file);
}
// Music WAVs exist only as the source for the shipped OGG tracks; no runtime path
// loads them. Keep the OGG playback set in the package and leave the masters local.
const audioIndex=JSON.parse(readSource('data/db/audio_index.json'));
const musicMasters=new Set(Object.values(audioIndex.entries).filter(entry=>entry.kind==='music').map(entry=>path.basename(entry.file)));
musicMasters.add('vend.wav');
for(const dir of ['media/sfx','media/music']){
  if(noOriginalMedia)continue;
  for(const file of listSource(dir))if(/\.(wav|ogg)$/i.test(file)&&!(file.endsWith('.wav')&&musicMasters.has(file)))add(dir+'/'+file);
}
// Godot may create ~FFmpegPlayer.dll while importing; package declared dependencies only.
const decoderConfig=readSource('addons/ffmpegplayer/FFmpegPlayer.gdextension');
for(const file of new Set(decoderConfig.match(/res:\/\/addons\/ffmpegplayer\/win64\/[^"\s]+\.dll/g)||[]))add(file);
for(const file of listSource('addons/ffmpegplayer'))if(/\.(txt|json)$/.test(file))add('addons/ffmpegplayer/'+file);
add('art/full/terrain_events/manifest.json');
for(const entry of Object.values(JSON.parse(readSource('art/full/terrain_events/manifest.json'))))add(entry.texture);
for(const filename of listSource('data').filter(x=>x.startsWith('chibi')&&x.endsWith('.json'))){
  const level=JSON.parse(readSource('data/'+filename));
  if(!videoCatalog[level.scenario?.avi]?.localOnly)throw Error('Campaign chapter does not select canonical HD: '+filename);
  if(level.artMode !== 'hd-catalog')throw new Error('Re-export HD metadata: '+filename);
  add('data/'+filename);
  if(omitGeneratedTerrain)continue;
  const chunkPath='art/full/terrain_chunks/'+filename.slice(0,-5)+'/manifest.json';add(chunkPath);
  const chunks=JSON.parse(fs.readFileSync(resolveInput(chunkPath)));
  for(const chunk of chunks.chunks)for(const lod of Object.values(chunk.lods))add(lod.texture);
}
if(listInputs){console.log(JSON.stringify([...selected].sort()));process.exit(0);}
fs.mkdirSync(stage,{recursive:true});
for(const file of selected){

  const target=path.join(stage,file);fs.mkdirSync(path.dirname(target),{recursive:true});
  if(localCampaign.has(file)){
    fs.copyFileSync(resolveInput(file),target);
    const bytes=fs.readFileSync(target),entry=videoCatalog[path.basename(file)];
    if(bytes.length!==entry.bytes||createHash('sha256').update(bytes).digest('hex')!==entry.sha256)throw Error('Staged local campaign media differs from catalog: '+file);
  }else if(snapshot&&!generated(file)){
    copyReleaseInput(snapshot,file,resolveInput(file),target);
  }else if(/\.(png|jpg|ogv|bin)$/.test(file)){
    // 已选定的二进制素材只读；同卷构建链接避免数万文件的重复复制。
    // 正式交付是独立打包的 PCK，不依赖这些构建链接。
    try{fs.linkSync(resolveInput(file),target);}catch{fs.copyFileSync(resolveInput(file),target);}
  }else fs.copyFileSync(resolveInput(file),target);
  // Import configuration is source metadata; compiled caches remain isolated.
  for(const suffix of ['.import','.uid']){
    if(!hasSource(file+suffix))continue;
    if(snapshot)copyReleaseInput(snapshot,file+suffix,path.join(source,file+suffix),target+suffix);
    else fs.copyFileSync(path.join(source,file+suffix),target+suffix);
  }

}

let cfg=readSource('export_presets.cfg').replace(/include_filter="[^"]*"/g,'include_filter="*.json,*.txt,*.otf,*.bin,*.AVI,*.mp4"');
const version=readSource('project.godot').match(/^config\/version="(\d+\.\d+\.\d+)"$/m)?.[1];
if(!version) throw Error('Missing project version');
cfg=cfg.replace(/^application\/(?:file_version|product_version)="[^"]*"/gm, setting=>setting.replace(/"[^"]*"/, '"'+version+'.0"'));
fs.writeFileSync(stage+'/export_presets.cfg',cfg);
const bytes=[...selected].reduce((sum,file)=>sum+fs.statSync(path.join(stage,file)).size,0);
const runtimeFiles=[...selected].map(file=>file.startsWith('art/full/terrain_chunks/')&&file.endsWith('.jpg')?file.replace(/\.jpg$/,'.bin'):file);
fs.writeFileSync(stage+'/release_inputs.json',JSON.stringify({schemaVersion:1,sourceCommit:commit,originalMedia:!noOriginalMedia,files:runtimeFiles.sort(),sourceFiles:[...selected].sort(),sourceBytes:bytes,budgets:{terrainResidentBytes:402653184}},null,2));
if(acceptanceDir)copyAcceptanceScripts(snapshot,source,acceptanceDir);
console.log('Staged only declared runtime resources:',selected.size,'source GiB',(bytes/2**30).toFixed(2));
