// Run with: node workers/jsoo/smoke-test.mjs
// Verifies that the staged dist/worker.js exports a valid CF Worker handler.
import { createRequire } from 'module';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dir = dirname(fileURLToPath(import.meta.url));

// Stub Response so the jsoo bundle can initialise without a real CF runtime
globalThis.Response = class {
  constructor(body) { this.body = body; }
};

const src = await import(join(__dir, 'dist/worker.js'));

if (typeof src.default?.fetch !== 'function') {
  console.error('jsoo smoke-test FAILED: default.fetch is not a function');
  console.error('  exports:', Object.keys(src));
  process.exit(1);
}

// Call the handler with a mock env and assert it returns a Response-like object
const r = src.default.fetch({}, { COMMIT_SHA: 'smoke-test' }, {});
if (!r?.body?.includes('js_of_ocaml')) {
  console.error('jsoo smoke-test FAILED: unexpected response body:', r?.body);
  process.exit(1);
}

console.log('jsoo smoke-test passed  (body: %s)', r.body);
