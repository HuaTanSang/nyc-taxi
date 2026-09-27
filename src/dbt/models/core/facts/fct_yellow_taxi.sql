{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        schema='core',
        alias='fct_yellow_taxi',
        engine='MergeTree()',
        partition_by=['source_year', 'source_month'],
        order_by=['vendor_id', 'pickup_datetime', 'dropoff_datetime'],
        settings={
            'allow_nullable_key': 1
        },
        tags=['core', 'fact', 'yellow_taxi']
    )
}}

{{ reject_full_refresh() }}

with source as (
    select *
    from {{ ref('stg_yellow_trips') }}
    where source_path is not null
        and source_year = toUInt16({{ var('year') | int }})
        and source_month = toUInt8({{ var('month') | int }})
)


select
    vendor_id,
    rate_code_id,
    payment_type_id,
    payment_type_id = 0 as is_flex_fare_trip,

    pickup_datetime,
    dropoff_datetime,
    toYYYYMMDD(pickup_datetime) as pickup_date_id,
    toYYYYMMDD(dropoff_datetime) as dropoff_date_id,
    pickup_location_id,
    dropoff_location_id,

    trip_distance_miles,
    passenger_count,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    congestion_surcharge,
    cbd_congestion_fee,
    airport_fee,
    total_amount,

    dateDiff('second', pickup_datetime, dropoff_datetime) as trip_duration_seconds,
    toUInt16(assumeNotNull(source_year)) as source_year,
    toUInt8(assumeNotNull(source_month)) as source_month,
    source_path,
    source_file,
    source_etag,
    source_file_id
from source
