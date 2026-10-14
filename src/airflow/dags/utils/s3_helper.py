from __future__ import annotations

import logging
from typing import Any

import requests
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from botocore.exceptions import ClientError
from common.constants import (
    MULTIPART_CHUNK_SIZE,
    RAW_BUCKET_NAME,
    S3_CONNECTION_ID,
)
from utils.utils import _build_filename, build_source_url

logger = logging.getLogger(__name__)


def _ensure_bucket(s3_hook: S3Hook, bucket_name: str) -> None:
    if s3_hook.check_for_bucket(bucket_name=bucket_name):
        return

    try:
        s3_hook.create_bucket(bucket_name=bucket_name)
    except ClientError as exc:
        error_code = exc.response.get("Error", {}).get("Code")
        if error_code not in {"BucketAlreadyExists", "BucketAlreadyOwnedByYou"}:
            raise


def _existing_object_is_valid(metadata: dict[str, Any] | None) -> bool:
    if not metadata:
        return False

    actual_size = int(metadata.get("ContentLength", 0))
    if actual_size <= 0:
        return False

    source_size = metadata.get("Metadata", {}).get("source-content-length")
    if source_size is None:
        return True

    return actual_size == int(source_size)


def build_object_key(taxi_type: str, year: int, month: int) -> str:
    filename = _build_filename(taxi_type, year, month)
    return f"{taxi_type}/year={year}/month={month:02d}/{filename}"


def get_minio_hook(minio_conn_id: str = S3_CONNECTION_ID) -> S3Hook:
    """
    Getting MinIO connection, add Airflow Connection before calling this function
    Args:
    - minio_conn_id: (str) id of minio connection
    Returns:
    - S3Hook
    """
    s3_hook = S3Hook(
        aws_conn_id=minio_conn_id,
        transfer_config_args={
            "multipart_threshold": MULTIPART_CHUNK_SIZE,
            "multipart_chunksize": MULTIPART_CHUNK_SIZE,
            "max_concurrency": 1,
            "use_threads": False,
        },
    )
    return s3_hook


def stream_taxi_month_to_minio(
    *,
    taxi_type: str,
    year: int,
    month: int,
    force_reload: bool,
) -> dict[str, Any]:
    source_url = build_source_url(taxi_type, year, month)
    object_key = build_object_key(taxi_type, year, month)

    s3_hook = get_minio_hook()

    _ensure_bucket(s3_hook, RAW_BUCKET_NAME)

    existing = s3_hook.head_object(
        key=object_key,
        bucket_name=RAW_BUCKET_NAME,
    )
    if not force_reload and _existing_object_is_valid(existing):
        return {
            "status": "skipped",
            "taxi_type": taxi_type,
            "year": year,
            "month": month,
            "source_url": source_url,
            "size": existing["ContentLength"],
            "etag": existing.get("ETag"),
        }

    logger.info("Streaming %s to %s", source_url, object_key)

    with requests.get(
        source_url,
        headers={"Accept-Encoding": "identity"},
        stream=True,
        timeout=(30, 300),
        allow_redirects=True,
    ) as response:
        response.raise_for_status()
        response.raw.decode_content = False

        source_size_header = response.headers.get("Content-Length")
        source_size = int(source_size_header) if source_size_header else None
        content_type = response.headers.get(
            "Content-Type",
            "application/octet-stream",
        )

        object_metadata = {
            "source-url": source_url,
            "dataset": f"nyc-{taxi_type}-taxi",
            "year": str(year),
            "month": f"{month:02d}",
        }
        if source_size is not None:
            object_metadata["source-content-length"] = str(source_size)

        s3_hook.get_conn().upload_fileobj(
            Fileobj=response.raw,
            Bucket=RAW_BUCKET_NAME,
            Key=object_key,
            ExtraArgs={
                "ContentType": content_type,
                "Metadata": object_metadata,
            },
            Config=s3_hook.transfer_config,
        )

    uploaded = s3_hook.head_object(
        key=object_key,
        bucket_name=RAW_BUCKET_NAME,
    )

    uploaded_size = int(uploaded["ContentLength"])
    if source_size is not None and uploaded_size != source_size:
        s3_hook.delete_objects(bucket=RAW_BUCKET_NAME, keys=object_key)
        raise RuntimeError(
            "Uploaded object size does not match the HTTP Content-Length: "
            f"expected={source_size}, actual={uploaded_size}, key={object_key}"
        )

    logger.info("Upload completed: %s (%s bytes)", object_key, uploaded_size)
    return {
        "status": "uploaded",
        "taxi_type": taxi_type,
        "year": year,
        "month": month,
        "source_url": source_url,
        "object_key": object_key,
        "size": uploaded_size,
        "etag": uploaded.get("ETag"),
    }
