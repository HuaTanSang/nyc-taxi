# NYC Taxi Data Platform

Azure migration of the NYC TLC analytics platform:
TLC → ADLS landing → Spark Bronze → dbt Silver/Gold → Superset.
Airflow/Cosmos, dbt, Superset and two PostgreSQL metadata databases will run on
an Azure VM; Databricks executes Spark and SQL.

The old on-premises Compose projects, MinIO/ClickHouse services and ClickHouse
Superset bootstrap have been retired. Existing containers, volumes and local
`.env` files are untouched by this repository change.

## Build and check images

Requires Docker Engine/Desktop. Run from the repository root:

```bash
make build
make smoke
```

Build one image with `make build-airflow`, `make build-dbt` or
`make build-superset`. Override the local tag with `IMAGE_TAG=<tag>` on both
build and smoke commands. All Dockerfiles use the repository root as context;
`.dockerignore` allows only application build inputs: Airflow requirements and
the dbt project, and Superset requirements/configuration/OAuth code.
Python unit tests, development scripts, documentation, infrastructure, local
credentials/data and generated artifacts are excluded. Keep tests and tooling in
Git for release validation; add future application source paths to the allowlist
when their Dockerfiles need them. dbt SQL data tests remain in the images because
they validate the demo data.

| Image | Dockerfile | Contents |
| --- | --- | --- |
| `nyc-taxi-airflow` | [Airflow](src/airflow/dockerfile) | Airflow 3.2.2/Python 3.12, Cosmos, Databricks provider, Azure SDKs and dbt source; no active DAGs yet |
| `nyc-taxi-dbt` | [dbt](src/dbt/dockerfile) | Python 3.12, dbt-core 1.11.12, dbt-databricks 1.13.0; CLI tool, no permanent service |
| `nyc-taxi-superset` | [Superset](src/superset/dockerfile) | Superset 6.0.0, PostgreSQL driver and Databricks SQLAlchemy 1.0.5 with OAuth M2M |

`make smoke` runs temporary containers with networking disabled. It imports
Airflow/Cosmos `DBT_RUNNER`, dbt and the Databricks integrations, checks dbt
source packaging and the empty active DAG directory, and tests Superset's OAuth hook. It uses no runtime
credentials and does not initialize metadata databases or call Azure.
The Superset unit test is passed from the host checkout over stdin; it is not
copied into the image. The temporary connection smoke DAG/project and offline dbt target have been
removed. These checks do not parse/compile the business graph, build a manifest
or prove connectivity to Databricks.

## Runtime configuration

Use [.env.example](.env.example) as the Azure configuration template. Keep the
runtime `.env` outside images/Git, restrict its permissions and keep an encrypted
recovery copy outside the VM. Preserve existing application keys when restoring
metadata. The template is not usable until its placeholders are supplied.

Airflow/dbt use the pipeline principal (`DATABRICKS_CLIENT_ID` and
`DBT_ENV_SECRET_DATABRICKS_CLIENT_SECRET`). Superset uses the separate reader
principal (`DATABRICKS_SUPERSET_CLIENT_ID` / `_CLIENT_SECRET`). Both use
`DATABRICKS_HOST`; dbt additionally uses the Warehouse HTTP path, catalog and
schema. Terraform must create the schema and grant access first.

The dbt image defaults to `/usr/app/dbt`. Supply the actual target schema in
`DATABRICKS_SCHEMA`; the image contains the original business project as migration
source. Its ClickHouse SQL is not yet compatible with the Databricks profile.

When Superset is deployed, use a database URI without credentials:

```text
databricks://<workspace-host>?http_path=/sql/1.0/warehouses/<id>&catalog=<catalog>&schema=<schema>
```

The configuration hook supplies the reader's OAuth credentials provider. Never
put a PAT or client secret in the URI. Live login, token renewal, reader grants
and denied writes still need integration checks.

## Migration status

Terraform will use local state on the owner's machine. The remote-state bootstrap
stack has been removed; keep local state and backups outside Git/images, with an
encrypted recovery copy outside the machine. Application infrastructure is not
yet implemented. These images currently prepare dependencies and source only. Azure Compose/bootstrap, provisioning,
metadata backup/restore and deployment are still phase 2 work; there is no
`make up` or automatic cloud deployment yet. UI access will use loopback ports
and SSH tunnels on the VM.

Business SQL under `src/dbt/models`, macros and tests, and the original DAGs
under `src/airflow/dags` remain as migration reference. They still target the
old platform and are not an operational Azure pipeline. No DAGs or manifest
are currently installed/generated in the Airflow image. At phase 3, port the
full graph and package the actual DAGs/dbt/manifest together before running
January 2025 for Yellow, Green, FHV and FHVHV, then replaying that source month.

Dashboard metrics and chart definitions remain in the [business reference](src/superset/SIMPLE_OVERVIEW_DASHBOARD.md).

Reference CSV generation remains in `scripts/generate_taxi_zone_centroids.py`.
Keep the existing local reference CSV pair for Azure bootstrap; ADLS publication
and validation come with ingestion work.
