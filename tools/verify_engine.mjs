import path from 'node:path';
import {resolveEngine, verifyEngine} from './lib/reviewed_engine.mjs';

const args = process.argv.slice(2);
const option = name => args.includes(name) ? args[args.indexOf(name) + 1] : undefined;
try {
  const engine = option('--engine') ? path.resolve(option('--engine')) : resolveEngine(option('--root') ?? process.cwd());
  const result = verifyEngine(engine, option('--platform'));
  console.log(args.includes('--resolve') ? engine : result);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
