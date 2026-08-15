{{
    config(
        materialized='incremental',        
        unique_key=['source_year', 'source_month', 'pickup_date_id', 'service_type', 'pickup_location_id'],
        schema='marts',
        alias='mart_zone_daily',
        engine='MergeTree()',
        order_by=[
            'source_year',
            'source_month',
            'service_type',
            'ifNull(pickup_date_id, 0)',
            'ifNull(pickup_location_id, 0)' 
        ],
        partition_by=['source_year', 'source_month'],
        tags=['serving', 'mart', 'daily', 'zone']
    )
}}

with trips as (
    select *
    from {{ ref('int_trips_unioned') }}

    {% if is_incremental() %}
    where source_year = toUInt16({{ var('year') | int }})
        and source_month = toUInt8({{ var('month') | int }})
    {% endif %}
),

aggregated as (
    select
        source_year,
        source_month,
        pickup_date_id,
        toDate(pickup_datetime) as pickup_date,
        service_type,
        pickup_location_id,
        count() as trip_count,
        count(trip_distance_miles) as distance_recorded_count,
        sum(ifNull(trip_distance_miles, toDecimal64(0, 3))) as total_distance_miles,
        count(trip_duration_seconds) as duration_recorded_count,
        avgOrNull(toFloat64(trip_duration_seconds)) as average_trip_duration_seconds,
        count(passenger_charge_amount) as passenger_charge_recorded_count,
        sum(ifNull(passenger_charge_amount, toDecimal64(0, 2))) as total_passenger_charge_amount,
        avgOrNull(toFloat64(passenger_charge_amount)) as average_passenger_charge_amount
    from trips
    group by
        source_year,
        source_month,
        pickup_date_id,
        pickup_date,
        service_type,
        pickup_location_id
)

select
    aggregated.source_year,
    aggregated.source_month,
    aggregated.pickup_date_id,
    aggregated.pickup_date,
    aggregated.service_type,
    aggregated.pickup_location_id,
    zones.borough as pickup_borough,
    zones.zone as pickup_zone,
    zones.service_zone as pickup_service_zone,
    aggregated.trip_count,
    aggregated.distance_recorded_count,
    aggregated.total_distance_miles,
    aggregated.duration_recorded_count,
    aggregated.average_trip_duration_seconds,
    aggregated.passenger_charge_recorded_count,
    aggregated.total_passenger_charge_amount,
    aggregated.average_passenger_charge_amount
from aggregated
left join {{ ref('dim_taxi_zone') }} as zones
    on aggregated.pickup_location_id = zones.location_id
