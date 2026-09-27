{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        schema='marts',
        alias='agg_pickup_zone_daily_by_source',
        engine='MergeTree()',
        partition_by=['source_year', 'source_month'],
        order_by=[
            'source_year',
            'source_month',
            'service_type',
            'pickup_date_id',
            'pickup_location_id'
        ],
        tags=['serving', 'aggregate', 'daily', 'zone']
    )
}}

{{ reject_full_refresh() }}

select
    source_year,
    source_month,
    pickup_date_id,
    pickup_date,
    service_type,
    assumeNotNull(pickup_location_id) as pickup_location_id,
    count() as trip_count
from {{ ref('int_trips_conformed') }}
where source_year = toUInt16({{ var('year') | int }})
  and source_month = toUInt8({{ var('month') | int }})
  and pickup_datetime_is_reported
  and pickup_zone_is_reported
  and service_type in ('yellow', 'green', 'fhvhv')
group by
    source_year,
    source_month,
    pickup_date_id,
    pickup_date,
    service_type,
    pickup_location_id
