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
    toInt16OrNull(toString(VendorID)) as vendor_id,
    toDateTime64OrNull(
        toString(tpep_pickup_datetime),
        3,
        '{{ var("business_timezone") }}'
    ) as pickup_datetime,
    toDateTime64OrNull(
        toString(tpep_dropoff_datetime),
        3,
        '{{ var("business_timezone") }}'
    ) as dropoff_datetime,
    toInt16OrNull(toString(passenger_count)) as passenger_count,
    toDecimal64OrNull(toString(trip_distance), 3) as trip_distance_miles,
    toInt16OrNull(toString(RatecodeID)) as rate_code_id,
    nullIf(trim(toString(store_and_fwd_flag)), '') as store_and_fwd_flag,
    toInt32OrNull(toString(PULocationID)) as pickup_location_id,
    toInt32OrNull(toString(DOLocationID)) as dropoff_location_id,
    toInt16OrNull(toString(payment_type)) as payment_type_id,
    toDecimal64OrNull(toString(fare_amount), 2) as fare_amount,
    toDecimal64OrNull(toString(extra), 2) as extra,
    toDecimal64OrNull(toString(mta_tax), 2) as mta_tax,
    toDecimal64OrNull(toString(tip_amount), 2) as tip_amount,
    toDecimal64OrNull(toString(tolls_amount), 2) as tolls_amount,
    toDecimal64OrNull(toString(improvement_surcharge), 2) as improvement_surcharge,
    toDecimal64OrNull(toString(total_amount), 2) as total_amount,
    toDecimal64OrNull(toString(congestion_surcharge), 2) as congestion_surcharge,
    toDecimal64OrNull(toString(Airport_fee), 2) as airport_fee,
    toDecimal64OrNull(toString(cbd_congestion_fee), 2) as cbd_congestion_fee,
    nullIf(trim(toString(source_path)), '') as source_path,
    nullIf(trim(toString(source_file)), '') as source_file,
    toUInt16OrNull(toString(source_year)) as source_year,
    toUInt8OrNull(toString(source_month)) as source_month,
    source_etag,
    source_file_id
from source
