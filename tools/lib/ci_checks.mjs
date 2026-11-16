export function runChecks(checks, execute) {
  return checks.map(check => {
    const start = Date.now();
    try {
      const result = execute(check);
      return {name: check.name, ok: result.status === 0 && !result.error && !result.signal,
        status: result.status, signal: result.signal ?? null, error: result.error?.message,
        seconds: (Date.now() - start) / 1000};
    } catch (error) {
      return {name: check.name, ok: false, error: error.message, seconds: (Date.now() - start) / 1000};
    }
  });
}
