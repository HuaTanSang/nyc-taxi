#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
EXAMPLE_FILE="$ROOT_DIR/.env.example"

if [ ! -f "$ENV_FILE" ]; then
    cp "$EXAMPLE_FILE" "$ENV_FILE"
fi

read_value() {
    file=$1
    key=$2
    [ -f "$file" ] || return 0
    awk -v wanted="$key" '
        index($0, wanted "=") == 1 {
            print substr($0, length(wanted) + 2)
            exit
        }
    ' "$file"
}

write_value() {
    key=$1
    value=$2
    tmp_file="${ENV_FILE}.tmp"
    awk -v wanted="$key" -v replacement="$value" '
        index($0, wanted "=") == 1 {
            print wanted "=" replacement
            found = 1
            next
        }
        { print }
        END {
            if (!found) {
                print wanted "=" replacement
            }
        }
    ' "$ENV_FILE" > "$tmp_file"
    mv "$tmp_file" "$ENV_FILE"
}

generate_hex() {
    openssl rand -hex "$1"
}

generate_fernet() {
    openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n'
}

generate_if_missing() {
    key=$1
    generator=$2
    current=$(read_value "$ENV_FILE" "$key")
    if [ -z "$current" ] || [ "$current" = "__GENERATE__" ]; then
        write_value "$key" "$($generator)"
    fi
}

host_uid() {
    id -u
}

generate_if_missing AIRFLOW_UID host_uid
generate_if_missing MINIO_SECRET_KEY 'generate_hex 24'
generate_if_missing CLICKHOUSE_PASSWORD 'generate_hex 24'
generate_if_missing AIRFLOW_ADMIN_PASSWORD 'generate_hex 24'
generate_if_missing AIRFLOW_FERNET_KEY generate_fernet
generate_if_missing AIRFLOW_API_JWT_SECRET 'generate_hex 32'
generate_if_missing AIRFLOW_POSTGRES_PASSWORD 'generate_hex 24'
generate_if_missing SUPERSET_SECRET_KEY 'generate_hex 32'
generate_if_missing SUPERSET_ADMIN_PASSWORD 'generate_hex 24'
generate_if_missing SUPERSET_POSTGRES_PASSWORD 'generate_hex 24'

required_keys='PROJECT_PREFIX IMAGE_TAG MINIO_ACCESS_KEY MINIO_SECRET_KEY MINIO_API_PORT MINIO_CONSOLE_PORT RAW_BUCKET_NAME CLICKHOUSE_USER CLICKHOUSE_PASSWORD CLICKHOUSE_DB CLICKHOUSE_HTTP_PORT CLICKHOUSE_NATIVE_PORT AIRFLOW_UID AIRFLOW_WEB_PORT AIRFLOW_ADMIN_USERNAME AIRFLOW_ADMIN_PASSWORD AIRFLOW_FERNET_KEY AIRFLOW_API_JWT_SECRET AIRFLOW_POSTGRES_USER AIRFLOW_POSTGRES_PASSWORD AIRFLOW_POSTGRES_DB SUPERSET_VERSION SUPERSET_PORT SUPERSET_SECRET_KEY SUPERSET_ADMIN_USERNAME SUPERSET_ADMIN_PASSWORD SUPERSET_POSTGRES_VERSION SUPERSET_POSTGRES_USER SUPERSET_POSTGRES_PASSWORD SUPERSET_POSTGRES_DB DBT_DOCS_PORT'

for key in $required_keys; do
    value=$(read_value "$ENV_FILE" "$key")
    if [ -z "$value" ] || [ "$value" = "__GENERATE__" ]; then
        echo "Missing required value: $key" >&2
        exit 1
    fi
done

chmod 600 "$ENV_FILE"
echo "Configuration ready: $ENV_FILE"
