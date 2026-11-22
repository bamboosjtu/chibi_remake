export function buildLevelIndex(maps,briefings){
 const byId=new Map();
 for(const [id,map]of maps){
  if(!/^chibi\w+$/.test(id)||map.kind&&map.kind!=='level'||!Array.isArray(map.objects)||!Array.isArray(map.walkable)||!(map.terrainW>0&&map.terrainH>0&&map.rows>0&&map.cols>0))throw Error('Invalid indexed level: '+id);
  byId.set(id,{id,map:id,name:map.name??id,objects:map.objects.length});
 }
 const order=[];
 for(const entry of briefings.levels){
  if(!byId.has(entry.map)||order.includes(entry.map))throw Error('Invalid campaign level: '+entry.map);
  const target=byId.get(entry.map);
  for(const key of ['campaign','chapter','title']){
   if(typeof entry[key]!=='string'||!entry[key])throw Error('Missing '+key+': '+entry.map);
   target[key]=entry[key];
  }
  order.push(entry.map);
 }
 if(order.length!==byId.size)throw Error('Every level needs a campaign entry');
 return {schemaVersion:1,levels:[...byId.values()].sort((a,b)=>a.id<b.id?-1:a.id>b.id?1:0),order};
}
