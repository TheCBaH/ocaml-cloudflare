// Run with: node workers/jsoo/smoke-test.mjs
// Tests OCaml step functions and the synchronous fetch handler.
// The OcamlWorkflow class (durable path) requires a CF runtime — use
// `wrangler workflows trigger` or `make wrangler-smoke-test-jsoo`.
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dir = dirname(fileURLToPath(import.meta.url));

globalThis.Response = class {
  constructor(body, init) { this.body = body; this.init = init; }
};

const src = await import(join(__dir, 'dist/worker.js'));

// 1. default.fetch is exported
if (typeof src.default?.fetch !== 'function') {
  console.error('jsoo smoke-test FAILED: default.fetch is not a function');
  console.error('  exports:', Object.keys(src));
  process.exit(1);
}

// 2. OcamlWorkflow class is exported
if (typeof src.OcamlWorkflow !== 'function') {
  console.error('jsoo smoke-test FAILED: OcamlWorkflow class not exported');
  process.exit(1);
}

// 3. Synchronous fetch handler calls OCaml steps and returns the right body
const r = src.default.fetch(
  { url: 'https://example.com/', method: 'GET' },
  { COMMIT_SHA: 'smoke-test' },
  {}
);
if (!r?.body?.includes('js_of_ocaml') || !r.body.includes('smoke-test')) {
  console.error('jsoo smoke-test FAILED: unexpected response body:', r?.body);
  process.exit(1);
}

console.log('jsoo smoke-test passed  (body: %s)', r.body);
