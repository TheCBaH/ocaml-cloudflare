#!/usr/bin/env bash
# Cloudflare Worker helper — usage: cf-worker.sh <command> [args...]
#
# Commands:
#   name <base-name>
#       Print the branch-scoped CF Worker name.
#       Branch is read from GITHUB_REF_NAME (CI) or current git branch.
#       main → <base-name>;  other → <base-name>-<branch>
#
#   deploy <backend> <wrangler-config> <dist-dir> <base-name>
#       Upload a new version via `wrangler versions upload`.  Requires
#       CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID in the environment.
#       Worker name and git SHA are computed automatically.
#       On main: promotes to 100% and writes the production URL to
#         <dist-dir>/.deploy-url.
#       On other branches: skips promotion and writes the version-specific
#         preview URL to <dist-dir>/.deploy-url.
#
#   test <backend> <expected-text> <base-name> [url]
#       Curl the URL from <dist-dir>/.deploy-url and assert it contains
#       <expected-text> and the current commit SHA.
set -euo pipefail

CMD="${1:?Usage: cf-worker.sh <name|deploy|test> [args...]}"
shift

_branch() {
    local raw="${GITHUB_REF_NAME:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)}"
    echo "${raw//\//-}"
}

_worker_name() {
    local base="$1" branch
    branch="$(_branch)"
    [[ "$branch" == "main" ]] && echo "$base" || echo "${base}-${branch}"
}

_git_sha() {
    git rev-parse --short HEAD 2>/dev/null || echo unknown
}

case "$CMD" in

  name)
    _worker_name "${1:?name requires <base-name>}"
    ;;

  deploy)
    BACKEND="${1:?}"; CONFIG="${2:?}"; DIST_DIR="${3:?}"; BASE_NAME="${4:?}"
    : "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is not set}"
    : "${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID is not set}"
    WORKER_NAME="$(_worker_name "$BASE_NAME")"
    GIT_SHA="$(_git_sha)"
    LOG="$DIST_DIR/deploy.log"

    npm exec -- wrangler versions upload \
        --config "$CONFIG" \
        --name "$WORKER_NAME" \
        --var "COMMIT_SHA:$GIT_SHA" \
        --message "$GIT_SHA" \
        2>&1 | tee "$LOG"

    VERSION=$(grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$LOG" | head -1)
    [[ -n "$VERSION" ]] || { echo "error: could not extract version ID" >&2; exit 1; }

    PREVIEW_URL=$(grep -oE 'https://[^ ]*\.workers\.dev' "$LOG" | head -1)
    [[ -n "$PREVIEW_URL" ]] || { echo "error: could not extract preview URL" >&2; exit 1; }

    if [[ "$(_branch)" == "main" ]]; then
        npm exec -- wrangler versions deploy \
            --name "$WORKER_NAME" \
            --version-id "$VERSION" \
            --percentage 100 \
            --message "$GIT_SHA" \
            --yes \
            2>&1 | tee -a "$LOG"
        echo "$BACKEND promoted to production: version $VERSION"
    else
        echo "$BACKEND not promoted (branch: $(_branch))"
    fi

    # Always test via the version-specific preview URL — no propagation delay
    echo "$PREVIEW_URL" > "$DIST_DIR/.deploy-url"
    echo "$BACKEND preview URL: $PREVIEW_URL  version: $VERSION"
    ;;

  test)
    BACKEND="${1:?}"; EXPECTED_TEXT="${2:?}"; BASE_NAME="${3:?}"
    URL="${4:-$(cat "workers/$BACKEND/dist/.deploy-url" 2>/dev/null || true)}"
    GIT_SHA="$(_git_sha)"
    [[ -n "$URL" ]] \
        || { echo "error: URL not set — run 'make deploy-$BACKEND' first" >&2; exit 1; }

    echo "Testing $URL  (expected commit: $GIT_SHA)"
    BODY=$(curl -sf --max-time 15 "$URL")
    echo "Response: $BODY"

    echo "$BODY" | grep -q "$EXPECTED_TEXT" \
        || { echo "ERROR: response missing '$EXPECTED_TEXT'" >&2; exit 1; }
    echo "$BODY" | grep -q "$GIT_SHA" \
        || { echo "ERROR: response missing commit SHA $GIT_SHA — wrong version live" >&2; exit 1; }

    echo "$BACKEND integration test PASSED"
    ;;

  *)
    echo "error: unknown command '$CMD' — expected name, deploy, or test" >&2
    exit 1
    ;;
esac
