{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by=['source_year', 'source_month'],
        engine='MergeTree()',
        order_by=[
            'source_year',
            'source_month',
            'source_file_id',
            'row_number'
        ]
    )
}}


with source as (
    select *
    from {{ ref('stg_yellow_trips') }}
    where source_path is not null
        and source_year = toUInt16({{ var('year') | int }})
        and source_month = toUInt8({{ var('month') | int }})
),


select
    {{ stable_trip_key('yellow', 'source_path', 'row_number') }} as trip_sk,

    toInt16OrNull(toString(vendor_id)) as vendor_id,
    toInt16OrNull(toString(rate_code_id)) as rate_code_id,
    toInt16OrNull(toString(payment_type_id)) as payment_type_id,

    pickup_datetime,
    dropoff_datetime,
    toYYYYMMDD(pickup_datetime) as pickup_date_id,
    toYYYYMMDD(dropoff_datetime) as dropoff_date_id,
    toInt32OrNull(toString(pickup_location_id)) as pickup_location_id,
    toInt32OrNull(toString(dropoff_location_id)) as dropoff_location_id,

    toDecimal64OrNull(toString(trip_distance), 3) as trip_distance_miles,
    toInt16OrNull(toString(passenger_count)) as passenger_count,
    toDecimal64OrNull(toString(fare_amount), 2) as fare_amount,
    toDecimal64OrNull(toString(extra), 2) as extra,
    toDecimal64OrNull(toString(mta_tax), 2) as mta_tax,
    toDecimal64OrNull(toString(tip_amount), 2) as tip_amount,
    toDecimal64OrNull(toString(tolls_amount), 2) as tolls_amount,
    toDecimal64OrNull(toString(improvement_surcharge), 2) as improvement_surcharge,
    toDecimal64OrNull(toString(congestion_surcharge), 2) as congestion_surcharge,
    toDecimal64OrNull(toString(cbd_congestion_fee), 2) as cbd_congestion_fee,
    toDecimal64OrNull(toString(airport_fee), 2) as airport_fee,
    toDecimal64OrNull(toString(total_amount), 2) as total_amount,

    dateDiff('second', pickup_datetime, dropoff_datetime) as trip_duration_seconds,

    assumeNotNull(source_path) as source_file_id,
    source_row_number,
    toUInt16(assumeNotNull(source_year)) as source_year,
    toUInt8(assumeNotNull(source_month)) as source_month
from source
