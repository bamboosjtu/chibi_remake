import assert from 'node:assert/strict';
import {matchesKnownFailure} from './lib/regression_result.mjs';

const root = {message: 'Assertion failed.', location: 'test_ai_slots.gd:25'};
const secondary = {message: "Invalid access of index '0' on a base object of type: 'Array'.", location: 'test_ai_slots.gd:136'};
const log = error => `SCRIPT ERROR: ${error.message}\n   at: dispatch (D:/tests/${error.location})\n`;
const expected = {...root, consequences: [secondary]};
assert(matchesKnownFailure(log(root), root));
assert(!matchesKnownFailure(log(root) + log(secondary), root));
assert(matchesKnownFailure(log(root), expected));
assert(matchesKnownFailure(log(root) + log(secondary), expected));
assert(!matchesKnownFailure(log(secondary) + log(root), expected));
assert(!matchesKnownFailure(log(root) + log({...secondary, location: 'test_ai_slots.gd:137'}), expected));
assert(!matchesKnownFailure(log({...root, message: 'A new assertion failed.'}), expected));
assert(!matchesKnownFailure(log(root) + log(secondary) + log(secondary), expected));
assert(!matchesKnownFailure(log(root) + 'SCRIPT ERROR: Unlocated error\n', expected));
assert(!matchesKnownFailure(log(root) + 'Parse Error: invalid script\n', expected));
assert(!matchesKnownFailure('', expected));
console.log('REGRESSION RESULT PASS exact root / optional recorded consequence / new-unlocated-reordered errors rejected');
