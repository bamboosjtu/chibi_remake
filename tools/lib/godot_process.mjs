import {spawn} from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

/** Run one isolated engine process. Drain both pipes while enforcing a deadline. */
export async function runGodot({engine, args, directory, name, markers = [], timeout = 120, env = {}}) {
  fs.mkdirSync(directory, {recursive: true});
  const profile = path.resolve(directory, name + '-profile');
  fs.mkdirSync(profile, {recursive: true});
  const started = Date.now();
  const child = spawn(engine, args, {windowsHide: true, env: {...process.env,
    APPDATA: profile, LOCALAPPDATA: profile, ...env}});
  let output = '', timedOut = false, stopping = false, errorTimer;
  const stop = () => {
    if (stopping || !child.pid) return;
    stopping = true;
    // Terminate the console launcher and its engine together on Windows.
    if (process.platform === 'win32') spawn('taskkill', ['/PID', String(child.pid), '/T', '/F'], {windowsHide: true, stdio: 'ignore'});
    else child.kill();
  };
  const log = path.join(directory, name + '.log');
  const append = chunk => {
    output += chunk;
    fs.writeFileSync(log, output);
    if (/SCRIPT ERROR:|Parse Error:/.test(output) && !errorTimer) errorTimer = setTimeout(stop, 25);
  };
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
  const ok = !timedOut && code === 0 && !/SCRIPT ERROR:|Parse Error:|SELFTEST RESULT: FAIL/.test(output) && !missing.length;
  return {name, ok, code, timedOut, missing, seconds: (Date.now() - started) / 1000, log, output};
}
