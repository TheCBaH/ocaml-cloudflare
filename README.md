# OCaml Cloudflare Workers

[![build](https://github.com/TheCBaH/ocaml-cloudflare/actions/workflows/build.yml/badge.svg?branch=devel)](https://github.com/TheCBaH/ocaml-cloudflare/actions/workflows/build.yml)

Hello-world [Cloudflare Workers](https://workers.cloudflare.com/) compiled from [OCaml](https://ocaml.org/) using two JS backends:

- **[js_of_ocaml](https://ocsigen.org/js_of_ocaml/)** — compiles OCaml bytecode to a JS bundle
- **[melange](https://melange.re/)** — compiles OCaml to native ES modules

Request/response types and the worker handler live in a shared pure-OCaml
library (`lib/`) used by both backends and the native binary. Each JS bridge is
a thin layer that maps JS↔OCaml types and appends the backend name and commit
SHA to the response.

## Get started

The easiest way is to open this repository in GitHub Codespaces — everything is pre-installed and configured.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/TheCBaH/ocaml-cloudflare)

Or clone and open locally in VS Code with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

## Build and verify

```bash
make npm-install       # install wrangler
make verify-workers    # compile OCaml → JS, smoke-test with Node.js
```

## Local dev server

```bash
make dev-jsoo          # http://localhost:8787  (miniflare, no CF account needed)
make dev-melange       # http://localhost:8788
```

## Deploy to Cloudflare

Set your Cloudflare credentials as environment variables and deploy:

```bash
export CLOUDFLARE_API_TOKEN="..."
export CLOUDFLARE_ACCOUNT_ID="..."
make deploy-test-workers   # deploy + integration test
```

See [CLAUDE.md](CLAUDE.md) for the full list of Makefile targets, architecture details, and CI/CD documentation.
