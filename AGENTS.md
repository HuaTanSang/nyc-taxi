# AGENTS.md

## Project

NYC TLC batch analytics platform for demand, revenue, and operations.

Stack: Python, Airflow + Cosmos, MinIO, dbt + ClickHouse, Superset, Docker Compose, Makefile.

Flow: NYC TLC → Python ingestion → MinIO → dbt/ClickHouse → Superset.

## Workflow

- Read relevant README, Makefile targets, configuration, and code before editing.
- Check `git status` and preserve existing user changes.
- Follow repository conventions and tooling; make focused changes.
- Treat repository configuration as the source of truth for paths, versions, and commands.
- Keep the current architecture unless the task requires otherwise.
- Update documentation when changing setup, configuration, or data contracts.

## Data rules

- Preserve monthly processing with `year`, `month`, and `force_reload`.
- Keep ingestion and reruns idempotent; validate existing objects before skipping them.
- Preserve `insert_overwrite` partitioning by `source_year`, `source_month`; distinguish source month from pickup month.
- Use monthly partition rebuilds. Do not use `--full-refresh` on protected models.
- Preserve layer responsibilities: raw → staging → intermediate → core → marts.
- Use dbt `source()` and `ref()`; preserve grain, join cardinality, and NULL/validity semantics.
- Calculate averages from sums and corresponding valid counts.
- Follow existing `DateTime64(3)` and `business_timezone` conventions.
- Check downstream models and Superset assets when changing schemas or metrics.

## Execution and validation

- Keep heavy processing and network calls outside DAG parsing.
- Preserve retry safety and ingestion/transformation dependencies.
- Account for ClickHouse memory usage; filter partitions early.
- Run relevant configured checks. For dbt, compile with explicit monthly vars and inspect `target/compiled/` when debugging.
- For incremental changes, check reruns, empty output, and unaffected partitions.
- Report checks that could not run; compilation alone does not verify data correctness.

## Safety and completion

- Keep secrets and raw/generated data out of commits.
- Run destructive operations or full historical backfills only when explicitly requested.
- Review the diff, then summarize changes, validation, and any required reprocessing.