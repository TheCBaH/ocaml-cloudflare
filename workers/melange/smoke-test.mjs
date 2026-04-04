// Run with: node workers/melange/smoke-test.mjs
// Verifies that the staged melange output exports a valid CF Worker handler.
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dir = dirname(fileURLToPath(import.meta.url));

// Stub Response so the melange module can initialise without a real CF runtime
globalThis.Response = class {
  constructor(body) { this.body = body; }
};

const m = await import(join(__dir, 'dist/output/workers/melange/worker.js'));

// Melange prefixes `fetch` with `$$` to avoid shadowing the JS global
if (typeof m.$$fetch !== 'function') {
  console.error('melange smoke-test FAILED: $$fetch is not a function');
  console.error('  exports:', Object.keys(m));
  process.exit(1);
}

const r = m.$$fetch({}, { COMMIT_SHA: 'smoke-test' }, {});
if (!r?.body?.includes('melange')) {
  console.error('melange smoke-test FAILED: unexpected response body:', r?.body);
  process.exit(1);
}

console.log('melange smoke-test passed  (body: %s)', r.body);
