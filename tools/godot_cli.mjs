import path from 'node:path';import {spawn} from 'node:child_process';
import {runGodot} from './lib/godot_process.mjs';
// PowerShell may return immediately for a GUI-subsystem SDK executable. Node
// waits for the actual child, including import/export failure exit codes.
const cli = process.argv.slice(2);
if (cli[0] === '--timeout') {
  const [, limit, logFlag, logFile, engine, ...args] = cli;
  if (logFlag !== '--log' || !logFile?.endsWith('.log') || !engine) throw Error('Expected --timeout <seconds> --log <file.log> <engine>');
  const result = await runGodot({engine: path.resolve(engine), args, timeout: Number(limit),
    directory: path.resolve(path.dirname(logFile)), name: path.basename(logFile, '.log'), isolateProfile: false, collectOutput: false});
  const detail = result.timedOut ? `exceeded ${result.timeoutSeconds}s (${result.idleSeconds.toFixed(1)}s since last output)` :
    `exit ${result.code}, ${result.seconds.toFixed(1)}s`;
  const message = `GODOT ${result.ok ? 'PASS' : 'FAIL'} ${detail}: ${result.log}`;
  if (result.ok) console.log(message);
  else { console.error(message); process.exitCode = 1; }
} else {
  const [engine, ...args] = cli;
  if (!engine) throw Error('Usage: node tools/godot_cli.mjs [--timeout <seconds> --log <file.log>] <engine> <arguments...>');
  const child = spawn(path.resolve(engine), args, {windowsHide: true, stdio: 'inherit'});
  child.on('error', error => { console.error(error); process.exitCode = 1; });
  child.on('close', code => { process.exitCode = code ?? 1; });
}
