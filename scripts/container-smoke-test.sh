#!/usr/bin/env bash
# Proves the built image actually works, not just that `docker build`
# exited zero - see container-learning/23-container-artifact-testing.md.
#
# This is the SQLite half of the artefact test. Its PostgreSQL counterpart,
# scripts/postgres-smoke-test.sh, runs the same image against a real database
# server.
#
# Requires: an image already built as notes-app:local (`make build`).
# Run this after every build, before you consider the artefact a release
# candidate - see container-learning/25-building-a-manual-release-quality-gate.md.

set -euo pipefail

IMAGE="${NOTES_APP_IMAGE:-notes-app:local}"
CONTAINER="notes-app-smoke-test"
PORT="18000"
VOLUME="notes-app-smoke-test-data"

cleanup() {
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    docker volume rm "$VOLUME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "== no secret baked into the image =="
# APP_SECRET must never appear as an image-level ENV - the Dockerfile never
# sets it, precisely so it can only ever come from runtime configuration.
# If this ever fails, something in the Dockerfile started hard-coding it.
if docker inspect "$IMAGE" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -qi "APP_SECRET"; then
    echo "FAIL: APP_SECRET is baked into the image's own ENV config"
    exit 1
fi
echo "ok - APP_SECRET is not present in the image's own config; it only exists once supplied at runtime"

echo "== container starts and runs as non-root =="
docker run -d --name "$CONTAINER" \
    -p "${PORT}:8000" \
    -e APP_ENV=development \
    -e DATABASE_URL="sqlite:////data/notes.db" \
    -v "${VOLUME}:/data" \
    "$IMAGE"

RUNTIME_USER="$(docker exec "$CONTAINER" id -u)"
if [ "$RUNTIME_USER" = "0" ]; then
    echo "FAIL: container is running as root (uid 0)"
    exit 1
fi
echo "ok - running as uid $RUNTIME_USER, not root"

echo "== waiting for health check =="
for _ in $(seq 1 15); do
    STATUS="$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null || echo "starting")"
    [ "$STATUS" = "healthy" ] && break
    sleep 2
done
if [ "$STATUS" != "healthy" ]; then
    echo "FAIL: container did not become healthy (last status: $STATUS)"
    docker logs "$CONTAINER"
    exit 1
fi
echo "ok - health check reports healthy"

echo "== API and dashboard smoke test =="
BASE="http://127.0.0.1:${PORT}"
curl -sf "${BASE}/health" >/dev/null && echo "ok - /health"
curl -sf "${BASE}/" >/dev/null && echo "ok - / (dashboard)"
curl -sf "${BASE}/styles.css" >/dev/null && echo "ok - static assets served"

NOTE_ID="$(curl -sf -X POST "${BASE}/notes" \
    -H 'Content-Type: application/json' \
    -d '{"title":"smoke test","content":"created by container-smoke-test.sh"}' \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"
echo "ok - created note id=${NOTE_ID}"
curl -sf "${BASE}/notes/${NOTE_ID}" >/dev/null && echo "ok - database write is readable back"

echo "== data survives container recreation =="
docker rm -f "$CONTAINER" >/dev/null
docker run -d --name "$CONTAINER" \
    -p "${PORT}:8000" \
    -e APP_ENV=development \
    -e DATABASE_URL="sqlite:////data/notes.db" \
    -v "${VOLUME}:/data" \
    "$IMAGE"
sleep 3
if curl -sf "${BASE}/notes/${NOTE_ID}" | grep -q "smoke test"; then
    echo "ok - note ${NOTE_ID} survived container recreation (named volume works)"
else
    echo "FAIL: note did not survive container recreation - persistence is broken"
    exit 1
fi

echo "== clean shutdown =="
START="$(date +%s)"
docker stop "$CONTAINER" >/dev/null
END="$(date +%s)"
ELAPSED=$((END - START))
echo "ok - container stopped in ${ELAPSED}s (exec-form CMD received SIGTERM directly)"

echo ""
echo "All container smoke tests passed."
