from __future__ import annotations

import logging
from typing import Any

from airflow.sdk import get_current_context, task
from utils.s3_helper import stream_taxi_month_to_minio

logger = logging.getLogger(__name__)


@task(
    task_id="stream_fhvhv_taxi_to_minio",
    do_xcom_push=False,
)
def stream_fhvhv_taxi_to_minio() -> None:
    context = get_current_context()
    task_instance = context["ti"]

    run_metadata = task_instance.xcom_pull(
        task_ids="startup_dag",
        key="run_metadata",
    )

    if run_metadata is None:
        raise ValueError("XCom 'run_metadata' was not found from task 'startup_dag'.")

    logger.info(
        "Starting fhvhv Taxi ingestion: partition=%s",
        run_metadata["partition"],
    )

    stream_result = stream_taxi_month_to_minio(
        taxi_type=run_metadata["taxi_type"],
        year=run_metadata["year"],
        month=run_metadata["month"],
        force_reload=run_metadata["force_reload"],
    )

    ingestion_result: dict[str, Any] = {
        "status": "success",
        "taxi_type": run_metadata["taxi_type"],
        "year": run_metadata["year"],
        "month": run_metadata["month"],
        "partition": run_metadata["partition"],
        "stream_result": stream_result,
    }

    task_instance.xcom_push(
        key="fhvhv_ingestion_result",
        value=ingestion_result,
    )

    logger.info(
        "Pushed XCom ingestion_result: partition=%s status=%s",
        ingestion_result["partition"],
        ingestion_result["status"],
    )
