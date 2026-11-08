# AGENTS.md

NYC TLC batch analytics for demand, revenue, and operations; migrating to Azure.

## Context and authorization

- Read [README.md](README.md) for build/smoke commands and packaging status. Keep original business DAGs/dbt models as migration references; on-premises deployment files are retired. Images currently contain dependencies/dbt source, with no active DAGs or manifest; Azure Compose/full pipeline are pending.
- For Azure design, implementation, deployment, or recovery, first read [NOTES.md](codex-artifacts/NOTES.md), [accepted design](codex-artifacts/docs/azure-platform-design.md), and the relevant plan, operations, or runtime document linked from NOTES. Follow these decisions without restarting the design interview; they do not authorize implementation/provisioning.
- Infrastructure is paused at the reviewed bootstrap plan until the user resumes it. Continue application review without provisioning or changing Terraform. In Terraform learning mode, the user writes files; guide/review one step at a time unless explicitly asked to change this preference.
- Azure guardrails: Korea Central, `Standard_B2as_v2`, USD 100 total student credit, no automatic paid fallback. Verify eligibility, capacity, quota and costs (including retained resources) before provisioning; obtain agreement before changing region/size.
- Owner-reported SSH allowlist: `104.28.205.71/32`; confirm the current owner IP before provisioning/access changes.

## Workflow and safety

- Check `git status`; preserve user changes. Read relevant README, Makefile targets, configuration and code before editing. Repository configuration defines paths, versions and commands.
- Make focused changes using existing conventions and architecture. Update docs when setup, configuration or data contracts change.
- Keep secrets and raw/generated data out of commits and images. Destructive operations, historical backfills and final teardown require explicit requests.

## Data and execution

- Preserve manual monthly processing with `year`, `month`, `force_reload`; use the reliable on-premises graph/results as migration baseline.
- Keep ingestion/reruns idempotent. Validate stored objects before reuse; validate replacement sources before replacing good ones with `force_reload=true`. Missing TLC publications fail the run. Source reuse still permits downstream rebuilds.
- Rebuild only selected `source_year`/`source_month` partitions, preserving ClickHouse `insert_overwrite` semantics; distinguish source month from pickup month. No `--full-refresh` on protected models.
- Preserve raw → staging → intermediate → core → marts responsibilities; staging/intermediate/core map to Silver, aggregates/marts to Gold. Use dbt `source()`/`ref()`; preserve grain, join cardinality and NULL/validity semantics. Calculate averages from sums and corresponding valid counts.
- Preserve `business_timezone` and millisecond timestamp semantics equivalent to `DateTime64(3)`. Check downstream models and Superset assets when schemas/metrics change.
- Keep network/heavy processing outside DAG parsing; filter source-month partitions early and account for VM/Warehouse memory. Preserve ingestion/transformation dependencies, bounded retries and retry safety; failures stop dependent tasks, with recovery by rerunning the selected month.

## Validation and completion

- Run relevant configured checks. For dbt, compile with explicit monthly vars; inspect `target/compiled/` when debugging. Compilation alone does not prove data correctness.
- For incremental changes, check reruns, empty output and unaffected partitions. Azure demo/replay acceptance criteria are in the plan linked from NOTES; demonstrate results only after all required checks pass.
- Review the diff; report changes, checks run/skipped and required reprocessing.
