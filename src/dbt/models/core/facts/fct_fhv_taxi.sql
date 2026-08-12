{{
    config(
        materialized='incremental',
        unique_key='trip_sk',
        schema='core',
        alias='fct_fhv_taxi',
        engine='MergeTree()',
        order_by=['source_year', 'source_month', 'trip_sk'],
        partition_by=['source_year', 'source_month'],
        tags=['core', 'fact', 'fhv_taxi']
    )
}}

with source as (
    select *
    from {{ ref('stg_fhv_trips') }}
    where source_path is not null
        and source_year = toUInt16({{ var('year') | int }})
        and source_month = toUInt8({{ var('month') | int }})
),

fingerprinted as (
    select
        *,
        {{ record_fingerprint([
            'dispatching_base_num',
            'pickup_datetime',
            'dropoff_datetime',
            'pickup_location_id',
            'dropoff_location_id',
            'sr_flag',
            'affiliated_base_number'
        ]) }} as record_fingerprint
    from source
),

numbered as (
    select
        *,
        row_number() over (
            partition by source_path
            order by record_fingerprint
        ) as source_row_number
    from fingerprinted
)

select
    {{ stable_trip_key('fhv', 'source_path', 'source_row_number') }} as trip_sk,

    dispatching_base_num as dispatching_base_number,
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

    assumeNotNull(source_path) as source_file_id,
    source_row_number,
    toUInt16(assumeNotNull(source_year)) as source_year,
    toUInt8(assumeNotNull(source_month)) as source_month
from numbered
