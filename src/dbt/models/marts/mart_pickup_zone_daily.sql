{{
    config(
        materialized='view',
        schema='marts',
        alias='mart_pickup_zone_daily',
        tags=['serving', 'mart', 'daily', 'zone']
    )
}}

with reaggregated as (
    select
        pickup_date_id,
        pickup_date,
        service_type,
        pickup_location_id,
        sum(trip_count) as trip_count
    from {{ ref('agg_pickup_zone_daily_by_source') }}
    group by pickup_date_id, pickup_date, service_type, pickup_location_id
)

select
    reaggregated.pickup_date_id,
    reaggregated.pickup_date,
    reaggregated.service_type,
    reaggregated.pickup_location_id,
    zones.borough as pickup_borough,
    zones.zone as pickup_zone,
    zones.service_zone as pickup_service_zone,
    zones.latitude as pickup_latitude,
    zones.longitude as pickup_longitude,
    reaggregated.trip_count
from reaggregated
inner join {{ ref('dim_taxi_zone') }} as zones
    on reaggregated.pickup_location_id = zones.location_id
where zones.latitude is not null
  and zones.longitude is not null
