// Keep offsets stable so callers can read resource arguments and report locations.
export function sourceViews(source) {
  const nonCode = /"""[\s\S]*?"""|'''[\s\S]*?'''|"(?:\\.|[^"\\\r\n])*"|'(?:\\.|[^'\\\r\n])*'|#[^\r\n]*/g;
  const blank = text => text.replace(/[^\r\n]/g, ' ');
  return {
    uncommented: source.replace(nonCode, text => text.startsWith('#') ? blank(text) : text),
    code: source.replace(nonCode, blank),
  };
}
