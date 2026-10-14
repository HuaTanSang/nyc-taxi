{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        schema='core',
        alias='fct_fhvhv_taxi',
        engine='MergeTree()',
        partition_by=['source_year', 'source_month'],
        order_by=['hvfhs_license_number', 'pickup_datetime', 'dropoff_datetime'],
        settings={
            'allow_nullable_key': 1
        },
        tags=['core', 'fact', 'fhvhv_taxi']
    )
}}

{{ reject_full_refresh() }}

with source as (
    select *
    from {{ ref('stg_fhvhv_trips') }}
    where source_path is not null
        and source_year = toUInt16({{ var('year') | int }})
        and source_month = toUInt8({{ var('month') | int }})
)

select
    hvfhs_license_number,
    original_base_number,
    dispatching_base_number,

    request_datetime,
    on_scene_datetime,
    pickup_datetime,
    dropoff_datetime,
    toYYYYMMDD(request_datetime) as request_date_id,
    toYYYYMMDD(on_scene_datetime) as on_scene_date_id,
    toYYYYMMDD(pickup_datetime) as pickup_date_id,
    toYYYYMMDD(dropoff_datetime) as dropoff_date_id,
    pickup_location_id,
    dropoff_location_id,

    {{ to_nullable_bool('shared_request_flag') }} as shared_request_flag,
    {{ to_nullable_bool('shared_match_flag') }} as shared_match_flag,
    {{ to_nullable_bool('access_a_ride_flag') }} as access_a_ride_flag,
    {{ to_nullable_bool('wav_request_flag') }} as wav_request_flag,
    {{ to_nullable_bool('wav_match_flag') }} as wav_match_flag,

    trip_miles,
    trip_time_seconds as reported_trip_time_seconds,
    base_passenger_fare,
    tolls,
    bcf,
    sales_tax,
    congestion_surcharge,
    airport_fee,
    cbd_congestion_fee,
    tips,
    driver_pay,

    dateDiff('second', pickup_datetime, dropoff_datetime) as calculated_trip_duration_seconds,
    dateDiff('second', request_datetime, pickup_datetime) as request_to_pickup_seconds,
    dateDiff('second', request_datetime, on_scene_datetime) as request_to_on_scene_seconds,
    dateDiff('second', on_scene_datetime, pickup_datetime) as on_scene_to_pickup_seconds,
    toUInt16(assumeNotNull(source_year)) as source_year,
    toUInt8(assumeNotNull(source_month)) as source_month,
    source_path,
    source_file,
    source_etag,
    source_file_id

from source
