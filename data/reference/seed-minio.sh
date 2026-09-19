#!/usr/bin/env sh
set -eu

REFERENCE_DIR=/reference
SOURCE_FILE="$REFERENCE_DIR/taxi_zone_lookup.csv"
CHECKSUM_FILE="$REFERENCE_DIR/taxi_zone_lookup.csv.sha256"
OBJECT_PATH="local/$RAW_BUCKET_NAME/zone/taxi_zone_lookup.csv"

cd "$REFERENCE_DIR"
sha256sum -c "$CHECKSUM_FILE"

mc alias set local http://minio:9000 "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY"
mc mb --ignore-existing "local/$RAW_BUCKET_NAME"

local_checksum_line=$(sha256sum "$SOURCE_FILE")
local_checksum=${local_checksum_line%% *}

if mc stat "$OBJECT_PATH" >/dev/null 2>&1; then
    remote_checksum_line=$(mc cat "$OBJECT_PATH" | sha256sum)
    remote_checksum=${remote_checksum_line%% *}
    if [ "$remote_checksum" = "$local_checksum" ]; then
        echo "Reference object is already current: $OBJECT_PATH"
        exit 0
    fi

    if [ "${FORCE:-0}" != "1" ]; then
        echo "Reference object differs; rerun with FORCE=1 to replace it." >&2
        exit 1
    fi
fi

mc cp "$SOURCE_FILE" "$OBJECT_PATH"
echo "Reference object uploaded: $OBJECT_PATH"
