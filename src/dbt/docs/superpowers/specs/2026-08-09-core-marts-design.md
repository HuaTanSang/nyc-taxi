# NYC Taxi core and serving marts design

## Goal

Build the dimensional core described by the approved DBML and add a small
serving layer that Superset can query directly. The implementation consumes the
existing 2025 staging contracts without changing their row-level grain.

## Considered approaches

1. One wide trip fact for every service type. This is simple for BI, but it
   conflates measures whose meanings differ across Yellow, Green, FHV, and
   FHVHV and leaves many columns empty.
2. Four isolated facts and four entirely separate sets of marts. This preserves
   semantics, but duplicates common date and zone aggregation logic.
3. Four atomic facts, conformed dimensions, one narrow unioned intermediate
   view, and a mix of common and service-specific marts. This preserves each
   source grain while keeping repeated serving logic in one place.

Approach 3 is selected.

## Core layer

The core schema contains these conformed dimensions:

- `dim_date`
- `dim_vendor`
- `dim_rate_code`
- `dim_payment_type`
- `dim_taxi_zone`
- `dim_trip_type`
- `dim_hvfhv_provider`
- `dim_fhv_base`

It also contains one atomic fact per TLC dataset:

- `fct_yellow_taxi`
- `fct_green_taxi`
- `fct_fhv_taxi`
- `fct_fhvhv_taxi`

Each fact remains at one row per source record. The TLC Parquet contract does
not expose a stable row ordinal, so the implementation deliberately does not
fabricate a trip key. Source path, file, ETag, and `source_file_id` are retained
for file-level lineage, and reconciliation tests protect row counts.

The DBML relationships from event timestamps directly to `dim_date.date_id`
are type-incompatible. The implementation therefore retains every event
timestamp and adds matching integer role-playing keys such as
`pickup_date_id`, `dropoff_date_id`, `request_date_id`, and
`on_scene_date_id`.

Fact tables use ClickHouse `MergeTree` incremental materialization with
`insert_overwrite`, partitioned by `source_year` and `source_month`. Every raw
model exposes one monthly object selected by dbt variables, so a rerun replaces
that source partition without duplicating trips and a later month does not
discard previously loaded months.

Static TLC code dimensions are defined in SQL. `dim_taxi_zone` is sourced from
`stg_locations`. `dim_fhv_base` is an inferred accumulating dimension because
the project has no TLC base-master source; descriptive base attributes remain
nullable rather than being fabricated.

`dim_date` spans configurable bounds and includes common US calendar holidays.
The default range is 2009-01-01 through 2030-12-31.

## Intermediate contract

`int_trips_conformed` exposes only mobility measures that can be compared safely
across service types: event time, zone, passenger count, distance, and calculated
duration. Applicability, reporting, and validity flags distinguish structural
source gaps from missing values. Missing measures remain `NULL`; they are never
replaced with zero. FHV `SR_Flag` is the only source null normalized to false,
because the official data dictionary defines null as a non-shared ride.

## Serving marts

The `marts` schema separates physical source-partition aggregates from public
serving views. It contains:

- `agg_trip_daily_by_source`, `agg_trip_hourly_by_source`, and
  `agg_pickup_zone_daily_by_source`: monthly replaceable additive aggregates.
- `mart_trip_daily`: daily mobility KPIs by service type.
- `mart_trip_hourly`: pickup-hour patterns by service type.
- `mart_pickup_zone_daily`: mappable pickup-zone demand for Yellow, Green, and
  FHVHV; FHV is excluded because pickup-zone coverage is insufficient.
- `mart_data_quality_monthly`: long-form coverage and anomaly metrics.

Public marts re-aggregate across source partitions at the event-date grain.
They expose sums and denominators instead of precomputed averages so Superset
can roll up days correctly. Structural source gaps remain null and are labelled
`not_applicable` in the quality mart.

## Data quality and documentation

Schema YAML documents models and business columns. Tests cover primary keys,
required lineage fields, accepted static codes, dimension relationships, and
the unique grain of each mart. Potentially dirty TLC foreign keys use warning
severity so anomalous source records remain observable without blocking the
entire monthly pipeline.

No tests assert that monetary values or durations are non-negative because TLC
data can contain corrections and source anomalies; such validity filtering
belongs in a separately approved quality policy.

## Operational behavior

The intended monthly command selects the current raw partition and all
downstream models, for example:

```bash
dbt build --select +path:models/core path:models/intermediate+ path:models/serving+ \
  --vars '{year: 2025, month: 1}'
```

Run months sequentially for the initial 2025 backfill. Avoid an isolated
`--full-refresh` of a fact with only one monthly raw object selected, because a
full refresh intentionally reconstructs the table from the selected month.

## Success criteria

- All DBML dimensions and facts are represented.
- Date relationships use integer date keys while original timestamps remain.
- Monthly reruns are idempotent at the source partition level.
- Core facts preserve source record grain and lineage.
- Serving marts have documented, tested grains and contain no divide-by-zero
  calculations.
- `dbt parse` succeeds, and compilation succeeds when ClickHouse and MinIO are
  available.
