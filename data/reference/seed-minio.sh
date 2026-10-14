#!/usr/bin/env sh
set -eu

REFERENCE_DIR=/reference

cd "$REFERENCE_DIR"
sha256sum -c taxi_zone_lookup.csv.sha256
sha256sum -c taxi_zone_centroids.csv.sha256

mc alias set local http://minio:9000 "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY"
mc mb --ignore-existing "local/$RAW_BUCKET_NAME"

seed_file() {
    source_file="$REFERENCE_DIR/$1"
    object_path="local/$RAW_BUCKET_NAME/zone/$1"
    local_checksum_line=$(sha256sum "$source_file")
    local_checksum=${local_checksum_line%% *}

    if mc stat "$object_path" >/dev/null 2>&1; then
        remote_checksum_line=$(mc cat "$object_path" | sha256sum)
        remote_checksum=${remote_checksum_line%% *}
        if [ "$remote_checksum" = "$local_checksum" ]; then
            echo "Reference object is already current: $object_path"
            return
        fi

        if [ "${FORCE:-0}" != "1" ]; then
            echo "Reference object differs; rerun with FORCE=1 to replace it: $object_path" >&2
            exit 1
        fi
    fi

    mc cp "$source_file" "$object_path"
    echo "Reference object uploaded: $object_path"
}

seed_file taxi_zone_lookup.csv
seed_file taxi_zone_centroids.csv
