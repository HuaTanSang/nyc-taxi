{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        schema='marts',
        alias='agg_trip_hourly_by_source',
        engine='MergeTree()',
        partition_by=['source_year', 'source_month'],
        order_by=[
            'source_year',
            'source_month',
            'service_type',
            'pickup_date_id',
            'pickup_hour'
        ],
        settings={'allow_nullable_key': 1},
        tags=['serving', 'aggregate', 'hourly']
    )
}}

{{ reject_full_refresh() }}

select
    source_year,
    source_month,
    pickup_date_id,
    pickup_date,
    pickup_hour,
    service_type,
    count() as trip_count
from {{ ref('int_trips_conformed') }}
where source_year = toUInt16({{ var('year') | int }})
  and source_month = toUInt8({{ var('month') | int }})
  and pickup_datetime_is_reported
group by
    source_year,
    source_month,
    pickup_date_id,
    pickup_date,
    pickup_hour,
    service_type
