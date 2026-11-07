# AGENTS.md

## Project

NYC TLC batch analytics platform for demand, revenue, and operations.

Azure migration in progress: Airflow/Cosmos, dbt/Databricks and Superset images are built from the repository root. See README.md for build and smoke commands.

The user retired on-premises service deployment files. Keep original business DAGs and dbt models as phase 3 migration references. Temporary connection smoke DAG/project files were removed; the current images package dependencies and dbt source, with no active DAGs or manifest. Package real DAGs/dbt/manifest when porting the pipeline. Azure runtime Compose and the full pipeline are pending.

## Accepted Azure portfolio design

- For Azure design, implementation, deployment, or recovery work, read `codex-artifacts/NOTES.md`, `codex-artifacts/docs/azure-platform-design.md`, and the plan, operations, or runtime document linked from NOTES for the work at hand. The design is agreed; implementation and provisioning require authorization for that work. Continue from accepted decisions without restarting the design interview.
- Region: Asia Pacific / Korea Central (`koreacentral`). Initial Linux VM: B2as_v2 (`Standard_B2as_v2`, 2 vCPU / 8 GiB). Verify subscription eligibility, availability, quota, and cost before provisioning; obtain agreement before changing region or size.
- Budget: USD 100 total student credit for the project. Run compute for development/demo sessions and retain data between sessions. Include retained-resource costs in estimates; no automatic fallback to paid billing.
- Host Airflow/Cosmos, Python ingestion, dbt, Superset, and both PostgreSQL metadata databases in Docker Compose on the VM. Flow: TLC → ADLS landing Parquet → Spark Bronze Delta → dbt Silver/Gold → Superset. dbt runs on the VM and sends SQL to the Databricks SQL Warehouse; Unity Catalog governs data access.
- Map staging/intermediate/core to Silver and aggregates/marts to Gold. Preserve existing business logic while adapting the adapter, SQL dialect, physical types, and monthly Delta writes; preserve business timezone and millisecond timestamp semantics.
- The user confirmed the on-premises platform runs reliably; use its existing graph/results as the migration baseline without repeating local qualification. Trigger Airflow manually with `year`, `month`, and `force_reload`; no automatic schedule initially. Demo all four datasets (Yellow, Green, FHV, FHVHV) for source month January 2025, then replay January for all four. Prove no duplication, stable per-service/combined counts and aggregates, and failure recovery. Verify unaffected source-month partitions with a small fixture on existing compute; a full February TLC demo is not required.
- Validate stored sources before reuse. With `force_reload=true`, validate the replacement before replacing the previous valid source. Missing TLC publications fail the run. Source reuse still permits downstream rebuilds. Stop dependent tasks on failure, use bounded retries, and rerun the selected source month. Partial updates across serving tables are accepted; demonstrate results only after all required checks pass.
- Terraform owns Azure infrastructure, Unity Catalog foundations, and SQL Warehouse configuration; Bundles own Spark jobs/code/job compute; dbt owns model relations/tests; Compose owns application services. Give each resource one deployment owner. Bootstrap Azure Blob Terraform state separately and retain it independently of demo teardown.
- Use one Databricks pipeline principal for Airflow job invocation, Spark run-as, and dbt; a separate read-only Superset principal; and a separate deployment OIDC identity. VM managed identity handles ingestion/backup ADLS access; Unity Catalog uses its access connector/storage identity. Prefer OAuth M2M and verify client/token-refresh compatibility; no automatic PAT fallback or extra compute for identity separation.
- Keep runtime secrets and stable application keys in a restricted VM `.env`, outside Git/images, with an encrypted recovery copy outside the VM. No Key Vault initially. Owner-only UI access uses SSH tunnels, loopback application ports, and SSH restricted to the owner's configured IP; portfolio viewers use recordings/screenshots.
- PR checks run offline. After merge to `main`, publish public GHCR Airflow/Superset images tagged by full commit SHA; manual deployment pins image digests using GitHub Actions OIDC and Azure Run Command. Package DAGs, dbt project, and manifest in the Airflow image. Deploy between demos without an active pipeline; keep deployment coordination simple. Live integration is manually triggered.
- Start helper starts the VM and checks services. End helper backs up metadata before deallocation; leave the VM running if a pipeline is active or backup fails. Spark compute ends with its job. The owner manually stops SQL Warehouse, including after pipeline failure; SQL Warehouse auto-stop is 10 idle minutes; manual shutdown still applies.
- Persist metadata on VM disks and back up both databases to ADLS after demos and before migration deployments. Restore the latest successful backup with the matching application keys; image rollback alone does not reverse database migrations. Dashboard migration is deferred to the user. Final teardown requires an explicit request after preserving portfolio evidence.

## Workflow

- Infrastructure work is paused at the reviewed bootstrap plan until the user resumes it. Continue Airflow/application review without provisioning or changing Terraform.

- Terraform learning mode: the user writes Terraform files; guide one step at a time and review their changes. Do not author Terraform files unless the user explicitly changes this preference.

- Read relevant README, Makefile targets, configuration, and code before editing.
- Check `git status` and preserve existing user changes.
- Follow repository conventions and tooling; make focused changes.
- Treat repository configuration as the source of truth for paths, versions, and commands.
- Keep the current architecture unless the task requires otherwise.
- Update documentation when changing setup, configuration, or data contracts.

## Data rules

- Preserve monthly processing with `year`, `month`, and `force_reload`.
- Keep ingestion and reruns idempotent; validate existing objects before skipping them.
- Preserve the original ClickHouse `insert_overwrite` behavior when adapting monthly Delta writes: partition by `source_year`, `source_month`, and distinguish source month from pickup month.
- Use monthly partition rebuilds. Do not use `--full-refresh` on protected models.
- Preserve layer responsibilities: raw → staging → intermediate → core → marts.
- Use dbt `source()` and `ref()`; preserve grain, join cardinality, and NULL/validity semantics.
- Calculate averages from sums and corresponding valid counts.
- Use existing `DateTime64(3)` and `business_timezone` conventions as migration references; preserve equivalent semantics in Databricks.
- Check downstream models and Superset assets when changing schemas or metrics.

## Execution and validation

- Keep heavy processing and network calls outside DAG parsing.
- Preserve retry safety and ingestion/transformation dependencies.
- Filter source-month partitions early and account for VM and Warehouse memory usage.
- Run relevant configured checks. For dbt, compile with explicit monthly vars and inspect `target/compiled/` when debugging.
- For incremental changes, check reruns, empty output, and unaffected partitions.
- Report checks that could not run; compilation alone does not verify data correctness.

## Safety and completion

- Keep secrets and raw/generated data out of commits.
- Run destructive operations or full historical backfills only when explicitly requested.
- Review the diff, then summarize changes, validation, and any required reprocessing.


## IP
When run curl -4 -fsS https://api.ipify.org, the result is 104.28.205.71. You asked me to add /32 behind the results.
