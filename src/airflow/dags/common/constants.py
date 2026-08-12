from __future__ import annotations

import os

from airflow.sdk import Param

TLC_TRIP_DATA_BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data"

S3_CONNECTION_ID = os.getenv("S3_CONNECTION_ID", "minio_s3")
RAW_BUCKET_NAME = os.getenv("RAW_BUCKET_NAME", "raw")

MULTIPART_CHUNK_SIZE = 16 * 1024 * 1024

SUPPORTED_TAXI_TYPES = {"yellow", "green", "fhv", "fhvhv"}

DEFAULT_DAG_PARAMS = {
    "year": Param(default=2025, type="integer", minimum=2009, maximum=2100),
    "month": Param(default=1, type="integer", minimum=1, maximum=12),
    "force_reload": Param(default=False, type="boolean"),
}

MONTHLY_PIPELINE_PARAMS = {
    "year": Param(
        default=2025,
        type="integer",
        enum=[2025, 2026],
    ),
    "month": Param(
        default=1,
        type="integer",
        minimum=1,
        maximum=12,
    ),
    "force_reload": Param(
        default=False,
        type="boolean",
    ),
}

SUPPORTED_PIPELINE_YEARS = frozenset({2025, 2026})

TAXI_PIPELINES = (
    {
        "taxi_type": "yellow",
        "dag_id": "yellow_taxi_pipeline",
    },
    {
        "taxi_type": "green",
        "dag_id": "green_taxi_pipeline",
    },
    {
        "taxi_type": "fhv",
        "dag_id": "fhv_taxi_pipeline",
    },
    {
        "taxi_type": "fhvhv",
        "dag_id": "fhvhv_taxi_pipeline",
    },
)
