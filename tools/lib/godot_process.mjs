import {spawn} from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import {finished} from 'node:stream/promises';

export const isEngineFailure = output => /SCRIPT ERROR:|Parse Error:|SELFTEST RESULT: FAIL|ERROR: (?:Error calling (?:deferred method|from signal)|Corrupted header|(?:Error: )?Couldn't load project data|Couldn't save project\.binary)/.test(output);

/** Run one isolated engine process. Drain both pipes while enforcing a deadline. */
export async function runGodot({engine, args, directory, name, markers = [], timeout = 120, env = {},
  expectSelftestFailure = false, isolateProfile = true, collectOutput = true}) {
  if (!Number.isFinite(timeout) || timeout <= 0 || timeout * 1000 > 2_147_483_647) throw Error('Invalid engine timeout: ' + timeout);
  fs.mkdirSync(directory, {recursive: true});
  const profile = path.resolve(directory, name + '-profile');
  const started = Date.now();
  const isolated = isolateProfile ? {
    APPDATA: profile, LOCALAPPDATA: profile,
    XDG_DATA_HOME: path.join(profile, 'data'), XDG_CACHE_HOME: path.join(profile, 'cache'),
    XDG_CONFIG_HOME: path.join(profile, 'config')
  } : {};
  if (isolateProfile) fs.mkdirSync(profile, {recursive: true});
  const log = path.join(directory, name + '.log');
  const writer = fs.createWriteStream(log);
  const saved = finished(writer, {cleanup: true}).then(() => null, error => error);
  const child = spawn(engine, args, {windowsHide: true, detached: process.platform !== 'win32',
    env: {...process.env, ...isolated, ...env}});
  const chunks = [];
  const pending = new Set(markers);
  const pipes = [child.stdout, child.stderr];
  let timedOut = false, stopping = false, failed = false, grace, resolveExit, lastOutput = started, idleSeconds;
  const stop = () => {
    if (stopping || !child.pid) return;
    stopping = true;
    if (process.platform === 'win32') {
      const killer = spawn('taskkill.exe', ['/PID', String(child.pid), '/T', '/F'], {windowsHide: true, stdio: 'ignore'});
      killer.on('error', () => child.kill('SIGKILL'));
      killer.unref();
    } else {
      try { process.kill(-child.pid, 'SIGKILL'); }
      catch (error) { if (error.code !== 'ESRCH') child.kill('SIGKILL'); }
    }
    grace = setTimeout(() => {
      for (const pipe of pipes) pipe.destroy();
      child.kill('SIGKILL');
      child.unref();
      resolveExit(null);
    }, 3000);
  };
  const exited = new Promise((resolve, reject) => {
    resolveExit = resolve;
    child.on('error', reject); child.on('close', resolve);
  });
  writer.on('error', stop);
  writer.on('drain', () => { for (const pipe of pipes) pipe.resume(); });
  const failure = text => isEngineFailure(expectSelftestFailure ? text.replaceAll('SELFTEST RESULT: FAIL', '') : text);
  const overlap = Math.max(256, ...markers.map(marker => marker.length));
  for (const pipe of pipes) {
    let tail = '';
    pipe.setEncoding('utf8');
    pipe.on('data', chunk => {
      lastOutput = Date.now();
      if (collectOutput) chunks.push(chunk);
      if (!writer.write(chunk)) for (const stream of pipes) stream.pause();
      const window = tail + chunk;
      tail = window.slice(-overlap);
      for (const marker of pending) if (window.includes(marker)) pending.delete(marker);
      if (failure(window)) { failed = true; stop(); }
    });
  }
  const timer = setTimeout(() => {
    if (stopping) return;
    timedOut = true;
    idleSeconds = (Date.now() - lastOutput) / 1000;
    stop();
  }, timeout * 1000);
  let code;
  try { code = await exited; }
  finally { clearTimeout(timer); clearTimeout(grace); writer.end(); }
  const loggingError = await saved;
  if (loggingError) throw loggingError;
  const output = chunks.join('');
  const missing = [...pending].filter(marker => !output.includes(marker));
  const ok = !timedOut && code === (expectSelftestFailure ? 1 : 0) && !failed && !failure(output) && !missing.length;
  return {name, ok, code, timedOut, missing, seconds: (Date.now() - started) / 1000, log, output,
    ...(timedOut ? {timeoutSeconds: timeout, idleSeconds} : {})};
}
