{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        schema='marts',
        alias='mart_trip_daily',
        engine='MergeTree()',
        order_by=[
            'source_year',
            'source_month',
            'service_type',
            'ifNull(pickup_date_id, 0)'
        ],
        partition_by=['source_year', 'source_month'],
        tags=['serving', 'mart', 'daily']
    )
}}

with trips as (
    select *
    from {{ ref('int_trips_unioned') }}
    where source_year = toUInt16({{ var('year') | int }})
    and source_month = toUInt8({{ var('month') | int }})
)

select
    source_year,
    source_month,
    pickup_date_id,
    toDate(pickup_datetime) as pickup_date,
    service_type,

    count() as trip_count,
    count(passenger_count) as passenger_count_recorded,
    sum(ifNull(toInt64(passenger_count), 0)) as total_passengers,
    count(trip_distance_miles) as distance_recorded_count,
    sum(ifNull(trip_distance_miles, toDecimal64(0, 3))) as total_distance_miles,
    count(trip_duration_seconds) as duration_recorded_count,
    sum(ifNull(trip_duration_seconds, 0)) as total_trip_duration_seconds,
    count(passenger_charge_amount) as passenger_charge_recorded_count,
    sum(ifNull(passenger_charge_amount, toDecimal64(0, 2))) as total_passenger_charge_amount,

    avgOrNull(toFloat64(passenger_count)) as average_passengers,
    avgOrNull(toFloat64(trip_distance_miles)) as average_trip_distance_miles,
    avgOrNull(toFloat64(trip_duration_seconds)) as average_trip_duration_seconds,
    avgOrNull(toFloat64(passenger_charge_amount)) as average_passenger_charge_amount,
    if(
        sumIf(
            toFloat64(trip_distance_miles),
            trip_distance_miles > 0 and passenger_charge_amount is not null
        ) = 0,
        cast(null as Nullable(Float64)),
        sumIf(
            toFloat64(passenger_charge_amount),
            trip_distance_miles > 0 and passenger_charge_amount is not null
        ) / sumIf(
            toFloat64(trip_distance_miles),
            trip_distance_miles > 0 and passenger_charge_amount is not null
        )
    ) as average_passenger_charge_per_mile
from trips
group by
    source_year,
    source_month,
    pickup_date_id,
    pickup_date,
    service_type
