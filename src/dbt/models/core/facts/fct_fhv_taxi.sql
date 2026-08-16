{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        schema='core',
        alias='fct_fhv_taxi',
        engine='MergeTree()',
        partition_by=['source_year', 'source_month'],
        order_by=['dispatching_base_number', 'pickup_datetime', 'dropoff_datetime'],
        settings={
            'allow_nullable_key': 1
        },
        tags=['core', 'fact', 'fhv_taxi']
    )
}}

with source as (
    select *
    from {{ ref('stg_fhv_trips') }}
    where source_path is not null
        and source_year = toUInt16({{ var('year') | int }})
        and source_month = toUInt8({{ var('month') | int }})
)

select
    dispatching_base_number,
    affiliated_base_number,

    pickup_datetime,
    dropoff_datetime,
    toYYYYMMDD(pickup_datetime) as pickup_date_id,
    toYYYYMMDD(dropoff_datetime) as dropoff_date_id,
    toInt32OrNull(toString(pickup_location_id)) as pickup_location_id,
    toInt32OrNull(toString(dropoff_location_id)) as dropoff_location_id,

    multiIf(
        sr_flag = 1,
        true,
        sr_flag = 0,
        false,
        cast(null as Nullable(Bool))
    ) as shared_ride_flag,

    dateDiff('second', pickup_datetime, dropoff_datetime) as trip_duration_seconds,
    toUInt16(assumeNotNull(source_year)) as source_year,
    toUInt8(assumeNotNull(source_month)) as source_month,
    source_path, 
    source_file
from source
