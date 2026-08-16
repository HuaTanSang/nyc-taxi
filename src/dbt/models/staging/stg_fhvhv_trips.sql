{{
    table_configuration(
        materialized='view',
        schema='staging',
        alias='stg_fhvhv_trips',
        tags=['staging', 'view', 'fhvhv_taxi_trips']
    )
}}

with source as (
    select *
    from {{ ref('raw_fhvhv_taxi') }}
)

select
    nullIf(trim(toString(hvfhs_license_num)), '') as hvfhs_license_number,
    nullIf(trim(toString(dispatching_base_num)), '') as dispatching_base_number,
    nullIf(trim(toString(originating_base_num)), '') as original_base_number,
    toDateTime64OrNull(toString(request_datetime), 3) as request_datetime,
    toDateTime64OrNull(toString(on_scene_datetime), 3) as on_scene_datetime,
    toDateTime64OrNull(toString(pickup_datetime), 3) as pickup_datetime,
    toDateTime64OrNull(toString(dropoff_datetime), 3) as dropoff_datetime,
    toUInt32OrNull(toString(PULocationID)) as pickup_location_id,
    toUInt32OrNull(toString(DOLocationID)) as dropoff_location_id,
    toFloat64OrNull(toString(trip_miles)) as trip_miles,
    toInt64OrNull(toString(trip_time)) as trip_time_seconds,
    toFloat64OrNull(toString(base_passenger_fare)) as base_passenger_fare,
    toFloat64OrNull(toString(tolls)) as tolls,
    toFloat64OrNull(toString(bcf)) as bcf,
    toFloat64OrNull(toString(sales_tax)) as sales_tax,
    toFloat64OrNull(toString(congestion_surcharge)) as congestion_surcharge,
    toFloat64OrNull(toString(airport_fee)) as airport_fee,
    toFloat64OrNull(toString(tips)) as tips,
    toFloat64OrNull(toString(driver_pay)) as driver_pay,
    nullIf(trim(toString(shared_request_flag)), '') as shared_request_flag,
    nullIf(trim(toString(shared_match_flag)), '') as shared_match_flag,
    nullIf(trim(toString(access_a_ride_flag)), '') as access_a_ride_flag,
    nullIf(trim(toString(wav_request_flag)), '') as wav_request_flag,
    nullIf(trim(toString(wav_match_flag)), '') as wav_match_flag,
    toFloat64OrNull(toString(cbd_congestion_fee)) as cbd_congestion_fee,
    nullIf(trim(toString(source_path)), '') as source_path,
    nullIf(trim(toString(source_file)), '') as source_file,
    toUInt16OrNull(toString(source_year)) as source_year,
    toUInt8OrNull(toString(source_month)) as source_month,
    source_etag, 
    source_file_id,


from source
