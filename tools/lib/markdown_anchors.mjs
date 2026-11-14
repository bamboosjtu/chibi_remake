// Anchors used by the repository's Markdown headings (including duplicates).
export function headingAnchors(text) {
 const anchors=new Set(),counts=new Map();let fenced=false;
 for(const line of text.split(/\r?\n/)){
  if(/^\s*```|^\s*~~~/.test(line)){fenced=!fenced;continue;}
  if(fenced)continue;
  const match=line.match(/^#{1,6}\s+(.+?)(?:\s+#+)?$/);if(!match)continue;
  const base=match[1].replace(/<[^>]*>/g,'').replace(/\[([^\]]*)\]\([^)]*\)/g,'$1').toLowerCase().replace(/[^\p{L}\p{N}\p{M}\s_-]/gu,'').replace(/\s/g,'-');
  const count=counts.get(base)||0;counts.set(base,count+1);anchors.add(base+(count?'-'+count:''));
 }
 for(const m of text.matchAll(/\b(?:id|name)=["']([^"']+)["']/g))anchors.add(m[1]);
 return anchors;
}
