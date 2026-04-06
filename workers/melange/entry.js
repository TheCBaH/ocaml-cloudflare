// ESM entry point for the melange-compiled Cloudflare Worker.
// Step functions (step_parse, step_greet, step_annotate) are imported from the
// melange output and called inside CF Workflow steps.
import { step_parse, step_greet, step_annotate }
  from './output/workers/melange/worker.js';

import { WorkflowEntrypoint } from 'cloudflare:workers';

// Durable Workflow class — use this when you need retry-safe, persistent
// multi-step execution.  Trigger via `wrangler workflows trigger` or by
// calling env.OCAML_WORKFLOW.create() from another Worker.
export class OcamlWorkflow extends WorkflowEntrypoint {
  async run(event, step) {
    const { url, method } = event.payload;

    const methodNorm = await step.do('parse',
      () => step_parse(url, method));

    const body = await step.do('greet',
      () => step_greet(url, methodNorm));

    return await step.do('annotate',
      () => step_annotate(body, this.env.COMMIT_SHA));
  }
}

// fetch — calls OCaml steps directly for a fast, synchronous response.
export default {
  fetch(request, env, _ctx) {
    const methodNorm = step_parse(request.url, request.method);
    const body      = step_greet(request.url, methodNorm);
    const result    = step_annotate(body, env.COMMIT_SHA || '');
    return new Response(result);
  },
};
