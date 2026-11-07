#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
IMAGE_TAG=${IMAGE_TAG:-azure-local}

docker run --rm --network none -i --entrypoint python \
    "nyc-taxi-dbt:$IMAGE_TAG" - <<'PY'
from pathlib import Path

from dbt.adapters.databricks import DatabricksAdapter
from dbt.cli.main import dbtRunner

assert Path('/usr/app/dbt/dbt_project.yml').is_file()
assert not Path('/usr/app/dbt/smoke').exists()
print('dbt/Databricks imports passed.')
PY

docker run --rm --network none -i --entrypoint python \
    "nyc-taxi-airflow:$IMAGE_TAG" - <<'PY'
from pathlib import Path

from airflow.providers.databricks.operators.databricks import DatabricksSubmitRunOperator
from cosmos import ExecutionConfig
from cosmos.constants import InvocationMode
from cosmos.operators.local import DbtLocalBaseOperator
from dbt.adapters.databricks import DatabricksAdapter

config = ExecutionConfig(invocation_mode=InvocationMode.DBT_RUNNER)
assert config.invocation_mode == InvocationMode.DBT_RUNNER
assert Path('/opt/airflow/dbt/dbt_project.yml').is_file()
assert not any(Path('/opt/airflow/dags').rglob('*.py'))
assert not Path('/opt/airflow/dbt/smoke').exists()
print('Airflow/Cosmos DBT_RUNNER and Databricks imports passed; no active DAGs.')
PY

docker run --rm --network none -i --entrypoint /app/.venv/bin/python \
    "nyc-taxi-superset:$IMAGE_TAG" - < "$ROOT_DIR/src/superset/test_databricks_auth.py"

echo "Offline image smoke checks passed."
