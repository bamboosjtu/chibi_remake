import {spawn} from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

export const isEngineFailure = output => /SCRIPT ERROR:|Parse Error:|SELFTEST RESULT: FAIL|ERROR: (?:Error calling (?:deferred method|from signal)|Corrupted header|(?:Error: )?Couldn't load project data|Couldn't save project\.binary)/.test(output);

/** Run one isolated engine process. Drain both pipes while enforcing a deadline. */
export async function runGodot({engine, args, directory, name, markers = [], timeout = 120, env = {}}) {
  fs.mkdirSync(directory, {recursive: true});
  const profile = path.resolve(directory, name + '-profile');
  fs.mkdirSync(profile, {recursive: true});
  const started = Date.now();
  const child = spawn(engine, args, {windowsHide: true, env: {...process.env,
    APPDATA: profile, LOCALAPPDATA: profile,
    XDG_DATA_HOME: path.join(profile, 'data'), XDG_CACHE_HOME: path.join(profile, 'cache'),
    XDG_CONFIG_HOME: path.join(profile, 'config'), ...env}});
  let output = '', timedOut = false, stopping = false, errorTimer;
  const stop = () => {
    if (stopping || !child.pid) return;
    stopping = true;
    // Terminate the console launcher and its engine together on Windows.
    if (process.platform === 'win32') spawn('taskkill', ['/PID', String(child.pid), '/T', '/F'], {windowsHide: true, stdio: 'ignore'});
    else child.kill();
  };
  const log = path.join(directory, name + '.log');
  fs.writeFileSync(log, "");
  const append = chunk => {
    output += chunk;
    fs.appendFileSync(log, chunk);
    if (isEngineFailure(output) && !errorTimer) errorTimer = setTimeout(stop, 25);
  };
  child.stdout.setEncoding('utf8');
  child.stderr.setEncoding('utf8');
  child.stdout.on('data', append);
  child.stderr.on('data', append);
  const timer = setTimeout(() => {
    timedOut = true;
    stop();
  }, timeout * 1000);
  const code = await new Promise((resolve, reject) => {
    child.on('error', reject); child.on('close', resolve);
  }).finally(() => { clearTimeout(timer); clearTimeout(errorTimer); });
  fs.writeFileSync(log, output);
  const missing = markers.filter(marker => !output.includes(marker));
  const ok = !timedOut && code === 0 && !isEngineFailure(output) && !missing.length;
  return {name, ok, code, timedOut, missing, seconds: (Date.now() - started) / 1000, log, output};
}
