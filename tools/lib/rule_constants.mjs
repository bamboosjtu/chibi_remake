import crypto from 'node:crypto';
const canonical=value=>Array.isArray(value)?value.map(canonical):value&&typeof value==='object'?Object.fromEntries(Object.keys(value).sort().map(key=>[key,canonical(value[key])])):value;
export const valueHash=value=>crypto.createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
export function sourceViolations(source,roles){
 const code=source.replace(/("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|#[^\r\n]*/g,()=> ' ');
 const errors=[];
 if(/\b(?:TECH_TABLE|TECH_LINES|TECH_BUILDING_LINES|TECH_MELEE_UNITS|TECH_WATER_UNITS|TECH_TICKS|MOBILE_HP_UNITS|HERO_UNITS|HERO_TYPES|B_ATTACK_TYPES|NAVAL_UNITS|WORKER_UNITS|TRANSPORT_UNIT|TRANSPORT_CAPACITY|TEAM_MAX_MEMBERS|EXP_LEVELS)\b/.test(code))errors.push('retired rule constant or alias; query the shared definitions');
 const sets=Object.entries(roles).filter(([key])=>key!=='technologyCategories').map(([key,ids])=>[key,[...ids].sort((a,b)=>a-b).join(',')]);
 for(const match of code.matchAll(/\[\s*((?:(?:0x[\da-fA-F]+|\d+)\s*,\s*)+(?:0x[\da-fA-F]+|\d+)\s*,?)\]/g)){
  const ids=match[1].split(',').map(s=>s.trim()).filter(Boolean).map(Number).sort((a,b)=>a-b).join(',');
  for(const [role,expected] of sets)if(ids===expected)errors.push('duplicated '+role+' classification');
 }
 for(const match of code.matchAll(/\b(_army_count|_commander_count)\s*\(/g)){
  let end=match.index+match[0].length,depth=1;
  while(end<code.length&&depth){if(code[end]==='(')depth++;if(code[end]===')')depth--;end++;}
  const tail=code.slice(end).split(/\r?\n|;|\b(?:or|and)\b/)[0];
  const literal=tail.match(/^\s*(?:\+\s*\w+\s*)?(?:>=|>|==|<=|<)\s*(0x[\da-fA-F]+|\d+)\b/);
  if(literal&&Number(literal[1])>0)errors.push('literal population limit; query Balance');
 }
 return errors;
}
export function documentation(tech,roles,balance){
 const table=(head,rows)=>[head,'|'+head.split('|').slice(1,-1).map(()=>'---').join('|')+'|',...rows.map(row=>'| '+row.join(' | ')+' |')].join('\n');
 return {
  limits:`每方实体上限 ${balance.armyCap}，主将上限 ${balance.commanderCap}，每队成员上限 ${balance.teamMaxMembers}（主将另计），运输船载员上限 ${balance.transportCapacity}；研究周期 ${tech.researchTicks} tick。`,
  headquarters:table('| 目标 | 金 | 木 | 铁 | 关卡门槛 | 其他条件 |',tech.rows.slice(0,3).map((r,i)=>[['二级','三级','四级'][i],...r.v.slice(0,3),'≥ '+(i+2),['木材场、武器库已建成；战斗成员 ≥ 2','木材场、武器库已建成；战斗成员 ≥ 3','战斗成员 ≥ 4；弓术 ≥ 2 且兵器 ≥ 2'][i]])),
  costs:table('| 项 | 金 | 木 | 铁 |',tech.rows.filter(row=>!row.sell).map(row=>[row.name,...row.v.slice(0,3)])),
  effects:table('| 研究 | '+roles.technologyCategories.map((ids,i)=>`${['一','二','三','四'][i]}档（类型 ${ids.join('/')}）`).join(' | ')+' |',tech.rows.slice(3,12).map(row=>[row.name,...row.v.slice(4).map(v=>'+'+v)]))
 };
}
