// ESM entry point for the melange-compiled Cloudflare Worker.
// Step functions (step_parse, step_greet, step_annotate) are imported from the
// melange output and called inside CF Workflow steps.
import { step_parse, step_greet, step_annotate }
  from './output/workers/melange/worker.js';

// WorkflowEntrypoint — available in CF runtime; fall back to a stub in Node.js
// so that `make smoke-test-melange` can load melange output without a CF runtime.
const { WorkflowEntrypoint } = await import('cloudflare:workers').catch(
  () => ({ WorkflowEntrypoint: class {} })
);

// Workflow class — steps delegate to OCaml functions exported above.
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

// fetch — creates a Workflow instance and polls for completion.
export default {
  async fetch(request, env, ctx) {
    const instance = await env.OCAML_WORKFLOW.create({
      params: { url: request.url, method: request.method },
    });
    for (let i = 0; i < 20; i++) {
      const st = await instance.status();
      if (st.status === 'complete') return new Response(st.output);
      if (st.status === 'errored')  return new Response(st.error, { status: 500 });
      await scheduler.wait(50);
    }
    return new Response(
      JSON.stringify({ workflowId: instance.id, status: 'running' }),
      { status: 202, headers: { 'content-type': 'application/json' } }
    );
  },
};
