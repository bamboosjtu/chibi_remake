// Deliberately restricted source form, not a general GDScript call graph.
// Only a literal `ports.acquire([...])` followed by its empty-scope guard may
// introduce the local `services` receiver used by internal collaborators.
const literals=/("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')/g;
const spaces=text=>text.replace(/[^\r\n]/g,' ');
export function argumentsAt(source, opening){
  const code=source.replace(literals,spaces), stack=['('], items=[];
  let begin=opening+1;
  for(let i=begin;i<code.length;i++){
    const c=code[i];
    if('([{'.includes(c))stack.push(c);
    else if(')]}'.includes(c)){
      if('([{'.indexOf(stack.pop())!==')]}'.indexOf(c))throw Error('Unbalanced argument list');
      if(!stack.length){if(source.slice(begin,i).trim())items.push(source.slice(begin,i).trim());return items;}
    }else if(c===','&&stack.length===1){items.push(source.slice(begin,i).trim());begin=i+1;}
  }
  throw Error('Unterminated argument list');
}
export function internalCalls(source, label) {
  const code=source.replace(/("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|#[^\r\n]*/g,(all,string)=>string??spaces(all));
  const result=[];
  for(const fn of code.matchAll(/^func (\w+)\([^]*?(?=^func |^const |^var |$(?![^]))/gm)) {
    const body=fn[0];
    const receivers=body.replace(literals,spaces);
    if(!/\bports\./.test(receivers))continue;
    const acquisition=body.match(/^\tvar services := ports\.acquire\((\[[^\n]*\])\)\r?\n\tif services\.is_empty\(\): return[^\n]*\r?\n/m);
    if(!acquisition)throw Error(label+'::'+fn[1]+': missing guarded provider scope');
    if((receivers.match(/\bports\./g)||[]).length!==1)throw Error(label+': internal forwarding or multiple scopes');
    if(/\bservices\s*(?:=|\[)|\bservices\.(?:set|get|erase|clear|merge)\(/.test(receivers))throw Error(label+': dynamic/reassigned provider scope');
    const requested=JSON.parse(acquisition[1]);
    const used=new Set();
    for(const call of receivers.matchAll(/\bservices\.(\w+)\.(\w+)\b/g)) {
      if(call.index<acquisition.index+acquisition[0].length)throw Error(label+': call before scope guard');
      used.add(call[1]);
      const tail=receivers.slice(call.index+call[0].length),opening=tail.match(/^\s*\(/);
      const argumentCount=opening?argumentsAt(body,call.index+call[0].length+opening[0].length-1).length:undefined;
      result.push({caller:fn[1],provider:call[1],method:call[2],line:source.slice(0,fn.index+call.index).split('\n').length,...(argumentCount===undefined?{}:{argumentCount})});
    }
    if(JSON.stringify([...used].sort())!==JSON.stringify([...new Set(requested)].sort()))throw Error(label+'::'+fn[1]+': provider scope differs from direct receivers');
  }
  return result;
}

export function validateInternalScope(file, source, declared) {
  if(!source.includes('var ports := preload("res://simulation/service_dependencies.gd").new(REQUIRED_SERVICES)'))throw Error(file+': internal collaborators must use guarded direct scopes');
  const calls=internalCalls(source,file), actual={};
  for(const {provider,method} of calls)(actual[provider]??=new Set()).add(method);
  const normalize=value=>Object.fromEntries(Object.keys(value).sort().map(key=>[key,[...value[key]].sort()]));
  if(JSON.stringify(normalize(actual))!==JSON.stringify(normalize(declared)))throw Error(file+': contract differs from verified direct receivers');
  return calls.map(call=>({file,...call}));
}
