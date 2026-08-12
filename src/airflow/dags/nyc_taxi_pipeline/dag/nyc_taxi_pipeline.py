from __future__ import annotations

import os
from pathlib import Path

import pendulum
from airflow.providers.standard.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.sdk import dag
from common.constants import MONTHLY_PIPELINE_PARAMS
from cosmos import (
    DbtTaskGroup,
    ExecutionConfig,
    ProfileConfig,
    ProjectConfig,
    RenderConfig,
)
from cosmos.constants import InvocationMode
from cosmos.profiles import ClickhouseUserPasswordProfileMapping
from nyc_taxi_pipeline.task.build_ingestion_plan import build_ingestion_plan

DBT_ROOT_PATH = Path(
    os.getenv(
        "DBT_ROOT_PATH",
        "/opt/airflow/dags/dbt",
    )
)
# DBT_PROJECT_NAME = os.getenv("DBT_PROJECT_NAME", "nyc_taxi",)
# DBT_PROJECT_PATH = DBT_ROOT_PATH / DBT_PROJECT_NAME


@dag(
    dag_id="nyc_taxi_pipeline",
    schedule=None,
    start_date=pendulum.datetime(2025, 1, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    params=MONTHLY_PIPELINE_PARAMS,
    render_template_as_native_obj=True,
    tags=["nyc-taxi", "monthly", "orchestration"],
)
def nyc_taxi_pipeline():
    ingestion_plan = build_ingestion_plan()

    ingestion_task = TriggerDagRunOperator.partial(
        task_id="trigger_ingestion",
        wait_for_completion=True,
        deferrable=True,
        poke_interval=30,
        reset_dag_run=True,
        logical_date="{{ logical_date }}",
        map_index_template="{{ task.trigger_dag_id }}",
        retries=0,
    ).expand_kwargs(ingestion_plan)

    # dbt transformation
    project_config = ProjectConfig(
        dbt_project_path=str(DBT_ROOT_PATH),
    )

    profile_config = ProfileConfig(
        profile_name="nyc_taxi",
        target_name="dev",
        profile_mapping=ClickhouseUserPasswordProfileMapping(
            conn_id="clickhouse_default",
            profile_args={
                "schema": "default",
            },
        ),
    )

    execution_config = ExecutionConfig(
        invocation_mode=InvocationMode.SUBPROCESS,
    )

    load_to_raw_layer = DbtTaskGroup(
        group_id="load_to_raw_layer",
        project_config=project_config,
        profile_config=profile_config,
        execution_config=execution_config,
        render_config=RenderConfig(
            select=[
                "path:models/raw",
            ],
        ),
    )

    load_to_staging_layer = DbtTaskGroup(
        group_id="load_to_staging_layer",
        project_config=project_config,
        profile_config=profile_config,
        execution_config=execution_config,
        render_config=RenderConfig(
            select=[
                "path:models/staging",
            ],
        ),
    )

    load_to_core_layer = DbtTaskGroup(
        group_id="load_to_core_layer",
        project_config=project_config,
        profile_config=profile_config,
        execution_config=execution_config,
        render_config=RenderConfig(
            select=[
                "path:models/core",
            ],
        ),
    )

    load_to_marts_layer = DbtTaskGroup(
        group_id="load_to_marts_layer",
        project_config=project_config,
        profile_config=profile_config,
        execution_config=execution_config,
        render_config=RenderConfig(
            select=[
                "path:models/marts",
            ],
        ),
    )

    (
        ingestion_task
        >> load_to_raw_layer
        >> load_to_staging_layer
        >> load_to_core_layer
        >> load_to_marts_layer
    )


nyc_taxi_pipeline()
