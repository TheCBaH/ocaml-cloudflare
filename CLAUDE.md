# OCaml Cloudflare Workers

OCaml project that compiles hello-world Cloudflare Workers using two JS
backends: **js_of_ocaml (jsoo)** and **melange**. The devcontainer provides a
fully configured OCaml + Node.js environment.

## Repository layout

```
lib/
  worker_types.ml   Shared request/response types + pretty printers
  worker_handler.ml Shared handle : request -> response implementation
src/
  main.ml           Native binary — pretty-prints a sample request/response
  main.t            Cram test for main.exe (run by dune runtest)
workers/
  jsoo/         OCaml source + dune config for the jsoo backend
  melange/      OCaml source + dune config for the melange backend
package.json    wrangler pinned as a local dev dependency
scripts/
  cf-worker.sh  CF Worker helper: name / deploy / test commands
.devcontainer/  Devcontainer definition + custom features
.github/
  workflows/
    build.yml         Build, smoke-test, and deploy on push
    images.yml        Build and push devcontainer image
  dependabot.yml      Weekly bumps for npm, actions, docker, devcontainers
```

## Makefile targets

### Build

| Target | Description |
|---|---|
| `make` | Native OCaml build |
| `make runtest` | Native build + dune tests (includes `main.t` cram test) |
| `make npm-install` | Install `node_modules` from lockfile (`npm ci`) |
| `make stage-jsoo` | Compile OCaml → JS, assemble `workers/jsoo/dist/` |
| `make stage-melange` | Compile OCaml → JS, assemble `workers/melange/dist/` |
| `make stage-workers` | Both of the above |

### Verify (no CF account needed)

| Target | Description |
|---|---|
| `make smoke-test-jsoo` | Stage + validate jsoo bundle with Node.js |
| `make smoke-test-melange` | Stage + validate melange bundle with Node.js |
| `make verify-workers` | Both smoke tests |

### Local dev

| Target | Description |
|---|---|
| `make dev-jsoo` | `wrangler dev` on http://localhost:8787 (miniflare) |
| `make dev-melange` | `wrangler dev` on http://localhost:8788 (miniflare) |

### Deploy (requires `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID`)

| Target | Description |
|---|---|
| `make deploy-jsoo` | Upload jsoo worker version to Cloudflare (promotes on `main`) |
| `make deploy-melange` | Upload melange worker version to Cloudflare (promotes on `main`) |
| `make deploy-workers` | Both uploads |
| `make deploy-test-workers` | Both uploads + integration tests via preview URL |

### GitHub secrets

| Target | Description |
|---|---|
| `make gh-secrets-devel` | Push CF credentials to `cloudflare-devel` environment |
| `make gh-secrets-main` | Push CF credentials to `cloudflare-production` environment |
| `make gh-secrets` | Both of the above |

Use `./with-cloudflare make <target>` to inject credentials from the local wrapper script.

## Architecture

### Shared library (`lib/`)

`lib/worker_lib` is a pure OCaml library compiled in all three modes
(`byte native melange`) and used by every target:

- `Worker_types` — `request` (url, method, headers) and `response` (status,
  body) types, `method_of/to_string` helpers, and `pp_request`/`pp_response`
  pretty-printers.
- `Worker_handler` — `handle : request -> response` that produces the greeting
  body from request fields; no JS FFI.

Each JS worker bridge maps JS→OCaml request fields, calls `Worker_handler.handle`,
then appends the backend name and `COMMIT_SHA` env binding before constructing
the JS `Response`. The native `main.exe` constructs a sample request and pretty-
prints the response directly.

### jsoo backend

jsoo compiles OCaml to a self-contained JavaScript IIFE bundle. Cloudflare
Workers require ESM, so staging concatenates three files:

```
worker_prefix.js   stubs require() — jsoo runtime references Node.js APIs
                   during init even in browser mode
worker.bc.js       jsoo IIFE; sets globalThis.ocamlWorkerFetch
worker_suffix.js   export default { fetch } that calls the global
```

`wrangler.toml` sets `no_bundle = true` — the file is already complete ESM.

### melange backend

melange emits native ESM. `melange.emit` with `(module_systems esm)` and
`(preprocess (pps melange.ppx))` produces `output/workers/melange/worker.js`.
Melange prefixes `fetch` with `$$` to avoid shadowing the JS global.

`entry.js` imports `{ $$fetch as fetch }` and re-exports as
`export default { fetch }`. Wrangler bundles `entry.js` + the output tree
via esbuild into a single upload.

### Version verification

Each worker reads a `COMMIT_SHA` CF Worker binding (injected at deploy time
via `--var COMMIT_SHA:<sha>`) and includes it in the response:

```
Hello, World! [GET https://example.com/] from js_of_ocaml (commit: abc1234)
```

Post-deploy integration tests curl the live URL and assert both the greeting
text and the exact SHA are present.

## CI / CD

`build.yml` runs on every push and PR:

1. `make runtest` — native OCaml build and tests
2. `make npm-install` + `make verify-workers` — build JS bundles, smoke-test with Node.js
3. On push to `devel` or `main` only:
   - `make deploy-jsoo` + `make deploy-melange` — upload new version to Cloudflare
   - On `main`: also promotes to 100% production traffic
   - Integration tests always run against the version-specific preview URL (no propagation delay)

Branch-scoped worker names (computed in `scripts/cf-worker.sh`):
- `main` → `ocaml-worker-jsoo` / `ocaml-worker-melange`
- `devel` → `ocaml-worker-jsoo-devel` / `ocaml-worker-melange-devel`

GitHub Environments:
- `cloudflare-devel` — used for all non-main branches
- `cloudflare-production` — used for main

## Local credentials

Create a `with-cloudflare` wrapper (gitignored):

```sh
#!/bin/sh
export CLOUDFLARE_API_TOKEN="..."
export CLOUDFLARE_ACCOUNT_ID="..."
exec "$@"
```

```bash
./with-cloudflare make deploy-test-workers
./with-cloudflare make gh-secrets-devel
```

## Dependencies

| Tool | Version | Purpose |
|---|---|---|
| OCaml | 4.14.2 | Compiler (via opam devcontainer feature) |
| js_of_ocaml | 6.3.2 | OCaml → JS IIFE |
| melange | 6.0.1 | OCaml → ESM |
| dune | 3.22.1 | Build system (`lang 3.17`, `using melange 0.1`) |
| wrangler | 4.x | CF Worker deploy + local dev |
