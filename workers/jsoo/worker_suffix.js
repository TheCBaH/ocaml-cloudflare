// ESM export — appended to the jsoo IIFE bundle by `make stage-jsoo`.
// By the time this export is evaluated the IIFE above has already run and
// populated globalThis.ocamlWorkerFetch.
// env is passed through so the OCaml handler can read CF Worker bindings
// (e.g. COMMIT_SHA injected at deploy time by wrangler --var).
export default {
  fetch(request, env, ctx) {
    return globalThis.ocamlWorkerFetch(request, env);
  },
};
