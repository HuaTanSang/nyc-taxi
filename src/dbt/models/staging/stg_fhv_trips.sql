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
    nullIf(trim(toString(dispatching_base_num)), '') as dispatching_base_num,
    toDateTime64OrNull(toString(pickup_datetime), 3) as pickup_datetime,
    toDateTime64OrNull(toString(dropOff_datetime), 3) as dropoff_datetime,
    toUInt32OrNull(toString(PUlocationID)) as pickup_location_id,
    toUInt32OrNull(toString(DOlocationID)) as dropoff_location_id,
    toUInt8OrNull(toString(SR_Flag)) as sr_flag,
    nullIf(trim(toString(Affiliated_base_number)), '') as affiliated_base_number,
    nullIf(trim(toString(source_path)), '') as source_path,
    nullIf(trim(toString(source_file)), '') as source_file,
    toUInt16OrNull(toString(source_year)) as source_year,
    toUInt8OrNull(toString(source_month)) as source_month
from source
