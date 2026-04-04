// ESM entry point for the melange-compiled Cloudflare Worker.
// Melange prefixes `fetch` with `$$` to avoid clashing with the JS built-in.
import { $$fetch as fetch } from "./output/workers/melange/worker.js";

export default { fetch };
