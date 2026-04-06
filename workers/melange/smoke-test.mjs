// Run with: node workers/melange/smoke-test.mjs
// Tests OCaml step function logic directly from the melange output.
// Full Workflow execution requires a CF runtime — use `make dev-melange`.
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dir = dirname(fileURLToPath(import.meta.url));

// Stub Response for the melange module initialisation
globalThis.Response = class {
  constructor(body, init) { this.body = body; this.init = init; }
};

const m = await import(join(__dir, 'dist/output/workers/melange/worker.js'));

// 1. step functions are exported
if (typeof m.step_parse !== 'function' ||
    typeof m.step_greet !== 'function' ||
    typeof m.step_annotate !== 'function') {
  console.error('melange smoke-test FAILED: step functions not exported');
  console.error('  exports:', Object.keys(m));
  process.exit(1);
}

// 2. OCaml step logic
const methodNorm = m.step_parse('https://example.com/', 'GET');
if (methodNorm !== 'GET') {
  console.error('melange smoke-test FAILED: step_parse returned', methodNorm);
  process.exit(1);
}

const body = m.step_greet('https://example.com/', 'GET');
if (!body?.includes('Hello, World!')) {
  console.error('melange smoke-test FAILED: step_greet returned', body);
  process.exit(1);
}

const annotated = m.step_annotate(body, 'smoke-test');
if (!annotated?.includes('melange') || !annotated.includes('smoke-test')) {
  console.error('melange smoke-test FAILED: step_annotate returned', annotated);
  process.exit(1);
}

console.log('melange smoke-test passed  (body: %s)', annotated);
