import fs from 'node:fs';
const source = fs.readFileSync('godot/chibi_remake/export_presets.cfg', 'utf8');
if ((source.match(/^\[preset\.\d+\]$/gm) ?? []).length !== 1 || !source.includes('name="Windows HD Art"') || !source.includes('binary_format/embed_pck=false')) {
  throw new Error('Expected the single Windows HD Art preset with a separate PCK');
}
console.log('HD export profile PASS single authoritative Windows preset / separate PCK.');
