{{
    table_configuration(
        materialized='view',
        schema='staging',
        alias='stg_yellow_trips',
        tags=['staging', 'view', 'yellow_taxi_trips']
    )
}}

with source as (
    select *
    from {{ ref('raw_yellow_taxi') }}
)

select
    toUInt16OrNull(toString(VendorID)) as vendor_id,
    toDateTime64OrNull(toString(tpep_pickup_datetime), 3) as pickup_datetime,
    toDateTime64OrNull(toString(tpep_dropoff_datetime), 3) as dropoff_datetime,
    toFloat64OrNull(toString(passenger_count)) as passenger_count,
    toFloat64OrNull(toString(trip_distance)) as trip_distance,
    toUInt16OrNull(toString(RatecodeID)) as rate_code_id,
    nullIf(trim(toString(store_and_fwd_flag)), '') as store_and_fwd_flag,
    toUInt32OrNull(toString(PULocationID)) as pickup_location_id,
    toUInt32OrNull(toString(DOLocationID)) as dropoff_location_id,
    toInt16OrNull(toString(payment_type)) as payment_type_id,
    toFloat64OrNull(toString(fare_amount)) as fare_amount,
    toFloat64OrNull(toString(extra)) as extra,
    toFloat64OrNull(toString(mta_tax)) as mta_tax,
    toFloat64OrNull(toString(tip_amount)) as tip_amount,
    toFloat64OrNull(toString(tolls_amount)) as tolls_amount,
    toFloat64OrNull(toString(improvement_surcharge)) as improvement_surcharge,
    toFloat64OrNull(toString(total_amount)) as total_amount,
    toFloat64OrNull(toString(congestion_surcharge)) as congestion_surcharge,
    toFloat64OrNull(toString(Airport_fee)) as airport_fee,
    toFloat64OrNull(toString(cbd_congestion_fee)) as cbd_congestion_fee,
    nullIf(trim(toString(source_path)), '') as source_path,
    nullIf(trim(toString(source_file)), '') as source_file,
    toUInt16OrNull(toString(source_year)) as source_year,
    toUInt8OrNull(toString(source_month)) as source_month,
    source_file, 
    source_etag, 
    source_file_id,
    row_number

from source
