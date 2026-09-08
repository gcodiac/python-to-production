#!/usr/bin/env bash
# Proves the built image works against a real PostgreSQL server - the same
# image container-smoke-test.sh just exercised against SQLite.
#
# See container-learning/13-running-on-sqlite-or-postgresql.md.
#
# The point is not "PostgreSQL works". It is that ONE image, with no rebuild
# and no code change, works on both backends - which is the claim the whole
# database-portability design makes, and therefore the claim worth testing.
#
# Requires: an image already built as notes-app:local (`make build`), or any
# image passed via NOTES_APP_IMAGE - which is how CI runs this same script
# against the image it has just built, without rebuilding anything.

set -euo pipefail

IMAGE="${NOTES_APP_IMAGE:-notes-app:local}"
APP="notes-app-pg-smoke-app"
DB="notes-app-pg-smoke-db"
NETWORK="notes-app-pg-smoke-net"
VOLUME="notes-app-pg-smoke-data"
PORT="18001"
PG_IMAGE="postgres:17.6-alpine"

# Throwaway credentials for a container that exists for the length of this
# script. Not a secret, not reused anywhere, and deliberately not read from
# the environment so this script cannot accidentally pick up a real one.
PGUSER_LOCAL="notes"
PGDB_LOCAL="notes"
PGPASS_LOCAL="smoke-test-only-not-a-real-password"

cleanup() {
    docker rm -f "$APP" >/dev/null 2>&1 || true
    docker rm -f "$DB" >/dev/null 2>&1 || true
    docker volume rm "$VOLUME" >/dev/null 2>&1 || true
    docker network rm "$NETWORK" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

echo "== start a throwaway PostgreSQL server =="
docker network create "$NETWORK" >/dev/null
docker run -d --name "$DB" --network "$NETWORK" \
    -e POSTGRES_DB="$PGDB_LOCAL" \
    -e POSTGRES_USER="$PGUSER_LOCAL" \
    -e POSTGRES_PASSWORD="$PGPASS_LOCAL" \
    -v "${VOLUME}:/var/lib/postgresql/data" \
    "$PG_IMAGE" >/dev/null

echo "== wait for it to accept connections =="
# "Container running" is not "database ready" - pg_isready is the difference.
for _ in $(seq 1 30); do
    if docker exec "$DB" pg_isready -U "$PGUSER_LOCAL" -d "$PGDB_LOCAL" >/dev/null 2>&1; then
        READY="yes"
        break
    fi
    sleep 1
done
if [ "${READY:-no}" != "yes" ]; then
    echo "FAIL: PostgreSQL never became ready"
    docker logs "$DB"
    exit 1
fi
echo "ok - pg_isready reports the server is accepting connections"

echo "== start the SAME application image against it =="
# Note what is NOT happening here: no rebuild, no different tag, no
# PostgreSQL-specific image. Only DATABASE_URL differs from the SQLite run.
docker run -d --name "$APP" --network "$NETWORK" \
    -p "${PORT}:8000" \
    -e APP_ENV=development \
    -e APP_HOST=0.0.0.0 \
    -e DATABASE_URL="postgresql+psycopg://${PGUSER_LOCAL}:${PGPASS_LOCAL}@${DB}:5432/${PGDB_LOCAL}" \
    "$IMAGE" >/dev/null

BASE="http://127.0.0.1:${PORT}"

echo "== wait for readiness =="
for _ in $(seq 1 30); do
    if curl -sf "${BASE}/ready" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

READY_BODY="$(curl -sf "${BASE}/ready")"
echo "   /ready -> ${READY_BODY}"
if ! echo "$READY_BODY" | grep -q '"database":"postgresql"'; then
    echo "FAIL: the application is not reporting a PostgreSQL backend"
    docker logs "$APP"
    exit 1
fi
echo "ok - the application reports it reached PostgreSQL"

echo "== API works =="
NOTE_ID="$(curl -sf -X POST "${BASE}/notes" \
    -H 'Content-Type: application/json' \
    -d '{"title":"postgres smoke test","content":"created by postgres-smoke-test.sh"}' \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"
echo "ok - created note id=${NOTE_ID}"
curl -sf "${BASE}/notes/${NOTE_ID}" >/dev/null && echo "ok - readable back through the API"

echo "== the row is genuinely in PostgreSQL =="
# The strongest available evidence: ask the database directly, with a client
# that has nothing to do with the application. A postgres container merely
# *existing* alongside the app would prove nothing.
FOUND="$(docker exec "$DB" psql -U "$PGUSER_LOCAL" -d "$PGDB_LOCAL" -tAc \
    "SELECT title FROM notes WHERE id = ${NOTE_ID};")"
if [ "$FOUND" != "postgres smoke test" ]; then
    echo "FAIL: the note is not in PostgreSQL (psql returned: '${FOUND}')"
    exit 1
fi
echo "ok - psql found the row the HTTP API created"

echo "== data survives application container recreation =="
docker rm -f "$APP" >/dev/null
docker run -d --name "$APP" --network "$NETWORK" \
    -p "${PORT}:8000" \
    -e APP_ENV=development \
    -e APP_HOST=0.0.0.0 \
    -e DATABASE_URL="postgresql+psycopg://${PGUSER_LOCAL}:${PGPASS_LOCAL}@${DB}:5432/${PGDB_LOCAL}" \
    "$IMAGE" >/dev/null
for _ in $(seq 1 30); do
    curl -sf "${BASE}/ready" >/dev/null 2>&1 && break
    sleep 1
done
if curl -sf "${BASE}/notes/${NOTE_ID}" | grep -q "postgres smoke test"; then
    echo "ok - note ${NOTE_ID} survived: the data was never in the app container"
else
    echo "FAIL: note did not survive application recreation"
    exit 1
fi

echo "== data survives DATABASE container recreation =="
# The database container is disposable too; the named volume is what is not.
docker rm -f "$DB" >/dev/null
docker run -d --name "$DB" --network "$NETWORK" \
    -e POSTGRES_DB="$PGDB_LOCAL" \
    -e POSTGRES_USER="$PGUSER_LOCAL" \
    -e POSTGRES_PASSWORD="$PGPASS_LOCAL" \
    -v "${VOLUME}:/var/lib/postgresql/data" \
    "$PG_IMAGE" >/dev/null
for _ in $(seq 1 30); do
    docker exec "$DB" pg_isready -U "$PGUSER_LOCAL" -d "$PGDB_LOCAL" >/dev/null 2>&1 && break
    sleep 1
done
SURVIVED="$(docker exec "$DB" psql -U "$PGUSER_LOCAL" -d "$PGDB_LOCAL" -tAc \
    "SELECT title FROM notes WHERE id = ${NOTE_ID};")"
if [ "$SURVIVED" != "postgres smoke test" ]; then
    echo "FAIL: the note did not survive recreating the database container"
    exit 1
fi
echo "ok - note survived: ${VOLUME} outlived the container that used it"

echo ""
echo "All PostgreSQL smoke tests passed - same image, different backend."
