// Run with: node workers/melange/miniflare-test.mjs
// Tests the staged melange bundle in a real workerd isolate via Miniflare.
// Unlike the offline smoke test, this exercises the actual CF Workers runtime
// (V8 isolate, fetch handler, bindings) without needing a deployed worker.
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { Miniflare } from '../node_modules/miniflare/dist/src/index.js';

const __dir = dirname(fileURLToPath(import.meta.url));

const mf = new Miniflare({
  modules: true,
  scriptPath: join(__dir, 'dist/bundle.js'),
  compatibilityDate: '2024-01-01',
  bindings: { COMMIT_SHA: 'mf-test' },
});

let ok = false;
try {
  const resp = await mf.dispatchFetch('http://localhost/');
  const body = await resp.text();

  if (resp.status !== 200) {
    console.error('melange miniflare-test FAILED: status', resp.status);
    process.exit(1);
  }
  if (!body.includes('Hello, World!') || !body.includes('melange') || !body.includes('mf-test')) {
    console.error('melange miniflare-test FAILED: unexpected body:', body);
    process.exit(1);
  }
  console.log('melange miniflare-test passed  (body: %s)', body);
  ok = true;
} finally {
  await mf.dispose();
  if (!ok) process.exit(1);
}
