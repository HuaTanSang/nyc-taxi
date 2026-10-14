from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from airflow.exceptions import AirflowException
from airflow.sdk import get_current_context, task
from common.constants import SUPPORTED_TAXI_TYPES

logger = logging.getLogger(__name__)


@task(
    task_id="startup_dag",
    do_xcom_push=False,
)
def startup_dag(taxi_type: str) -> None:
    logger.info("[STARTING] Starting DAG...")

    context = get_current_context()
    params = context["params"]
    task_instance = context["ti"]
    year = params["year"]
    month = params["month"]
    force_reload = params["force_reload"]

    normalized_taxi_type = taxi_type.strip().lower()

    if normalized_taxi_type not in SUPPORTED_TAXI_TYPES:
        raise AirflowException(
            f"Invalid taxi type: {taxi_type}. "
            f"Supported values: {sorted(SUPPORTED_TAXI_TYPES)}"
        )

    _validate_partition(taxi_type, year, month)

    run_metadata: dict[str, Any] = {
        "dag_id": context["dag"].dag_id,
        "run_id": task_instance.run_id,
        "taxi_type": normalized_taxi_type,
        "year": year,
        "month": month,
        "partition": f"year={year}/month={month:02d}",
        "partition_source": "dag_params",
        "force_reload": force_reload,
        "started_at": datetime.now(timezone.utc).isoformat(),
    }

    task_instance.xcom_push(
        key="run_metadata",
        value=run_metadata,
    )

    logger.info(
        "Pushed XCom run_metadata: taxi_type=%s partition=%s force_reload=%s",
        run_metadata["taxi_type"],
        run_metadata["partition"],
        run_metadata["force_reload"],
    )


def _validate_partition(taxi_type: str, year: int, month: int) -> None:
    if taxi_type not in SUPPORTED_TAXI_TYPES:
        raise AirflowException(f"Unsupported taxi type: {taxi_type}")
    if not 2009 <= year <= 2100:
        raise AirflowException(f"Year must be between 2009 and 2100: {year}")
    if not 1 <= month <= 12:
        raise AirflowException(f"Month must be between 1 and 12: {month}")
