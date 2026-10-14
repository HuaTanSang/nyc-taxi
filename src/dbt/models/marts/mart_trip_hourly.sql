{{
    config(
        materialized='view',
        schema='marts',
        alias='mart_trip_hourly',
        tags=['serving', 'mart', 'hourly']
    )
}}

with reaggregated as (
    select
        pickup_date_id,
        pickup_date,
        pickup_hour,
        service_type,
        sum(trip_count) as trip_count
    from {{ ref('agg_trip_hourly_by_source') }}
    group by pickup_date_id, pickup_date, pickup_hour, service_type
)

select
    reaggregated.pickup_date_id,
    reaggregated.pickup_date,
    dates.day_of_week as pickup_day_of_week,
    dates.day_name as pickup_day_name,
    dates.is_weekend as pickup_is_weekend,
    reaggregated.pickup_hour,
    reaggregated.service_type,
    reaggregated.trip_count
from reaggregated
left join {{ ref('dim_date') }} as dates
    on reaggregated.pickup_date_id = dates.date_id
