import fs from 'node:fs';
const officer=(id,rect)=>({kind:'officer_in_rect',officer:id,rect});
const units=rect=>({kind:'unit_in_rect',rect});
const near=(id,other,side)=>({kind:'officers_near',officer:id,otherOfficer:other,otherSide:side,radius:10});
const definitions={schemaVersion:1,source:'CB.EXE FUN_00404800 / FUN_004045a0 / FUN_0041ab30',missions:{
5:{stages:[{id:'a',condition:officer(40,[47,65,126,144]),effects:[{kind:'status_delta',side:'enemy',amount:-50},{kind:'event',id:3}]},{id:'win',condition:officer(40,[87,105,266,284]),win:true}]},
8:{stages:[{id:'a',condition:officer(34,[1,19,76,94]),effects:[{kind:'event',id:6},{kind:'clear_tiles',layer:1,cells:[[10,84],[11,84],[10,83],[10,85]]}]},{id:'b',requires:['a'],condition:officer(34,[91,109,291,309]),win:true},{id:'c',condition:{kind:'all',conditions:[{...units([78,96,253,271]),side:'enemy'},officer(35,[82,100,264,282])]},effects:[{kind:'status_delta',side:'enemy',amount:-40},{kind:'event',id:7}]}]},
14:{stages:[{id:'a',condition:near(60,34,'player'),effects:[{kind:'status_delta',side:'player',amount:20},{kind:'event',id:9}],yield:true},{id:'b',condition:near(60,35,'player'),effects:[{kind:'status_delta',side:'player',amount:20},{kind:'event',id:10}],yield:true},{id:'c',condition:near(60,36,'player'),effects:[{kind:'event',id:11}],win:true},{id:'rect',condition:officer(60,[11,29,34,52]),win:true}]},
27:{stages:[{id:'a',condition:{kind:'unit_type_present',unit:49},effects:[{kind:'event',id:5}]}]},
30:{stages:[{id:'a',condition:near(60,34,'enemy'),effects:[{kind:'status_delta',side:'player',amount:-20},{kind:'event',id:9}],yield:true},{id:'b',condition:near(60,35,'enemy'),effects:[{kind:'status_delta',side:'player',amount:-20},{kind:'event',id:10}],yield:true},{id:'c',condition:near(60,36,'enemy'),effects:[{kind:'event',id:11}],win:true},{id:'rect',condition:units([11,29,34,52]),win:true}]}
}};
for(const [mission,rect,target] of [[19,[41,59,51,69],[50,60]],[20,[54,72,232,250],[63,241]],[29,[45,63,162,180],[54,171]]])definitions.missions[mission]={stages:[{id:'event',condition:{kind:'all',conditions:[units(rect),{kind:'enemy_mobile_present'}]},effects:[{kind:'enemy_order',target,experienceParameter:'eventExperience'}]}]};
fs.writeFileSync('godot/chibi_remake/data/db/scenario_rules.json',JSON.stringify(definitions,null,2));
const raw=fs.readFileSync('_work/iso/SET/EVENTEX.EXT');
const names=new TextDecoder('gbk').decode(Buffer.from(raw.map(x=>x^0x46))).split('\0\0').filter(Boolean);
const events={schemaVersion:1,events:{}};
for(let i=0;i<names.length;i++)if(/\.avi$/i.test(names[i]))events.events[i]={video:`res://media/videos/${names[i].toUpperCase()}`,source:names[i]};else events.events[i]={text:names[i]};
fs.writeFileSync('godot/chibi_remake/data/db/events.json',JSON.stringify(events,null,2));
console.log('Source-correct task conditions and event index generated.');
