// WorkflowEntrypoint — available in CF runtime; fall back to a stub in Node.js
// so that `make smoke-test-jsoo` can load this file without a real CF runtime.
const { WorkflowEntrypoint } = await import('cloudflare:workers').catch(
  () => ({ WorkflowEntrypoint: class {} })
);

// Workflow class — CF durable executor.
// Each step.do() callback delegates to an OCaml function set on globalThis by
// the jsoo IIFE above; results are plain strings so CF can serialise them.
export class OcamlWorkflow extends WorkflowEntrypoint {
  async run(event, step) {
    const { url, method } = event.payload;

    const methodNorm = await step.do('parse',
      () => globalThis.ocamlStepParse(url, method));

    const body = await step.do('greet',
      () => globalThis.ocamlStepGreet(url, methodNorm));

    return await step.do('annotate',
      () => globalThis.ocamlStepAnnotate(body, this.env.COMMIT_SHA));
  }
}

// fetch — creates a Workflow instance and polls for completion.
// Fast workflows (pure OCaml computation) finish in < 1 s.
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
