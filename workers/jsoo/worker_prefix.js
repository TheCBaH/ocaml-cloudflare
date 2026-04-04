// jsoo's runtime references Node.js APIs (require) during initialisation even
// in browser mode.  CF Workers / browsers don't have `require`, so we stub it
// with a Proxy that silently absorbs property access.  File-system operations
// would fail at runtime if actually attempted, but a CF Worker that only
// returns a Response never touches the OCaml stdlib file system.
if (typeof require === "undefined") {
  const _noopModule = new Proxy(
    {},
    { get: (_, p) => (typeof p === "string" ? () => _noopModule : undefined) }
  );
  globalThis.require = (_id) => _noopModule;
}
