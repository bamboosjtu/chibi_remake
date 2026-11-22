// Atlas packing metadata only. Native animation indices and original draw bounds remain unchanged.
import fs from 'node:fs';
const file='godot/chibi_remake/art/production/catalog.json';
const c=JSON.parse(fs.readFileSync(file));
for(const page of c.pages){
  if(page.sourceId<34||page.sourceId>51)continue;
  const skip=new Set(page.nonvisualFrames.map(x=>x.frame));
  const visual=Array.from({length:page.sourceFrameCount},(_,i)=>i).filter(i=>!skip.has(i));
  let cols=Math.max(...visual.map(i=>i%page.columns))+1;
  // Accepted page 36/0 contains five painted columns; its fifth is unused.
  if(page.assetId==='units-036-page-00')cols=5;
  page.renderColumns=cols;
  page.renderRows=page.rows;
  page.renderFrameMap=Array.from({length:page.sourceFrameCount},(_,i)=>skip.has(i)?-1:Math.floor(i/page.columns)*cols+i%page.columns);
}
fs.writeFileSync(file,JSON.stringify(c,null,2));
console.log('Recorded compact painting layouts without changing native frame indices.');
