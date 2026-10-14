{{
    table_configuration(
        materialized='view',
        schema='staging',
        alias='stg_fhv_trips',
        tags=['staging', 'view', 'fhv_taxi_trips']
    )
}}

with source as (
    select *
    from {{ ref('raw_fhv_taxi') }}
)

select
    nullIf(trim(toString(dispatching_base_num)), '') as dispatching_base_number,
    toDateTime64OrNull(
        toString(pickup_datetime),
        3,
        '{{ var("business_timezone") }}'
    ) as pickup_datetime,
    toDateTime64OrNull(
        toString(dropOff_datetime),
        3,
        '{{ var("business_timezone") }}'
    ) as dropoff_datetime,
    toInt32OrNull(toString(PUlocationID)) as pickup_location_id,
    toInt32OrNull(toString(DOlocationID)) as dropoff_location_id,
    toUInt8OrNull(toString(SR_Flag)) as sr_flag,
    nullIf(trim(toString(Affiliated_base_number)), '') as affiliated_base_number,
    toUInt16OrNull(toString(source_year)) as source_year,
    toUInt8OrNull(toString(source_month)) as source_month,
    nullIf(trim(toString(source_path)), '') as source_path,
    nullIf(trim(toString(source_file)), '') as source_file,
    source_etag,
    source_file_id
from source
