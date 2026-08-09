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

Each fact remains at one row per source record. Deterministic `trip_sk` values
are generated from the service type, source path, and a stable row ordinal
within the source file. The row ordinal is retained as `source_row_number` for
lineage.

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

`int_trips_unioned` exposes only measures that can be compared safely across
service types: event time, zone, passenger count, distance, duration, passenger
charge, and tip. Missing source measures remain `NULL`; they are never replaced
with zero in this contract.

For FHVHV, `passenger_charge_amount` is calculated as the reported passenger
fare plus tolls, BCF, sales tax, congestion surcharges, airport fee, CBD fee,
and tips. FHV has no monetary or distance measures in the TLC source and keeps
those fields null.

## Serving marts

The existing `serving` schema is the physical mart layer. It contains:

- `mart_trip_daily`: daily KPIs by service type.
- `mart_zone_daily`: daily pickup demand and measures by service type and zone.
- `mart_street_taxi_payment_daily`: Yellow/Green fare and payment analysis.
- `mart_fhvhv_provider_daily`: FHVHV provider, wait-time, shared-ride, WAV,
  passenger-charge, and driver-pay KPIs.

All marts use explicit grains and retain `source_year` and `source_month` so
monthly reruns can replace only the affected source partition. Average and rate
KPIs protect against zero denominators. Null source coverage remains visible
through recorded-value counts in the common marts.

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
