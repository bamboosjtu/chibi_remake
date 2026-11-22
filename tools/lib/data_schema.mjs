// Validator for the deliberately small JSON Schema vocabulary used by our
// checked-in content contracts. Unsupported keywords fail instead of weakening
// a schema silently. No package install or network access is needed in CI.
export function validate(schema, value, root = schema, at = '$') {
  if (schema.$ref) return validate(schema.$ref.split('/').slice(1).reduce((node, key) => node[key], root), value, root, at);
  const supported = new Set(['$schema','$id','$defs','$ref','title','description','type','required','properties','additionalProperties','items','minimum','exclusiveMinimum','minItems','maxItems','minProperties','minLength','pattern']);
  for (const key of Object.keys(schema)) if (!supported.has(key)) throw new Error('Unsupported schema keyword: ' + key);
  const type = schema.type;
  const object = value !== null && typeof value === 'object' && !Array.isArray(value);
  const matches = type === 'object' ? object : type === 'array' ? Array.isArray(value) : type === 'integer' ? Number.isSafeInteger(value) : type === 'number' ? typeof value === 'number' && Number.isFinite(value) : typeof value === type;
  if (type && !matches) throw new Error(`${at}: expected ${type}`);
  if (object) {
    if (Object.keys(value).length < (schema.minProperties ?? 0)) throw new Error(at + ': too few properties');
    for (const key of schema.required ?? []) if (!Object.hasOwn(value, key)) throw new Error(at + ': missing ' + key);
    for (const [key, child] of Object.entries(value)) {
      const rule = schema.properties?.[key] ?? schema.additionalProperties;
      if (rule === false) throw new Error(at + ': unknown ' + key);
      if (rule && rule !== true) validate(rule, child, root, at + '.' + key);
    }
  }
  if (Array.isArray(value)) {
    if (value.length < (schema.minItems ?? 0) || value.length > (schema.maxItems ?? Infinity)) throw new Error(at + ': invalid array length');
    value.forEach((child, i) => { if (schema.items) validate(schema.items, child, root, `${at}[${i}]`); });
  }
  if (typeof value === 'number' && (value < (schema.minimum ?? -Infinity) || value <= (schema.exclusiveMinimum ?? -Infinity))) throw new Error(at + ': number outside bounds');
  if (typeof value === 'string' && (value.length < (schema.minLength ?? 0) || (schema.pattern && !new RegExp(schema.pattern).test(value)))) throw new Error(at + ': invalid string');
}
