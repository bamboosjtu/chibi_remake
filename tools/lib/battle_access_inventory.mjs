// Literal host access inventory, not an AST or receiver-identity proof.
export function collectReadModelUses(sources) {
  const references = [];
  const strings = /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/g;
  for (const [file, source] of Object.entries(sources).sort(([a],[b]) => a.localeCompare(b,'en'))) {
    if (file.endsWith('/battle_access.gd')) continue; // Provider owns the boundary reads.
    const code = source.replace(/("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|#[^\r\n]*/g, (all,string) => string ?? '');
    const masked = code.replace(strings, value => value.replace(/[^\r\n]/g,' '));
    const add = (match, field, syntax) => references.push({file, line:code.slice(0,match.index).split('\n').length,
      field, syntax, origin:file.endsWith('/software_cursor.gd') ? 'scene-facade' : 'battle-access-host',
      source:source.split(/\r?\n/)[code.slice(0,match.index).split('\n').length-1].trim()});
    for (const match of masked.matchAll(/\b(?:_ui\.)?host\s*\.\s*(units|selected|map_data|nav|decor_cells)\b/g)) add(match,match[1],'property');
    for (const match of code.matchAll(/\b(?:_ui\.)?host(?:\.(?:get|get\.bind)\(\s*|\[\s*)(['"])(units|selected|map_data|nav|decor_cells)\1/g)) {
      if (masked.slice(match.index,match.index+4).trim()) add(match,match[2],'literal-lookup');
    }
  }
  return references.sort((a,b) => a.file.localeCompare(b.file,'en') || a.line-b.line || a.field.localeCompare(b.field));
}
