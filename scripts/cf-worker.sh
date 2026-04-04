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
#       Deploy a staged worker via wrangler.  Requires CLOUDFLARE_API_TOKEN
#       and CLOUDFLARE_ACCOUNT_ID in the environment.
#       Worker name and git SHA are computed automatically.
#       Writes the live workers.dev URL to <dist-dir>/.deploy-url and the
#       deployed version ID to <dist-dir>/.deploy-version.
#
#   wait <backend> <base-name>
#       Poll `wrangler deployments status` until the version ID from the last
#       deploy is the active deployment.  Requires CF credentials.
#       Timeout controlled by CF_WAIT_TIMEOUT (default 60s) and
#       CF_WAIT_INTERVAL (default 5s).
#
#   test <backend> <expected-text> <base-name> [url]
#       Curl a live worker endpoint and assert it contains <expected-text>
#       and the current commit SHA.
#       url defaults to <dist-dir>/.deploy-url content.
set -euo pipefail

CMD="${1:?Usage: cf-worker.sh <name|deploy|wait|test> [args...]}"
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

    npm exec -- wrangler deploy \
        --config "$CONFIG" \
        --name "$WORKER_NAME" \
        --var "COMMIT_SHA:$GIT_SHA" \
        2>&1 | tee "$LOG"

    URL=$(grep -oE 'https://[^ ]+\.workers\.dev' "$LOG" | head -1)
    [[ -n "$URL" ]] || { echo "error: could not extract workers.dev URL" >&2; exit 1; }
    echo "$URL" > "$DIST_DIR/.deploy-url"

    VERSION=$(grep -oE 'Current Version ID: [0-9a-f-]+' "$LOG" | head -1 | awk '{print $NF}')
    [[ -n "$VERSION" ]] || { echo "error: could not extract version ID" >&2; exit 1; }
    echo "$VERSION" > "$DIST_DIR/.deploy-version"

    echo "$BACKEND deploy URL: $URL  version: $VERSION"
    ;;

  wait)
    BACKEND="${1:?}"; BASE_NAME="${2:?}"
    : "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is not set}"
    : "${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID is not set}"
    WORKER_NAME="$(_worker_name "$BASE_NAME")"
    EXPECTED_VERSION=$(cat "workers/$BACKEND/dist/.deploy-version" 2>/dev/null || true)
    [[ -n "$EXPECTED_VERSION" ]] \
        || { echo "error: version file not found — run 'make deploy-$BACKEND' first" >&2; exit 1; }

    TIMEOUT="${CF_WAIT_TIMEOUT:-60}"
    INTERVAL="${CF_WAIT_INTERVAL:-5}"

    echo "Waiting for $BACKEND worker '$WORKER_NAME' to activate version $EXPECTED_VERSION (timeout ${TIMEOUT}s)..."
    DEADLINE=$(( $(date +%s) + TIMEOUT ))
    while true; do
        STATUS=$(npm exec -- wrangler deployments status \
            --name "$WORKER_NAME" --json 2>/dev/null || true)
        if echo "$STATUS" | grep -qF "$EXPECTED_VERSION"; then
            echo "$BACKEND deployment confirmed active: version $EXPECTED_VERSION"
            break
        fi
        if (( $(date +%s) >= DEADLINE )); then
            echo "ERROR: timed out after ${TIMEOUT}s — last status: $STATUS" >&2
            exit 1
        fi
        echo "  not yet — retrying in ${INTERVAL}s..."
        sleep "$INTERVAL"
    done
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
    echo "error: unknown command '$CMD' — expected name, deploy, wait, or test" >&2
    exit 1
    ;;
esac
