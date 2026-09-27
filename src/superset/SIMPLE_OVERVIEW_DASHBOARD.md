# NYC Taxi Overview dashboard

This guide creates one intentionally small Superset dashboard over the dbt
serving marts. Labels and chart titles are in English. Financial measures are
out of scope because standard FHV trip records do not contain comparable fare
data.

## 1. Create datasets

In **Data > Datasets**, add these ClickHouse tables from the `marts` schema:

1. `mart_trip_daily`
2. `mart_trip_hourly`
3. `mart_pickup_zone_daily`
4. `mart_data_quality_monthly`

Mark `pickup_date` as temporal on the first three datasets and `source_period`
as temporal on the quality dataset. Do not expose any `agg_*_by_source` table
to dashboard authors; those tables contain operational source-partition grain.

Create the following metrics on `mart_trip_daily`:

| Metric name | SQL expression | Format |
| --- | --- | --- |
| `Total Trips` | `SUM(trip_count)` | `,.0f` |
| `Average Daily Trips` | `SUM(trip_count) / NULLIF(COUNT(DISTINCT pickup_date), 0)` | `,.0f` |
| `Average Duration (min)` | `SUM(duration_sum_seconds) / NULLIF(SUM(duration_valid_count), 0) / 60.0` | `,.1f` |
| `Average Distance (mi)` | `SUM(distance_sum_miles) / NULLIF(SUM(distance_valid_count), 0)` | `,.2f` |

Create `Total Trips = SUM(trip_count)` on the hourly and pickup-zone datasets.
Never use `AVG` over a daily average; the marts intentionally provide additive
numerators and denominators for correct weighted rollups.

## 2. Create charts

Use these chart definitions and add them to a dashboard named
**NYC Taxi Overview**:

| Title | Dataset | Visualization | Configuration |
| --- | --- | --- | --- |
| Total Trips | `mart_trip_daily` | Big Number | Metric `Total Trips` |
| Average Daily Trips | `mart_trip_daily` | Big Number | Metric `Average Daily Trips` |
| Average Trip Duration | `mart_trip_daily` | Big Number | Metric `Average Duration (min)`; subtitle `Calculated from pickup and drop-off timestamps` |
| Average Trip Distance | `mart_trip_daily` | Big Number | Metric `Average Distance (mi)`; subtitle `Reported services only; FHV is not applicable` |
| Daily Trips by Service | `mart_trip_daily` | Time-series Line | Time `pickup_date`; metric `Total Trips`; series `service_type` |
| Trips by Service | `mart_trip_daily` | Bar Chart | X `service_type`; metric `Total Trips`; sort descending |
| Trips by Pickup Hour and Day | `mart_trip_hourly` | Heatmap | X `pickup_hour`; Y `pickup_day_name`; metric `Total Trips`; sort day by `pickup_day_of_week` |
| Pickup Zone Demand | `mart_pickup_zone_daily` | deck.gl Scatterplot | Longitude `pickup_longitude`; latitude `pickup_latitude`; size and color `Total Trips`; tooltip zone, borough, service, trips |
| Source Data Coverage | `mart_data_quality_monthly` | Pivot Table v2 | Rows `service_type`; columns `metric_name`; metric `MAX(coverage_percent)`; percentage format `,.1f` |

The map mart already excludes FHV and unknown/outside locations. Add this chart
subtitle: **Yellow, Green, and High Volume FHV only; standard FHV is excluded
because pickup-zone coverage is insufficient.** If the global service filter is
set to FHV only, an empty map is the expected and honest result.

For the coverage pivot, filter `metric_name` to `pickup_zone`, `duration`,
`distance`, and `passenger_count`. A blank cell means `not_applicable`, not 0%
coverage. Keep `coverage_status` and `note` available in the dataset details for
investigation.

## 3. Dashboard layout and filters

Place the four KPI cards in the first row, the daily line chart across the
second row, service bar and hourly heatmap in the third row, the map in the
fourth row, and the compact coverage panel last.

Add native filters:

- **Date Range**, scoped to the four mobility charts and KPI cards using
  `pickup_date`.
- **Service Type**, scoped to all mobility charts. The quality panel uses its
  own `service_type` field and may be included in the same filter mapping.

Use the full available date range by default. Show each service with a stable
color across charts: Yellow `#F2C80F`, Green `#2CA02C`, FHV `#7F7F7F`, and
FHVHV `#1F77B4`.

## Interpretation notes

- TLC publishes provider-submitted records and does not guarantee complete or
  perfectly accurate data.
- `Average Distance (mi)` excludes services/rows without valid reported
  distance through its denominator; it does not treat missing values as zero.
- FHV `SR_Flag` null means non-shared according to the official dictionary.
- Taxi tips are not shown: cash tips are absent from the source records.
- Coverage is measured for every ingested source month; the January 2025
  findings are a baseline, not a permanent assumption.
