from __future__ import annotations

from airflow.sdk import get_current_context, task
from airflow.sdk.exceptions import AirflowException
from common.constants import SUPPORTED_PIPELINE_YEARS, TAXI_PIPELINES


def make_ingestion_plan(
    year: int,
    month: int,
    force_reload: bool,
    parent_run_id: str,
) -> list[dict]:
    if year not in SUPPORTED_PIPELINE_YEARS:
        raise AirflowException(f"Year is not supported: {year}")

    if month < 1 and month > 12:
        raise AirflowException(f"Month is not supported: {month}")

    ingestion_plan = []

    for taxi_pipeline in TAXI_PIPELINES:
        taxi_type = taxi_pipeline.get("taxi_type", None)
        ingestion_plan.append(
            {
                "trigger_dag_id": taxi_pipeline.get("dag_id", None),
                "trigger_run_id": (f"orchestrated__{parent_run_id}__{taxi_type}"),
                "conf": {
                    "year": year,
                    "month": month,
                    "force_reload": force_reload,
                },
            }
        )

    return ingestion_plan


@task
def build_ingestion_plan():
    context = get_current_context()
    params = context["params"]

    return make_ingestion_plan(
        year=params["year"],
        month=params["month"],
        force_reload=params["force_reload"],
        parent_run_id=context["run_id"],
    )
