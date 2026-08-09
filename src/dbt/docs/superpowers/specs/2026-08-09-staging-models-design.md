# NYC Taxi staging models design

## Goal

Create a consistent staging layer for the five existing raw models:

- `raw_yellow_taxi`
- `raw_green_taxi`
- `raw_fhv_taxi`
- `raw_fhvhv_taxi`
- `raw_location`

The staging layer provides stable, typed, documented inputs for the future core layer while preserving source-level detail.

## Chosen approach

Use one staging view for each raw model:

- `stg_yellow_trips`
- `stg_green_trips`
- `stg_fhv_trips`
- `stg_fhvhv_trips`
- `stg_locations`

Each model reads its raw model through `ref()`. It explicitly selects and renames columns to `snake_case`, applies ClickHouse-safe type conversion where necessary, converts blank text values to `NULL`, and retains source metadata.

This approach is preferred over pass-through `select *` because it creates a stable contract for downstream models. It is also preferred over combining all trip types in staging because Yellow, Green, FHV, and FHVHV have different grains and fields; conformance belongs in a later intermediate or core model.

## Model behavior

- Materialization: `view`.
- Grain: exactly one row per input record; staging does not change row count intentionally.
- Transformations: column selection, renaming, type normalization, and blank-string normalization only.
- Excluded logic: filtering, deduplication, joins, surrogate keys, calculated business measures, and aggregated KPIs.
- Lineage: every model uses `ref()` to its corresponding raw model.

Trip models retain `source_path`, `source_file`, `source_year`, and `source_month`. Location retains `source_path` and `source_file`, because its raw source is not partitioned by year and month.

## Data contracts and error behavior

The SQL will use explicit ClickHouse types suitable for the TLC 2025 schemas. Nullable source fields remain nullable. Safe conversions will be used for source values that can be blank or inconsistent so that a malformed optional value becomes `NULL` instead of failing the whole model. Required metadata is not silently fabricated.

The models will not hide malformed rows with filters. Data quality issues remain visible for tests and downstream handling.

## Documentation and tests

A staging YAML file will document every model and its selected columns.

Tests will be intentionally conservative:

- `stg_locations.location_id`: `not_null` and `unique`.
- Source metadata: `not_null` where the raw model always supplies it.
- Trip business columns: documented but not assigned broad `not_null` or uniqueness tests unless guaranteed by the TLC source.

This avoids false failures on known real-world nulls in NYC Taxi trip data.

## File changes

- Replace the incomplete and incorrectly configured `stg_yellow_taxi.sql` with `stg_yellow_trips.sql`.
- Add four missing staging SQL models.
- Add one staging model YAML file for documentation and tests.
- Do not modify raw models, macros, profiles, or downstream layers unless a compile error proves a minimal compatibility fix is required.

## Verification

Run the strongest checks available in the supplied environment, in this order:

1. `dbt deps` if packages are unavailable.
2. `dbt parse` to validate Jinja, YAML, model references, and project structure.
3. `dbt compile --select path:models/staging` when a usable ClickHouse profile/connection is available.

If ClickHouse or MinIO is unavailable, report that integration compilation/execution was not possible rather than treating it as a model failure.

## Success criteria

- Five staging views exist with the approved names.
- Each staging model references exactly one matching raw model.
- No staging model performs business aggregation or changes the intended grain.
- The Yellow model no longer carries the FHV alias or tags.
- YAML parses and dbt can parse the project.
- The returned archive contains the original project plus the approved staging changes.
