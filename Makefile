# ── Native OCaml ──────────────────────────────────────────────────────────────

default:
	opam exec dune build

runtest:
	opam exec -- dune build
	opam exec -- dune runtest

format:
	opam exec -- dune fmt

run:
	opam exec -- dune exec src/main.exe

clean:
	opam exec dune $@
	rm -rf workers/jsoo/dist workers/melange/dist

# ── OCaml → JS build ─────────────────────────────────────────────────────────

build-jsoo:
	opam exec -- dune build workers/jsoo/worker.bc.js

build-melange:
	opam exec -- dune build @workers/melange/all

# ── Staging (build artefacts → dist/) ────────────────────────────────────────

stage-jsoo: build-jsoo
	rm -rf workers/jsoo/dist
	mkdir -p workers/jsoo/dist
	cat workers/jsoo/worker_prefix.js \
	    _build/default/workers/jsoo/worker.bc.js \
	    workers/jsoo/worker_suffix.js \
	    > workers/jsoo/dist/worker.js

stage-melange: build-melange
	rm -rf workers/melange/dist
	mkdir -p workers/melange/dist
	cp -r _build/default/workers/melange/output workers/melange/dist/
	cp workers/melange/entry.js workers/melange/dist/
	npm exec --prefix workers -- esbuild workers/melange/dist/entry.js \
	    --bundle --format=esm --external:'cloudflare:*' \
	    --outfile=workers/melange/dist/bundle.js

stage-workers: stage-jsoo stage-melange

# ── npm ───────────────────────────────────────────────────────────────────────

npm-install:
	npm ci

npm-update:
	npm update

# ── Local dev (wrangler dev / miniflare) ─────────────────────────────────────

dev-jsoo: stage-jsoo
	npm exec -- wrangler dev --config workers/jsoo/wrangler.toml

dev-melange: stage-melange
	npm exec -- wrangler dev --config workers/melange/wrangler.toml

# ── Smoke tests (no CF account needed) ───────────────────────────────────────

smoke-test-jsoo: stage-jsoo
	node workers/jsoo/smoke-test.mjs

smoke-test-melange: stage-melange
	node workers/melange/smoke-test.mjs

verify-workers: smoke-test-jsoo smoke-test-melange

# ── Miniflare tests (real workerd isolate, no CF account or wrangler dev TTY) ─

miniflare-test-jsoo: stage-jsoo
	node workers/jsoo/miniflare-test.mjs

miniflare-test-melange: stage-melange
	node workers/melange/miniflare-test.mjs

miniflare-test-workers: miniflare-test-jsoo miniflare-test-melange

# ── Cloudflare credentials guard ─────────────────────────────────────────────
# Depend on this target to fail early if CF credentials are missing.

check-cf-credentials:
	@test -n "$$CLOUDFLARE_API_TOKEN"  || { echo "error: CLOUDFLARE_API_TOKEN is not set";  exit 1; }
	@test -n "$$CLOUDFLARE_ACCOUNT_ID" || { echo "error: CLOUDFLARE_ACCOUNT_ID is not set"; exit 1; }

# ── Deploy to Cloudflare ──────────────────────────────────────────────────────

deploy-jsoo: stage-jsoo check-cf-credentials
	scripts/cf-worker.sh deploy jsoo \
	    workers/jsoo/wrangler.toml workers/jsoo/dist ocaml-worker-jsoo

deploy-melange: stage-melange check-cf-credentials
	scripts/cf-worker.sh deploy melange \
	    workers/melange/wrangler.toml workers/melange/dist ocaml-worker-melange

deploy-workers: deploy-jsoo deploy-melange

# ── GitHub secrets (populate from environment variables) ─────────────────────
# Usage: ./with-cloudflare make gh-secrets-devel

gh-secrets-devel: check-cf-credentials
	gh secret set CLOUDFLARE_API_TOKEN  --env cloudflare-devel --body "$$CLOUDFLARE_API_TOKEN"
	gh secret set CLOUDFLARE_ACCOUNT_ID --env cloudflare-devel --body "$$CLOUDFLARE_ACCOUNT_ID"

gh-secrets-main: check-cf-credentials
	gh secret set CLOUDFLARE_API_TOKEN  --env cloudflare-production --body "$$CLOUDFLARE_API_TOKEN"
	gh secret set CLOUDFLARE_ACCOUNT_ID --env cloudflare-production --body "$$CLOUDFLARE_ACCOUNT_ID"

gh-secrets: gh-secrets-devel gh-secrets-main

# ── Integration tests (hit live CF endpoints) ─────────────────────────────────

integration-test-jsoo:
	scripts/cf-worker.sh test jsoo js_of_ocaml ocaml-worker-jsoo $(JSOO_URL)

integration-test-melange:
	scripts/cf-worker.sh test melange melange ocaml-worker-melange $(MELANGE_URL)

integration-test-workers: integration-test-jsoo integration-test-melange

# ── Combined deploy + test ────────────────────────────────────────────────────

deploy-test-jsoo: deploy-jsoo integration-test-jsoo

deploy-test-melange: deploy-melange integration-test-melange

deploy-test-workers: deploy-workers integration-test-workers

.PHONY: \
	build-jsoo \
	miniflare-test-jsoo \
	miniflare-test-melange \
	miniflare-test-workers \
	build-melange \
	check-cf-credentials \
	clean \
	default \
	deploy-jsoo \
	deploy-melange \
	deploy-test-jsoo \
	deploy-test-melange \
	deploy-test-workers \
	deploy-workers \
	dev-jsoo \
	dev-melange \
	format \
	gh-secrets \
	gh-secrets-devel \
	gh-secrets-main \
	integration-test-jsoo \
	integration-test-melange \
	integration-test-workers \
	npm-install \
	npm-update \
	run \
	runtest \
	smoke-test-jsoo \
	smoke-test-melange \
	stage-jsoo \
	stage-melange \
	stage-workers \
	verify-workers \
