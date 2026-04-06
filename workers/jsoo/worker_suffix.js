// WorkflowEntrypoint — available in CF runtime; fall back to a stub in Node.js
// so that `make smoke-test-jsoo` can load this file without a real CF runtime.
const { WorkflowEntrypoint } = await import('cloudflare:workers').catch(
  () => ({ WorkflowEntrypoint: class {} })
);

// Durable Workflow class — use this when you need retry-safe, persistent
// multi-step execution.  Trigger via `wrangler workflows trigger` or by
// calling env.OCAML_WORKFLOW.create() from another Worker.
// Each step.do() callback delegates to an OCaml function set on globalThis
// by the jsoo IIFE above; results are plain strings for durable serialisation.
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

// fetch — calls OCaml steps directly for a fast, synchronous response.
// The Workflow class above provides the durable path; the fetch handler
// keeps the request/response loop simple and runtime-independent.
export default {
  fetch(request, env, _ctx) {
    const methodNorm = globalThis.ocamlStepParse(request.url, request.method);
    const body      = globalThis.ocamlStepGreet(request.url, methodNorm);
    const result    = globalThis.ocamlStepAnnotate(body, env.COMMIT_SHA || '');
    return new Response(result);
  },
};
