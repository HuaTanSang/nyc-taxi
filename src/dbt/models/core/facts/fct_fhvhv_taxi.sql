{{
    config(
        materialized='incremental',
        unique_key='trip_sk',
        schema='core',
        alias='fct_fhvhv_taxi',
        engine='MergeTree()',
        order_by=['source_year', 'source_month', 'trip_sk'],
        partition_by=['source_year', 'source_month'],
        tags=['core', 'fact', 'fhvhv_taxi']
    )
}}

with source as (
    select *
    from {{ ref('stg_fhvhv_trips') }}
    where source_path is not null
        and source_year = toUInt16({{ var('year') | int }})
        and source_month = toUInt8({{ var('month') | int }})
),

fingerprinted as (
    select
        *,
        {{ record_fingerprint([
            'hvfhs_license_num',
            'dispatching_base_num',
            'originating_base_num',
            'request_datetime',
            'on_scene_datetime',
            'pickup_datetime',
            'dropoff_datetime',
            'pickup_location_id',
            'dropoff_location_id',
            'trip_miles',
            'trip_time_seconds',
            'base_passenger_fare',
            'tolls',
            'bcf',
            'sales_tax',
            'congestion_surcharge',
            'airport_fee',
            'tips',
            'driver_pay',
            'shared_request_flag',
            'shared_match_flag',
            'access_a_ride_flag',
            'wav_request_flag',
            'wav_match_flag',
            'cbd_congestion_fee'
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
    {{ stable_trip_key('fhvhv', 'source_path', 'source_row_number') }} as trip_sk,

    hvfhs_license_num as hvfhs_license_number,
    originating_base_num as original_base_number,
    dispatching_base_num as dispatching_base_number,

    request_datetime,
    on_scene_datetime,
    pickup_datetime,
    dropoff_datetime,
    toYYYYMMDD(request_datetime) as request_date_id,
    toYYYYMMDD(on_scene_datetime) as on_scene_date_id,
    toYYYYMMDD(pickup_datetime) as pickup_date_id,
    toYYYYMMDD(dropoff_datetime) as dropoff_date_id,
    toInt32OrNull(toString(pickup_location_id)) as pickup_location_id,
    toInt32OrNull(toString(dropoff_location_id)) as dropoff_location_id,

    {{ to_nullable_bool('shared_request_flag') }} as shared_request_flag,
    {{ to_nullable_bool('shared_match_flag') }} as shared_match_flag,
    {{ to_nullable_bool('access_a_ride_flag') }} as access_a_ride_flag,
    {{ to_nullable_bool('wav_request_flag') }} as wav_request_flag,
    {{ to_nullable_bool('wav_match_flag') }} as wav_match_flag,

    toDecimal64OrNull(toString(trip_miles), 3) as trip_miles,
    toInt64OrNull(toString(trip_time_seconds)) as reported_trip_time_seconds,
    toDecimal64OrNull(toString(base_passenger_fare), 2) as base_passenger_fare,
    toDecimal64OrNull(toString(tolls), 2) as tolls,
    toDecimal64OrNull(toString(bcf), 2) as bcf,
    toDecimal64OrNull(toString(sales_tax), 2) as sales_tax,
    toDecimal64OrNull(toString(congestion_surcharge), 2) as congestion_surcharge,
    toDecimal64OrNull(toString(airport_fee), 2) as airport_fee,
    toDecimal64OrNull(toString(cbd_congestion_fee), 2) as cbd_congestion_fee,
    toDecimal64OrNull(toString(tips), 2) as tips,
    toDecimal64OrNull(toString(driver_pay), 2) as driver_pay,

    dateDiff('second', pickup_datetime, dropoff_datetime) as calculated_trip_duration_seconds,
    dateDiff('second', request_datetime, pickup_datetime) as request_to_pickup_seconds,
    dateDiff('second', request_datetime, on_scene_datetime) as request_to_on_scene_seconds,
    dateDiff('second', on_scene_datetime, pickup_datetime) as on_scene_to_pickup_seconds,

    assumeNotNull(source_path) as source_file_id,
    source_row_number,
    toUInt16(assumeNotNull(source_year)) as source_year,
    toUInt8(assumeNotNull(source_month)) as source_month
from numbered
