// Run with: node workers/jsoo/smoke-test.mjs
// Tests OCaml step functions and bundle structure.
// Full Workflow execution requires a CF runtime — use `make dev-jsoo`.
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dir = dirname(fileURLToPath(import.meta.url));

// Stubs for CF APIs referenced during module evaluation
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

// 3. OCaml step functions are set on globalThis by the jsoo IIFE
const methodNorm = globalThis.ocamlStepParse('https://example.com/', 'GET');
if (methodNorm !== 'GET') {
  console.error('jsoo smoke-test FAILED: ocamlStepParse returned', methodNorm);
  process.exit(1);
}

const body = globalThis.ocamlStepGreet('https://example.com/', 'GET');
if (!body?.includes('Hello, World!')) {
  console.error('jsoo smoke-test FAILED: ocamlStepGreet returned', body);
  process.exit(1);
}

const annotated = globalThis.ocamlStepAnnotate(body, 'smoke-test');
if (!annotated?.includes('js_of_ocaml') || !annotated.includes('smoke-test')) {
  console.error('jsoo smoke-test FAILED: ocamlStepAnnotate returned', annotated);
  process.exit(1);
}

console.log('jsoo smoke-test passed  (body: %s)', annotated);
