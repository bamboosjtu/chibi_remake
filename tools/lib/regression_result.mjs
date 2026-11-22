/** Accept only the recorded root error and its explicitly recorded consequences. */
export function matchesKnownFailure(output, expected) {
  if (!expected || /Parse Error:/.test(output)) return false;
  const failures = [...output.matchAll(/SCRIPT ERROR: ([^\r\n]+)\r?\n\s+at: ([^\r\n]+)/g)];
  const allowed = [expected, ...(expected.consequences ?? [])];
  if (!failures.length || failures.length > allowed.length ||
      failures.length !== (output.match(/SCRIPT ERROR:/g) ?? []).length) return false;
  return failures.every((failure, index) => failure[1] === allowed[index].message &&
    failure[2].includes(allowed[index].location + ')'));
}
