# NYC Taxi Data Platform

Local analytics platform built with Airflow, MinIO, ClickHouse, dbt, and
Superset. Docker Compose projects are orchestrated through the root Makefile.

## Prerequisites

- Docker Engine or Docker Desktop with Compose v2
- At least 6 GiB assigned to Docker
- OpenSSL and curl

## First run

```bash
make configure
make bootstrap
make up
make doctor
make smoke
```

`make configure` creates an ignored root `.env` from `.env.example` and
generates missing local-development secrets. Run it for the initial setup and
again only when adding or rotating configuration; it never replaces an existing
secret.

Useful commands:

```bash
make status
make logs STACK=airflow SERVICE=airflow-scheduler
make down
```

`make down` stops containers without deleting named volumes. To run a second
clone, use a distinct project prefix and host ports in that clone's `.env`:

```bash
make up PROJECT_PREFIX=nyc_taxi_second
```

The service-level `.env` files are deprecated. All Compose projects now receive
configuration from the root `.env` and explicitly expose only the variables
their containers need.

## Local endpoints

| Service | Default URL | Login |
| --- | --- | --- |
| MinIO API | `http://localhost:9000` | `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY` |
| MinIO console | `http://localhost:9001` | `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY` |
| ClickHouse HTTP | `http://localhost:8123` | `CLICKHOUSE_USER` / `CLICKHOUSE_PASSWORD` |
| Airflow | `http://localhost:8080` | `AIRFLOW_ADMIN_USERNAME` / `AIRFLOW_ADMIN_PASSWORD` |
| dbt docs | `http://localhost:8050` | none |
| Superset | `http://localhost:8088` | `SUPERSET_ADMIN_USERNAME` / `SUPERSET_ADMIN_PASSWORD` |

All credentials are stored in the ignored root `.env`. Trigger the parent taxi
pipeline from the Airflow UI after the platform passes `make doctor` and
`make smoke`. `make doctor` checks the current Docker network and container
states; `make smoke` verifies the service endpoints and runs `dbt parse`.

## Persistence and maintenance

Named volumes preserve MinIO objects, ClickHouse data, Airflow metadata and
logs, and Superset metadata across `make down`. Rebuild an image after changing
its Dockerfile or Python requirements with `make build`, then run `make up`.

To rotate an application secret, first run `make down`, replace its value in
`.env` (or set it to `__GENERATE__`), and rerun `make configure`. Database and
storage credentials also live inside persistent service state; rotate those in
the service itself or recreate the corresponding local-development volume.

A full data reset is intentionally not a Make target. After `make down`, inspect
the exact project volumes with:

```bash
docker volume ls --filter label=com.docker.compose.project=nyc_taxi_airflow
```

Remove only the named volumes you intend to discard with `docker volume rm`.
This is destructive and cannot be undone.

If `make check-tools` cannot reach Docker from WSL, enable Docker Desktop's WSL
integration for the distribution. If a service does not become healthy, use
`make status` and `make logs STACK=<stack> [SERVICE=<service>]` before retrying
the idempotent bootstrap.
