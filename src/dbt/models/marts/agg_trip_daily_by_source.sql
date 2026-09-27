{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        schema='marts',
        alias='agg_trip_daily_by_source',
        engine='MergeTree()',
        partition_by=['source_year', 'source_month'],
        order_by=['source_year', 'source_month', 'service_type', 'pickup_date_id'],
        tags=['serving', 'aggregate', 'daily']
    )
}}

{{ reject_full_refresh() }}

with trips as (
    select *
    from {{ ref('int_trips_conformed') }}
    where source_year = toUInt16({{ var('year') | int }})
      and source_month = toUInt8({{ var('month') | int }})
      and pickup_datetime_is_reported
)

select
    source_year,
    source_month,
    pickup_date_id,
    pickup_date,
    service_type,
    count() as trip_count,
    countIf(passenger_count_is_reported) as passenger_count_recorded_count,
    if(
        countIf(passenger_count_is_reported) = 0,
        cast(null as Nullable(Int64)),
        sumIf(toInt64(passenger_count), passenger_count_is_reported)
    ) as passenger_count_sum,
    countIf(distance_is_valid) as distance_valid_count,
    if(
        countIf(distance_is_valid) = 0,
        cast(null as Nullable(Decimal64(3))),
        sumIf(trip_distance_miles, distance_is_valid)
    ) as distance_sum_miles,
    countIf(duration_is_valid) as duration_valid_count,
    if(
        countIf(duration_is_valid) = 0,
        cast(null as Nullable(Int64)),
        sumIf(trip_duration_seconds, duration_is_valid)
    ) as duration_sum_seconds
from trips
group by
    source_year,
    source_month,
    pickup_date_id,
    pickup_date,
    service_type
