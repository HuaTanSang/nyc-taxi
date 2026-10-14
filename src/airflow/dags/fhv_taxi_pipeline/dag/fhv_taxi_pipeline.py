from __future__ import annotations

from datetime import timedelta

import pendulum
from airflow.sdk import dag
from common.constants import DEFAULT_DAG_PARAMS
from common.tasks.end_dag import end_dag
from common.tasks.startup_dag import startup_dag

from fhv_taxi_pipeline.task.ingest_fhv_taxi import (
    stream_fhv_taxi_to_minio,
)


@dag(
    dag_id="fhv_taxi_pipeline",
    description="Stream fhv Taxi data to MinIO",
    schedule=None,
    start_date=pendulum.datetime(2025, 1, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    default_args={
        "owner": "data-engineering",
        "retries": 3,
        "retry_delay": timedelta(minutes=2),
        "retry_exponential_backoff": True,
        "max_retry_delay": timedelta(minutes=15),
    },
    params=DEFAULT_DAG_PARAMS,
    tags=["nyc-taxi", "fhv", "minio", "raw"],
)
def fhv_taxi_pipeline() -> None:
    startup_task = startup_dag(taxi_type="fhv")

    ingestion_task = stream_fhv_taxi_to_minio()

    end_task = end_dag()

    startup_task >> ingestion_task >> end_task


fhv_taxi_pipeline()
