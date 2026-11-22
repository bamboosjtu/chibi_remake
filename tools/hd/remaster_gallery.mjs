#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
const dir='godot/chibi_remake/art/production';
const c=JSON.parse(fs.readFileSync(`${dir}/catalog.json`));
const escape=s=>String(s).replace(/[&<>"']/g,x=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[x]));
const href=p=>escape(path.relative(dir,p).replaceAll('\\','/'));
const tally={};
const pagesById=new Map((c.pages||[]).map(x=>[x.assetId,x]));
const rows=[...c.assets,...(c.pages||[])].map(a=>{
  const file=`${dir}/deliveries/${a.assetId}.json`;
  let d=fs.existsSync(file)?JSON.parse(fs.readFileSync(file)):null;
  let current=d?.texture===a.target;
  if(a.category==='units'&&a.pages?.length) {
    const source=a.aliasSourceId!=null?c.assets.find(x=>x.category==='units'&&x.sourceId===a.aliasSourceId):a;
    const child=source.pages.map(id=>{
      const page=pagesById.get(id),filename=`${dir}/deliveries/${id}.json`;
      const value=fs.existsSync(filename)?JSON.parse(fs.readFileSync(filename)):null;
      return page&&value?.texture===page.target?value:null;
    });
    current=child.every(Boolean);
    if(current)d={...child[0],pageCount:child.length,validation:{structure:child.every(x=>x.validation?.structure==='pass')?'pass':'pending',visual:child.every(x=>x.validation?.visual==='pass')?'pass':'pending'}};
  }
  const state=current?(d.validation?.structure==='fail'?'结构失败':d.validation?.structure==='pass'?(d.validation?.visual==='pass'?'已验收 · 已接入':'结构通过 · 美术待验收'):'已生成 · 待检查'):'待重绘';
  const t=tally[a.category]||= {total:0,generated:0,structurePassed:0,artApproved:0};
  t.total++;if(current)t.generated++;
  if(current&&d.validation?.structure==='pass')t.structurePassed++;
  if(current&&d.validation?.visual==='pass')t.artApproved++;
  return `<article data-category="${escape(a.category)}" data-generated="${current}"><h3>${escape(a.assetId)} · ${escape(a.name)}</h3><p>${state}</p><div class="pair"><figure><img loading="lazy" src="${href(a.reference||'')}" alt="原版"><figcaption>原版参考</figcaption></figure>${current?`<figure><img loading="lazy" src="${href(d.texture)}" alt="重绘候选"><figcaption>重绘候选 · ${d.width}×${d.height}${d.pageCount?' · 完整 '+d.pageCount+' 页，预览首张':''}</figcaption></figure>`:'<div class="empty">尚未交付</div>'}</div><p class="meta">${escape(a.expectedCoverage||'原始帧序保持')}<br>${escape(a.target)}</p></article>`;
}).join('');
fs.writeFileSync(`${dir}/progress.json`,JSON.stringify({updatedAt:new Date().toISOString(),scope:c.scope,categories:tally,additionalBanks:c.additionalBanks,visualReviewPolicy:c.visualReviewPolicy,allComplete:Object.values(tally).every(x=>x.artApproved===x.total)&&Object.values(c.additionalBanks||{}).every(x=>x.complete===true)},null,2));
fs.writeFileSync(`${dir}/gallery.html`,`<!doctype html><html lang="zh"><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>赤壁 · 全量重绘验收</title><style>body{background:#171512;color:#e5d8bd;font:15px system-ui;margin:24px}h1{color:#cda56e}header{position:sticky;top:0;background:#171512f5;padding:12px;z-index:2}button,select{background:#332b22;color:#e5d8bd;padding:9px;border:1px solid #88704f}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(440px,1fr));gap:18px}article{border:1px solid #514333;padding:14px;background:#211d18}h3{margin:0}.pair{display:flex;gap:12px;align-items:center;min-height:180px}figure{margin:0;width:48%;text-align:center}img{max-width:100%;max-height:250px;object-fit:contain;background:repeating-conic-gradient(#34302a 0% 25%,#29251f 0% 50%) 0 0/16px 16px}.meta{font-size:12px;color:#b3a48e;overflow-wrap:anywhere}.empty{color:#ab8c64}@media(max-width:500px){main{display:block}article{margin-bottom:16px}}</style><header><h1>赤壁 · 全量重绘验收</h1><p>原批次沿用用户人工验收；本批补绘按运行与帧映射检查接入，各项状态分别记录。</p><select id="category"><option value="">全部类别</option>${Object.keys(tally).map(x=>`<option>${x}</option>`).join('')}</select> <label><input id="generated" type="checkbox">只看已生成候选</label><p>${escape(JSON.stringify(tally))}</p></header><main>${rows}</main><script>function filter(){document.querySelectorAll('article').forEach(a=>a.hidden=(category.value&&a.dataset.category!==category.value)||(generated.checked&&a.dataset.generated!=='true'));}category.onchange=generated.onchange=filter;</script></html>`);
console.log(JSON.stringify(tally));
