from __future__ import annotations

import logging
from datetime import datetime, timezone

from airflow.sdk import get_current_context, task

logger = logging.getLogger(__name__)


@task(
    task_id="end_dag",
    do_xcom_push=False,
)
def end_dag() -> None:
    context = get_current_context()
    task_instance = context["ti"]

    run_metadata = task_instance.xcom_pull(
        task_ids="startup_dag",
        key="run_metadata",
    )

    if run_metadata is None:
        raise ValueError("XCom 'run_metadata' was not found from task 'startup_dag'.")

    finished_at = datetime.now(timezone.utc).isoformat()

    logger.info(
        "Pipeline completed: dag_id=%s run_id=%s partition=%s status=%s finished_at=%s",
        run_metadata["dag_id"],
        run_metadata["run_id"],
        run_metadata["partition"],
        finished_at,
    )
