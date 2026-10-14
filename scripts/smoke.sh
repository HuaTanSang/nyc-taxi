#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"

set -a
source "$ENV_FILE"
set +a

curl --fail --silent --show-error "http://localhost:${MINIO_API_PORT}/minio/health/ready" >/dev/null
curl --fail --silent --show-error "http://localhost:${CLICKHOUSE_HTTP_PORT}/?query=SELECT%201" | grep -qx '1'
curl --fail --silent --show-error "http://localhost:${AIRFLOW_WEB_PORT}/api/v2/version" >/dev/null
curl --fail --silent --show-error "http://localhost:${SUPERSET_PORT}/health" >/dev/null

docker compose \
    --env-file "$ENV_FILE" \
    --project-name "${PROJECT_PREFIX}_dbt" \
    --project-directory "$ROOT_DIR/src/dbt" \
    --file "$ROOT_DIR/src/dbt/docker-compose.yaml" \
    run --rm dbt dbt parse

echo "Smoke checks passed."
