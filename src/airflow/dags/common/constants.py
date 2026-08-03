from __future__ import annotations

import os

from airflow.sdk import Param

TLC_TRIP_DATA_BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data"

S3_CONNECTION_ID = os.getenv("NYC_TAXI_S3_CONN_ID", "minio_s3")
RAW_BUCKET_NAME = os.getenv("NYC_TAXI_RAW_BUCKET", "raw")

MULTIPART_CHUNK_SIZE = 16 * 1024 * 1024

SUPPORTED_TAXI_TYPES = {"yellow", "green", "fhv", "fhvhv"}

DEFAULT_DAG_PARAMS = {
    "year": Param(default=2025, type="integer", minimum=2009, maximum=2100),
    "month": Param(default=1, type="integer", minimum=1, maximum=12),
    "force_reload": Param(default=False, type="boolean"),
}
